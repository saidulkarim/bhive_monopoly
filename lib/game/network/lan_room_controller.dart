import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/config/game_config.dart';
import '../engine/game_engine.dart';
import '../experience/player_palette.dart';
import '../models/game_models.dart';
import 'bluetooth_game_bridge.dart';
import 'bluetooth_host_transport.dart';
import 'lan_action_dispatcher.dart';
import 'lan_avatar_codec.dart';
import 'lan_discovery.dart';
import 'lan_game_codec.dart';
import 'lan_host_factory.dart';
import 'lan_host_transport.dart';
import 'relay_host_transport.dart';
import 'relay_protocol.dart';
import 'lan_trade_coordinator.dart';

/// Versioned, small JSON protocol over WebSockets. A server controls the game.
/// Only the host calls [LanActionDispatcher]. Clients never send dice/state.
class LanMember {
  LanMember({
    required this.id,
    required this.name,
    this.connected = true,
    this.connection,
    this.secret = '',
    this.avatarIndex = 0,
    this.avatarBytes,
  });

  int id;
  final String name;
  bool connected;
  Object? connection;
  String secret;
  final int avatarIndex;
  final Uint8List? avatarBytes;

  Map<String, dynamic> toWire() => <String, dynamic>{
    'id': id,
    'name': name,
    'connected': connected,
    'avatarIndex': avatarIndex,
    'avatarData': LanAvatarCodec.encode(avatarBytes),
  };
}

class LanMoveEvent {
  const LanMoveEvent({
    required this.sequence,
    required this.action,
    required this.actorId,
    this.startPosition,
    this.endPosition,
    this.dice,
  });

  final int sequence;
  final String action;
  final int actorId;
  final int? startPosition;
  final int? endPosition;
  final DiceRoll? dice;

  Map<String, dynamic> toWire() => <String, dynamic>{
    'sequence': sequence,
    'action': action,
    'actorId': actorId,
    'startPosition': startPosition,
    'endPosition': endPosition,
    'dice': dice == null
        ? null
        : <String, dynamic>{'first': dice!.first, 'second': dice!.second},
  };

  factory LanMoveEvent.fromWire(Map<String, dynamic> wire) {
    final sequence = wire['sequence'];
    final action = wire['action'];
    final actorId = wire['actorId'];
    final start = wire['startPosition'];
    final end = wire['endPosition'];
    if (sequence is! int ||
        sequence < 1 ||
        action is! String ||
        action.isEmpty ||
        action.length > 60 ||
        actorId is! int ||
        actorId < 0 ||
        actorId >= 6 ||
        (start != null && (start is! int || start < 0 || start >= 40)) ||
        (end != null && (end is! int || end < 0 || end >= 40))) {
      throw const FormatException('Invalid LAN action event.');
    }
    final roll = wire['dice'];
    DiceRoll? validatedRoll;
    if (roll != null) {
      if (roll is! Map<String, dynamic>) {
        throw const FormatException('Invalid LAN dice.');
      }
      final first = roll['first'];
      final second = roll['second'];
      if (first is! int ||
          first < 1 ||
          first > 6 ||
          second is! int ||
          second < 1 ||
          second > 6) {
        throw const FormatException('Invalid LAN dice values.');
      }
      validatedRoll = DiceRoll(first, second);
    }
    return LanMoveEvent(
      sequence: sequence,
      action: action,
      actorId: actorId,
      startPosition: start,
      endPosition: end,
      dice: validatedRoll,
    );
  }
}

class LanRoomController extends ChangeNotifier {
  LanRoomController._({
    required this.isHost,
    required this.playerName,
    required this.pin,
    required this.maxPlayers,
    required this.port,
    required this.hostIp,
    required this.avatarIndex,
    required this.avatarBytes,
    this.relayUri,
    this.bluetoothAddress,
  });

  static const int protocolVersion = 3; // Phase 6 avatars + room discovery.
  static const int defaultPort = 8787;

  final bool isHost;
  final String playerName;
  final String pin;
  final int maxPlayers;
  final int port;
  final String hostIp;
  final int avatarIndex;
  final Uint8List? avatarBytes;
  final Uri? relayUri;
  final String? bluetoothAddress;
  bool get isBluetoothRoom => bluetoothAddress != null;
  bool get isRelayRoom => relayUri != null;
  // A socket opening is not an authenticated connection. Complete the
  // handshake only after host welcome + room + (for a started match) state.
  Completer<String?>? _handshake;
  bool _welcomed = false;
  bool _receivedRoom = false;
  bool _receivedState = false;
  bool _transportLost = false;
  final LanDiscoveryService _discovery = LanDiscoveryService();
  final LanActionDispatcher _dispatcher = LanActionDispatcher();
  final LanTradeCoordinator _trade = LanTradeCoordinator();
  final List<LanMember> _members = <LanMember>[];
  final Map<Object, LanMember> _peers = <Object, LanMember>{};
  final Random _random = Random.secure();

  LanHostTransport? _host;
  WebSocketChannel? _channel;
  BluetoothGuestConnection? _bluetoothClient;
  StreamSubscription<dynamic>? _subscription;
  int _connectionEpoch = 0;
  bool _closed = false;
  bool connected = true;
  bool started = false;
  bool paused = false;
  bool reconnecting = false;
  bool _rejoinUnavailable = false;

  /// The relay explicitly removed this room, or the host rejected its token.
  bool get rejoinUnavailable => _rejoinUnavailable;
  int? playerId;
  String _reconnectSecret = '';
  GameEngine? game;
  LanMoveEvent? lastEvent;
  int _sequence = 0;
  int _errorRevision = 0;
  String? lastError;

  List<LanMember> get members => List<LanMember>.unmodifiable(_members);
  LanPendingTrade? get pendingTrade => _trade.pending;
  int get errorRevision => _errorRevision;
  List<String> get hostAddresses => _host?.addresses ?? const <String>[];
  int get connectedPlayers => _members.where((m) => m.connected).length;
  bool get canStart =>
      isHost && connected && !paused && !started && connectedPlayers >= 2;
  bool get isMyTurn =>
      started &&
      !paused &&
      connected &&
      game != null &&
      playerId == game!.currentPlayerId;
  bool get isMyAuctionBid =>
      started &&
      !paused &&
      connected &&
      game?.phase == TurnPhase.auction &&
      game!.auction!.bidderId == playerId;

  static Future<LanRoomController> host({
    required String name,
    int maxPlayers = 4,
    int port = defaultPort,
    int avatarIndex = 0,
    Uint8List? avatarBytes,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Host a Wi-Fi game on Android/desktop, then join from Web.',
      );
    }
    if (name.trim().isEmpty || maxPlayers < 2 || maxPlayers > 6) {
      throw ArgumentError('Enter a name and choose 2–6 player slots.');
    }
    final secret = Random.secure().nextInt(900000) + 100000;
    final room = LanRoomController._(
      isHost: true,
      playerName: name.trim(),
      pin: secret.toString(),
      maxPlayers: maxPlayers,
      port: port,
      hostIp: '',
      avatarIndex: LanAvatarCodec.preset(avatarIndex),
      avatarBytes: LanAvatarCodec.decode(LanAvatarCodec.encode(avatarBytes)),
    );
    room.playerId = 0;
    room._members.add(
      LanMember(
        id: 0,
        name: name.trim(),
        avatarIndex: room.avatarIndex,
        avatarBytes: room.avatarBytes,
      ),
    );
    try {
      room._host = createLanHostTransport(port);
      await room._host!.start(
        onMessage: room._onHostMessage,
        onDisconnect: room._onHostDisconnect,
      );
      // Discovery is best-effort; an unavailable UDP broadcast must never
      // prevent hosting via the existing manual-IP connection.
      try {
        final id = List<int>.generate(
          12,
          (_) => room._random.nextInt(256),
        ).map((v) => v.toRadixString(16).padLeft(2, '0')).join();
        await room._discovery.startAdvertising(
          LanDiscoveryInfo(
            roomId: id,
            name: name.trim(),
            players: 1,
            capacity: maxPlayers,
            hostPort: port,
            protocol: protocolVersion,
          ),
        );
      } catch (_) {
        /* Manual join remains available. */
      }
      return room;
    } catch (_) {
      await room._discovery.close();
      await room._host?.close();
      rethrow;
    }
  }

  static Future<LanRoomController> join({
    required String name,
    required String hostIp,
    required String pin,
    int port = defaultPort,
    int avatarIndex = 0,
    Uint8List? avatarBytes,
  }) async {
    if (name.trim().isEmpty || hostIp.trim().isEmpty || pin.trim().isEmpty) {
      throw ArgumentError('Name, host IP and room PIN are required.');
    }
    final room = LanRoomController._(
      isHost: false,
      playerName: name.trim(),
      pin: pin.trim(),
      maxPlayers: 6,
      port: port,
      hostIp: hostIp.trim(),
      avatarIndex: LanAvatarCodec.preset(avatarIndex),
      avatarBytes: LanAvatarCodec.decode(LanAvatarCodec.encode(avatarBytes)),
    );
    try {
      await room._connect();
    } catch (_) {
      await room.shutdown();
      rethrow;
    }
    return room;
  }

  /// Android-only secure Bluetooth Classic room. No internet, router, or
  /// ASP.NET server is required. Pair devices in Android settings first.
  static Future<LanRoomController> hostBluetooth({
    required String name,
    int maxPlayers = 4,
    int avatarIndex = 0,
    Uint8List? avatarBytes,
  }) async {
    if (!BluetoothGameBridge.isSupported) {
      throw UnsupportedError('Bluetooth hosting is available on Android only.');
    }
    if (name.trim().isEmpty || maxPlayers < 2 || maxPlayers > 6) {
      throw ArgumentError('Enter a name and choose 2–6 player slots.');
    }
    final pin = (Random.secure().nextInt(900000) + 100000).toString();
    final room = LanRoomController._(
      isHost: true,
      playerName: name.trim(),
      pin: pin,
      maxPlayers: maxPlayers,
      port: 0,
      hostIp: '',
      bluetoothAddress: '', // Host has no remote-device address.
      avatarIndex: LanAvatarCodec.preset(avatarIndex),
      avatarBytes: LanAvatarCodec.decode(LanAvatarCodec.encode(avatarBytes)),
    );
    room.playerId = 0;
    room._members.add(
      LanMember(
        id: 0,
        name: name.trim(),
        avatarIndex: room.avatarIndex,
        avatarBytes: room.avatarBytes,
      ),
    );
    try {
      room._host = BluetoothHostTransport();
      await room._host!.start(
        onMessage: room._onHostMessage,
        onDisconnect: room._onHostDisconnect,
      );
      return room;
    } catch (_) {
      await room._host?.close();
      await room._discovery.close();
      rethrow;
    }
  }

  /// Join a paired Android Bluetooth host by its device address and PIN.
  /// Gameplay still uses the same hello/welcome/state/action protocol.
  static Future<LanRoomController> joinBluetooth({
    required String name,
    required String deviceAddress,
    required String pin,
    int avatarIndex = 0,
    Uint8List? avatarBytes,
  }) async {
    if (!BluetoothGameBridge.isSupported) {
      throw UnsupportedError('Bluetooth joining is available on Android only.');
    }
    if (name.trim().isEmpty || !RegExp(r'^\d{6}$').hasMatch(pin.trim())) {
      throw ArgumentError('Enter a player name and 6-digit room PIN.');
    }
    final address = BluetoothGameDevice.fromMap(<String, String>{
      'address': deviceAddress,
      'name': 'Host',
    }).address;
    final room = LanRoomController._(
      isHost: false,
      playerName: name.trim(),
      pin: pin.trim(),
      maxPlayers: 6,
      port: 0,
      hostIp: '',
      bluetoothAddress: address,
      avatarIndex: LanAvatarCodec.preset(avatarIndex),
      avatarBytes: LanAvatarCodec.decode(LanAvatarCodec.encode(avatarBytes)),
    );
    try {
      await room._connect();
      return room;
    } catch (_) {
      await room.shutdown();
      rethrow;
    }
  }

  /// Create a server-relayed room on Web or Android. The creating Flutter
  /// client remains the authoritative game engine. The relay only routes
  /// WebSocket traffic; a dedicated server process must be running.
  static Future<LanRoomController> hostViaRelay({
    required String name,
    required Uri endpoint,
    int maxPlayers = 4,
    int avatarIndex = 0,
    Uint8List? avatarBytes,
  }) async {
    if (name.trim().isEmpty || maxPlayers < 2 || maxPlayers > 6) {
      throw ArgumentError('Enter a name and choose 2–6 player slots.');
    }
    final room = LanRoomController._(
      isHost: true,
      playerName: name.trim(),
      pin: RelayProtocol.roomCode(),
      maxPlayers: maxPlayers,
      port: endpoint.hasPort
          ? endpoint.port
          : (endpoint.scheme == 'wss' ? 443 : 80),
      hostIp: endpoint.host,
      relayUri: endpoint,
      avatarIndex: LanAvatarCodec.preset(avatarIndex),
      avatarBytes: LanAvatarCodec.decode(LanAvatarCodec.encode(avatarBytes)),
    );
    room.playerId = 0;
    room._members.add(
      LanMember(
        id: 0,
        name: name.trim(),
        avatarIndex: room.avatarIndex,
        avatarBytes: room.avatarBytes,
      ),
    );
    try {
      room._host = RelayHostTransport(
        endpoint: endpoint,
        code: room.pin,
        capacity: maxPlayers,
        onConnectionLost: () {
          if (room._closed) return;
          room.connected = false;
          room.paused = true;
          room._rejoinUnavailable = true;
          room._error('Relay disconnected. The host must create a new room.');
        },
      );
      await room._host!.start(
        onMessage: room._onHostMessage,
        onDisconnect: room._onHostDisconnect,
      );
      return room;
    } catch (_) {
      await room._host?.close();
      await room._discovery.close();
      rethrow;
    }
  }

  /// Connect as a guest to an online room using the shared room code.
  /// The existing hello/welcome/state/action protocol remains unchanged.
  static Future<LanRoomController> joinRelay({
    required String name,
    required Uri endpoint,
    required String roomCode,
    int avatarIndex = 0,
    Uint8List? avatarBytes,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('Please enter your player name.');
    }
    final code = RelayProtocol.verifiedCode(roomCode);
    final room = LanRoomController._(
      isHost: false,
      playerName: name.trim(),
      pin: code,
      maxPlayers: 6,
      port: endpoint.hasPort
          ? endpoint.port
          : (endpoint.scheme == 'wss' ? 443 : 80),
      hostIp: endpoint.host,
      relayUri: endpoint,
      avatarIndex: LanAvatarCodec.preset(avatarIndex),
      avatarBytes: LanAvatarCodec.decode(LanAvatarCodec.encode(avatarBytes)),
    );
    try {
      await room._connect();
      return room;
    } catch (_) {
      await room.shutdown();
      rethrow;
    }
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  void _error(String message) {
    lastError = message;
    _errorRevision++;
    _notify();
  }

  String _newSecret() => List<int>.generate(
    24,
    (_) => _random.nextInt(256),
  ).map((v) => v.toRadixString(16).padLeft(2, '0')).join();

  void _sendTo(Object peer, Map<String, dynamic> packet) {
    _host?.send(peer, jsonEncode(packet));
  }

  void _sendToGuest(LanMember member, Map<String, dynamic> packet) {
    if (member.connection != null && member.connected) {
      _sendTo(member.connection!, packet);
    }
  }

  void _broadcast(Map<String, dynamic> packet) {
    // Encode once for every connected guest, rather than once per recipient.
    // Keep the wire payload and delivery order unchanged.
    String? payload;
    for (final member in _members.skip(1)) {
      if (member.connected && member.connection != null) {
        _host?.send(member.connection!, payload ??= jsonEncode(packet));
      }
    }
  }

  Map<String, dynamic> _roomPacket() => <String, dynamic>{
    'type': 'room',
    'started': started,
    'paused': paused,
    'members': [for (final member in _members) member.toWire()],
  };

  void _broadcastRoom() {
    if (isHost && !isRelayRoom && !isBluetoothRoom && !started) {
      _discovery.updateAdvertisingCount(connectedPlayers);
    }
    _broadcast(_roomPacket());
    _notify();
  }

  void _sendWelcome(LanMember m) => _sendToGuest(m, <String, dynamic>{
    'type': 'welcome',
    'id': m.id,
    'token': m.secret,
  });

  void _onHostMessage(Object peer, String raw) {
    if (_closed) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['type'] == 'hello') {
        _handleHello(peer, data);
        return;
      }
      final member = _peers[peer];
      if (member == null || !member.connected || !started || paused) {
        _sendTo(peer, <String, dynamic>{
          'type': 'error',
          'message': 'Join an active room before sending actions.',
        });
        return;
      }
      if (data['type'] != 'action') {
        _sendTo(peer, <String, dynamic>{
          'type': 'error',
          'message': 'Unknown message type.',
        });
        return;
      }
      _execute(member.id, data, errorRecipient: peer);
    } catch (error) {
      _sendTo(peer, <String, dynamic>{
        'type': 'error',
        'message': 'Malformed message: ${error.runtimeType}',
      });
    }
  }

  void _handleHello(Object peer, Map<String, dynamic> packet) {
    if (_peers.containsKey(peer)) return;
    if (packet['version'] != protocolVersion || packet['pin'] != pin) {
      _sendTo(peer, <String, dynamic>{
        'type': 'error',
        'message': 'Incorrect room PIN or incompatible game version.',
      });
      return;
    }
    final token = packet['token'];
    if (started) {
      // A started room is strictly closed to new participants. Rejoining
      // requires the 192-bit secret assigned at the original handshake.
      LanMember? returning;
      for (final member in _members.skip(1)) {
        if (member.secret.isNotEmpty && member.secret == token) {
          returning = member;
          break;
        }
      }
      if (returning == null) {
        _sendTo(peer, <String, dynamic>{
          'type': 'error',
          'message': 'Match in progress. Only disconnected players may rejoin.',
        });
        return;
      }
      // Replace a stale socket even if TCP has not reported disconnect yet.
      if (returning.connection != null) _peers.remove(returning.connection);
      returning.connection = peer;
      returning.connected = true;
      _peers[peer] = returning;
      paused = _members
          .skip(1)
          .any((m) => !m.connected && !(game?.players[m.id].bankrupt ?? false));
      _sendWelcome(returning);
      _broadcastRoom();
      _sendToGuest(returning, _statePacket());
      return;
    }
    if (_members.length >= maxPlayers) {
      _sendTo(peer, <String, dynamic>{
        'type': 'error',
        'message': 'This lobby is full.',
      });
      return;
    }
    final name = packet['name'];
    if (name is! String || name.trim().isEmpty || name.trim().length > 24) {
      _sendTo(peer, <String, dynamic>{
        'type': 'error',
        'message': 'Please enter a valid name (1–24 characters).',
      });
      return;
    }
    if (_members.any(
      (m) => m.name.toLowerCase() == name.trim().toLowerCase(),
    )) {
      _sendTo(peer, <String, dynamic>{
        'type': 'error',
        'message': 'A player with this name already joined.',
      });
      return;
    }
    final member = LanMember(
      id: _members.length,
      name: name.trim(),
      connection: peer,
      secret: _newSecret(),
      avatarIndex: LanAvatarCodec.preset(packet['avatarIndex']),
      avatarBytes: LanAvatarCodec.decode(packet['avatarData']),
    );
    _members.add(member);
    _peers[peer] = member;
    _sendWelcome(member);
    _broadcastRoom();
  }

  void _onHostDisconnect(Object peer) {
    final member = _peers.remove(peer);
    if (member == null || _closed) return;
    member.connection = null;
    member.connected = false;
    if (started &&
        _trade.pending != null &&
        (_trade.pending!.offer.fromPlayerId == member.id ||
            _trade.pending!.offer.toPlayerId == member.id)) {
      _trade.dismiss();
    }
    if (!started) {
      _members.remove(member);
      for (var i = 0; i < _members.length; i++) {
        _members[i].id = i;
      }
      for (final guest in _members.skip(1)) {
        _sendWelcome(guest); // Lobby indices may shift when someone leaves.
      }
    } else {
      paused = _members
          .skip(1)
          .any((m) => !m.connected && !(game?.players[m.id].bankrupt ?? false));
    }
    _broadcastRoom();
    if (started && game != null) _broadcast(_statePacket());
  }

  void startMatch() {
    if (!canStart) {
      throw StateError('At least two connected players are required.');
    }
    started = true;
    paused = false;
    if (!isRelayRoom && !isBluetoothRoom) {
      unawaited(_discovery.stopAdvertising());
    }
    game = GameEngine(
      playerNames: [for (final member in _members) member.name],
      colorIndices: PlayerColorPreferences.instance.selections,
    );
    _sequence = 0;
    _trade.dismiss();
    for (final guest in _members.skip(1)) {
      _sendWelcome(guest);
    }
    _broadcastRoom();
    _broadcast(_statePacket());
  }

  Map<String, dynamic> _statePacket() => <String, dynamic>{
    'type': 'state',
    'state': LanGameCodec.encode(game!),
    'paused': paused,
    'event': lastEvent?.toWire(),
    'pendingTrade': _trade.pending?.toWire(),
  };

  void _execute(
    int actorId,
    Map<String, dynamic> packet, {
    Object? errorRecipient,
  }) {
    if (game == null || paused || !started) return;
    try {
      final action = packet['action'];
      if (action is! String) throw const GameRuleException('Invalid action.');
      final original = game!.players[actorId].position;
      DiceRoll? dice;
      if (const <String>{
        'offerTrade',
        'acceptTrade',
        'declineTrade',
        'cancelTrade',
      }.contains(action)) {
        _applyTradeAction(actorId, action, packet);
      } else {
        if (_trade.pending != null) {
          throw const GameRuleException('Respond to the pending trade first.');
        }
        dice = _dispatcher.apply(
          game!,
          actorId,
          action,
          index: packet['index'] as int?,
          amount: packet['amount'] as int?,
        );
      }
      lastEvent = LanMoveEvent(
        sequence: ++_sequence,
        action: action,
        actorId: actorId,
        startPosition: original,
        endPosition: game!.players[actorId].position,
        dice: dice,
      );
      _broadcast(_statePacket());
      _notify();
    } on GameRuleException catch (error) {
      // A failed acceptance may invalidate/clear the offer; tell every guest.
      if (game != null && started) _broadcast(_statePacket());
      if (errorRecipient != null) {
        _sendTo(errorRecipient, <String, dynamic>{
          'type': 'error',
          'message': error.message,
        });
      } else {
        _error(error.message);
      }
    } catch (_) {
      if (errorRecipient != null) {
        _sendTo(errorRecipient, <String, dynamic>{
          'type': 'error',
          'message': 'Invalid command parameters.',
        });
      } else {
        _error('Invalid command parameters.');
      }
    }
  }

  /// Server-only: identity is taken from the authenticated WebSocket, never
  /// from the untrusted payload. All game rules run on the authoritative host.
  void _applyTradeAction(
    int actorId,
    String action,
    Map<String, dynamic> packet,
  ) {
    switch (action) {
      case 'offerTrade':
        final raw = packet['trade'] as Map<String, dynamic>;
        final recipient = raw['toPlayerId'] as int;
        if (recipient < 0 ||
            recipient >= _members.length ||
            !_members[recipient].connected) {
          throw const GameRuleException('The trade recipient is unavailable.');
        }
        _trade.propose(
          game!,
          actorId,
          TradeOffer(
            fromPlayerId: actorId,
            toPlayerId: recipient,
            cashFrom: raw['cashFrom'] as int,
            cashTo: raw['cashTo'] as int,
            propertiesFrom: (raw['propertiesFrom'] as List).cast<int>(),
            propertiesTo: (raw['propertiesTo'] as List).cast<int>(),
          ),
        );
        break;
      case 'acceptTrade':
      case 'declineTrade':
        _trade.respond(
          game!,
          actorId,
          packet['tradeId'] as int,
          accept: action == 'acceptTrade',
        );
        break;
      case 'cancelTrade':
        _trade.cancel(actorId, packet['tradeId'] as int);
        break;
      default:
        throw const GameRuleException('Unknown trade action.');
    }
  }

  Future<void> sendTradeOffer({
    required int toPlayerId,
    int cashFrom = 0,
    int cashTo = 0,
    List<int> propertiesFrom = const <int>[],
    List<int> propertiesTo = const <int>[],
  }) => _sendPacket(<String, dynamic>{
    'type': 'action',
    'action': 'offerTrade',
    'trade': <String, dynamic>{
      'toPlayerId': toPlayerId,
      'cashFrom': cashFrom,
      'cashTo': cashTo,
      'propertiesFrom': propertiesFrom,
      'propertiesTo': propertiesTo,
    },
  });

  Future<void> respondToTrade(String action, int requestId) {
    if (!const <String>{
      'acceptTrade',
      'declineTrade',
      'cancelTrade',
    }.contains(action)) {
      throw ArgumentError('Invalid trade response.');
    }
    return _sendPacket(<String, dynamic>{
      'type': 'action',
      'action': action,
      'tradeId': requestId,
    });
  }

  Future<void> sendAction(String action, {int? index, int? amount}) =>
      _sendPacket(<String, dynamic>{
        'type': 'action',
        'action': action,
        'index': ?index,
        'amount': ?amount,
      });

  Future<void> _sendPacket(Map<String, dynamic> packet) async {
    if (_closed || !connected || paused || !started || game == null) {
      _error('Room unavailable or waiting for another player to reconnect.');
      return;
    }
    if (isHost) {
      _execute(0, packet);
    } else {
      final epoch = _connectionEpoch;
      try {
        final payload = jsonEncode(packet);
        if (isBluetoothRoom) {
          final client = _bluetoothClient;
          if (client == null) {
            throw StateError('Bluetooth transport unavailable.');
          }
          await client.send(payload);
        } else {
          final channel = _channel;
          if (channel == null) throw StateError('WebSocket unavailable.');
          channel.sink.add(
            isRelayRoom
                ? jsonEncode(<String, dynamic>{
                    'kind': 'to_host',
                    'payload': payload,
                  })
                : payload,
          );
        }
      } catch (_) {
        // Never replay an action whose delivery/commit outcome is unknown.
        _onClientLost(epoch);
      }
    }
  }

  Future<void> _connect() async {
    if (_closed) return;
    final epoch = ++_connectionEpoch;
    connected = false;
    reconnecting = true;
    paused = true;
    _welcomed = false;
    _receivedRoom = false;
    _receivedState = false;
    _transportLost = false;
    final handshake = Completer<String?>();
    _handshake = handshake;
    _notify();
    try {
      if (isBluetoothRoom) {
        final client = BluetoothGuestConnection();
        _bluetoothClient = client;
        _listenClient(client.messages, epoch);
        // The Android native call cannot safely be cancelled by Dart Future
        // timeout. Keep the single-flight lock until that call settles.
        await client.connect(bluetoothAddress!);
        if (_closed || epoch != _connectionEpoch) return;
        if (_transportLost) {
          throw StateError('Host connection lost. Reconnect to continue.');
        }
        await client.send(jsonEncode(_helloPacket()));
      } else {
        final uri =
            relayUri ?? Uri(scheme: 'ws', host: hostIp, port: port, path: '/');
        final channel = WebSocketChannel.connect(uri);
        _channel = channel;
        _listenClient(channel.stream, epoch);
        await channel.ready.timeout(
          const Duration(
            seconds: GameConfig.multiplayerSocketOpenTimeoutSeconds,
          ),
        );
        if (_closed || epoch != _connectionEpoch) return;
        if (_transportLost) {
          throw StateError('Host connection lost. Reconnect to continue.');
        }
        if (isRelayRoom) {
          channel.sink.add(
            jsonEncode(<String, dynamic>{'kind': 'join', 'room': pin}),
          );
        } else {
          _sendHello(channel);
        }
      }
      final failure = await handshake.future.timeout(
        const Duration(seconds: GameConfig.multiplayerHandshakeTimeoutSeconds),
        onTimeout: () =>
            'Host synchronization timed out. Reconnect to continue.',
      );
      if (_closed || epoch != _connectionEpoch) return;
      if (failure != null) throw StateError(failure);
      if (_transportLost) {
        throw StateError('Host connection lost. Reconnect to continue.');
      }
      // Only now may the UI send new commands. No queued actions are replayed.
      connected = true;
      reconnecting = false;
      _handshake = null;
      _notify();
    } catch (error) {
      if (_closed || epoch != _connectionEpoch) return;
      // Reject all late callbacks before cleanup; retain the reconnect lock
      // until the old transport is released.
      ++_connectionEpoch;
      _handshake = null;
      connected = false;
      paused = true;
      try {
        await _closeGuestTransport();
      } catch (_) {
        // Report the original connection failure, not a secondary close error.
      }
      if (_closed) return;
      reconnecting = false;
      final message = error is StateError
          ? error.message.toString()
          : (isBluetoothRoom
                ? 'Bluetooth connection failed: ${error.runtimeType}'
                : 'Could not connect to the host.');
      _error(message);
      throw StateError(message);
    }
  }

  void _listenClient(Stream<dynamic> stream, int epoch) {
    _subscription = stream.listen(
      (message) {
        if (_closed || epoch != _connectionEpoch || _transportLost) return;
        _onClientMessage(message);
      },
      onDone: () => _onClientLost(epoch),
      onError: (Object _) => _onClientLost(epoch),
      cancelOnError: true,
    );
  }

  Future<void> _closeGuestTransport() async {
    final subscription = _subscription;
    final channel = _channel;
    final bluetooth = _bluetoothClient;
    _subscription = null;
    _channel = null;
    _bluetoothClient = null;
    try {
      await subscription?.cancel();
    } catch (_) {}
    try {
      if (channel != null) {
        await channel.sink.close().timeout(
          const Duration(
            seconds: GameConfig.multiplayerSocketCloseTimeoutSeconds,
          ),
        );
      }
    } catch (_) {}
    // Do not start a new Bluetooth connection until native stop has settled.
    await bluetooth?.close();
  }

  void _completeHandshake(String? failure) {
    final handshake = _handshake;
    if (failure != null) _transportLost = true;
    if (handshake != null && !handshake.isCompleted) {
      handshake.complete(failure);
    }
  }

  void _maybeCompleteHandshake() {
    if (_welcomed && _receivedRoom && (!started || _receivedState)) {
      _completeHandshake(null);
    }
  }

  Map<String, dynamic> _helloPacket() => <String, dynamic>{
    'type': 'hello',
    'version': protocolVersion,
    'name': playerName,
    'pin': pin,
    if (_reconnectSecret.isNotEmpty) 'token': _reconnectSecret,
    'avatarIndex': avatarIndex,
    'avatarData': LanAvatarCodec.encode(avatarBytes),
  };

  void _sendHello(WebSocketChannel channel) {
    final payload = jsonEncode(_helloPacket());
    channel.sink.add(
      isRelayRoom
          ? jsonEncode(<String, dynamic>{'kind': 'to_host', 'payload': payload})
          : payload,
    );
  }

  void _onClientLost(
    int epoch, {
    String message = 'Host connection lost. Reconnect to continue.',
  }) {
    if (_closed || epoch != _connectionEpoch || _transportLost) return;
    _transportLost = true;
    connected = false;
    paused = true;
    if (reconnecting) {
      // The connecting coroutine owns cleanup and releases its lock.
      _completeHandshake(message);
      return;
    }
    ++_connectionEpoch;
    _error(message);
  }

  void _onClientMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      if (isRelayRoom && data['kind'] == 'joined') {
        if (!reconnecting || _welcomed) return;
        final channel = _channel;
        if (channel != null) _sendHello(channel);
        return;
      }
      if (isRelayRoom && data['kind'] == 'error') {
        final message =
            data['message']?.toString() ?? 'Cannot join relay room.';
        if (reconnecting) {
          if (started && message == 'Room not found. Check the room code.') {
            _rejoinUnavailable = true;
          }
          _completeHandshake(message);
        } else {
          _error(message);
        }
        return;
      }
      switch (data['type']) {
        case 'welcome':
          final id = data['id'];
          final token = data['token'];
          if (id is! int ||
              id < 0 ||
              id >= 6 ||
              token is! String ||
              token.isEmpty ||
              (started &&
                  _reconnectSecret.isNotEmpty &&
                  (id != playerId || token != _reconnectSecret))) {
            throw const FormatException('Invalid room identity.');
          }
          playerId = id;
          _reconnectSecret = token;
          _welcomed = true;
          break;
        case 'room':
          if (reconnecting && !_welcomed) {
            throw const FormatException('Missing welcome.');
          }
          final incomingStarted = data['started'] as bool;
          final incomingPaused = data['paused'] as bool;
          final incomingMembers = (data['members'] as List).map((entry) {
            final m = entry as Map<String, dynamic>;
            return LanMember(
              id: m['id'] as int,
              name: m['name'] as String,
              connected: m['connected'] as bool,
              avatarIndex: LanAvatarCodec.preset(m['avatarIndex']),
              avatarBytes: LanAvatarCodec.decode(m['avatarData']),
            );
          }).toList();
          if (incomingMembers.isEmpty ||
              incomingMembers.length > 6 ||
              (started && !incomingStarted) ||
              !incomingMembers.any((m) => m.id == playerId && m.connected)) {
            throw const FormatException('Invalid room membership.');
          }
          _members
            ..clear()
            ..addAll(incomingMembers);
          started = incomingStarted;
          paused = incomingPaused;
          _receivedRoom = true;
          break;
        case 'state':
          if (reconnecting && (!_welcomed || !_receivedRoom)) {
            throw const FormatException('Missing room handshake.');
          }
          // Parse the complete envelope before mutating any game fields.
          // LanGameCodec also validates the entire board before applying it.
          final snapshot = data['state'] as Map<String, dynamic>;
          final incomingPaused = data['paused'];
          if (incomingPaused is! bool) {
            throw const FormatException('Missing room pause state.');
          }
          final tradeWire = data['pendingTrade'];
          final incomingTrade = tradeWire == null
              ? null
              : LanPendingTrade.fromWire(tradeWire as Map<String, dynamic>);
          final event = data['event'];
          final incomingEvent = event == null
              ? null
              : LanMoveEvent.fromWire(event as Map<String, dynamic>);
          if (game == null) {
            game = LanGameCodec.decode(snapshot);
          } else {
            LanGameCodec.apply(game!, snapshot);
          }
          started = true;
          paused = incomingPaused;
          _trade.pending = incomingTrade;
          lastEvent = incomingEvent;
          _receivedState = true;
          break;
        case 'error':
          final message =
              data['message'] as String? ?? 'Unknown network error.';
          if (isRelayRoom &&
              message == 'The room host disconnected. This room is closed.') {
            _rejoinUnavailable = true;
            _onClientLost(_connectionEpoch, message: message);
          } else if (reconnecting) {
            if (started &&
                message ==
                    'Match in progress. Only disconnected players may rejoin.') {
              _rejoinUnavailable = true;
            }
            _completeHandshake(message);
          } else {
            _error(message);
          }
          return;
      }
      if (reconnecting) {
        _maybeCompleteHandshake();
      } else {
        _notify();
      }
    } catch (_) {
      const message = 'Received an invalid game update from the host.';
      if (reconnecting) {
        _completeHandshake(message);
      } else {
        // The client cannot safely act on a stale projection. Require a new
        // authoritative snapshot via authenticated rejoin.
        _onClientLost(_connectionEpoch, message: message);
      }
    }
  }

  Future<void> reconnect() async {
    if (isHost || _closed || _rejoinUnavailable || reconnecting || connected) {
      return;
    }
    // Acquire synchronously, before the first await (including socket close).
    reconnecting = true;
    ++_connectionEpoch;
    _notify();
    try {
      await _closeGuestTransport();
    } catch (_) {
      if (!_closed) {
        reconnecting = false;
        _error('Connection failed. Rejoin the room.');
      }
      rethrow;
    }
    if (!_closed) await _connect();
  }

  Future<void> shutdown() async {
    if (_closed) return;
    _closed = true;
    ++_connectionEpoch;
    _completeHandshake('Room closed.');
    _handshake = null;
    try {
      await _closeGuestTransport();
    } finally {
      try {
        await _host?.close();
      } finally {
        _host = null;
        try {
          await _discovery.close();
        } finally {
          super.dispose();
        }
      }
    }
  }
}

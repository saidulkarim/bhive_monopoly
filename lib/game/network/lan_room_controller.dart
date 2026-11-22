import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../engine/game_engine.dart';
import '../models/game_models.dart';
import 'lan_action_dispatcher.dart';
import 'lan_avatar_codec.dart';
import 'lan_discovery.dart';
import 'lan_game_codec.dart';
import 'lan_host_factory.dart';
import 'lan_host_transport.dart';
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
  final LanDiscoveryService _discovery = LanDiscoveryService();
  final LanActionDispatcher _dispatcher = LanActionDispatcher();
  final LanTradeCoordinator _trade = LanTradeCoordinator();
  final List<LanMember> _members = <LanMember>[];
  final Map<Object, LanMember> _peers = <Object, LanMember>{};
  final Random _random = Random.secure();

  LanHostTransport? _host;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  int _connectionEpoch = 0;
  bool _closed = false;
  bool connected = true;
  bool started = false;
  bool paused = false;
  bool reconnecting = false;
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
  bool get canStart => isHost && !started && connectedPlayers >= 2;
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
      await room._discovery.close();
      rethrow;
    }
    return room;
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
    for (final member in _members.skip(1)) {
      _sendToGuest(member, packet);
    }
  }

  Map<String, dynamic> _roomPacket() => <String, dynamic>{
    'type': 'room',
    'started': started,
    'paused': paused,
    'members': [for (final member in _members) member.toWire()],
  };

  void _broadcastRoom() {
    if (isHost && !started) {
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
    unawaited(_discovery.stopAdvertising());
    game = GameEngine(
      playerNames: [for (final member in _members) member.name],
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
    if (_closed || !connected || paused || !started) {
      _error('Room unavailable or waiting for another player to reconnect.');
      return;
    }
    if (isHost) {
      _execute(0, packet);
    } else {
      try {
        _channel?.sink.add(jsonEncode(packet));
      } catch (_) {
        _error('Connection failed. Rejoin the room.');
      }
    }
  }

  Future<void> _connect() async {
    final currentEpoch = ++_connectionEpoch;
    reconnecting = true;
    _notify();
    final uri = Uri(scheme: 'ws', host: hostIp, port: port, path: '/');
    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _subscription = channel.stream.listen(
        (message) {
          if (currentEpoch != _connectionEpoch || _closed) return;
          _onClientMessage(message);
        },
        onDone: () {
          _onClientLost(currentEpoch);
        },
        onError: (_) {
          _onClientLost(currentEpoch);
        },
        cancelOnError: true,
      );
      await channel.ready.timeout(const Duration(seconds: 8));
      if (_closed || currentEpoch != _connectionEpoch) return;
      connected = true;
      reconnecting = false;
      channel.sink.add(
        jsonEncode(<String, dynamic>{
          'type': 'hello',
          'version': protocolVersion,
          'name': playerName,
          'pin': pin,
          if (_reconnectSecret.isNotEmpty) 'token': _reconnectSecret,
          'avatarIndex': avatarIndex,
          'avatarData': LanAvatarCodec.encode(avatarBytes),
        }),
      );
      _notify();
    } catch (error) {
      if (currentEpoch != _connectionEpoch) return;
      connected = false;
      reconnecting = false;
      await _subscription?.cancel();
      _subscription = null;
      await _channel?.sink.close();
      _channel = null;
      _error('Could not connect to $hostIp:$port — $error');
      rethrow;
    }
  }

  void _onClientLost(int epoch) {
    if (_closed || epoch != _connectionEpoch) return;
    connected = false;
    reconnecting = false;
    paused = true;
    _error('Host connection lost. Reconnect to continue.');
  }

  void _onClientMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      switch (data['type']) {
        case 'welcome':
          playerId = data['id'] as int;
          _reconnectSecret = data['token'] as String;
          connected = true;
          break;
        case 'room':
          _members
            ..clear()
            ..addAll(
              (data['members'] as List).map((entry) {
                final m = entry as Map<String, dynamic>;
                return LanMember(
                  id: m['id'] as int,
                  name: m['name'] as String,
                  connected: m['connected'] as bool,
                  avatarIndex: LanAvatarCodec.preset(m['avatarIndex']),
                  avatarBytes: LanAvatarCodec.decode(m['avatarData']),
                );
              }),
            );
          started = data['started'] as bool;
          paused = data['paused'] as bool;
          break;
        case 'state':
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
          break;
        case 'error':
          _error(data['message'] as String? ?? 'Unknown network error.');
          return;
      }
      _notify();
    } catch (_) {
      _error('Received an invalid game update from the host.');
    }
  }

  Future<void> reconnect() async {
    if (isHost || _closed || reconnecting || connected) return;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    await _connect();
  }

  Future<void> shutdown() async {
    if (_closed) return;
    _closed = true;
    ++_connectionEpoch;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    await _host?.close();
    _host = null;
    await _discovery.close();
    super.dispose();
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/config/game_config.dart';
import 'lan_host_transport.dart';

/// Browser-compatible transport for the existing authoritative Dart game host.
/// The relay does not execute game rules: it forwards existing LAN payloads.
class RelayHostTransport implements LanHostTransport {
  RelayHostTransport({
    required this.endpoint,
    required this.code,
    required this.capacity,
    this.onConnectionLost,
  });

  final Uri endpoint;
  final String code;
  final int capacity;
  final void Function()? onConnectionLost;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Completer<String?>? _opened;
  bool _transportLost = false;
  bool _ready = false;
  bool _closed = false;
  void Function(Object, String)? _onMessage;
  void Function(Object)? _onDisconnect;

  @override
  List<String> get addresses => <String>[endpoint.toString()];

  @override
  Future<void> start({
    required void Function(Object connection, String message) onMessage,
    required void Function(Object connection) onDisconnect,
  }) async {
    if (_closed || _channel != null) {
      throw StateError('Relay transport already started or closed.');
    }
    _onMessage = onMessage;
    _onDisconnect = onDisconnect;
    final opened = Completer<String?>();
    _opened = opened;
    try {
      final channel = WebSocketChannel.connect(endpoint);
      _channel = channel;
      _subscription = channel.stream.listen(
        _handle,
        onDone: () => _disconnected('Relay server disconnected.'),
        onError: (Object error) => _disconnected('$error'),
        cancelOnError: true,
      );
      await channel.ready.timeout(
        const Duration(seconds: GameConfig.multiplayerSocketOpenTimeoutSeconds),
      );
      if (_closed || _transportLost) {
        throw StateError('Relay server disconnected.');
      }
      channel.sink.add(
        jsonEncode(<String, dynamic>{
          'kind': 'create',
          'room': code,
          'capacity': capacity,
        }),
      );
      final failure = await opened.future.timeout(
        const Duration(seconds: GameConfig.multiplayerHandshakeTimeoutSeconds),
        onTimeout: () => 'Relay room creation timed out.',
      );
      if (failure != null) throw StateError(failure);
      if (_closed || _transportLost) {
        throw StateError('Relay server disconnected.');
      }
      _ready = true;
    } catch (_) {
      await close();
      rethrow;
    }
  }

  void _handle(dynamic data) {
    if (_closed || _transportLost || data is! String) return;
    try {
      final wire = jsonDecode(data) as Map<String, dynamic>;
      switch (wire['kind']) {
        case 'created':
          if (wire['room'] != code) {
            _disconnected('Room code mismatch.');
            return;
          }
          if (_opened?.isCompleted == false) _opened!.complete(null);
          break;
        case 'peer_message':
          final peer = wire['peer'];
          final payload = wire['payload'];
          if (peer is String && payload is String && peer.isNotEmpty) {
            _onMessage?.call(peer, payload);
          }
          break;
        case 'peer_left':
          final peer = wire['peer'];
          if (peer is String && peer.isNotEmpty) _onDisconnect?.call(peer);
          break;
        case 'error':
          final message = wire['message']?.toString() ?? 'Relay error.';
          if (_opened?.isCompleted == false) {
            _opened!.complete(message);
          }
          break;
      }
    } catch (_) {
      // Ignore invalid/unrecognized relay controls; game wire is unchanged.
    }
  }

  void _disconnected(String message) {
    if (_closed || _transportLost) return;
    _transportLost = true;
    if (_opened?.isCompleted == false) {
      _opened!.complete(message);
    }
    if (_ready) onConnectionLost?.call();
  }

  @override
  void send(Object connection, String message) {
    if (_closed ||
        _transportLost ||
        connection is! String ||
        _channel == null) {
      return;
    }
    try {
      _channel!.sink.add(
        jsonEncode(<String, dynamic>{
          'kind': 'to_peer',
          'peer': connection,
          'payload': message,
        }),
      );
    } catch (_) {
      _disconnected('Relay server disconnected.');
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (_opened?.isCompleted == false) {
      _opened!.complete('Relay transport closed.');
    }
    await _subscription?.cancel();
    _subscription = null;
    try {
      final channel = _channel;
      if (channel != null) {
        await channel.sink.close().timeout(
          const Duration(
            seconds: GameConfig.multiplayerSocketCloseTimeoutSeconds,
          ),
        );
      }
    } catch (_) {}
    _channel = null;
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

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
  Completer<void>? _opened;
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
    _opened = Completer<void>();
    try {
      final channel = WebSocketChannel.connect(endpoint);
      _channel = channel;
      _subscription = channel.stream.listen(
        _handle,
        onDone: () => _disconnected('Relay server disconnected.'),
        onError: (Object error) => _disconnected('$error'),
        cancelOnError: true,
      );
      await channel.ready.timeout(const Duration(seconds: 8));
      channel.sink.add(
        jsonEncode(<String, dynamic>{
          'kind': 'create',
          'room': code,
          'capacity': capacity,
        }),
      );
      await _opened!.future.timeout(const Duration(seconds: 8));
    } catch (_) {
      await close();
      rethrow;
    }
  }

  void _handle(dynamic data) {
    if (_closed || data is! String) return;
    try {
      final wire = jsonDecode(data) as Map<String, dynamic>;
      switch (wire['kind']) {
        case 'created':
          if (wire['room'] != code) {
            _disconnected('Room code mismatch.');
            return;
          }
          if (_opened?.isCompleted == false) _opened!.complete();
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
            _opened!.completeError(StateError(message));
          }
          break;
      }
    } catch (_) {
      // Ignore invalid/unrecognized relay controls; game wire is unchanged.
    }
  }

  void _disconnected(String message) {
    if (_closed) return;
    if (_opened?.isCompleted == false) {
      _opened!.completeError(StateError(message));
    } else {
      onConnectionLost?.call();
    }
  }

  @override
  void send(Object connection, String message) {
    if (_closed || connection is! String || _channel == null) return;
    _channel!.sink.add(
      jsonEncode(<String, dynamic>{
        'kind': 'to_peer',
        'peer': connection,
        'payload': message,
      }),
    );
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }
}

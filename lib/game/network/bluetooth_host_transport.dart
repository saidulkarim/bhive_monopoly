import 'dart:async';

import 'bluetooth_game_bridge.dart';
import 'lan_host_transport.dart';

/// Android Bluetooth Classic RFCOMM host, plugged into the existing LAN
/// room's authoritative server pipeline. Peer IDs are native socket IDs.
class BluetoothHostTransport implements LanHostTransport {
  BluetoothHostTransport({BluetoothGameBridge? bridge})
    : _bridge = bridge ?? BluetoothGameBridge.instance;

  final BluetoothGameBridge _bridge;
  StreamSubscription<BluetoothGameEvent>? _subscription;
  bool _closed = false;

  @override
  List<String> get addresses => const <String>[]; // No IP in Bluetooth.

  @override
  Future<void> start({
    required void Function(Object connection, String message) onMessage,
    required void Function(Object connection) onDisconnect,
  }) async {
    if (_closed || _subscription != null) {
      throw StateError('Bluetooth host already started or closed.');
    }
    _subscription = _bridge.events.listen((event) {
      if (_closed || event.peer.isEmpty || event.peer == 'client') return;
      if (event.type == 'message') {
        onMessage(event.peer, event.message);
      } else if (event.type == 'disconnected' || event.type == 'error') {
        onDisconnect(event.peer);
      }
    });
    try {
      await _bridge.startHost();
    } catch (_) {
      await _subscription?.cancel();
      _subscription = null;
      rethrow;
    }
  }

  @override
  void send(Object connection, String message) {
    if (_closed) return;
    // Method-channel calls must not leave unhandled asynchronous exceptions.
    unawaited(
      _bridge.send(connection as String, message).catchError((Object _) {}),
    );
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription?.cancel();
    _subscription = null;
    await _bridge.stop();
  }
}

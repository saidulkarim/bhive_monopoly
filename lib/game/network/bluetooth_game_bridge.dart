import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A paired Android phone, identified by its Bluetooth Classic MAC address.
@immutable
class BluetoothGameDevice {
  const BluetoothGameDevice({required this.name, required this.address});

  final String name;
  final String address;

  factory BluetoothGameDevice.fromMap(Map<dynamic, dynamic> data) {
    final address = data['address'];
    final name = data['name'];
    if (address is! String ||
        !RegExp(r'^(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$').hasMatch(address)) {
      throw const FormatException('Invalid Bluetooth device address.');
    }
    return BluetoothGameDevice(
      address: address.toUpperCase(),
      name: name is String && name.trim().isNotEmpty
          ? name.trim()
          : 'Bluetooth device',
    );
  }
}

@immutable
class BluetoothGameEvent {
  const BluetoothGameEvent({
    required this.type,
    this.peer = '',
    this.message = '',
  });

  final String type;
  final String peer;
  final String message;

  factory BluetoothGameEvent.fromMap(Map<dynamic, dynamic> data) {
    return BluetoothGameEvent(
      type: data['type']?.toString() ?? '',
      peer: data['peer']?.toString() ?? '',
      message: data['message']?.toString() ?? '',
    );
  }
}

/// One Android-native bridge. No Dart IO, WebSocket server, or extra Flutter
/// plugin dependency is needed. A browser must use Wi-Fi or Online instead.
class BluetoothGameBridge {
  BluetoothGameBridge._();

  static final BluetoothGameBridge instance = BluetoothGameBridge._();

  static const MethodChannel _methods = MethodChannel(
    'com.bhive.monopoly/bluetooth',
  );
  static const EventChannel _eventsChannel = EventChannel(
    'com.bhive.monopoly/bluetooth_events',
  );

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Stream<BluetoothGameEvent>? _events;

  Stream<BluetoothGameEvent> get events => _events ??= _eventsChannel
      .receiveBroadcastStream()
      .where((value) => value is Map)
      .map((value) => BluetoothGameEvent.fromMap(value as Map))
      .asBroadcastStream();

  void _requireAndroid() {
    if (!isSupported) {
      throw UnsupportedError(
        'Bluetooth rooms require the bHiVE Monopoly Android app.',
      );
    }
  }

  Future<void> ensureReady() async {
    _requireAndroid();
    final granted = await _methods.invokeMethod<bool>('permissions');
    if (granted != true) {
      throw StateError('Allow Nearby devices permission to use Bluetooth.');
    }
    final enabled = await _methods.invokeMethod<bool>('enabled');
    if (enabled != true) {
      throw StateError('Turn on Bluetooth in Android settings and try again.');
    }
  }

  Future<List<BluetoothGameDevice>> pairedDevices() async {
    await ensureReady();
    final raw = await _methods.invokeMethod<List<dynamic>>('pairedDevices');
    final devices = <BluetoothGameDevice>[];
    for (final item in raw ?? const <dynamic>[]) {
      if (item is Map) {
        try {
          devices.add(BluetoothGameDevice.fromMap(item));
        } on FormatException {
          // Ignore invalid Android device records.
        }
      }
    }
    devices.sort((a, b) => a.name.compareTo(b.name));
    return devices;
  }

  Future<void> openSettings() async {
    _requireAndroid();
    await _methods.invokeMethod<void>('openSettings');
  }

  Future<void> startHost() async {
    await ensureReady();
    await _methods.invokeMethod<void>('startHost');
  }

  Future<void> connect(String deviceAddress) async {
    await ensureReady();
    final checked = BluetoothGameDevice.fromMap(<String, String>{
      'name': 'Host',
      'address': deviceAddress,
    });
    await _methods.invokeMethod<void>('connect', <String, String>{
      'address': checked.address,
    });
  }

  Future<void> send(String peer, String message) async {
    _requireAndroid();
    await _methods.invokeMethod<void>('send', <String, String>{
      'peer': peer,
      'message': message,
    });
  }

  Future<void> stop() async {
    if (isSupported) {
      await _methods.invokeMethod<void>('stop');
    }
  }
}

/// Client transport for the existing LAN room protocol over RFCOMM.
class BluetoothGuestConnection {
  BluetoothGuestConnection({BluetoothGameBridge? bridge})
    : _bridge = bridge ?? BluetoothGameBridge.instance;

  final BluetoothGameBridge _bridge;
  final StreamController<String> _messages =
      StreamController<String>.broadcast();
  StreamSubscription<BluetoothGameEvent>? _subscription;
  bool _closed = false;

  Stream<String> get messages => _messages.stream;

  Future<void> connect(String address) async {
    if (_closed || _subscription != null) {
      throw StateError('Bluetooth client already started or closed.');
    }
    _subscription = _bridge.events.listen((event) {
      if (_closed || event.peer != 'client') return;
      if (event.type == 'message') {
        _messages.add(event.message);
      } else if (event.type == 'disconnected' || event.type == 'error') {
        if (event.type == 'error') {
          _messages.addError(StateError(event.message));
        }
        unawaited(_closeMessages());
      }
    });
    try {
      await _bridge.connect(address);
    } catch (_) {
      await close();
      rethrow;
    }
  }

  Future<void> send(String text) async {
    if (_closed) throw StateError('Bluetooth connection closed.');
    await _bridge.send('client', text);
  }

  Future<void> _closeMessages() async {
    if (!_messages.isClosed) await _messages.close();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _bridge.stop();
    } on PlatformException {
      // The native socket may already have disconnected.
    }
    await _closeMessages();
  }
}

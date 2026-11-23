import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/game/network/bluetooth_game_bridge.dart';

void main() {
  test('Bluetooth device records validate RFCOMM host addresses', () {
    final device = BluetoothGameDevice.fromMap(<String, String>{
      'address': 'aa:bb:cc:11:22:33',
      'name': '  Nova phone  ',
    });
    expect(device.address, 'AA:BB:CC:11:22:33');
    expect(device.name, 'Nova phone');
    expect(
      () => BluetoothGameDevice.fromMap(<String, String>{
        'address': '127.0.0.1',
        'name': 'Invalid',
      }),
      throwsFormatException,
    );
  });

  test('Bluetooth device with missing name retains a useful label', () {
    final device = BluetoothGameDevice.fromMap(<String, String>{
      'address': 'AA:BB:CC:DD:EE:FF',
      'name': '',
    });
    expect(device.name, 'Bluetooth device');
  });

  test('Bluetooth bridge accepts a typed native message event', () {
    final event = BluetoothGameEvent.fromMap(<String, dynamic>{
      'type': 'message',
      'peer': 'bt-1',
      'message': '{"type":"hello","pin":"123456"}',
    });
    expect(event.type, 'message');
    expect(event.peer, 'bt-1');
    expect(event.message, contains('123456'));
  });

  test('Platform guard hides Bluetooth in non-Android widgets', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      expect(BluetoothGameBridge.isSupported, isFalse);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

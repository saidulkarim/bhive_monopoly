// ignore_for_file: avoid_relative_lib_imports

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../lib/game/network/lan_room_controller.dart';

Future<void> waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 8));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Avatar room update did not synchronize');
    }
    await Future<void>.delayed(const Duration(milliseconds: 30));
  }
}

void main() {
  test('two native peers sync presets and bounded PNG avatars', () async {
    final tmp = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = tmp.port;
    await tmp.close();
    final png = Uint8List.fromList(<int>[
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      0,
      0,
      0,
      0,
    ]);
    final host = await LanRoomController.host(
      name: 'Alice',
      maxPlayers: 2,
      port: port,
      avatarIndex: 4,
      avatarBytes: png,
    );
    LanRoomController? guest;
    try {
      guest = await LanRoomController.join(
        name: 'Bob',
        hostIp: '127.0.0.1',
        pin: host.pin,
        port: port,
        avatarIndex: 2,
        avatarBytes: png,
      );
      final client = guest;
      await waitFor(
        () =>
            host.members.length == 2 &&
            client.members.length == 2 &&
            client.playerId == 1,
      );
      expect(client.members.first.avatarIndex, 4);
      expect(client.members.first.avatarBytes, png);
      expect(host.members[1].avatarIndex, 2);
      expect(host.members[1].avatarBytes, png);
      host.startMatch();
      await waitFor(() => client.game != null);
      expect(client.members.map((m) => m.name), <String>['Alice', 'Bob']);
    } finally {
      await guest?.shutdown();
      await host.shutdown();
    }
  });
}

// ignore_for_file: avoid_relative_lib_imports

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../lib/game/network/lan_room_controller.dart';

Future<void> waitUntil(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 6),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Room state did not synchronize in time');
    }
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }
}

void main() {
  test(
    'real WebSocket loopback: join, sync and enforce turn ownership',
    () async {
      // Reserve an available local port, then release it for the host.
      final reservation = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final port = reservation.port;
      await reservation.close();

      final host = await LanRoomController.host(
        name: 'Alice',
        maxPlayers: 2,
        port: port,
      );
      LanRoomController? guest;
      try {
        final joined = await LanRoomController.join(
          name: 'Bob',
          hostIp: '127.0.0.1',
          pin: host.pin,
          port: port,
        );
        guest = joined;
        await waitUntil(
          () =>
              host.members.length == 2 &&
              joined.playerId == 1 &&
              joined.members.length == 2,
        );

        host.startMatch();
        await waitUntil(() => joined.game != null);
        expect(joined.game!.players.map((p) => p.name), ['Alice', 'Bob']);

        // Guest cannot make host move, even with a direct fabricated command.
        await joined.sendAction('roll');
        await waitUntil(() => joined.errorRevision > 0);
        expect(host.game!.currentPlayer.position, 0);

        // Only the host generates the dice; guest receives the same exact roll.
        await host.sendAction('roll');
        await waitUntil(() => joined.game!.lastRoll != null);
        expect(joined.game!.lastRoll!.sum, host.game!.lastRoll!.sum);
        expect(
          joined.game!.currentPlayer.position,
          host.game!.currentPlayer.position,
        );
        expect(joined.game!.phase, host.game!.phase);
      } finally {
        await guest?.shutdown();
        await host.shutdown();
      }
    },
  );
}

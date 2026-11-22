// ignore_for_file: avoid_relative_lib_imports

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../../lib/game/network/lan_room_controller.dart';

Future<void> until(bool Function() check) async {
  final timeout = DateTime.now().add(const Duration(seconds: 7));
  while (!check()) {
    if (DateTime.now().isAfter(timeout)) {
      throw TimeoutException('LAN trade did not synchronize');
    }
    await Future<void>.delayed(const Duration(milliseconds: 30));
  }
}

void main() {
  test(
    'LAN trade offer, refusal of unauthorized consent, and acceptance',
    () async {
      final reservation = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final port = reservation.port;
      await reservation.close();
      final host = await LanRoomController.host(
        name: 'Host',
        maxPlayers: 2,
        port: port,
      );
      LanRoomController? guest;
      try {
        guest = await LanRoomController.join(
          name: 'Guest',
          hostIp: '127.0.0.1',
          pin: host.pin,
          port: port,
        );
        final joined = guest;
        await until(() => host.members.length == 2 && joined.playerId == 1);
        host.startMatch();
        await until(() => joined.game != null);
        await host.sendTradeOffer(toPlayerId: 1, cashFrom: 80);
        await until(() => joined.pendingTrade != null);
        final id = joined.pendingTrade!.id;
        expect(host.game!.players[0].balance, 1500);

        // Proposer cannot approve their own request, even as room host.
        await host.respondToTrade('acceptTrade', id);
        await until(() => host.errorRevision != 0);
        expect(host.pendingTrade, isNotNull);
        expect(host.game!.players[0].balance, 1500);

        // The host cannot roll while guest consent is outstanding.
        final previousError = host.errorRevision;
        await host.sendAction('roll');
        await until(() => host.errorRevision > previousError);
        expect(host.game!.players[0].position, 0);

        await joined.respondToTrade('acceptTrade', id);
        await until(
          () =>
              host.pendingTrade == null &&
              joined.pendingTrade == null &&
              joined.game!.players[0].balance == 1420,
        );
        expect(host.game!.players[1].balance, 1580);
        expect(joined.game!.players[1].balance, 1580);
      } finally {
        await guest?.shutdown();
        await host.shutdown();
      }
    },
  );
}

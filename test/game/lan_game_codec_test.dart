// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter_test/flutter_test.dart';

import '../../lib/game/engine/game_engine.dart';
import '../../lib/game/models/game_models.dart';
import '../../lib/game/network/lan_game_codec.dart';

void main() {
  test('snapshot sends turn state, ownership, money, and players', () {
    final host = GameEngine(playerNames: ['Host', 'Guest'], cardSeed: 14);
    host.roll(1, 2); // index 3, unowned property
    host.buyProperty();
    final wire = LanGameCodec.encode(host);
    final viewer = LanGameCodec.decode(wire);
    expect(viewer.players.map((p) => p.name).toList(), ['Host', 'Guest']);
    expect(viewer.players.first.position, 3);
    expect(viewer.players.first.balance, 1440);
    expect(viewer.properties[3].ownerId, 0);
    expect(viewer.phase, TurnPhase.complete);
    expect(viewer.log, host.log);
  });

  test('auction and current bidder survive projection', () {
    final host = GameEngine(playerNames: ['Host', 'Guest']);
    host.roll(1, 2);
    host.declinePurchase();
    host.bid(30);
    final viewer = LanGameCodec.decode(LanGameCodec.encode(host));
    expect(viewer.phase, TurnPhase.auction);
    expect(viewer.auction!.highBid, 30);
    expect(viewer.auction!.bidderId, 1);
    expect(viewer.auction!.highestBidderId, 0);
  });

  test('existing guest projection updates without replacing board', () {
    final host = GameEngine(playerNames: ['Host', 'Guest']);
    final viewer = LanGameCodec.decode(LanGameCodec.encode(host));
    host.roll(1, 2);
    LanGameCodec.apply(viewer, LanGameCodec.encode(host));
    expect(viewer.phase, TurnPhase.purchase);
    expect(viewer.pendingPurchaseIndex, 3);
    expect(viewer.lastRoll!.sum, 3);
  });

  test('rejects a snapshot with the wrong board size', () {
    final host = GameEngine(playerNames: ['Host', 'Guest']);
    final json = LanGameCodec.encode(host);
    json['properties'] = <Object>[];
    expect(() => LanGameCodec.decode(json), throwsFormatException);
  });
}

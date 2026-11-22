import 'package:flutter_test/flutter_test.dart';

import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/models/game_models.dart';
import 'package:monopoly/game/network/lan_game_codec.dart';
import 'package:monopoly/game/validation/game_snapshot_validator.dart';

void main() {
  group('Phase 12 — snapshot integrity', () {
    test('accepts an actual host initial state and purchase', () {
      final host = GameEngine(playerNames: ['Host', 'Guest']);
      GameSnapshotValidator.validateLan(LanGameCodec.encode(host));
      host.roll(1, 2);
      GameSnapshotValidator.validateLan(LanGameCodec.encode(host));
      host.buyProperty();
      GameSnapshotValidator.validateLan(LanGameCodec.encode(host));
      GameSnapshotValidator.validateOffline(host.exportSave());
    });

    test('rejects invalid tile ownership before changing guest state', () {
      final host = GameEngine(playerNames: ['Host', 'Guest']);
      final guest = LanGameCodec.decode(LanGameCodec.encode(host));
      final unchanged = LanGameCodec.encode(guest);
      final incoming = LanGameCodec.encode(host);
      final props = (incoming['properties'] as List)
          .cast<Map<String, dynamic>>();
      props[0]['ownerId'] = 0; // START cannot be privately owned.

      expect(() => LanGameCodec.apply(guest, incoming), throwsFormatException);
      expect(LanGameCodec.encode(guest), equals(unchanged));
    });

    test('rejects invalid late property after early valid changes', () {
      final host = GameEngine(playerNames: ['Host', 'Guest']);
      final guest = LanGameCodec.decode(LanGameCodec.encode(host));
      final before = LanGameCodec.encode(guest);
      final incoming = LanGameCodec.encode(host);
      (incoming['players'] as List).first['balance'] = 987;
      (incoming['properties'] as List).last['development'] = 8;

      expect(() => LanGameCodec.apply(guest, incoming), throwsFormatException);
      expect(LanGameCodec.encode(guest), equals(before));
    });

    test('rejects negative positions, invalid dice and excess houses', () {
      final game = GameEngine(playerNames: ['A', 'B']);
      final wire = LanGameCodec.encode(game);
      (wire['players'] as List).first['position'] = -1;
      expect(
        () => GameSnapshotValidator.validateLan(wire),
        throwsFormatException,
      );
      (wire['players'] as List).first['position'] = 0;
      wire['lastRoll'] = <String, int>{'first': 7, 'second': 2};
      expect(
        () => GameSnapshotValidator.validateLan(wire),
        throwsFormatException,
      );
      wire['lastRoll'] = null;

      final props = (wire['properties'] as List).cast<Map<String, dynamic>>();
      // All are real street tiles; nine four-house streets exceed bank stock.
      const streets = <int>[1, 3, 6, 8, 9, 11, 13, 14, 16];
      for (final index in streets) {
        props[index]['ownerId'] = 0;
        props[index]['development'] = 4;
      }
      expect(
        () => GameSnapshotValidator.validateLan(wire),
        throwsFormatException,
      );
    });

    test('rejects inconsistent pending purchase and saved game', () {
      final game = GameEngine(playerNames: ['A', 'B']);
      final saved = game.exportSave();
      saved['phase'] = TurnPhase.purchase.name;
      saved['pendingPurchaseIndex'] = 3;
      // Current player is still at START.
      expect(() => GameEngine.importSave(saved), throwsFormatException);
      expect(game.phase, TurnPhase.roll);
    });

    test('valid new auction remains compatible with LAN codec', () {
      final host = GameEngine(playerNames: ['A', 'B']);
      host.roll(1, 2);
      host.declinePurchase();
      host.bid(30);
      final snapshot = LanGameCodec.encode(host);
      final client = LanGameCodec.decode(snapshot);
      expect(client.auction!.highBid, 30);
      expect(client.auction!.bidderId, 1);
    });
  });
}

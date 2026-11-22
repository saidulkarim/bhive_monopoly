import 'package:flutter_test/flutter_test.dart';

import 'package:monopoly/game/network/lan_room_controller.dart';

void main() {
  group('Phase 12 — LAN event preflight', () {
    test('accepts a genuine move event', () {
      const event = LanMoveEvent(
        sequence: 2,
        action: 'roll',
        actorId: 1,
        startPosition: 37,
        endPosition: 3,
      );
      final decoded = LanMoveEvent.fromWire(event.toWire());
      expect(decoded.sequence, 2);
      expect(decoded.startPosition, 37);
      expect(decoded.endPosition, 3);
    });

    test('rejects impossible board coordinates and sequence', () {
      const event = LanMoveEvent(sequence: 1, action: 'roll', actorId: 0);
      final wire = event.toWire()..['endPosition'] = 50;
      expect(() => LanMoveEvent.fromWire(wire), throwsFormatException);
      wire['endPosition'] = 3;
      wire['sequence'] = -5;
      expect(() => LanMoveEvent.fromWire(wire), throwsFormatException);
    });

    test('rejects invalid dice rather than animating them', () {
      const event = LanMoveEvent(sequence: 1, action: 'roll', actorId: 0);
      final wire = event.toWire()
        ..['dice'] = <String, int>{'first': 8, 'second': 2};
      expect(() => LanMoveEvent.fromWire(wire), throwsFormatException);
    });
  });
}

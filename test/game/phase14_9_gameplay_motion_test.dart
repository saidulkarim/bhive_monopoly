import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/game/experience/gameplay_motion.dart';

void main() {
  test('normal movement visits every tile across START and corners', () {
    expect(GameplayMotion.dicePath(38, 3, 5), [39, 0, 1, 2, 3]);
    expect(GameplayMotion.dicePath(8, 13, 5), [9, 10, 11, 12, 13]);
    expect(GameplayMotion.dicePath(28, 32, 4), [29, 30, 31, 32]);
  });
  test('teleports and invalid rolls do not walk the ring', () {
    expect(GameplayMotion.dicePath(35, 10, 5), isEmpty);
    expect(GameplayMotion.dicePath(5, 5, 0), isEmpty);
    expect(GameplayMotion.dicePath(-1, 3, 4), isEmpty);
    expect(GameplayMotion.adjacent(39, 0), isTrue);
    expect(GameplayMotion.adjacent(0, 39), isTrue);
    expect(GameplayMotion.adjacent(35, 10), isFalse);
  });
  test('glides finish before the next step and dice frames slow down', () {
    expect(GameplayMotion.stepInterval > GameplayMotion.tokenGlide, isTrue);
    final frames = GameplayMotion.diceFrames;
    for (var i = 1; i < frames.length; i++) {
      expect(frames[i], greaterThan(frames[i - 1]));
    }
  });
}

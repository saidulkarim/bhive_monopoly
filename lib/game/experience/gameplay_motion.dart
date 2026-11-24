/// Shared, presentation-only timing for local and network games.
/// The step interval includes a small buffer after each token glide.
class GameplayMotion {
  const GameplayMotion._();

  static const tokenGlide = Duration(milliseconds: 112);
  static const stepInterval = Duration(milliseconds: 128);
  static const cameraTransition = Duration(milliseconds: 420);
  static const diceFrames = <int>[48, 52, 58, 65, 76, 92, 112, 135];

  /// Only normal dice travel is animated around the ring. Card and jail
  /// teleports must never be mistaken for a full lap or a diagonal walk.
  static List<int> dicePath(int from, int to, int sum) {
    if (from < 0 ||
        from >= 40 ||
        to < 0 ||
        to >= 40 ||
        sum < 2 ||
        sum > 12 ||
        (from + sum) % 40 != to) {
      return const <int>[];
    }
    return List<int>.generate(sum, (i) => (from + i + 1) % 40, growable: false);
  }

  static bool adjacent(int from, int to) =>
      (from + 1) % 40 == to || (to + 1) % 40 == from;
}

import '../../core/config/game_config.dart';

/// A bounded, event-driven retry schedule; no timers or network I/O here.
class LanReconnectPolicy {
  const LanReconnectPolicy._();

  static int get maxAttempts =>
      GameConfig.multiplayerReconnectDelaysSeconds.length;

  static final List<Duration> delays = List<Duration>.unmodifiable(
    GameConfig.multiplayerReconnectDelaysSeconds.map(
      (s) => Duration(seconds: s),
    ),
  );

  /// Number of automatic attempts already started (not merely scheduled).
  static Duration? delayFor(int attempted) =>
      attempted < 0 || attempted >= maxAttempts ? null : delays[attempted];
}

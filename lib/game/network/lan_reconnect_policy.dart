/// Presentation-layer reconnection pacing. The existing host-authoritative
/// protocol and secure rejoin token are left unchanged.
class LanReconnectPolicy {
  const LanReconnectPolicy._();

  static const int maxAttempts = 5;
  static const List<Duration> delays = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 12),
  ];

  /// The parameter is the number of retries already attempted.
  static Duration? delayFor(int attempted) =>
      attempted < 0 || attempted >= maxAttempts ? null : delays[attempted];
}

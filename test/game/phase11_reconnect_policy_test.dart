import 'package:flutter_test/flutter_test.dart';

import 'package:monopoly/game/network/lan_reconnect_policy.dart';

void main() {
  test('bounded retries with increasing delays prevent connection storms', () {
    expect(LanReconnectPolicy.maxAttempts, 5);
    expect(LanReconnectPolicy.delayFor(0), const Duration(seconds: 2));
    expect(LanReconnectPolicy.delayFor(1), const Duration(seconds: 4));
    expect(LanReconnectPolicy.delayFor(2), const Duration(seconds: 8));
    expect(LanReconnectPolicy.delayFor(3), const Duration(seconds: 16));
    expect(LanReconnectPolicy.delayFor(4), const Duration(seconds: 30));
    expect(LanReconnectPolicy.delayFor(5), isNull);
    expect(LanReconnectPolicy.delayFor(-1), isNull);
  });
}

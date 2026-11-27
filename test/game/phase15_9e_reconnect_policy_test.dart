import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/core/config/game_config.dart';
import 'package:monopoly/game/network/lan_reconnect_policy.dart';
import 'package:monopoly/game/ui/game_text.dart';

void main() {
  test('reconnect policy follows a finite centralized schedule', () {
    final configured = GameConfig.multiplayerReconnectDelaysSeconds;
    expect(LanReconnectPolicy.maxAttempts, configured.length);
    expect(LanReconnectPolicy.delayFor(-1), isNull);
    for (var i = 0; i < configured.length; i++) {
      expect(LanReconnectPolicy.delayFor(i), Duration(seconds: configured[i]));
      expect(configured[i], greaterThan(0));
      if (i > 0) expect(configured[i], greaterThanOrEqualTo(configured[i - 1]));
    }
    expect(LanReconnectPolicy.delayFor(configured.length), isNull);
    expect(LanReconnectPolicy.delayFor(configured.length + 1), isNull);
  });

  test('handshake timeout is localized in both supported languages', () {
    const message = 'Host synchronization timed out. Reconnect to continue.';
    expect(const GameText('en').errorMessage(message), message);
    expect(const GameText('bn').errorMessage(message), contains('পুনঃসংযোগ'));
  });
}

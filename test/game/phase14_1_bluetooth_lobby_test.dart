import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/game/ui/lan_lobby_screen.dart';

void main() {
  testWidgets('Android multiplayer lobby offers all three transports', (
    tester,
  ) async {
    // Widget tests run on the desktop test runner. Simulate Android only
    // while mounting and inspecting the lobby, then restore the global debug
    // variable *before this test body ends*. addTearDown is too late for
    // Flutter's foundation invariant verification.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: LanLobbyScreen(playerName: 'Alice', languageCode: 'en'),
        ),
      );

      expect(find.byKey(const ValueKey('relay-online-mode')), findsOneWidget);
      expect(find.byKey(const ValueKey('relay-lan-mode')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('bluetooth-offline-mode')),
        findsOneWidget,
      );
    } finally {
      // Dispose the lobby before restoring the simulated platform. This
      // cleanup also runs when a widget expectation fails.
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:monopoly/game/ui/match_history_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('empty history screen has three accessible tabs', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      const MaterialApp(home: MatchHistoryScreen(languageCode: 'en')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Matches'), findsOneWidget);
    expect(find.text('Achievements'), findsOneWidget);
    expect(find.text('Finished matches'), findsOneWidget);
    await tester.tap(find.text('Matches'));
    await tester.pumpAndSettle();
    expect(find.text('No completed matches yet.'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:monopoly/game/ui/game_text.dart';
import 'package:monopoly/game/ui/widgets/game_activity_sheet.dart';

void main() {
  testWidgets('activity history can be opened and closed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => GameActivitySheet.show(
                context,
                text: const GameText('en'),
                events: ['Paid rent', 'Rolled dice'],
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Match activity'), findsOneWidget);
    expect(find.text('Paid rent'), findsOneWidget);
    expect(find.text('Rolled dice'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Paid rent'), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:monopoly/game/ui/widgets/animated_deed_entrance.dart';

void main() {
  testWidgets('animated deed preserves child content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AnimatedDeedEntrance(child: Text('TITLE DEED'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('TITLE DEED'), findsOneWidget);
  });
}

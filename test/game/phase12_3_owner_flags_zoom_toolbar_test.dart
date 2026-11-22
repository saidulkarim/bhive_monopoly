import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/experience/token_preferences.dart';
import 'package:monopoly/game/ui/board_explorer_screen.dart';
import 'package:monopoly/game/ui/game_text.dart';
import 'package:monopoly/game/ui/widgets/ownership_corner_badge.dart';

void main() {
  test('Ownership pennants always point toward the board centre', () {
    expect(OwnerFlagGeometry.forTile(23)?.direction, OwnerFlagDirection.down);
    expect(OwnerFlagGeometry.forTile(3)?.direction, OwnerFlagDirection.up);
    expect(OwnerFlagGeometry.forTile(13)?.direction, OwnerFlagDirection.right);
    expect(OwnerFlagGeometry.forTile(33)?.direction, OwnerFlagDirection.left);
    for (final corner in <int>[0, 10, 20, 30]) {
      expect(OwnerFlagGeometry.forTile(corner), isNull);
    }
  });

  testWidgets('Owner pennant renders selected token icon, not seat number',
      (tester) async {
    final expected = TokenPreferences.instance.styleFor(0).icon;
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: OwnershipCornerBadge(
            ownerId: 0,
            direction: OwnerFlagDirection.down,
            ownerName: 'Player',
          ),
        ),
      ),
    ));

    expect(find.byIcon(expected), findsOneWidget);
    expect(find.text('1'), findsNothing);
    expect(find.byType(OwnershipCornerBadge), findsOneWidget);
  });

  testWidgets('Explorer has one horizontal zoom toolbar below board',
      (tester) async {
    final engine = GameEngine(playerNames: <String>['Player', 'Computer 1']);
    await tester.pumpWidget(MaterialApp(
      home: BoardExplorerScreen(
        game: engine,
        text: const GameText('en'),
        onSelect: (_) {},
      ),
    ));

    expect(find.byKey(const ValueKey<String>('board-zoom-toolbar')),
        findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pump();
    expect(find.text('150%'), findsOneWidget);

    await tester.tap(find.byTooltip('Reset zoom'));
    await tester.pump();
    expect(find.text('100%'), findsOneWidget);
  });
}

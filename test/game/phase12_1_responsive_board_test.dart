import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/experience/board_camera_preset.dart';
import 'package:monopoly/game/ui/board_explorer_screen.dart';
import 'package:monopoly/game/ui/game_text.dart';
import 'package:monopoly/game/ui/widgets/adaptive_board_panel.dart';
import 'package:monopoly/game/ui/widgets/game_board_view.dart';

/// Tests the Phase 12.1 board controls independently, so a navigation or
/// layout error does not hide unrelated failures in another feature.
void main() {
  test('Portrait versus wide layout uses available dimensions', () {
    expect(usesWideGameBoardLayout(const Size(360, 780)), isFalse);
    expect(usesWideGameBoardLayout(const Size(820, 400)), isTrue);
    expect(usesWideGameBoardLayout(const Size(1024, 768)), isTrue);
    expect(usesWideGameBoardLayout(const Size(700, 1100)), isFalse);
  });

  testWidgets('2D is the default; switching to 3D and back works', (
    tester,
  ) async {
    final game = GameEngine(playerNames: ['Player', 'Computer 1']);
    await tester.pumpWidget(_testApp(game, (_) {}));

    expect(find.byType(AdaptiveBoardPanel), findsOneWidget);
    expect(
      tester.widget<GameBoardView>(find.byType(GameBoardView)).cameraOverride,
      BoardCameraPreset.topDown,
    );

    await tester.tap(find.text('3D'));
    await tester.pump();
    expect(
      tester.widget<GameBoardView>(find.byType(GameBoardView)).cameraOverride,
      BoardCameraPreset.tabletop,
    );

    await tester.tap(find.text('2D'));
    await tester.pump();
    expect(
      tester.widget<GameBoardView>(find.byType(GameBoardView)).cameraOverride,
      BoardCameraPreset.topDown,
    );
  });

  testWidgets('Board explorer lists properties and returns selected tile', (
    tester,
  ) async {
    final game = GameEngine(playerNames: ['Player', 'Computer 1']);
    int? selectedTile;
    await tester.pumpWidget(_testApp(game, (index) => selectedTile = index));

    final expand = find.byIcon(Icons.open_in_full_rounded);
    expect(expand, findsOneWidget);
    await tester.tap(expand);
    // Continuous glossy tile highlights deliberately never settle.
    // Pump the navigation transition explicitly instead of pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byType(BoardExplorerScreen), findsOneWidget);

    final showList = find.text('All 40');
    expect(showList, findsOneWidget);
    await tester.tap(showList);
    await tester.pump();
    expect(find.byType(ListTile), findsWidgets);

    // The board and tile list can both render "River Walk" during the
    // explorer transition. Select the ListTile, not an ambiguous text match.
    final riverWalkTile = find.widgetWithText(ListTile, 'River Walk');
    expect(riverWalkTile, findsOneWidget);
    await tester.ensureVisible(riverWalkTile);
    await tester.tap(riverWalkTile);
    // Tapping the list row calls Navigator.pop(), but a full-screen route
    // remains mounted until its reverse transition is fully completed.
    // One large pump is not always sufficient to dispose the route.
    // Do not use pumpAndSettle(): continuously glowing player positions
    // intentionally schedule animation frames without ever settling.
    await tester.pump();
    for (var frame = 0; frame < 20; frame++) {
      if (find.byType(BoardExplorerScreen).evaluate().isEmpty) break;
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Verify both the selection and the completed return to the game page.
    expect(selectedTile, 1);
    expect(find.byType(BoardExplorerScreen), findsNothing);
  });
}

Widget _testApp(GameEngine game, ValueChanged<int> onSelect) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 380,
          height: 460,
          child: AdaptiveBoardPanel(
            game: game,
            text: const GameText('en'),
            onSelect: onSelect,
          ),
        ),
      ),
    ),
  );
}

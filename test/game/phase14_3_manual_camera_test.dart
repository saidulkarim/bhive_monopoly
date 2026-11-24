import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/ui/board_explorer_screen.dart';
import 'package:monopoly/game/ui/game_text.dart';

void main() {
  testWidgets('Turn changes never move the camera; Find Player works by tap', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    final game = GameEngine(playerNames: ['Player', 'Nova']);
    final updates = ValueNotifier<int>(0);
    addTearDown(updates.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: BoardExplorerScreen(
          game: game,
          text: const GameText('en'),
          onSelect: (_) {},
          boardUpdates: updates,
        ),
      ),
    );
    TransformationController camera() => tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    expect(camera().value.getMaxScaleOnAxis(), closeTo(1, .001));

    game.currentPlayerId = 1;
    game.currentPlayer.position = 23;
    updates.value++;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    expect(camera().value.getMaxScaleOnAxis(), closeTo(1, .001));

    await tester.tap(
      find.byKey(const ValueKey<String>('board-smart-focus-current')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));
    expect(camera().value.getMaxScaleOnAxis(), greaterThan(1.5));
    await tester.pump(const Duration(seconds: 3));
    // Manual focus should NOT bounce the player back to overview.
    expect(camera().value.getMaxScaleOnAxis(), greaterThan(1.5));

    await tester.tap(find.byTooltip('Reset zoom'));
    await tester.pump();
    expect(camera().value.getMaxScaleOnAxis(), closeTo(1, .001));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

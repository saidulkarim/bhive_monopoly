import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/experience/game_experience_settings.dart';
import 'package:monopoly/game/experience/player_palette.dart';
import 'package:monopoly/game/ui/game_text.dart';
import 'package:monopoly/game/ui/widgets/active_position_glow.dart';
import 'package:monopoly/game/ui/widgets/game_board_view.dart';

void main() {
  setUp(() {
    GameExperienceSettings.instance.reducedMotion = false;
  });
  tearDown(() {
    GameExperienceSettings.instance.reducedMotion = false;
  });

  Widget board(GameEngine game, {
    Map<int, int> visiblePositions = const <int, int>{},
    ValueChanged<int>? onSelect,
  }) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 600,
          height: 600,
          child: GameBoardView(
            engine: game,
            text: const GameText('en'),
            perspective: false,
            visiblePositions: visiblePositions,
            onSelect: onSelect ?? (_) {},
          ),
        ),
      ),
    ),
  );

  testWidgets('Current player and opponents each receive a colored glow',
      (tester) async {
    final game = GameEngine(playerNames: <String>['Player', 'Nova']);
    game.currentPlayer.position = 23;
    game.currentPlayer.colorIndex = 8;

    await tester.pumpWidget(board(game));

    expect(find.byType(ActivePositionGlow), findsNWidgets(2));
    expect(find.byKey(const ValueKey<String>('player-position-tile-0')),
        findsOneWidget);
    final location = find.byKey(
      const ValueKey<String>('active-position-tile-23'),
    );
    expect(location, findsOneWidget);
    expect(
      tester.widget<ActivePositionGlow>(location).color,
      PlayerPalette.at(8),
    );
    expect(find.byKey(const ValueKey<String>('active-position-tile-0')),
        findsNothing); // Other player is highlighted as an opponent, not active.
    expect(find.byKey(const ValueKey<String>('player-position-tile-0')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('The marker follows each visible animated movement step',
      (tester) async {
    final game = GameEngine(playerNames: <String>['Player', 'Nova']);
    game.currentPlayer.position = 24; // Authoritative landing position.

    await tester.pumpWidget(board(game, visiblePositions: <int, int>{0: 22}));
    expect(find.byKey(const ValueKey<String>('active-position-tile-22')),
        findsOneWidget);
    expect(find.byKey(const ValueKey<String>('active-position-tile-24')),
        findsNothing);

    await tester.pumpWidget(board(game, visiblePositions: <int, int>{0: 23}));
    expect(find.byKey(const ValueKey<String>('active-position-tile-23')),
        findsOneWidget);
    expect(game.currentPlayer.position, 24); // Animation never writes game state.
  });

  testWidgets('Glow moves to the next player at the start of their turn',
      (tester) async {
    final game = GameEngine(playerNames: <String>['Player', 'Nova']);
    game.players[0].position = 8;
    game.players[1].position = 32;

    await tester.pumpWidget(board(game));
    expect(find.byKey(const ValueKey<String>('active-position-tile-8')),
        findsOneWidget);

    game.currentPlayerId = 1;
    await tester.pumpWidget(board(game));
    expect(find.byKey(const ValueKey<String>('active-position-tile-32')),
        findsOneWidget);
    expect(find.byKey(const ValueKey<String>('active-position-tile-8')),
        findsNothing);
  });

  testWidgets('The tile remains tappable through the decorative glow',
      (tester) async {
    final game = GameEngine(playerNames: <String>['Player', 'Nova']);
    game.currentPlayer.position = 23;
    int? selected;
    await tester.pumpWidget(board(game, onSelect: (index) => selected = index));

    await tester.tap(find.text('23'));
    await tester.pump();
    expect(selected, 23);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduced Motion retains a non-animated visible location outline',
      (tester) async {
    GameExperienceSettings.instance.reducedMotion = true;
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 90,
          height: 90,
          child: ActivePositionGlow(
            color: Color(0xFF65C8F0),
            reducedMotion: true,
          ),
        ),
      ),
    ));

    expect(find.byType(ActivePositionGlow), findsOneWidget);
    expect(tester.takeException(), isNull);
    // An infinite ticker must not run when animation is disabled.
    await tester.pump(const Duration(seconds: 3));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}

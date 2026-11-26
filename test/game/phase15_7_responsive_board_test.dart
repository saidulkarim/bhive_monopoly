import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/ui/board_explorer_screen.dart';
import 'package:monopoly/game/ui/game_text.dart';

void main() {
  const sidebar = ValueKey('explorer-player-sidebar');
  const toolbar = ValueKey<String>('board-zoom-toolbar');
  const player0 = ValueKey<String>('player-cash-card-0');
  const player1 = ValueKey<String>('player-cash-card-1');

  Future<void> open(
    WidgetTester tester,
    GameEngine game, {
    bool list = false,
    String language = 'en',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BoardExplorerScreen(
          game: game,
          text: GameText(language),
          initialList: list,
          onSelect: (_) {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('wide board has vertical players and sidebar zoom controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 650));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final game = GameEngine(playerNames: ['ROOO', 'Cleo', 'Finn']);
    await open(tester, game);
    expect(find.byKey(sidebar), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(player1)).dy,
      greaterThan(tester.getTopLeft(find.byKey(player0)).dy),
    );
    expect(
      find.descendant(of: find.byKey(sidebar), matching: find.byKey(toolbar)),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byType(InteractiveViewer)).width,
      greaterThan(350),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('wide list filters by owner, toggles off, and survives resize', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 650));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final game = GameEngine(playerNames: ['ROOO', 'Cleo']);
    game.properties[1].ownerId = 0;
    game.properties[3].ownerId = 1;
    await open(tester, game, list: true);
    expect(find.byKey(sidebar), findsOneWidget);
    await tester.tap(find.byKey(player0));
    await tester.pump();
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.text('Owner: ROOO'), findsOneWidget);
    await tester.tap(find.byKey(player1));
    await tester.pump();
    expect(find.text('Owner: Cleo'), findsOneWidget);
    await tester.binding.setSurfaceSize(const Size(400, 760));
    await tester.pump();
    expect(find.byKey(sidebar), findsNothing);
    expect(find.text('Owner: Cleo'), findsOneWidget);
    await tester.tap(find.byKey(player1));
    await tester.pump();
    expect(find.byType(ListTile), findsWidgets);
    expect(find.text('Show all'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('list-only explorer disposes without creating a ticker late', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 650));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await open(tester, GameEngine(playerNames: ['ROOO', 'Cleo']), list: true);
    expect(find.byType(InteractiveViewer), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bangla portrait retains horizontal cards and bottom zoom', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await open(
      tester,
      GameEngine(playerNames: ['ROOO', 'Cleo']),
      language: 'bn',
    );
    expect(find.byKey(sidebar), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(player0)).dy,
      tester.getTopLeft(find.byKey(player1)).dy,
    );
    expect(find.byKey(toolbar), findsOneWidget);
    expect(find.text('বোর্ড দেখুন'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/ui/board_explorer_screen.dart';
import 'package:monopoly/game/ui/game_text.dart';
import 'package:monopoly/game/ui/widgets/board_center_action.dart';
import 'package:monopoly/game/ui/widgets/compact_players_strip.dart';

void main() {
  testWidgets('Board center shows current cash and the highest cash balance',
      (tester) async {
    final engine = GameEngine(playerNames: <String>['Player', 'Computer 1']);
    engine.players[1].balance = 2250;
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: BoardCenterAction(
        engine: engine,
        text: const GameText('en'),
        canAct: true,
        onRoll: () {},
      ))),
    ));

    expect(find.byKey(const ValueKey<String>('board-cash-scoreboard')),
        findsOneWidget);
    expect(find.text(r'$1,500'), findsOneWidget);
    expect(find.text(r'$2,250'), findsOneWidget);
    expect(find.text('Computer 1'), findsOneWidget);
    expect(find.text('CASH LEADER'), findsOneWidget);
  });

  testWidgets('Newest monetary activity is shown beneath the dice',
      (tester) async {
    final engine = GameEngine(playerNames: <String>['Player', 'Computer 1']);
    engine.roll(1, 2); // Canal Street, an unowned purchasable property.
    engine.buyProperty();
    var activityOpens = 0;
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: BoardCenterAction(
        engine: engine,
        text: const GameText('en'),
        onViewActivity: () => activityOpens++,
      ))),
    ));

    expect(find.text('LATEST ACTIVITY'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('board-latest-activity')),
        findsOneWidget);
    expect(find.textContaining(r'$60'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey<String>('board-latest-activity')));
    expect(activityOpens, 1);
  });

  testWidgets('Cash leader is marked in the player strip', (tester) async {
    final engine = GameEngine(playerNames: <String>['Player', 'Computer 1']);
    engine.players[1].balance = 2300;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: CompactPlayersStrip(
        game: engine,
        text: const GameText('en'),
      )),
    ));

    expect(find.byKey(const ValueKey<String>('player-cash-card-0')),
        findsOneWidget);
    expect(find.byKey(const ValueKey<String>('player-cash-1')),
        findsOneWidget);
    expect(find.text('CASH LEADER'), findsOneWidget);
  });

  testWidgets('Full-screen auction offers a one-tap reopen bid button',
      (tester) async {
    final game = GameEngine(playerNames: <String>['Player', 'Computer 1']);
    game.roll(1, 2);
    game.declinePurchase();
    var reviews = 0;
    await tester.pumpWidget(MaterialApp(
      home: BoardExplorerScreen(
        game: game,
        text: const GameText('en'),
        onSelect: (_) {},
        onReviewDecision: () => reviews++,
        decisionEnabled: () => true,
      ),
    ));

    expect(find.byKey(const ValueKey<String>('explorer-review-decision')),
        findsOneWidget);
    await tester.tap(find.text('OPEN BID'));
    expect(reviews, 1);
  });

  testWidgets('Full-screen cash balances follow replacement LAN snapshots',
      (tester) async {
    final first = GameEngine(playerNames: <String>['Player', 'Computer 1']);
    final second = GameEngine(playerNames: <String>['Player', 'Computer 1']);
    second.players[0].balance = 950;
    GameEngine latest = first;
    final updates = ChangeNotifier();
    addTearDown(updates.dispose);

    await tester.pumpWidget(MaterialApp(
      home: BoardExplorerScreen(
        game: first,
        gameProvider: () => latest,
        boardUpdates: updates,
        text: const GameText('en'),
        onSelect: (_) {},
      ),
    ));
    latest = second;
    updates.notifyListeners();
    await tester.pump();
    expect(find.text(r'$950'), findsWidgets);
  });

  testWidgets('Full-screen board keeps the cash leaderboard visible',
      (tester) async {
    final engine = GameEngine(playerNames: <String>['Player', 'Computer 1']);
    await tester.pumpWidget(MaterialApp(
      home: BoardExplorerScreen(
        game: engine,
        text: const GameText('en'),
        onSelect: (_) {},
      ),
    ));
    expect(find.byKey(const ValueKey<String>('explorer-cash-leaderboard')),
        findsOneWidget);
    expect(find.byType(CompactPlayersStrip), findsOneWidget);
    // The fullscreen strip and center scoreboard both identify cash leaders.
    expect(find.text('CASH LEADER'), findsWidgets);
    expect(find.byKey(const ValueKey<String>('board-dice-action')),
        findsOneWidget);
  });
}

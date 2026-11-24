import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/models/activity_event.dart';
import 'package:monopoly/game/network/lan_game_codec.dart';
import 'package:monopoly/game/ui/game_text.dart';
import 'package:monopoly/game/ui/widgets/game_activity_sheet.dart';
import 'package:monopoly/ui/screens/credits_screen.dart';

void main() {
  test('typed activity survives save and LAN; old snapshots still open', () {
    final game = GameEngine(playerNames: ['A', 'B'], cardSeed: 1);
    game.roll(1, 2);
    game.buyProperty();
    final event = game.activityEvents.first;
    expect(event.kind, ActivityKind.purchase);
    expect(event.tileIndex, 3);
    expect(event.amount, 60);
    expect(event.actors, ['A']);
    expect(event.flow, ActivityFlow.expense);
    final save = game.exportSave();
    expect(GameEngine.importSave(save).exportSave(), save);
    final wire = LanGameCodec.encode(game);
    expect(
      LanGameCodec.decode(wire).activityEvents.first.toJson(),
      event.toJson(),
    );
    save.remove('activity');
    wire.remove('activity');
    expect(
      GameEngine.importSave(save).activityEvents.first.kind,
      ActivityKind.purchase,
    );
    expect(LanGameCodec.decode(wire).activityEvents.first.tileIndex, 3);
  });

  test('invalid optional metadata falls back to the canonical log', () {
    final game = GameEngine(playerNames: ['A', 'B']);
    final save = game.exportSave();
    save['activity'] = [
      {'kind': 'broken'},
    ];
    expect(
      GameEngine.importSave(save).activityEvents.first.kind,
      ActivityKind.turn,
    );
    expect(ActivityEvent.fromLog('Unknown event').kind, ActivityKind.other);
  });

  test('typed text uses the selected board language', () {
    final game = GameEngine(playerNames: ['A', 'B']);
    game.roll(1, 2);
    game.buyProperty();
    expect(
      const GameText('en').activityText(game.activityEvents.first),
      contains('Canal Street'),
    );
    expect(
      const GameText('bn').activityText(game.activityEvents.first),
      contains('শাঁখারীবাজার'),
    );
  });

  testWidgets('activity category filter preserves newest-first order', (
    tester,
  ) async {
    final game = GameEngine(playerNames: ['A', 'B']);
    game.roll(1, 2);
    game.buyProperty();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameActivitySheet(
            text: const GameText('en'),
            events: game.log,
            structuredEvents: game.activityEvents,
            players: game.players,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(DropdownButton<ActivityKind>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Purchase').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('A purchased Canal Street'), findsOneWidget);
    expect(find.textContaining('A rolled'), findsNothing);
  });

  testWidgets(
    'Credits displays both contacts and installed version in both languages',
    (tester) async {
      PackageInfo.setMockInitialValues(
        appName: 'bHiVE Monopoly',
        packageName: 'com.bhive.monopoly',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: 'test',
      );
      for (final language in ['en', 'bn']) {
        await tester.pumpWidget(
          MaterialApp(home: CreditsScreen(languageCode: language)),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(language == 'en' ? 'Credits' : 'কৃতজ্ঞতা ও পরিচিতি'),
          findsOneWidget,
        );
        // The contact cards are in a scrollable layout on compact displays.
        await tester.scrollUntilVisible(
          find.text(CreditsScreen.mobile),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(CreditsScreen.mobile), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text(CreditsScreen.email),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(CreditsScreen.email), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text(
            language == 'en' ? 'Version 1.0.0 (1)' : 'সংস্করণ ১.০.০ (১)',
          ),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.text(
            language == 'en' ? 'Version 1.0.0 (1)' : 'সংস্করণ ১.০.০ (১)',
          ),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
}

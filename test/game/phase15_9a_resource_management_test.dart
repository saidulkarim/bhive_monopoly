import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:monopoly/core/ui/visual_activity_scope.dart';
import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/experience/game_experience_settings.dart';
import 'package:monopoly/game/persistence/offline_game_store.dart';
import 'package:monopoly/game/ui/widgets/active_position_glow.dart';
import 'package:monopoly/game/ui/widgets/dice_face.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test(
    'unchanged save preserves primary timestamp and distinct backup',
    () async {
      final game = GameEngine(playerNames: ['A', 'B']);
      await OfflineGameStore.save(game, const {}, matchId: 'match-A');
      final prefs = await SharedPreferences.getInstance();
      final initial = prefs.getString(OfflineGameStore.storageKey);
      game.roll(1, 2);
      await OfflineGameStore.save(game, const {}, matchId: 'match-A');
      final current = prefs.getString(OfflineGameStore.storageKey);
      expect(current, isNot(initial));
      expect(prefs.getString(OfflineGameStore.backupKey), initial);
      await OfflineGameStore.save(game, const {}, matchId: 'match-A');
      expect(prefs.getString(OfflineGameStore.storageKey), current);
      expect(prefs.getString(OfflineGameStore.backupKey), initial);
      await prefs.setString(OfflineGameStore.storageKey, 'damaged');
      final recovered = await OfflineGameStore.load();
      expect(recovered!.recoveredFromBackup, isTrue);
      expect(recovered.game.currentPlayer.position, 0);
    },
  );

  test('identical state in a different match must still be saved', () async {
    final game = GameEngine(playerNames: ['A', 'B']);
    await OfflineGameStore.save(game, const {}, matchId: 'match-A');
    await OfflineGameStore.save(game, const {}, matchId: 'match-B');
    expect((await OfflineGameStore.load())!.matchId, 'match-B');
  });

  test('unchanged save repairs missing active match metadata', () async {
    final game = GameEngine(playerNames: ['A', 'B']);
    await OfflineGameStore.save(game, const {}, matchId: 'match-A');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(OfflineGameStore.activeMatchKey);
    await OfflineGameStore.save(game, const {}, matchId: 'match-A');
    expect(prefs.getString(OfflineGameStore.activeMatchKey), 'match-A');
  });

  testWidgets('decorative dice spin settles even if rolling stays true', (
    tester,
  ) async {
    final settings = GameExperienceSettings.instance;
    final oldProfile = settings.powerProfile;
    final oldReduced = settings.reducedMotion;
    settings.powerProfile = GamePowerProfile.balanced;
    settings.reducedMotion = false;
    addTearDown(() {
      settings.powerProfile = oldProfile;
      settings.reducedMotion = oldReduced;
    });
    Widget screen(bool rolling) => MaterialApp(
      home: Scaffold(
        body: Center(child: RollingDiceFace(value: 4, rolling: rolling)),
      ),
    );
    await tester.pumpWidget(screen(true));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(screen(false));
    await tester.pumpAndSettle();
    await tester.pumpWidget(screen(true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('lifecycle hides decorative glow and does not replay on resume', (
    tester,
  ) async {
    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    addTearDown(
      () => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
    );
    await tester.pumpWidget(
      const VisualActivityScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 90,
              height: 90,
              child: ActivePositionGlow(color: Colors.red),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Inactive permits frames in Flutter; hidden does not. Check resumed
    // rendering after the inherited lifecycle update has been delivered.
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(ActivePositionGlow), findsOneWidget);
    expect(binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
}

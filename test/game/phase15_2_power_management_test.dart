import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monopoly/game/experience/game_experience_settings.dart';
import 'package:monopoly/game/ui/widgets/active_position_glow.dart';
import 'package:monopoly/game/ui/widgets/animated_board_tokens.dart';
import 'package:monopoly/game/engine/game_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('power profile persists independently of reduce motion', () async {
    final settings = GameExperienceSettings();
    await settings.ensureLoaded();
    expect(settings.powerProfile, GamePowerProfile.balanced);
    await settings.setPowerProfile(GamePowerProfile.ultraSaver);
    expect(settings.effectiveReducedMotion, isTrue);
    expect(settings.reducedMotion, isFalse);
    final reloaded = GameExperienceSettings();
    await reloaded.ensureLoaded();
    expect(reloaded.powerProfile, GamePowerProfile.ultraSaver);
    await reloaded.restoreDefaults();
    expect(reloaded.powerProfile, GamePowerProfile.balanced);
    expect(reloaded.effectiveReducedMotion, isFalse);
    settings.dispose();
    reloaded.dispose();
  });

  test('unknown profile falls back to balanced', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      GameExperienceSettings.powerProfileKey: 'unknown',
    });
    final settings = GameExperienceSettings();
    await settings.ensureLoaded();
    expect(settings.powerProfile, GamePowerProfile.balanced);
    settings.dispose();
  });

  Widget glow({Color color = Colors.red, int cycles = 1}) => MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 90,
        height: 90,
        child: ActivePositionGlow(color: color, pulseCycles: cycles),
      ),
    ),
  );

  testWidgets('glow settles without recurring frames and restarts on change', (
    tester,
  ) async {
    await tester.pumpWidget(glow());
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.byType(ActivePositionGlow), findsOneWidget);
    await tester.pumpWidget(glow());
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(glow(color: Colors.blue));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('zero cycles and covered board are static', (tester) async {
    await tester.pumpWidget(glow(cycles: 0));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.byType(ActivePositionGlow), findsOneWidget);
    await tester.pumpWidget(
      const MaterialApp(
        home: TickerMode(
          enabled: false,
          child: ActivePositionGlow(color: Colors.red),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('token aura settles while preserving player markers', (
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
    final game = GameEngine(playerNames: ['Human', 'Nova']);
    Widget board() => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 1000,
          height: 1000,
          child: AnimatedBoardTokens(game: game, visiblePositions: const {}),
        ),
      ),
    );
    await tester.pumpWidget(board());
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(
      find.byKey(const ValueKey<String>('player-token-aura-0')),
      findsOneWidget,
    );
    game.players[0].position = 1;
    await tester.pumpWidget(board());
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(game.players[0].position, 1);
    expect(tester.takeException(), isNull);
  });
}

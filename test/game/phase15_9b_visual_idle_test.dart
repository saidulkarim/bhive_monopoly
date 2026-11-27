import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/core/config/game_config.dart';
import 'package:monopoly/core/ui/visual_activity_scope.dart';
import 'package:monopoly/game/models/game_models.dart';
import 'package:monopoly/game/ui/widgets/game_board_view.dart';

void main() {
  const deadline = Duration(seconds: GameConfig.idleAnimationSuspendSeconds);

  test(
    'grouping preserves visible positions, current player order and bankruptcy',
    () {
      final a = PlayerState(id: 0, name: 'A')..position = 4;
      final b = PlayerState(id: 1, name: 'B')..position = 4;
      final c = PlayerState(id: 2, name: 'C')..position = 8;
      final d = PlayerState(id: 3, name: 'D')..bankrupt = true;
      final result = groupBoardOccupants([a, b, c, d], {2: 4}, 1);
      expect(result.keys, [4]);
      expect(result[4]!.map((p) => p.id), [1, 0, 2]);
      a.position = 9;
      final next = groupBoardOccupants([a, b, c, d], {}, 0);
      expect(next[9], [a]);
      expect(next[8], [c]);
      expect(next[4], [b]);
      expect(next.containsKey(0), isFalse);
    },
  );

  Widget screen() => VisualActivityScope(
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return Center(
              child: Text(
                VisualActivityScope.allowsIdleDecorationOf(context)
                    ? 'active'
                    : 'idle',
              ),
            );
          },
        ),
      ),
    ),
  );

  testWidgets('idle deadline fires once and pointer activity wakes visuals', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(screen());
    expect(find.text('active'), findsOneWidget);
    await tester.pump(deadline);
    expect(find.text('idle'), findsOneWidget);
    await tester.tap(find.text('idle'));
    await tester.pump();
    expect(find.text('active'), findsOneWidget);
    await tester.pump(deadline - const Duration(seconds: 1));
    expect(find.text('active'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('idle'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard wakes idle and disposal cancels deadline', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(screen());
    await tester.pump(deadline);
    expect(find.text('idle'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(find.text('active'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(deadline);
    expect(tester.takeException(), isNull);
  });

  testWidgets('foreground resume restarts idle deadline', (tester) async {
    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(screen());
    await tester.pump(deadline);
    expect(find.text('idle'), findsOneWidget);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('active'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}

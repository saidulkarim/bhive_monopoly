import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/game/experience/game_experience_settings.dart';
import 'package:monopoly/game/ui/widgets/dice_face.dart';

void main() {
  testWidgets(
    'Every value 1–6 renders in the new die at small and large sizes',
    (tester) async {
      for (final size in <double>[56, 90, 106]) {
        for (var face = 1; face <= 6; face++) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: ThreeDimensionalDiceFace(value: face, size: size),
                ),
              ),
            ),
          );
          expect(find.byType(ThreeDimensionalDiceFace), findsOneWidget);
          expect(tester.widget<DiceFace>(find.byType(DiceFace)).value, face);
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets('Rolling preview settles on the authoritative game value', (
    tester,
  ) async {
    final settings = GameExperienceSettings.instance;
    final original = settings.reducedMotion;
    settings.reducedMotion = false;
    addTearDown(() => settings.reducedMotion = original);

    Widget scene({required int value, required bool rolling}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: RollingDiceFace(value: value, rolling: rolling, size: 106),
        ),
      ),
    );

    await tester.pumpWidget(scene(value: 2, rolling: false));
    expect(tester.widget<DiceFace>(find.byType(DiceFace)).value, 2);

    await tester.pumpWidget(scene(value: 2, rolling: true));
    await tester.pump(const Duration(milliseconds: 180));
    expect(tester.takeException(), isNull);

    // The engine's actual result arrives when rolling becomes false.
    await tester.pumpWidget(scene(value: 6, rolling: false));
    await tester.pump();
    expect(tester.widget<DiceFace>(find.byType(DiceFace)).value, 6);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Reduced motion does not animate or replace the displayed value',
    (tester) async {
      final settings = GameExperienceSettings.instance;
      final original = settings.reducedMotion;
      settings.reducedMotion = true;
      addTearDown(() => settings.reducedMotion = original);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: RollingDiceFace(value: 4, rolling: true, size: 90),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.widget<DiceFace>(find.byType(DiceFace)).value, 4);
      expect(tester.takeException(), isNull);
    },
  );
}

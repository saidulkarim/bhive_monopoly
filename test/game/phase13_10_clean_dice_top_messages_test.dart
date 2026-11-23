import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:monopoly/core/ui/app_notices.dart';
import 'package:monopoly/game/ui/widgets/dice_face.dart';

void main() {
  setUp(AppNotices.hideCurrentSnackBar);
  tearDown(AppNotices.hideCurrentSnackBar);

  testWidgets('Settled dice have only one porcelain-painted face', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: ThreeDimensionalDiceFace(value: 5, size: 130)),
        ),
      ),
    );

    final settled = find.byType(ThreeDimensionalDiceFace);
    expect(settled, findsOneWidget);
    expect(tester.widget<DiceFace>(find.byType(DiceFace)).value, 5);
    // No separate CustomPaint for the old top/right cube seams.
    expect(
      find.descendant(of: settled, matching: find.byType(CustomPaint)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('A solid top notification stays visible with a modal sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => AppNoticeOverlay(child: child!),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  builder: (sheetContext) => SizedBox(
                    height: 230,
                    child: Center(
                      child: ElevatedButton(
                        onPressed: () =>
                            AppNotices.of(sheetContext).showSnackBar(
                              const SnackBar(
                                content: Text('Complete the color group first'),
                                backgroundColor: Color(0xFF9C423C),
                              ),
                            ),
                        child: const Text('Display warning'),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Open sheet'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open sheet'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Display warning'), findsOneWidget);

    await tester.tap(find.text('Display warning'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('app-top-notice')),
      findsOneWidget,
    );
    expect(find.text('Complete the color group first'), findsOneWidget);
    // The sheet is still open; the notification is drawn ABOVE the Navigator.
    expect(find.text('Display warning'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey<String>('app-top-notice')),
        matching: find.byType(AppNoticeOverlay),
      ),
      findsOneWidget,
    );
    // This root-level banner must not create RawTooltip: it is ABOVE
    // the Navigator overlay and has no Overlay ancestor of its own.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('app-top-notice')),
        matching: find.byType(Tooltip),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.byKey(const ValueKey<String>('app-top-notice-dismiss')),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('app-top-notice')), findsNothing);
  });

  testWidgets('Top notification wraps on a narrow screen without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            AppNoticeOverlay(child: child ?? const SizedBox.shrink()),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => AppNotices.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'This is a longer game-rule warning that needs to wrap '
                    'over more than one line on a narrow mobile screen.',
                  ),
                ),
              ),
              child: const Text('Show notice'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show notice'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('app-top-notice')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    // The banner uses a five-second auto-dismiss Timer. Dismiss it BEFORE
    // this test ends; tearDown runs too late for Flutter's pending-timer
    // invariant, and pumpAndSettle() is unsafe with continuous animations.
    await tester.tap(
      find.byKey(const ValueKey<String>('app-top-notice-dismiss')),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('app-top-notice')), findsNothing);
  });

  testWidgets('Unmounting the notice overlay cancels its pending timer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            AppNoticeOverlay(child: child ?? const SizedBox.shrink()),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => AppNotices.of(context).showSnackBar(
                const SnackBar(content: Text('Temporary game notice')),
              ),
              child: const Text('Display notice'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Display notice'));
    await tester.pump();
    expect(find.text('Temporary game notice'), findsOneWidget);

    // Simulate removing the app root before its five-second timer elapses.
    // The overlay must cancel the Timer during dispose.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('app-top-notice')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

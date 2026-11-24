import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/core/fonts/font_app_builder.dart';
import 'package:monopoly/core/theme/app_theme.dart';
import 'package:monopoly/l10n/generated/app_localizations.dart';
import 'package:monopoly/models/app_state.dart';
import 'package:monopoly/providers/app_controller.dart';
import 'package:monopoly/ui/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ReadyProfile extends AppController {
  @override
  Future<AppState> build() async => const AppState();
}

Future<void> _pumpHome(WidgetTester tester, Size logicalSize) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = logicalSize;
  final container = ProviderContainer(
    overrides: [appControllerProvider.overrideWith(_ReadyProfile.new)],
  );
  addTearDown(container.dispose);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await container.read(appControllerProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark(languageCode: 'en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('Chrome-size home cards do not overflow vertically', (
    tester,
  ) async {
    await _pumpHome(tester, const Size(980, 782));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('How to play'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Wide Chrome home panels are equal-height without clipping', (
    tester,
  ) async {
    await _pumpHome(tester, const Size(980, 782));
    final profile = find.byKey(const ValueKey<String>('home-profile-panel'));
    final balance = find.byKey(const ValueKey<String>('home-balance-panel'));
    expect(profile, findsOneWidget);
    expect(balance, findsOneWidget);
    final a = tester.getRect(profile);
    final b = tester.getRect(balance);
    expect((a.top - b.top).abs(), lessThan(0.5));
    expect((a.height - b.height).abs(), lessThan(0.5));
    expect(find.text('How to play'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Chrome home panels also match at a narrower desktop width', (
    tester,
  ) async {
    await _pumpHome(tester, const Size(800, 740));
    final profile = tester.getRect(
      find.byKey(const ValueKey<String>('home-profile-panel')),
    );
    final balance = tester.getRect(
      find.byKey(const ValueKey<String>('home-balance-panel')),
    );
    // The 800dp viewport leaves 752dp after 24dp padding on each side;
    // both cards must still be in the same row and have equal heights.
    expect(balance.left, greaterThan(profile.right));
    expect((profile.top - balance.top).abs(), lessThan(0.5));
    expect((profile.height - balance.height).abs(), lessThan(0.5));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Narrow browser stacks home panels without layout overflow', (
    tester,
  ) async {
    await _pumpHome(tester, const Size(760, 800));
    final profile = tester.getRect(
      find.byKey(const ValueKey<String>('home-profile-panel')),
    );
    final balance = tester.getRect(
      find.byKey(const ValueKey<String>('home-balance-panel')),
    );
    // Only 712dp is available; stacking is intentional below 720dp.
    expect(balance.top, greaterThanOrEqualTo(profile.bottom));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Mobile home still exposes the start shortcut', (tester) async {
    await _pumpHome(tester, const Size(390, 844));
    expect(
      find.byKey(const ValueKey<String>('home-floating-start-game')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Home settings hides optional showcase and redundant token link',
    (tester) async {
      await _pumpHome(tester, const Size(980, 782));
      await tester.tap(find.byKey(const ValueKey<String>('home-menu-button')));
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.text('3D Showroom'), findsNothing);
      expect(find.text('Player Tokens'), findsNothing);
      expect(find.text('Match History'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Bangla text has a more readable base theme size', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(languageCode: 'bn'),
        builder: (context, child) => FontAppBuilder(
          languageCode: 'bn',
          child: child ?? const SizedBox.shrink(),
        ),
        home: const Scaffold(body: Text('বাংলা ভাষার নমুনা')),
      ),
    );
    await tester.pump();
    final label = tester.element(find.text('বাংলা ভাষার নমুনা'));
    final theme = Theme.of(label);
    expect(theme.textTheme.bodyMedium!.fontSize!, greaterThan(14));
    expect(theme.textTheme.bodyMedium!.fontFamily, 'Nikosh');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

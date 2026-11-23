import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/core/theme/app_theme.dart';
import 'package:monopoly/game/ui/game_setup_screen.dart';
import 'package:monopoly/l10n/generated/app_localizations.dart';
import 'package:monopoly/models/app_state.dart';
import 'package:monopoly/providers/app_controller.dart';
import 'package:monopoly/ui/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Use an in-memory profile so these UI tests do not depend on device storage.
class _TestProfileController extends AppController {
  @override
  Future<AppState> build() async => const AppState();
}

/// Configure the logical view size used by MediaQuery for responsive layouts.
void _setLogicalScreenSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Mount the actual HomeScreen with a *ready* profile provider.
///
/// Testing through MonopolyApp makes this small, focused UI test dependent
/// on its asynchronous loading/splash route. In particular, pumpAndSettle()
/// does not guarantee a Future-backed provider has reached AsyncData before
/// a finder checks for HomeScreen. Resolve the provider first, and let a
/// real MaterialApp own the Navigator used by the Start Game button.
Future<void> _pumpReadyHome(WidgetTester tester) async {
  final container = ProviderContainer(
    overrides: [appControllerProvider.overrideWith(_TestProfileController.new)],
  );
  addTearDown(container.dispose);

  // Resolving the AsyncNotifier before mounting avoids a loading screen.
  expect(await container.read(appControllerProvider.future), isA<AppState>());

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: AppTheme.dark(languageCode: 'en'),
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pump();
  expect(find.byType(HomeScreen), findsOneWidget);
}

void main() {
  // GameSetupScreen checks for a saved game when it opens. Mock the legacy
  // preferences API used by OfflineGameStore, without depending on device IO.
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Mobile home floating Start Game opens the existing setup', (
    tester,
  ) async {
    _setLogicalScreenSize(tester, const Size(410, 880));
    await _pumpReadyHome(tester);

    final homeContext = tester.element(find.byType(HomeScreen));
    expect(MediaQuery.sizeOf(homeContext).width, lessThan(650));

    final quickStart = find.byKey(
      const ValueKey<String>('home-floating-start-game'),
    );
    expect(quickStart, findsOneWidget);
    await tester.tap(quickStart);
    await tester.pump();
    // Bounded navigation frames; do not use pumpAndSettle with indefinitely
    // repeating gameplay animations.
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.byType(GameSetupScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Desktop home also exposes the quick start button', (
    tester,
  ) async {
    _setLogicalScreenSize(tester, const Size(1024, 768));
    await _pumpReadyHome(tester);

    final homeContext = tester.element(find.byType(HomeScreen));
    expect(MediaQuery.sizeOf(homeContext).width, greaterThanOrEqualTo(650));
    expect(
      find.byKey(const ValueKey<String>('home-floating-start-game')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

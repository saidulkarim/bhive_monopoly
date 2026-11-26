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

class _BanglaProfileController extends AppController {
  @override
  Future<AppState> build() async => const AppState(languageCode: 'bn');
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

/// Record actual route pushes, including routes hidden behind the top route.
class _SetupNavigationObserver extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (previousRoute != null) pushes++;
  }
}

/// Mount the actual HomeScreen with a *ready* profile provider.
///
/// Testing through MonopolyApp makes this small, focused UI test dependent
/// on its asynchronous loading/splash route. In particular, pumpAndSettle()
/// does not guarantee a Future-backed provider has reached AsyncData before
/// a finder checks for HomeScreen. Resolve the provider first, and let a
/// real MaterialApp own the Navigator used by the Start Game button.
Future<void> _pumpReadyHome(
  WidgetTester tester, {
  String language = 'en',
  NavigatorObserver? observer,
}) async {
  final container = ProviderContainer(
    overrides: [
      appControllerProvider.overrideWith(
        () => language == 'bn'
            ? _BanglaProfileController()
            : _TestProfileController(),
      ),
    ],
  );
  addTearDown(container.dispose);

  // Resolving the AsyncNotifier before mounting avoids a loading screen.
  expect(await container.read(appControllerProvider.future), isA<AppState>());

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: AppTheme.dark(languageCode: language),
        navigatorObservers: [?observer],
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

  testWidgets('Mobile home primary Start Game opens the existing setup', (
    tester,
  ) async {
    _setLogicalScreenSize(tester, const Size(410, 880));
    final observer = _SetupNavigationObserver();
    await _pumpReadyHome(tester, observer: observer);

    final homeContext = tester.element(find.byType(HomeScreen));
    expect(MediaQuery.sizeOf(homeContext).width, lessThan(650));

    final quickStart = find.byKey(
      const ValueKey<String>('home-primary-start-game'),
    );
    expect(quickStart, findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('home-floating-start-game')),
      findsNothing,
    );
    final panel = find.byKey(const ValueKey<String>('home-profile-panel'));
    expect(
      tester.getRect(quickStart).bottom,
      lessThan(tester.getRect(panel).top),
    );
    expect(tester.getSize(quickStart).width, greaterThan(300));
    final action = tester.widget<FilledButton>(quickStart).onPressed!;
    action();
    action(); // Repeated activation before the next frame must not push twice.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();

    // A visible-widget finder alone cannot detect a duplicate hidden route.
    expect(observer.pushes, 1);
    final setup = find.byType(GameSetupScreen, skipOffstage: false);
    expect(setup, findsOneWidget);
    final navigator = Navigator.of(tester.element(setup));
    navigator.pop();

    // Reverse transitions and overlay removal can take separate frames.
    // Advance bounded frames rather than settling unrelated animations.
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (setup.evaluate().isEmpty) break;
    }
    await tester.pump();
    expect(setup, findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(navigator.canPop(), isFalse);
    expect(observer.pushes, 1);
    expect(tester.widget<FilledButton>(quickStart).onPressed, isNotNull);
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
      find.byKey(const ValueKey<String>('home-primary-start-game')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Bangla home has a single wide primary action above profile', (
    tester,
  ) async {
    _setLogicalScreenSize(tester, const Size(360, 800));
    await _pumpReadyHome(tester, language: 'bn');
    final start = find.byKey(const ValueKey<String>('home-primary-start-game'));
    final profile = find.byKey(const ValueKey<String>('home-profile-panel'));
    expect(start, findsOneWidget);
    expect(
      find.descendant(of: start, matching: find.text('খেলা শুরু করুন')),
      findsOneWidget,
    );
    expect(tester.getRect(start).bottom, lessThan(tester.getRect(profile).top));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

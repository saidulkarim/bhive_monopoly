import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:monopoly/main.dart';
import 'package:monopoly/models/app_state.dart';
import 'package:monopoly/providers/app_controller.dart';

class _MemoryController extends AppController {
  @override
  Future<AppState> build() async => const AppState();

  @override
  Future<void> setLanguage(String code) async {
    state = AsyncData(state.requireValue.withLanguage(code));
  }
}

/// Open the real home-page settings drawer. Language choices are no longer
/// visible directly on the home page.
Future<void> _openSettingsIfNeeded(WidgetTester tester) async {
  if (find.text('বাংলা').evaluate().isEmpty) {
    await tester.tap(find.byKey(const ValueKey<String>('home-menu-button')));
    await tester.pumpAndSettle();
  }
  expect(find.text('বাংলা'), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // The settings drawer persists explicit USD/BDT choices through the
    // legacy SharedPreferences API. Avoid reading actual user preferences.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Home menu switches language and currency independently', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('bn');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appControllerProvider.overrideWith(_MemoryController.new)],
        child: const MonopolyApp(),
      ),
    );
    await tester.pumpAndSettle();

    // English remains the default, even when the device locale is Bangla.
    expect(find.text(r'$1,500'), findsOneWidget);
    expect(find.text('My profile'), findsOneWidget);

    // Phase 13 moved the language controls into the hamburger menu.
    await _openSettingsIfNeeded(tester);
    await tester.tap(find.text('বাংলা'));
    await tester.pumpAndSettle();
    expect(find.text('আমার প্রোফাইল'), findsOneWidget);

    // Currency is an independent preference: explicitly choose Taka.
    await _openSettingsIfNeeded(tester);
    await tester.tap(find.byKey(const ValueKey<String>('home-currency-bdt')));
    await tester.pumpAndSettle();
    expect(find.text('৳১,৫০০'), findsOneWidget);

    // Switching back to English must NOT silently change the selected Taka.
    await _openSettingsIfNeeded(tester);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('My profile'), findsOneWidget);
    expect(find.text('৳1,500'), findsOneWidget);

    // The user may explicitly switch back to Dollar in English.
    await _openSettingsIfNeeded(tester);
    await tester.tap(find.byKey(const ValueKey<String>('home-currency-usd')));
    await tester.pumpAndSettle();
    expect(find.text(r'$1,500'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
  testWidgets('English is default and switching to Bangla updates money', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('bn');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appControllerProvider.overrideWith(_MemoryController.new)],
        child: const MonopolyApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(r'$1,500'), findsOneWidget);
    expect(find.text('My profile'), findsOneWidget);

    await tester.tap(find.text('বাংলা'));
    await tester.pumpAndSettle();
    expect(find.text('৳১,৫০০'), findsOneWidget);
    expect(find.text('আমার প্রোফাইল'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text(r'$1,500'), findsOneWidget);
  });
}

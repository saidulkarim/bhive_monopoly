// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lib/core/fonts/font_catalog.dart';
import '../../lib/core/fonts/font_preferences.dart';
import '../../lib/core/fonts/font_app_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Default font order is Hadi -> Nikosh and Exo2', () {
    expect(FontCatalog.defaultFor('bn'), 'Hadi');
    expect(FontCatalog.fallbacks('bn', 'Hadi'), <String>['Nikosh']);
    expect(FontCatalog.defaultFor('en'), 'Exo2');
    expect(FontCatalog.isAllowed('bn', 'Unregistered Font'), isFalse);
  });

  test(
    'Persists separate default fonts and restores them on relaunch',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final firstSession = FontPreferences();
      await firstSession.load();
      expect(firstSession.banglaFamily, 'Hadi');
      expect(firstSession.englishFamily, 'Exo2');

      await firstSession.save(banglaFamily: 'Nikosh', englishFamily: 'Roboto');
      expect(firstSession.banglaFamily, 'Nikosh');
      expect(firstSession.englishFamily, 'Roboto');
      expect(firstSession.fallbacksFor('bn'), contains('Hadi'));

      final secondSession = FontPreferences();
      await secondSession.load();
      expect(secondSession.banglaFamily, 'Nikosh');
      expect(secondSession.englishFamily, 'Roboto');

      await secondSession.restoreDefaults();
      expect(secondSession.banglaFamily, 'Hadi');
      expect(secondSession.englishFamily, 'Exo2');

      firstSession.dispose();
      secondSession.dispose();
    },
  );

  test('Invalid stale selections safely resolve to default font', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bhive_font_bangla_v1': 'MissingBanglaFont',
      'bhive_font_english_v1': 'MissingEnglishFont',
    });
    final prefs = FontPreferences();
    await prefs.load();
    expect(prefs.banglaFamily, 'Hadi');
    expect(prefs.englishFamily, 'Exo2');
    prefs.dispose();
  });

  testWidgets('FontAppBuilder applies saved locale font to Material theme', (
    WidgetTester tester,
  ) async {
    // This test loads the singleton before the first widget frame.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bhive_font_bangla_v1': 'Hadi',
      'bhive_font_english_v1': 'Exo2',
    });
    await FontPreferences.instance.load();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            FontAppBuilder(languageCode: 'bn', child: child!),
        home: const Scaffold(body: Text('বাংলা অ আ ক খ')),
      ),
    );
    expect(
      Theme.of(
        tester.element(find.text('বাংলা অ আ ক খ')),
      ).textTheme.bodyMedium!.fontFamily,
      'Hadi',
    );
    expect(
      Theme.of(
        tester.element(find.text('বাংলা অ আ ক খ')),
      ).textTheme.bodyMedium!.fontFamilyFallback,
      <String>['Nikosh'],
    );
  });
}

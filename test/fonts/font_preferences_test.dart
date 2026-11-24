import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:monopoly/core/fonts/font_catalog.dart';
import 'package:monopoly/core/fonts/font_preferences.dart';
import 'package:monopoly/core/fonts/font_app_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('KarnaphuliMJ default and supported Unicode fallbacks', () {
    expect(FontCatalog.defaultFor('bn'), 'KarnaphuliMJ');
    expect(FontCatalog.fallbacks('bn', 'KarnaphuliMJ'), <String>[
      'Nikosh',
      'NikoshBAN',
    ]);
    expect(FontCatalog.fallbacks('bn', 'Hadi'), <String>[
      'Nikosh',
      'NikoshBAN',
    ]);
    expect(FontCatalog.isAllowed('bn', 'KarnaphuliMJ'), isTrue);
    expect(FontCatalog.defaultFor('en'), 'Exo2');
  });

  test('Independent font choices persist and restore', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final first = FontPreferences();
    await first.load();
    expect(first.banglaFamily, 'KarnaphuliMJ');
    expect(first.englishFamily, 'Exo2');

    await first.save(banglaFamily: 'Hadi', englishFamily: 'Roboto');
    expect(first.banglaFamily, 'Hadi');
    expect(first.fallbacksFor('bn'), <String>['Nikosh', 'NikoshBAN']);

    final second = FontPreferences();
    await second.load();
    expect(second.banglaFamily, 'Hadi');
    expect(second.englishFamily, 'Roboto');

    await second.restoreDefaults();
    expect(second.banglaFamily, 'KarnaphuliMJ');
    expect(second.englishFamily, 'Exo2');
    first.dispose();
    second.dispose();
  });

  test('Invalid old selection reverts to KarnaphuliMJ default', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bhive_font_bangla_v1': 'MissingBanglaFont',
      'bhive_font_english_v1': 'MissingEnglishFont',
    });
    final prefs = FontPreferences();
    await prefs.load();
    expect(prefs.banglaFamily, 'KarnaphuliMJ');
    expect(prefs.englishFamily, 'Exo2');
    prefs.dispose();
  });

  test('Old Karnaphuli alias migrates to KarnaphuliMJ', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bhive_font_bangla_v1': 'Karnaphuli',
      'bhive_font_english_v1': 'Exo2',
      'bhive_font_migrated_to_karnaphuli_v1': true,
    });
    final prefs = FontPreferences();
    await prefs.load();
    expect(prefs.banglaFamily, 'KarnaphuliMJ');
    final stored = await SharedPreferences.getInstance();
    expect(stored.getString('bhive_font_bangla_v1'), 'KarnaphuliMJ');
    expect(stored.getBool('bhive_font_default_karnaphuli_mj_v3'), isTrue);
    prefs.dispose();
  });

  test(
    'Explicit Nikosh selection is preserved without prior migration',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'bhive_font_bangla_v1': 'Nikosh',
        'bhive_font_english_v1': 'Exo2',
      });
      final prefs = FontPreferences();
      await prefs.load();
      expect(prefs.banglaFamily, 'Nikosh');
      prefs.dispose();
    },
  );

  test('Previous automatic Nikosh migration restores KarnaphuliMJ', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bhive_font_bangla_v1': 'Nikosh',
      'bhive_font_english_v1': 'Exo2',
      'bhive_font_unicode_nikosh_v2': true,
    });
    final prefs = FontPreferences();
    await prefs.load();
    expect(prefs.banglaFamily, 'KarnaphuliMJ');
    final stored = await SharedPreferences.getInstance();
    expect(stored.getString('bhive_font_bangla_v1'), 'KarnaphuliMJ');
    expect(stored.getBool('bhive_font_default_karnaphuli_mj_v3'), isTrue);
    prefs.dispose();
  });

  testWidgets('App font builder keeps MJ selection with Unicode-safe text', (
    tester,
  ) async {
    // Singleton is loaded only once in this isolate.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bhive_font_bangla_v1': 'KarnaphuliMJ',
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
    final ctx = tester.element(find.text('বাংলা অ আ ক খ'));
    expect(Theme.of(ctx).textTheme.bodyMedium!.fontFamily, 'Nikosh');
    expect(Theme.of(ctx).textTheme.bodyMedium!.fontFamilyFallback, <String>[
      'NikoshBAN',
    ]);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

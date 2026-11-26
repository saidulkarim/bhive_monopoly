import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:monopoly/core/fonts/font_catalog.dart';
import 'package:monopoly/core/fonts/font_preferences.dart';
import 'package:monopoly/core/fonts/font_app_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Noto Sans Bengali default and supported Unicode fallbacks', () {
    expect(FontCatalog.defaultFor('bn'), 'NotoSansBengali');
    expect(FontCatalog.fallbacks('bn', 'KarnaphuliMJ'), <String>[
      'NotoSansBengali',
      'Nikosh',
      'NikoshBAN',
    ]);
    expect(FontCatalog.fallbacks('bn', 'Hadi'), <String>[
      'NotoSansBengali',
      'Nikosh',
      'NikoshBAN',
    ]);
    expect(
      FontCatalog.renderFamily('bn', 'NotoSansBengali'),
      'NotoSansBengali',
    );
    expect(FontCatalog.renderFallbacks('bn', 'NotoSansBengali'), <String>[
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
    expect(first.banglaFamily, 'NotoSansBengali');
    expect(first.englishFamily, 'Exo2');

    await first.save(banglaFamily: 'Hadi', englishFamily: 'Roboto');
    expect(first.banglaFamily, 'Hadi');
    expect(first.fallbacksFor('bn'), <String>[
      'NotoSansBengali',
      'Nikosh',
      'NikoshBAN',
    ]);

    final second = FontPreferences();
    await second.load();
    expect(second.banglaFamily, 'Hadi');
    expect(second.englishFamily, 'Roboto');

    await second.restoreDefaults();
    expect(second.banglaFamily, 'NotoSansBengali');
    expect(second.englishFamily, 'Exo2');
    first.dispose();
    second.dispose();
  });

  test('Invalid old selection reverts to Noto Sans Bengali default', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bhive_font_bangla_v1': 'MissingBanglaFont',
      'bhive_font_english_v1': 'MissingEnglishFont',
    });
    final prefs = FontPreferences();
    await prefs.load();
    expect(prefs.banglaFamily, 'NotoSansBengali');
    expect(prefs.englishFamily, 'Exo2');
    prefs.dispose();
  });

  test('Old Karnaphuli alias migrates to Noto Sans Bengali', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bhive_font_bangla_v1': 'Karnaphuli',
      'bhive_font_english_v1': 'Exo2',
      'bhive_font_migrated_to_karnaphuli_v1': true,
    });
    final prefs = FontPreferences();
    await prefs.load();
    expect(prefs.banglaFamily, 'NotoSansBengali');
    final stored = await SharedPreferences.getInstance();
    expect(stored.getString('bhive_font_bangla_v1'), 'NotoSansBengali');
    expect(stored.getBool('bhive_font_default_noto_bengali_v4'), isTrue);
    prefs.dispose();
  });

  test('Explicit Nikosh selection is preserved after Noto migration', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bhive_font_bangla_v1': 'Nikosh',
      'bhive_font_default_noto_bengali_v4': true,
      'bhive_font_english_v1': 'Exo2',
    });
    final prefs = FontPreferences();
    await prefs.load();
    expect(prefs.banglaFamily, 'Nikosh');
    prefs.dispose();
  });

  test(
    'Previous automatic Nikosh migration migrates to Noto Sans Bengali',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'bhive_font_bangla_v1': 'Nikosh',
        'bhive_font_english_v1': 'Exo2',
        'bhive_font_unicode_nikosh_v2': true,
      });
      final prefs = FontPreferences();
      await prefs.load();
      expect(prefs.banglaFamily, 'NotoSansBengali');
      final stored = await SharedPreferences.getInstance();
      expect(stored.getString('bhive_font_bangla_v1'), 'NotoSansBengali');
      expect(stored.getBool('bhive_font_default_noto_bengali_v4'), isTrue);
      prefs.dispose();
    },
  );

  testWidgets('App font builder keeps MJ selection with Unicode-safe text', (
    tester,
  ) async {
    // Singleton is loaded only once in this isolate.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bhive_font_bangla_v1': 'KarnaphuliMJ',
      'bhive_font_default_noto_bengali_v4': true,
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
      'NotoSansBengali',
      'NikoshBAN',
    ]);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

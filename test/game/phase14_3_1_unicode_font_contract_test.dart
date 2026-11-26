import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monopoly/core/fonts/font_catalog.dart';
import 'package:monopoly/core/fonts/font_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Noto Sans Bengali is default with legacy Unicode font fallback', () {
    expect(FontCatalog.defaultBangla, 'NotoSansBengali');
    expect(
      FontCatalog.renderFamily('bn', 'NotoSansBengali'),
      'NotoSansBengali',
    );
    expect(FontCatalog.renderFallbacks('bn', 'NotoSansBengali'), <String>[
      'Nikosh',
      'NikoshBAN',
    ]);
    expect(FontCatalog.isAllowed('bn', 'KarnaphuliMJ'), isTrue);
    expect(FontCatalog.isAllowed('bn', 'Nikosh'), isTrue);
    expect(FontCatalog.fallbacks('bn', 'KarnaphuliMJ'), <String>[
      'NotoSansBengali',
      'Nikosh',
      'NikoshBAN',
    ]);
    expect(FontCatalog.renderFamily('bn', 'KarnaphuliMJ'), 'Nikosh');
    expect(FontCatalog.renderFallbacks('bn', 'KarnaphuliMJ'), <String>[
      'NotoSansBengali',
      'NikoshBAN',
    ]);
    expect(FontCatalog.defaultBangla, 'NotoSansBengali');
  });

  test('Previously migrated Nikosh default restores once', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bhive_font_bangla_v1': 'Nikosh',
      'bhive_font_unicode_nikosh_v2': true,
    });
    final prefs = FontPreferences();
    await prefs.load();
    final values = await SharedPreferences.getInstance();
    expect(prefs.banglaFamily, 'NotoSansBengali');
    expect(values.getString('bhive_font_bangla_v1'), 'NotoSansBengali');
    expect(values.getBool('bhive_font_default_noto_bengali_v4'), isTrue);
    prefs.dispose();
  });
}

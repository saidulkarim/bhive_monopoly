import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monopoly/core/fonts/font_catalog.dart';
import 'package:monopoly/core/fonts/font_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('KarnaphuliMJ is preferred with Unicode font fallback', () {
    expect(FontCatalog.defaultBangla, 'KarnaphuliMJ');
    expect(FontCatalog.isAllowed('bn', 'KarnaphuliMJ'), isTrue);
    expect(FontCatalog.isAllowed('bn', 'Nikosh'), isTrue);
    expect(FontCatalog.fallbacks('bn', 'KarnaphuliMJ'), <String>[
      'Nikosh',
      'NikoshBAN',
    ]);
    expect(FontCatalog.renderFamily('bn', 'KarnaphuliMJ'), 'Nikosh');
    expect(FontCatalog.renderFallbacks('bn', 'KarnaphuliMJ'), <String>[
      'NikoshBAN',
    ]);
    expect(FontCatalog.defaultBangla, 'KarnaphuliMJ');
  });

  test('Previously migrated Nikosh default restores once', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bhive_font_bangla_v1': 'Nikosh',
      'bhive_font_unicode_nikosh_v2': true,
    });
    final prefs = FontPreferences();
    await prefs.load();
    final values = await SharedPreferences.getInstance();
    expect(prefs.banglaFamily, 'KarnaphuliMJ');
    expect(values.getString('bhive_font_bangla_v1'), 'KarnaphuliMJ');
    expect(values.getBool('bhive_font_default_karnaphuli_mj_v3'), isTrue);
    prefs.dispose();
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monopoly/core/fonts/font_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final previous in ['KarnaphuliMJ', 'Nikosh', 'Hadi', 'NikoshBAN']) {
    test('Migrates $previous once and preserves later manual choice', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'bhive_font_bangla_v1': previous,
        'bhive_font_english_v1': 'Roboto',
        'bhive_font_default_karnaphuli_mj_v3': true,
      });
      final first = FontPreferences();
      addTearDown(first.dispose);
      await first.load();
      expect(first.banglaFamily, 'NotoSansBengali');
      expect(first.englishFamily, 'Roboto');
      final storage = await SharedPreferences.getInstance();
      expect(storage.getString('bhive_font_bangla_v1'), 'NotoSansBengali');
      expect(storage.getBool('bhive_font_default_noto_bengali_v4'), isTrue);
      await first.save(banglaFamily: previous, englishFamily: 'Roboto');
      final second = FontPreferences();
      addTearDown(second.dispose);
      await second.load();
      expect(second.banglaFamily, previous);
      expect(second.englishFamily, 'Roboto');
      await second.restoreDefaults();
      expect(second.banglaFamily, 'NotoSansBengali');
      expect(second.englishFamily, 'Exo2');
    });
  }
}

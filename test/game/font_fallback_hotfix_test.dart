import 'package:flutter_test/flutter_test.dart';

import 'package:monopoly/core/fonts/font_catalog.dart';
import 'package:monopoly/core/fonts/font_preferences.dart';
import 'package:monopoly/game/ui/game_text.dart';

void main() {
  test('Noto Sans Bengali default uses Nikosh fallback when needed', () {
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
    expect(FontCatalog.fallbacks('en', 'Exo2'), isEmpty);
    expect(FontCatalog.fallbacks('en', 'Roboto'), <String>['Exo2']);
  });

  test('GameText respects the selected font fallback', () {
    const text = GameText('bn');
    final current = FontPreferences.instance.familyFor('bn');
    expect(text.fallbackFonts, FontCatalog.renderFallbacks('bn', current));
    expect(text.fallbackFonts, isNot(contains(text.font)));
  });
}

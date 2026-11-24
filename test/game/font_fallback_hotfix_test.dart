import 'package:flutter_test/flutter_test.dart';

import 'package:monopoly/core/fonts/font_catalog.dart';
import 'package:monopoly/core/fonts/font_preferences.dart';
import 'package:monopoly/game/ui/game_text.dart';

void main() {
  test('KarnaphuliMJ default uses Nikosh fallback when needed', () {
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

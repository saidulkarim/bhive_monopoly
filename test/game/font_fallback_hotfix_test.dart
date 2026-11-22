import 'package:flutter_test/flutter_test.dart';

import 'package:monopoly/core/fonts/font_catalog.dart';
import 'package:monopoly/core/fonts/font_preferences.dart';
import 'package:monopoly/game/ui/game_text.dart';

void main() {
  test('Karnaphuli primary uses Nikosh alone as fallback', () {
    expect(FontCatalog.fallbacks('bn', 'Karnaphuli'), <String>['Nikosh']);
    expect(FontCatalog.fallbacks('bn', 'Nikosh'), <String>['Karnaphuli']);
    expect(FontCatalog.fallbacks('en', 'Exo2'), isEmpty);
    expect(FontCatalog.fallbacks('en', 'Roboto'), <String>['Exo2']);
    expect(FontCatalog.fallbacks('bn', 'Karnaphuli').contains('Karnaphuli'), isFalse);
  });

  test('GameText respects the selected font fallback', () {
    const text = GameText('bn');
    final current = FontPreferences.instance.familyFor('bn');
    expect(text.fallbackFonts, FontCatalog.fallbacks('bn', current));
    expect(text.fallbackFonts, isNot(contains(current)));
  });
}

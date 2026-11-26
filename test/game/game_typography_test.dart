import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:monopoly/game/ui/game_text.dart';
import 'package:monopoly/game/ui/game_typography.dart';

void main() {
  test('Bangla font, fallback, numerals, and all board labels', () {
    const bn = GameText('bn');
    const en = GameText('en');
    expect(bn.font, 'NotoSansBengali');
    expect(bn.fallbackFonts, <String>['Nikosh', 'NikoshBAN']);
    expect(en.font, 'Exo2');
    expect(bn.integer(1500), '১৫০০');
    expect(bn.money(1500), '৳১,৫০০');
    const overrides = <int, String>{
      2: 'Community Chest',
      4: 'Income Tax',
      5: 'Central Railway',
      7: 'Chance',
      10: 'JAIL / JUST VISITING',
      12: 'Electric Company',
      15: 'Airport Railway',
      17: 'Community Chest',
      22: 'Chance',
      25: 'Eastern Railway',
      33: 'Community Chest',
      35: 'Western Railway',
      36: 'Chance',
    };
    for (var index = 0; index < 40; index++) {
      final localized = bn.spaceName(index, 'English name');
      expect(localized, isNot('English name'));
      expect(localized, isNotEmpty);
      expect(
        en.spaceName(index, 'English name'),
        overrides[index] ?? 'English name',
      );
    }
    expect(bn.spaceName(100, 'Unknown'), 'Unknown');
  });

  testWidgets('Material theme switches fonts when language changes', (
    tester,
  ) async {
    Future<void> pumpLanguage(String code) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GameTypography(
            languageCode: code,
            child: const Scaffold(body: Text('Sample')),
          ),
        ),
      );
    }

    await pumpLanguage('bn');
    var ctx = tester.element(find.text('Sample'));
    expect(Theme.of(ctx).textTheme.bodyMedium!.fontFamily, 'NotoSansBengali');
    expect(Theme.of(ctx).textTheme.bodyMedium!.fontFamilyFallback, <String>[
      'Nikosh',
      'NikoshBAN',
    ]);

    await pumpLanguage('en');
    ctx = tester.element(find.text('Sample'));
    expect(Theme.of(ctx).textTheme.bodyMedium!.fontFamily, 'Exo2');
  });
}

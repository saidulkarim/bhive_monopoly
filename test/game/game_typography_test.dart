// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/game/ui/game_text.dart';
import '../../lib/game/ui/game_typography.dart';

void main() {
  test('Bangla font, fallback, numerals, and all board labels', () {
    const bn = GameText('bn');
    const en = GameText('en');
    expect(bn.font, 'Karnaphuli');
    expect(bn.fallbackFonts, ['Nikosh']);
    expect(en.font, 'Exo2');
    expect(bn.integer(1500), '১৫০০');
    expect(bn.money(1500), '৳১,৫০০');
    for (var index = 0; index < 40; index++) {
      final localized = bn.spaceName(index, 'English name');
      expect(localized, isNot('English name'));
      expect(localized, isNotEmpty);
      expect(en.spaceName(index, 'English name'), 'English name');
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
    expect(Theme.of(ctx).textTheme.bodyMedium!.fontFamily, 'Karnaphuli');

    await pumpLanguage('en');
    ctx = tester.element(find.text('Sample'));
    expect(Theme.of(ctx).textTheme.bodyMedium!.fontFamily, 'Exo2');
  });
}

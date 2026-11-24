import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/core/fonts/font_catalog.dart';
import 'package:monopoly/core/fonts/font_preferences.dart';
import 'package:monopoly/core/fonts/font_app_builder.dart';
import 'package:monopoly/game/ui/game_typography.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'KarnaphuliMJ remains the default preference, with legible Unicode rendering',
    () {
      expect(FontCatalog.defaultBangla, 'KarnaphuliMJ');
      expect(
        FontCatalog.renderFamily('bn', FontCatalog.defaultBangla),
        'Nikosh',
      );
      expect(
        FontCatalog.renderFallbacks('bn', FontCatalog.defaultBangla),
        <String>['NikoshBAN'],
      );
      expect(FontCatalog.renderFamily('bn', 'Hadi'), 'Hadi');
      expect(FontCatalog.renderFamily('en', 'Exo2'), 'Exo2');
    },
  );

  test('Saved KarnaphuliMJ selection survives a reload unchanged', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = FontPreferences();
    await preferences.load();
    expect(preferences.banglaFamily, 'KarnaphuliMJ');
    expect(preferences.renderFamilyFor('bn'), 'Nikosh');
    final reloaded = FontPreferences();
    await reloaded.load();
    expect(reloaded.banglaFamily, 'KarnaphuliMJ');
    preferences.dispose();
    reloaded.dispose();
  });

  testWidgets(
    'Bangla theme and nested game pages use one Unicode-safe family',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => FontAppBuilder(
            languageCode: 'bn',
            child: child ?? const SizedBox.shrink(),
          ),
          home: const GameTypography(
            languageCode: 'bn',
            child: Scaffold(body: Text('বাংলা · ভাষা · ডলার · টাকা')),
          ),
        ),
      );
      await tester.pump();
      final context = tester.element(find.text('বাংলা · ভাষা · ডলার · টাকা'));
      expect(Theme.of(context).textTheme.bodyMedium!.fontFamily, 'Nikosh');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

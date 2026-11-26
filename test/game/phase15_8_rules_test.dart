import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/core/config/game_config.dart';
import 'package:monopoly/core/theme/app_theme.dart';
import 'package:monopoly/l10n/generated/app_localizations.dart';
import 'package:monopoly/ui/screens/rules_content.dart';
import 'package:monopoly/ui/screens/rules_screen.dart';

void main() {
  test('updated rules use shared duration and reminder configuration', () {
    final rules = updatedRules('en');
    final duration = rules
        .singleWhere((r) => r.$1 == 'Match duration and winner')
        .$2;
    expect(duration, contains('Quick (${GameConfig.quickMatchMaximumTurns})'));
    expect(
      duration,
      contains('Standard (${GameConfig.standardMatchMaximumTurns})'),
    );
    expect(duration, contains('Network matches do not yet offer'));
    final turn = rules.singleWhere((r) => r.$1 == 'Smart turn assistance').$2;
    expect(turn, contains('${GameConfig.endTurnReminderSeconds} seconds'));
    expect(turn, contains('${GameConfig.autoEndTurnCountdownSeconds} seconds'));
  });

  test('Bangla rules localize dynamic numeric values and headings', () {
    final rules = updatedRules('bn');
    expect(rules.length, updatedRules('en').length);
    final text = rules.map((r) => '${r.$1} ${r.$2}').join(' ');
    expect(text, contains('কেনার প্রস্তাব'));
    expect(text, isNot(contains(RegExp(r'[0-9]'))));
  });

  for (final code in ['en', 'bn']) {
    testWidgets('rules render and scroll in $code without overflow', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 760);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(code),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: AppTheme.dark(languageCode: code),
          home: const RulesScreen(),
        ),
      );
      await tester.pump();
      expect(
        find.text(code == 'bn' ? 'মৌলিক নিয়ম' : 'Core rules'),
        findsOneWidget,
      );
      final title = code == 'bn'
          ? 'কেনার প্রস্তাব ও দর-কষাকষি'
          : 'Buy requests and negotiation';
      // All list children are declared eagerly; scroll until the target is visible.
      await tester.scrollUntilVisible(find.text(title), 450, maxScrolls: 40);
      expect(find.text(title), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

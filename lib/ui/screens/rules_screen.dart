import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_preferences.dart';
import '../../core/utils/money_formatter.dart';
import '../../game/ui/game_typography.dart';
import '../../l10n/generated/app_localizations.dart';
import 'rules_content.dart';

/// Readable in-app rules, independent of the bundled PDF viewer.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final bn = language == 'bn';
    final basicRules = <(String, String)>[
      (l10n.ruleGoalTitle, l10n.ruleGoal),
      (l10n.ruleTurnTitle, l10n.ruleTurn),
      (l10n.rulePropertyTitle, l10n.ruleProperty),
      (l10n.ruleBuildingsTitle, l10n.ruleBuildings),
      (l10n.ruleJailTitle, l10n.ruleJail),
      (l10n.ruleDebtTitle, l10n.ruleDebt),
      (l10n.ruleParkingTitle, l10n.ruleParking),
    ];
    return AnimatedBuilder(
      animation: CurrencyPreferences.instance,
      builder: (context, _) => GameTypography(
        languageCode: language,
        child: Scaffold(
          appBar: AppBar(title: Text(l10n.howToPlay)),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _sectionHeading(bn ? 'মৌলিক নিয়ম' : 'Core rules'),
                    for (final rule in basicRules)
                      _RuleCard(
                        title: rule.$1,
                        body: _formatCurrency(rule.$2, language),
                      ),
                    const SizedBox(height: 16),
                    _sectionHeading(
                      bn
                          ? 'নতুন সুবিধা ও হালনাগাদ নিয়ম'
                          : 'New features and updated rules',
                    ),
                    for (final rule in updatedRules(language))
                      _RuleCard(title: rule.$1, body: rule.$2),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _sectionHeading(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppTheme.gold,
      ),
    ),
  );

  static String _formatCurrency(String text, String language) {
    // Existing translations contain whole-number game amounts. Preserve their
    // meaning while honoring independent language and currency preferences.
    return text.replaceAllMapped(RegExp(r'[$৳]([0-9০-৯]+)'), (match) {
      const bangla = '০১২৩৪৫৬৭৮৯';
      final digits = match[1]!.replaceAllMapped(
        RegExp(r'[০-৯]'),
        (digit) => bangla.indexOf(digit[0]!).toString(),
      );
      final amount = int.tryParse(digits);
      return amount == null
          ? match[0]!
          : MoneyFormatter.format(amount, languageCode: language);
    });
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.panel,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF34433A)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.gold,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(body, style: const TextStyle(fontSize: 16, height: 1.6)),
      ],
    ),
  );
}

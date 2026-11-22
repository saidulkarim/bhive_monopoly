// ignore_for_file: unnecessary_underscores

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rules = [
      (l10n.ruleGoalTitle, l10n.ruleGoal),
      (l10n.ruleTurnTitle, l10n.ruleTurn),
      (l10n.rulePropertyTitle, l10n.ruleProperty),
      (l10n.ruleBuildingsTitle, l10n.ruleBuildings),
      (l10n.ruleJailTitle, l10n.ruleJail),
      (l10n.ruleDebtTitle, l10n.ruleDebt),
      (l10n.ruleParkingTitle, l10n.ruleParking),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.howToPlay)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: rules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 24),
              itemBuilder: (context, index) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rules[index].$1,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: AppTheme.gold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    rules[index].$2,
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

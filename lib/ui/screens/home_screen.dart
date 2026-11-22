import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money_formatter.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers/app_controller.dart';
import '../widgets/player_avatar.dart';
import 'profile_screen.dart';
import 'font_settings_screen.dart';
import 'rules_screen.dart';
import '../../game/ui/game_setup_screen.dart';
import '../../game/ui/game_typography.dart';
import '../../game/ui/experience_settings_screen.dart';
import '../../game/ui/three_d_showroom_screen.dart';
import '../../game/ui/token_settings_screen.dart';
import '../../game/ui/match_history_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _changeLanguage(
    BuildContext context,
    WidgetRef ref,
    String code,
  ) async {
    try {
      await ref.read(appControllerProvider.notifier).setLanguage(code);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).saveError)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider).requireValue;
    final l10n = AppLocalizations.of(context);
    final name = state.displayName.isEmpty ? l10n.player : state.displayName;
    return GameTypography(
      languageCode: state.languageCode,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.emerald, AppTheme.obsidian, AppTheme.obsidian],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          const Text(
                            'bHiVE',
                            style: TextStyle(
                              fontFamily: 'Exo2',
                              color: AppTheme.gold,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                label: Text(
                                  'English',
                                  style: TextStyle(
                                    fontFamily: GameTypography.family('en'),
                                    fontFamilyFallback:
                                        GameTypography.fallbacks('en'),
                                  ),
                                ),
                                selected: state.languageCode == 'en',
                                onSelected: state.isSaving
                                    ? null
                                    : (selected) {
                                        if (selected &&
                                            state.languageCode != 'en') {
                                          _changeLanguage(context, ref, 'en');
                                        }
                                      },
                              ),
                              ChoiceChip(
                                label: Text(
                                  'বাংলা',
                                  style: TextStyle(
                                    fontFamily: GameTypography.family('bn'),
                                    fontFamilyFallback:
                                        GameTypography.fallbacks('bn'),
                                  ),
                                ),
                                selected: state.languageCode == 'bn',
                                onSelected: state.isSaving
                                    ? null
                                    : (selected) {
                                        if (selected &&
                                            state.languageCode != 'bn') {
                                          _changeLanguage(context, ref, 'bn');
                                        }
                                      },
                              ),
                              ActionChip(
                                avatar: const Icon(
                                  Icons.font_download_outlined,
                                  size: 20,
                                ),
                                label: Text(
                                  state.languageCode == 'bn'
                                      ? 'ফন্ট সেটিংস'
                                      : 'Font Settings',
                                ),
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => FontSettingsScreen(
                                      languageCode: state.languageCode,
                                    ),
                                  ),
                                ),
                              ),
                              ActionChip(
                                avatar: const Icon(
                                  Icons.view_in_ar_rounded,
                                  size: 20,
                                ),
                                label: Text(
                                  state.languageCode == 'bn'
                                      ? '৩ডি মডেল'
                                      : '3D Showroom',
                                ),
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ThreeDShowroomScreen(
                                      languageCode: state.languageCode,
                                    ),
                                  ),
                                ),
                              ),
                              ActionChip(
                                avatar: const Icon(
                                  Icons.directions_car_rounded,
                                  size: 20,
                                ),
                                label: Text(
                                  state.languageCode == 'bn'
                                      ? 'টোকেন নির্বাচন'
                                      : 'Player Tokens',
                                ),
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => TokenSettingsScreen(
                                      languageCode: state.languageCode,
                                    ),
                                  ),
                                ),
                              ),
                              ActionChip(
                                avatar: const Icon(
                                  Icons.leaderboard_rounded,
                                  size: 20,
                                ),
                                label: Text(
                                  state.languageCode == 'bn'
                                      ? 'খেলার ইতিহাস'
                                      : 'Match History',
                                ),
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => MatchHistoryScreen(
                                      languageCode: state.languageCode,
                                    ),
                                  ),
                                ),
                              ),
                              ActionChip(
                                avatar: const Icon(
                                  Icons.graphic_eq_rounded,
                                  size: 20,
                                ),
                                label: Text(
                                  state.languageCode == 'bn'
                                      ? 'গেম অভিজ্ঞতা'
                                      : 'Game Experience',
                                ),
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ExperienceSettingsScreen(
                                      languageCode: state.languageCode,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),
                      const Icon(
                        Icons.domain_rounded,
                        size: 100,
                        color: AppTheme.gold,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'bHiVE Monopoly',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Exo2',
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.gold,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.tagline,
                        textAlign: TextAlign.center,
                        style: GameTypography.style(
                          state.languageCode,
                          Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 40),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final sideBySide = constraints.maxWidth >= 680;
                          final actionStyle = ButtonStyle(
                            minimumSize: const WidgetStatePropertyAll(
                              Size(0, 56),
                            ),
                            padding: const WidgetStatePropertyAll(
                              EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 18,
                              ),
                            ),
                            shape: WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          );
                          final profile = _Panel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                PlayerAvatar(
                                  preset: state.avatarIndex,
                                  bytes: state.avatarBytes,
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  l10n.welcome(name),
                                  style: GameTypography.style(
                                    state.languageCode,
                                    Theme.of(context).textTheme.titleLarge,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(l10n.profileIntro),
                                if (sideBySide) const Spacer(),
                                const SizedBox(height: 24),
                                FilledButton.icon(
                                  style: actionStyle,
                                  onPressed: state.isSaving
                                      ? null
                                      : () => Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                const ProfileScreen(),
                                          ),
                                        ),
                                  icon: const Icon(
                                    Icons.person_outline_rounded,
                                  ),
                                  label: Text(l10n.editProfile),
                                ),
                              ],
                            ),
                          );
                          final balance = _Panel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.account_balance_wallet_outlined,
                                  color: AppTheme.gold,
                                  size: 36,
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  l10n.startingBalance,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  MoneyFormatter.format(
                                    1500,
                                    languageCode: state.languageCode,
                                  ),
                                  style: const TextStyle(
                                    color: AppTheme.gold,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(l10n.balanceExplanation),
                                if (sideBySide) const Spacer(),
                                const SizedBox(height: 24),
                                OutlinedButton.icon(
                                  style: actionStyle,
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const RulesScreen(),
                                    ),
                                  ),
                                  icon: const Icon(Icons.menu_book_outlined),
                                  label: Text(l10n.howToPlay),
                                ),
                              ],
                            ),
                          );
                          if (sideBySide) {
                            // Derive the shared height from the taller card so
                            // translated text and wrapped names remain visible.
                            return IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(child: profile),
                                  const SizedBox(width: 20),
                                  Expanded(child: balance),
                                ],
                              ),
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              profile,
                              const SizedBox(height: 16),
                              balance,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.gold,
                          foregroundColor: AppTheme.obsidian,
                          minimumSize: const Size.fromHeight(60),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => GameTypography(
                              languageCode: state.languageCode,
                              child: GameSetupScreen(
                                languageCode: state.languageCode,
                                playerName: name,
                                avatarIndex: state.avatarIndex,
                                avatarBytes: state.avatarBytes,
                              ),
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.casino_rounded),
                        label: Text(
                          state.languageCode == 'bn'
                              ? 'খেলা শুরু করুন (লোকাল মাল্টিপ্লেয়ার)'
                              : 'START GAME · LOCAL MULTIPLAYER',
                          style: TextStyle(
                            fontFamily: GameTypography.family(
                              state.languageCode,
                            ),
                            fontFamilyFallback: GameTypography.fallbacks(
                              state.languageCode,
                            ),
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppTheme.panel,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFF34433A)),
    ),
    child: child,
  );
}

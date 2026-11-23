import 'package:flutter/material.dart';

import '../../core/ui/app_notices.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/utils/currency_preferences.dart';
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
      AppNotices.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).saveError)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider).requireValue;
    final l10n = AppLocalizations.of(context);
    final name = state.displayName.isEmpty ? l10n.player : state.displayName;
    return AnimatedBuilder(
      animation: CurrencyPreferences.instance,
      builder: (context, _) => GameTypography(
        languageCode: state.languageCode,
        child: Scaffold(
          endDrawer: _settingsDrawer(
            context,
            ref,
            state.languageCode,
            state.isSaving,
          ),
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.emerald,
                  AppTheme.obsidian,
                  AppTheme.obsidian,
                ],
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
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'bHiVE',
                                style: TextStyle(
                                  fontFamily: 'Exo2',
                                  color: AppTheme.gold,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            Builder(
                              builder: (menuContext) => IconButton(
                                key: const ValueKey<String>('home-menu-button'),
                                tooltip: state.languageCode == 'bn'
                                    ? 'মেনু'
                                    : 'Menu',
                                onPressed: () =>
                                    Scaffold.of(menuContext).openEndDrawer(),
                                icon: const Icon(
                                  Icons.menu_rounded,
                                  color: AppTheme.gold,
                                  size: 30,
                                ),
                              ),
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
                                  Text(
                                    state.languageCode == 'bn'
                                        ? 'প্রত্যেকে একই পরিমাণ অর্থ নিয়ে শুরু করবে। ভাষা ও মুদ্রা মেনু থেকে আলাদাভাবে নির্বাচন করতে পারবেন।'
                                        : 'Everyone starts with the same balance. Set language and currency independently in Menu.',
                                  ),
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
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
      ),
    );
  }

  Widget _settingsDrawer(
    BuildContext context,
    WidgetRef ref,
    String languageCode,
    bool isSaving,
  ) {
    final bn = languageCode == 'bn';
    void navigate(Widget screen) {
      Navigator.of(context).pop(); // Close the drawer first.
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => screen));
    }

    Widget action(
      IconData icon,
      String english,
      String bangla,
      Widget Function() screen,
    ) => ListTile(
      leading: Icon(icon, color: AppTheme.gold),
      title: Text(bn ? bangla : english),
      onTap: () => navigate(screen()),
    );

    return Drawer(
      backgroundColor: AppTheme.obsidian,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
          children: [
            Text(
              bn ? 'bHiVE  •  সেটিংস' : 'bHiVE  •  SETTINGS',
              style: const TextStyle(
                fontFamily: 'Exo2',
                fontSize: 21,
                color: AppTheme.gold,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 32),
            Text(
              bn ? 'ভাষা' : 'Language',
              style: const TextStyle(color: AppTheme.gold, fontSize: 15),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 9,
              runSpacing: 7,
              children: [
                ChoiceChip(
                  label: const Text('English'),
                  selected: !bn,
                  onSelected: isSaving
                      ? null
                      : (_) => _changeLanguage(context, ref, 'en'),
                ),
                ChoiceChip(
                  label: const Text('বাংলা'),
                  selected: bn,
                  onSelected: isSaving
                      ? null
                      : (_) => _changeLanguage(context, ref, 'bn'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              bn ? 'মুদ্রা (প্রদর্শন)' : 'Currency display',
              style: const TextStyle(color: AppTheme.gold, fontSize: 15),
            ),
            const SizedBox(height: 9),
            AnimatedBuilder(
              animation: CurrencyPreferences.instance,
              builder: (context, _) => Wrap(
                spacing: 9,
                children: [
                  ChoiceChip(
                    key: const ValueKey<String>('home-currency-usd'),
                    label: const Text(r'$  Dollar'),
                    selected:
                        CurrencyPreferences.instance.codeFor(languageCode) ==
                        'USD',
                    onSelected: (_) =>
                        CurrencyPreferences.instance.setCurrency('USD'),
                  ),
                  ChoiceChip(
                    key: const ValueKey<String>('home-currency-bdt'),
                    label: const Text('৳  Taka'),
                    selected:
                        CurrencyPreferences.instance.codeFor(languageCode) ==
                        'BDT',
                    onSelected: (_) =>
                        CurrencyPreferences.instance.setCurrency('BDT'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 17),
            action(
              Icons.font_download_outlined,
              'Font Settings',
              'ফন্ট সেটিংস',
              () => FontSettingsScreen(languageCode: languageCode),
            ),
            action(
              Icons.view_in_ar_rounded,
              '3D Showroom',
              '৩ডি মডেল',
              () => ThreeDShowroomScreen(languageCode: languageCode),
            ),
            action(
              Icons.directions_car_rounded,
              'Player Tokens',
              'টোকেন নির্বাচন',
              () => TokenSettingsScreen(languageCode: languageCode),
            ),
            action(
              Icons.leaderboard_rounded,
              'Match History',
              'খেলার ইতিহাস',
              () => MatchHistoryScreen(languageCode: languageCode),
            ),
            action(
              Icons.graphic_eq_rounded,
              'Game Experience',
              'গেম অভিজ্ঞতা',
              () => ExperienceSettingsScreen(languageCode: languageCode),
            ),
          ],
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

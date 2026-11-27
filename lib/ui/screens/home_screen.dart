import 'package:flutter/material.dart';

import '../../core/ui/app_notices.dart';
import '../../core/ui/game_diagnostics.dart';
import '../../core/config/game_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/utils/currency_preferences.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers/app_controller.dart';
import '../widgets/player_avatar.dart';
import '../../core/utils/avatar_preview_bytes.dart';
import 'profile_screen.dart';
import 'font_settings_screen.dart';
import 'rules_screen.dart';
import 'credits_screen.dart';
import 'play_guide_screen.dart';
import '../../game/engine/game_engine.dart';
import '../../game/ui/game_setup_screen.dart';
import '../../game/ui/game_typography.dart';
import '../../game/ui/experience_settings_screen.dart';
import '../../game/ui/match_history_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _openingGameSetup = false;
  final _avatarPreview = AvatarPreviewBytes();

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
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider).requireValue;
    final l10n = AppLocalizations.of(context);
    final name = state.displayName.isEmpty ? l10n.player : state.displayName;

    Future<void> openGameSetup() async {
      if (!mounted || _openingGameSetup) return;
      setState(() => _openingGameSetup = true);
      try {
        await Navigator.of(context).push(
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
        );
      } catch (error, stack) {
        GameDiagnostics.record('open game setup', error, stack);
        if (mounted) {
          AppNotices.of(this.context).showSnackBar(
            SnackBar(
              content: Text(
                state.languageCode == 'bn'
                    ? 'খেলা শুরু করা যায়নি। আবার চেষ্টা করুন।'
                    : 'Unable to open game setup. Please try again.',
              ),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _openingGameSetup = false);
      }
    }

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
                        SizedBox(
                          height: 100,
                          child: LayoutBuilder(
                            builder: (context, constraints) => Center(
                              child: Icon(
                                Icons.domain_rounded,
                                size: constraints.maxWidth < 305 ? 72 : 96,
                                color: AppTheme.gold,
                              ),
                            ),
                          ),
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
                        const SizedBox(
                          height: GameConfig.homeStartButtonTopSpacing,
                        ),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: GameConfig.homeStartButtonMaximumWidth,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                key: const ValueKey<String>(
                                  'home-primary-start-game',
                                ),
                                onPressed: _openingGameSetup
                                    ? null
                                    : openGameSetup,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.gold,
                                  foregroundColor: AppTheme.obsidian,
                                  minimumSize: const Size(
                                    0,
                                    GameConfig.homeStartButtonHeight,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      GameConfig.homeStartButtonBorderRadius,
                                    ),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: GameConfig.homeStartButtonIconSize,
                                ),
                                label: Text(
                                  state.languageCode == 'bn'
                                      ? 'খেলা শুরু করুন'
                                      : 'START GAME',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: GameTypography.family(
                                      state.languageCode,
                                    ),
                                    fontFamilyFallback:
                                        GameTypography.fallbacks(
                                          state.languageCode,
                                        ),
                                    fontWeight: FontWeight.w800,
                                    fontSize:
                                        GameConfig.homeStartButtonFontSize,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: GameConfig.homeStartButtonBottomSpacing,
                        ),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            // LayoutBuilder reports the *content* width,
                            // after the page's 24dp padding on each side.
                            // At an 800dp browser viewport this is 752dp;
                            // the previous 760dp breakpoint stacked the two
                            // cards, so the equal-height TableRow was skipped.
                            // Two 350dp cards plus the 20dp gutter fit at 720dp.
                            final sideBySide = constraints.maxWidth >= 720;
                            // Let buttons grow with their text. Chrome font
                            // metrics and browser zoom vary from Android.
                            final actionStyle = ButtonStyle(
                              minimumSize: const WidgetStatePropertyAll(
                                Size(0, 52),
                              ),
                              padding: const WidgetStatePropertyAll(
                                EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                              ),
                              shape: WidgetStatePropertyAll(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            );
                            final profile = _Panel(
                              key: const ValueKey<String>('home-profile-panel'),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  PlayerAvatar(
                                    preset: state.avatarIndex,
                                    bytes: _avatarPreview.resolve(
                                      state.avatarBase64,
                                    ),
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
                                  Text(
                                    l10n.profileIntro,
                                    style: TextStyle(
                                      fontSize: state.languageCode == 'bn'
                                          ? 17
                                          : 14,
                                      height: state.languageCode == 'bn'
                                          ? 1.5
                                          : 1.35,
                                    ),
                                  ),
                                  // Spacing is natural: no Spacer or tight height.
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
                              key: const ValueKey<String>('home-balance-panel'),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
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
                                      GameEngine.startingCash,
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
                                    style: TextStyle(
                                      fontSize: state.languageCode == 'bn'
                                          ? 17
                                          : 14,
                                      height: state.languageCode == 'bn'
                                          ? 1.5
                                          : 1.35,
                                    ),
                                  ),
                                  // Spacing is natural: no Spacer or tight height.
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
                              // One TableRow determines the taller card's
                              // natural height and fills BOTH cells equally.
                              // Unlike a fixed height or a Row with Spacer,
                              // this tolerates Chrome text metrics, web zoom,
                              // localization, and accessibility text scaling.
                              return Table(
                                columnWidths: const <int, TableColumnWidth>{
                                  0: FlexColumnWidth(),
                                  1: FixedColumnWidth(20),
                                  2: FlexColumnWidth(),
                                },
                                defaultVerticalAlignment:
                                    TableCellVerticalAlignment.fill,
                                children: <TableRow>[
                                  TableRow(
                                    children: <Widget>[
                                      TableCell(
                                        verticalAlignment:
                                            TableCellVerticalAlignment.fill,
                                        child: profile,
                                      ),
                                      const SizedBox(width: 20),
                                      TableCell(
                                        verticalAlignment:
                                            TableCellVerticalAlignment.fill,
                                        child: balance,
                                      ),
                                    ],
                                  ),
                                ],
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
      title: Text(
        bn ? bangla : english,
        style: TextStyle(
          fontFamily: GameTypography.family(languageCode),
          fontFamilyFallback: GameTypography.fallbacks(languageCode),
          fontSize: bn ? 17 : 16,
          fontWeight: FontWeight.w500,
          height: bn ? 1.38 : 1.2,
        ),
      ),
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
              style: TextStyle(
                fontFamily: bn ? GameTypography.family('bn') : 'Exo2',
                fontFamilyFallback: bn
                    ? GameTypography.fallbacks('bn')
                    : const <String>[],
                fontSize: bn ? 21 : 21,
                height: bn ? 1.38 : 1.2,
                color: AppTheme.gold,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 32),
            Text(
              bn ? 'ভাষা' : 'Language',
              style: TextStyle(color: AppTheme.gold, fontSize: bn ? 17 : 15),
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
                  label: Text(
                    'বাংলা',
                    style: TextStyle(
                      fontFamily: GameTypography.family('bn'),
                      fontFamilyFallback: GameTypography.fallbacks('bn'),
                      fontSize: 16,
                      height: 1.38,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
              style: TextStyle(color: AppTheme.gold, fontSize: bn ? 17 : 15),
            ),
            const SizedBox(height: 9),
            AnimatedBuilder(
              animation: CurrencyPreferences.instance,
              builder: (context, _) => Wrap(
                spacing: 9,
                children: [
                  ChoiceChip(
                    key: const ValueKey<String>('home-currency-usd'),
                    label: Text(
                      bn ? r'$ ডলার' : r'$ Dollar',
                      style: TextStyle(
                        fontFamily: GameTypography.family(languageCode),
                        fontFamilyFallback: GameTypography.fallbacks(
                          languageCode,
                        ),
                        fontSize: bn ? 16 : 14,
                      ),
                    ),
                    selected:
                        CurrencyPreferences.instance.codeFor(languageCode) ==
                        'USD',
                    onSelected: (_) =>
                        CurrencyPreferences.instance.setCurrency('USD'),
                  ),
                  ChoiceChip(
                    key: const ValueKey<String>('home-currency-bdt'),
                    label: Text(
                      bn ? '৳ টাকা' : '৳ Taka',
                      style: TextStyle(
                        fontFamily: GameTypography.family(languageCode),
                        fontFamilyFallback: GameTypography.fallbacks(
                          languageCode,
                        ),
                        fontSize: bn ? 16 : 14,
                      ),
                    ),
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
            // The showroom was only an optional asset preview, not part of
            // gameplay. Token choice remains in the active game's menu.
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
            action(
              Icons.menu_book_rounded,
              'How to Play',
              'খেলার নির্দেশিকা',
              () => PlayGuideScreen(languageCode: languageCode),
            ),
            action(
              Icons.info_outline_rounded,
              'Credits',
              'কৃতজ্ঞতা ও পরিচিতি',
              () => CreditsScreen(languageCode: languageCode),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({super.key, required this.child});
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

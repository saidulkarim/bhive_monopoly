// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/ui/app_notices.dart';
import '../../core/config/game_config.dart';
import '../../core/ui/visual_activity_scope.dart';
import '../experience/game_experience_settings.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../experience/token_preferences.dart';
import '../experience/player_palette.dart';
import 'game_text.dart';
import 'widgets/game_board_view.dart';

/// Assign a preferred board token to each of the six player seats.
/// The 3D preview renders one model at a time; board pieces remain efficient
/// Flutter widgets and can be updated without changing a live game state.
class TokenSettingsScreen extends StatefulWidget {
  const TokenSettingsScreen({super.key, required this.languageCode});
  final String languageCode;

  @override
  State<TokenSettingsScreen> createState() => _TokenSettingsScreenState();
}

class _TokenSettingsScreenState extends State<TokenSettingsScreen> {
  late final GameText t = GameText(widget.languageCode);
  final TokenPreferences prefs = TokenPreferences.instance;
  int seat = 0;
  bool showModel = true;
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    await prefs.ensureLoaded();
    if (mounted) setState(() => loaded = true);
  }

  Future<void> _select(int index) async {
    try {
      await prefs.select(seat, index);
      if (mounted) setState(() {});
    } catch (_) {
      if (!mounted) return;
      AppNotices.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t.choose(
              'Could not save token selection.',
              'টোকেন নির্বাচন সংরক্ষণ করা যায়নি।',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _reset() async {
    await prefs.restoreDefaults();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBoardDark,
    appBar: AppBar(
      backgroundColor: const Color(0xFF122729),
      foregroundColor: kBoardGold,
      title: Text(
        t.choose('Player Token Settings', 'খেলোয়াড়ের টোকেন সেটিংস'),
        style: TextStyle(
          fontFamily: t.font,
          fontFamilyFallback: t.fallbackFonts,
        ),
      ),
      actions: [
        IconButton(
          tooltip: t.choose('Restore defaults', 'ডিফল্ট ফিরিয়ে আনুন'),
          onPressed: loaded ? _reset : null,
          icon: const Icon(Icons.restart_alt_rounded),
        ),
      ],
    ),
    body: !loaded
        ? const Center(child: CircularProgressIndicator(color: kBoardGold))
        : AnimatedBuilder(
            animation: Listenable.merge([
              prefs,
              GameExperienceSettings.instance,
            ]),
            builder: (context, _) {
              final visible =
                  VisualActivityScope.isForegroundOf(context) &&
                  ModalRoute.isCurrentOf(context) != false &&
                  TickerMode.of(context);
              final experience = GameExperienceSettings.instance;
              final autoRotate =
                  !experience.effectiveReducedMotion &&
                  !(MediaQuery.maybeOf(context)?.disableAnimations ?? false) &&
                  (!GameConfig.advancedBatteryOptimizationEnabled ||
                      !GameConfig.tokenAutoRotationPerformanceOnly ||
                      experience.powerProfile == GamePowerProfile.performance);
              final selectedIndex = prefs.selectionFor(seat);
              final selected = prefs.styleFor(seat);
              return SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          t.choose(
                            'Choose the token for each player seat.',
                            'প্রতিটি খেলোয়াড়ের জন্য টোকেন নির্বাচন করুন।',
                          ),
                          style: TextStyle(
                            fontFamily: t.font,
                            fontFamilyFallback: t.fallbackFonts,
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 9,
                          runSpacing: 9,
                          children: [
                            for (var index = 0; index < 6; index++)
                              ChoiceChip(
                                selected: seat == index,
                                label: Text(
                                  '${t.choose('Player', 'খেলোয়াড়')} '
                                  '${t.integer(index + 1)}',
                                  style: TextStyle(
                                    fontFamily: t.font,
                                    fontFamilyFallback: t.fallbackFonts,
                                  ),
                                ),
                                avatar: Icon(
                                  prefs.styleFor(index).icon,
                                  size: 18,
                                ),
                                onSelected: (_) => setState(() => seat = index),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF173434),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: kBoardGold),
                          ),
                          child: Column(
                            children: [
                              SizedBox(
                                height: 235,
                                child:
                                    selected.modelAsset != null &&
                                        showModel &&
                                        visible
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: ModelViewer(
                                          key: ValueKey(
                                            '${selected.key}-$seat',
                                          ),
                                          src: selected.modelAsset!,
                                          alt: selected.english,
                                          cameraControls: true,
                                          autoRotate: autoRotate,
                                          rotationPerSecond: '14deg',
                                          ar: false,
                                          backgroundColor: const Color(
                                            0xFF173434,
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Icon(
                                          selected.icon,
                                          color: PlayerColorPreferences.instance
                                              .colorFor(seat),
                                          size: 104,
                                        ),
                                      ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  12,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        t.choose(
                                          selected.english,
                                          selected.bangla,
                                        ),
                                        style: TextStyle(
                                          fontFamily: t.font,
                                          fontFamilyFallback: t.fallbackFonts,
                                          color: kBoardGold,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (selected.modelAsset != null)
                                      IconButton(
                                        tooltip: t.choose(
                                          'Toggle 3D preview',
                                          '৩ডি প্রিভিউ চালু বা বন্ধ করুন',
                                        ),
                                        onPressed: () => setState(
                                          () => showModel = !showModel,
                                        ),
                                        icon: Icon(
                                          showModel
                                              ? Icons.view_in_ar_rounded
                                              : Icons.visibility_outlined,
                                          color: kBoardGold,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          t.choose('Available tokens', 'উপলব্ধ টোকেন'),
                          style: TextStyle(
                            fontFamily: t.font,
                            fontFamilyFallback: t.fallbackFonts,
                            color: kBoardGold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (var i = 0; i < TokenCatalog.styles.length; i++)
                              ChoiceChip(
                                selected: selectedIndex == i,
                                avatar: Icon(
                                  TokenCatalog.styles[i].icon,
                                  size: 20,
                                ),
                                label: Text(
                                  t.choose(
                                    TokenCatalog.styles[i].english,
                                    TokenCatalog.styles[i].bangla,
                                  ),
                                  style: TextStyle(
                                    fontFamily: t.font,
                                    fontFamilyFallback: t.fallbackFonts,
                                  ),
                                ),
                                onSelected: (_) => unawaited(_select(i)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          t.choose(
                            'Selections are saved automatically. In LAN games each device uses its own visual preferences; token choices do not change game rules.',
                            'নির্বাচিত টোকেন নিজে থেকেই সংরক্ষিত হয়। LAN খেলায় প্রতিটি ডিভাইসের নিজস্ব নির্বাচন প্রদর্শিত হয়; খেলার নিয়ম অপরিবর্তিত থাকে।',
                          ),
                          style: TextStyle(
                            fontFamily: t.font,
                            fontFamilyFallback: t.fallbackFonts,
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
  );
}

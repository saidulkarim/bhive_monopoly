import 'dart:async';

import 'package:flutter/material.dart';

import '../experience/game_audio.dart';
import '../experience/game_experience_settings.dart';
import '../experience/performance_diagnostics.dart';
import '../../core/config/game_config.dart';
import '../experience/board_camera_preset.dart';
import 'game_text.dart';
import 'widgets/game_board_view.dart';

/// On-device audio and animation preferences. Both Android and Flutter Web
/// use the same preferences; they do not change other LAN participants.
class ExperienceSettingsScreen extends StatefulWidget {
  const ExperienceSettingsScreen({super.key, required this.languageCode});
  final String languageCode;

  @override
  State<ExperienceSettingsScreen> createState() =>
      _ExperienceSettingsScreenState();
}

class _ExperienceSettingsScreenState extends State<ExperienceSettingsScreen> {
  final GameExperienceSettings settings = GameExperienceSettings.instance;
  late final GameText t = GameText(widget.languageCode);
  bool loading = true;
  double? _dragVolume;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await settings.ensureLoaded();
    if (mounted) setState(() => loading = false);
  }

  Future<void> _apply(Future<void> Function() save) async {
    try {
      await save();
    } catch (_) {
      if (mounted) {
        setState(
          () => error = t.choose(
            'Could not save settings on this device.',
            'এই ডিভাইসে সেটিংস সংরক্ষণ করা যায়নি।',
          ),
        );
      }
    }
  }

  Widget _diagnosticsCard() {
    final diagnostics = PerformanceDiagnostics.instance;
    return AnimatedBuilder(
      animation: diagnostics,
      builder: (context, _) => Card(
        color: const Color(0xFF1D3436),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.choose('Performance Diagnostics', 'পারফরম্যান্স নির্ণয়'),
                style: const TextStyle(
                  color: kBoardGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t.choose(
                  'Optional ${GameConfig.performanceDiagnosticsSessionSeconds}s frame sample. Start, return to gameplay, then reopen this screen to view results. Not a battery meter.',
                  'ঐচ্ছিক ${GameConfig.performanceDiagnosticsSessionSeconds} সেকেন্ডের ফ্রেম নমুনা। শুরু করে খেলায় ফিরুন, পরে ফলাফল দেখতে এখানে আসুন। এটি ব্যাটারি মিটার নয়।',
                ),
              ),
              const SizedBox(height: 8),
              Text('${t.choose('Frames', 'ফ্রেম')}: ${diagnostics.frames}'),
              Text(
                '${t.choose('Average total span (ms)', 'গড় মোট সময় (মি.সে.)')}: ${diagnostics.averageMilliseconds.toStringAsFixed(2)}',
              ),
              Text(
                '${t.choose('Over budget', 'সময়সীমা অতিক্রম')}: ${diagnostics.overBudget}',
              ),
              Text(
                '${t.choose('Worst span (ms)', 'সর্বোচ্চ সময় (মি.সে.)')}: ${(diagnostics.worstMicros / 1000).toStringAsFixed(2)}',
              ),
              const SizedBox(height: 8),
              Text(
                t.choose(
                  'Flutter image cache (snapshot, not GPU memory)',
                  'ফ্লাটার ছবির ক্যাশ (বর্তমান তথ্য, জিপিইউ মেমরি নয়)',
                ),
              ),
              Text(
                '${t.choose('Cached images', 'ক্যাশে থাকা ছবি')}: '
                '${PaintingBinding.instance.imageCache.currentSize}',
              ),
              Text(
                '${t.choose('Cached MiB', 'ক্যাশ মি.বি.')}: '
                '${(PaintingBinding.instance.imageCache.currentSizeBytes / 1048576).toStringAsFixed(2)}',
              ),
              Text(
                '${t.choose('Live images', 'সক্রিয় ছবি')}: '
                '${PaintingBinding.instance.imageCache.liveImageCount}',
              ),
              Text(
                '${t.choose('Pending images', 'অপেক্ষমাণ ছবি')}: '
                '${PaintingBinding.instance.imageCache.pendingImageCount}',
              ),
              OutlinedButton(
                onPressed: () => setState(() {}),
                child: Text(
                  t.choose(
                    'Refresh cache snapshot',
                    'ক্যাশের তথ্য হালনাগাদ করুন',
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: diagnostics.active ? null : diagnostics.start,
                    child: Text(t.choose('Start sample', 'নমুনা শুরু')),
                  ),
                  OutlinedButton(
                    onPressed: diagnostics.active ? diagnostics.stop : null,
                    child: Text(t.choose('Stop & view', 'বন্ধ করে দেখুন')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBoardDark,
    appBar: AppBar(
      backgroundColor: const Color(0xFF122729),
      foregroundColor: kBoardGold,
      title: Text(
        t.choose('Game Experience', 'গেম অভিজ্ঞতা'),
        style: TextStyle(
          fontFamily: t.font,
          fontFamilyFallback: t.fallbackFonts,
        ),
      ),
    ),
    body: SafeArea(
      child: loading
          ? const Center(child: CircularProgressIndicator(color: kBoardGold))
          : AnimatedBuilder(
              animation: settings,
              builder: (context, _) => Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Icon(
                        Icons.graphic_eq_rounded,
                        size: 60,
                        color: kBoardGold,
                      ),
                      const SizedBox(height: 15),
                      Text(
                        t.choose('Sound & animation', 'শব্দ ও অ্যানিমেশন'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: kBoardGold,
                          fontFamily: t.font,
                          fontFamilyFallback: t.fallbackFonts,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t.choose(
                          'Applies to this device only. Your match, saved games and fonts are unchanged.',
                          'শুধু এই ডিভাইসে প্রযোজ্য। খেলা, সংরক্ষিত গেম ও ফন্ট অপরিবর্তিত থাকবে।',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontFamily: t.font,
                          fontFamilyFallback: t.fallbackFonts,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Card(
                        color: const Color(0xFF1D3436),
                        child: Column(
                          children: [
                            SwitchListTile.adaptive(
                              title: Text(
                                t.choose('Sound effects', 'গেমের শব্দ'),
                                style: TextStyle(
                                  fontFamily: t.font,
                                  fontFamilyFallback: t.fallbackFonts,
                                  color: Colors.white,
                                ),
                              ),
                              subtitle: Text(
                                t.choose(
                                  'Dice, coins, purchase, build and win',
                                  'পাশা, কয়েন, কেনা, বাড়ি নির্মাণ ও জয়',
                                ),
                                style: TextStyle(
                                  fontFamily: t.font,
                                  fontFamilyFallback: t.fallbackFonts,
                                  color: Colors.white70,
                                ),
                              ),
                              secondary: const Icon(
                                Icons.volume_up_rounded,
                                color: kBoardGold,
                              ),
                              value: settings.effectsEnabled,
                              onChanged: (v) => unawaited(
                                _apply(() => settings.setEffectsEnabled(v)),
                              ),
                            ),
                            ListTile(
                              title: Text(
                                '${t.choose('Volume', 'শব্দের মাত্রা')} · ${((_dragVolume ?? settings.volume) * 100).round()}%',
                                style: TextStyle(
                                  fontFamily: t.font,
                                  fontFamilyFallback: t.fallbackFonts,
                                  color: Colors.white,
                                ),
                              ),
                              subtitle: Slider(
                                min: 0,
                                max: 1,
                                divisions: 20,
                                value: _dragVolume ?? settings.volume,
                                activeColor: kBoardGold,
                                onChanged: settings.effectsEnabled
                                    ? (v) => setState(() => _dragVolume = v)
                                    : null,
                                onChangeEnd: settings.effectsEnabled
                                    ? (v) {
                                        setState(() => _dragVolume = null);
                                        unawaited(
                                          _apply(() => settings.setVolume(v)),
                                        );
                                      }
                                    : null,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: settings.effectsEnabled
                                        ? () => GameAudio.instance.fire(
                                            GameSfx.dice,
                                          )
                                        : null,
                                    icon: const Icon(Icons.casino_outlined),
                                    label: Text(
                                      t.choose('Test dice', 'পাশা শুনুন'),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: settings.effectsEnabled
                                        ? () => GameAudio.instance.fire(
                                            GameSfx.purchase,
                                          )
                                        : null,
                                    icon: const Icon(Icons.paid_outlined),
                                    label: Text(
                                      t.choose('Test purchase', 'কেনার শব্দ'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        color: const Color(0xFF1D3436),
                        child: SwitchListTile.adaptive(
                          secondary: const Icon(
                            Icons.accessibility_new_rounded,
                            color: kBoardGold,
                          ),
                          title: Text(
                            t.choose('Reduce motion', 'অ্যানিমেশন কমান'),
                            style: TextStyle(
                              fontFamily: t.font,
                              fontFamilyFallback: t.fallbackFonts,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            t.choose(
                              'Skip the dice spin and long movement sequences.',
                              'পাশার ঘূর্ণন ও দীর্ঘ চলার অ্যানিমেশন বন্ধ করুন।',
                            ),
                            style: TextStyle(
                              fontFamily: t.font,
                              fontFamilyFallback: t.fallbackFonts,
                              color: Colors.white70,
                            ),
                          ),
                          value: settings.reducedMotion,
                          onChanged: (v) => unawaited(
                            _apply(() => settings.setReducedMotion(v)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        color: const Color(0xFF1D3436),
                        child: SwitchListTile.adaptive(
                          secondary: const Icon(
                            Icons.vibration_rounded,
                            color: kBoardGold,
                          ),
                          title: Text(
                            t.choose('Vibration feedback', 'কম্পন সংকেত'),
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: t.font,
                              fontFamilyFallback: t.fallbackFonts,
                            ),
                          ),
                          subtitle: Text(
                            t.choose(
                              'Device vibration for dice, purchases and victory (Android).',
                              'পাশা, কেনাকাটা ও জয়ের সময় ফোনে কম্পন (অ্যান্ড্রয়েড)।',
                            ),
                            style: TextStyle(
                              color: Colors.white70,
                              fontFamily: t.font,
                              fontFamilyFallback: t.fallbackFonts,
                            ),
                          ),
                          value: settings.vibrationEnabled,
                          onChanged: (value) => unawaited(
                            _apply(() => settings.setVibrationEnabled(value)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        color: const Color(0xFF1D3436),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.choose(
                                  'Default board camera',
                                  'বোর্ড ক্যামেরা',
                                ),
                                style: TextStyle(
                                  color: kBoardGold,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: t.font,
                                  fontFamilyFallback: t.fallbackFonts,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                t.choose(
                                  'Works in offline and Wi-Fi games. Pinch the board to zoom.',
                                  'অফলাইন ও ওয়াই-ফাই গেমে প্রযোজ্য। জুম করতে বোর্ডে দুই আঙুল ব্যবহার করুন।',
                                ),
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontFamily: t.font,
                                  fontFamilyFallback: t.fallbackFonts,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final camera in BoardCameraPreset.values)
                                    ChoiceChip(
                                      selected: settings.cameraPreset == camera,
                                      label: Text(
                                        camera.label(t.bn),
                                        style: TextStyle(
                                          fontFamily: t.font,
                                          fontFamilyFallback: t.fallbackFonts,
                                        ),
                                      ),
                                      onSelected: (selected) {
                                        if (selected) {
                                          unawaited(
                                            _apply(
                                              () => settings.setCameraPreset(
                                                camera,
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        color: const Color(0xFF1D3436),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.choose(
                                  'Power Management',
                                  'ব্যাটারি সাশ্রয়',
                                ),
                                style: TextStyle(
                                  color: kBoardGold,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: t.font,
                                  fontFamilyFallback: t.fallbackFonts,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                t.choose(
                                  'Applies to this device only. Game rules and AI are unchanged.',
                                  'শুধু এই ডিভাইসে প্রযোজ্য। খেলার নিয়ম ও কম্পিউটার খেলোয়াড় অপরিবর্তিত থাকবে।',
                                ),
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontFamily: t.font,
                                  fontFamilyFallback: t.fallbackFonts,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final profile in GamePowerProfile.values)
                                    ChoiceChip(
                                      selected:
                                          settings.selectedPowerProfile ==
                                          profile,
                                      label: Text(
                                        switch (profile) {
                                          GamePowerProfile.performance =>
                                            t.choose(
                                              'Performance',
                                              'উচ্চ পারফরম্যান্স',
                                            ),
                                          GamePowerProfile.balanced => t.choose(
                                            'Balanced',
                                            'ভারসাম্যপূর্ণ',
                                          ),
                                          GamePowerProfile.batterySaver =>
                                            t.choose(
                                              'Battery Saver',
                                              'ব্যাটারি সাশ্রয়',
                                            ),
                                          GamePowerProfile.ultraSaver =>
                                            t.choose(
                                              'Ultra Saver',
                                              'সর্বোচ্চ সাশ্রয়',
                                            ),
                                        },
                                        style: TextStyle(
                                          fontFamily: t.font,
                                          fontFamilyFallback: t.fallbackFonts,
                                        ),
                                      ),
                                      onSelected: (selected) {
                                        if (selected) {
                                          unawaited(
                                            _apply(
                                              () => settings.setPowerProfile(
                                                profile,
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${t.choose('Effective profile', 'কার্যকর মোড')}: ${switch (settings.powerProfile) {
                                  GamePowerProfile.performance => t.choose('Performance', 'উচ্চ পারফরম্যান্স'),
                                  GamePowerProfile.balanced => t.choose('Balanced', 'ভারসাম্যপূর্ণ'),
                                  GamePowerProfile.batterySaver => t.choose('Battery Saver', 'ব্যাটারি সাশ্রয়'),
                                  GamePowerProfile.ultraSaver => t.choose('Ultra Saver', 'সর্বোচ্চ সাশ্রয়'),
                                }}',
                              ),
                              Text(
                                switch (settings.powerProfile) {
                                  GamePowerProfile.performance => t.choose(
                                    'Full gameplay motion with longer location highlights.',
                                    'পূর্ণ অ্যানিমেশন ও দীর্ঘ সময়ের অবস্থান হাইলাইট।',
                                  ),
                                  GamePowerProfile.balanced => t.choose(
                                    'Full gameplay motion; location highlights settle when idle.',
                                    'পূর্ণ অ্যানিমেশন; নিষ্ক্রিয় অবস্থায় হাইলাইট স্থির থাকে।',
                                  ),
                                  GamePowerProfile.batterySaver => t.choose(
                                    'Static location highlights; gameplay motion is preserved.',
                                    'স্থির অবস্থান হাইলাইট; খেলার অ্যানিমেশন বজায় থাকে।',
                                  ),
                                  GamePowerProfile.ultraSaver => t.choose(
                                    'Static highlights and reduced gameplay motion.',
                                    'স্থির হাইলাইট ও কম অ্যানিমেশন।',
                                  ),
                                },
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontFamily: t.font,
                                  fontFamilyFallback: t.fallbackFonts,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        color: const Color(0xFF1D3436),
                        child: Column(
                          children: [
                            SwitchListTile.adaptive(
                              title: Text(
                                t.choose(
                                  'Automatic Battery Saver',
                                  'স্বয়ংক্রিয় ব্যাটারি সাশ্রয়',
                                ),
                              ),
                              subtitle: Text(
                                t.choose(
                                  'Uses a lower power profile at low battery on Android. Web keeps your selected profile.',
                                  'অ্যান্ড্রয়েডে ব্যাটারি কম হলে সাশ্রয়ী মোড চালু হয়। ওয়েবে নির্বাচিত মোড বজায় থাকে।',
                                ),
                              ),
                              value: settings.automaticPowerEnabled,
                              onChanged: (value) => unawaited(
                                _apply(
                                  () =>
                                      settings.setAutomaticPowerEnabled(value),
                                ),
                              ),
                            ),
                            if (settings.automaticPowerEnabled)
                              ListTile(
                                title: Text(
                                  settings.batteryReading == null
                                      ? t.choose(
                                          'Battery reading unavailable or pending',
                                          'ব্যাটারির তথ্য অনুপলব্ধ অথবা অপেক্ষমাণ',
                                        )
                                      : '${t.choose('Battery', 'ব্যাটারি')}: ${settings.batteryReading!.level}%',
                                ),
                                subtitle: Text(
                                  settings.batteryReading?.charging == true
                                      ? t.choose(
                                          'Charging — selected profile',
                                          'চার্জ হচ্ছে — নির্বাচিত মোড',
                                        )
                                      : t.choose(
                                          'Effective profile shown above',
                                          'উপরে কার্যকর মোড দেখানো হয়েছে',
                                        ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _diagnosticsCard(),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kBoardGold,
                        ),
                        onPressed: () =>
                            unawaited(_apply(settings.restoreDefaults)),
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: Text(
                          t.choose(
                            'Restore default settings',
                            'ডিফল্ট সেটিংস ফিরিয়ে আনুন',
                          ),
                        ),
                      ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text(
                            error!,
                            style: const TextStyle(color: Colors.orangeAccent),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    ),
  );
}

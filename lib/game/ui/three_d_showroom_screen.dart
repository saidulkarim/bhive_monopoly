// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import 'game_text.dart';
import 'widgets/game_board_view.dart';

/// Interactive showcase for original bundled glTF/GLB game pieces.
/// This is intentionally separate from the 40-space board renderer:
/// spinning up a WebView/WebGL instance for every tiny board tile would be
/// slow and would interfere with Flutter tile tap/zoom gestures.
class ThreeDShowroomScreen extends StatefulWidget {
  const ThreeDShowroomScreen({super.key, required this.languageCode});
  final String languageCode;

  @override
  State<ThreeDShowroomScreen> createState() => _ThreeDShowroomScreenState();
}

class _ModelDescription {
  const _ModelDescription(this.asset, this.english, this.bangla, this.icon);
  final String asset;
  final String english;
  final String bangla;
  final IconData icon;
}

class _ThreeDShowroomScreenState extends State<ThreeDShowroomScreen> {
  static const models = <_ModelDescription>[
    _ModelDescription(
      'assets/models/gold_car.glb',
      'Gold car',
      'সোনালি গাড়ি',
      Icons.directions_car_filled_rounded,
    ),
    _ModelDescription(
      'assets/models/pearl_yacht.glb',
      'Pearl yacht',
      'মুক্তা ইয়ট',
      Icons.sailing_rounded,
    ),
    _ModelDescription(
      'assets/models/royal_crown.glb',
      'Royal crown',
      'রাজমুকুট',
      Icons.workspace_premium_rounded,
    ),
    _ModelDescription(
      'assets/models/sky_rocket.glb',
      'Sky rocket',
      'রকেট',
      Icons.rocket_launch_rounded,
    ),
    _ModelDescription(
      'assets/models/pearl_dice.glb',
      'Pearl dice',
      'পাশা',
      Icons.casino_rounded,
    ),
  ];

  late final GameText t = GameText(widget.languageCode);
  int selected = 0;
  bool autoRotate = true;

  @override
  Widget build(BuildContext context) {
    final current = models[selected];
    return Scaffold(
      backgroundColor: kBoardDark,
      appBar: AppBar(
        backgroundColor: const Color(0xFF122729),
        foregroundColor: kBoardGold,
        title: Text(
          t.choose('3D Model Showroom', '৩ডি মডেল প্রদর্শনী'),
          style: TextStyle(
            fontFamily: t.font,
            fontFamilyFallback: t.fallbackFonts,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final previewHeight = (constraints.maxHeight * .54).clamp(
                  220.0,
                  475.0,
                );
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      t.choose(
                        'Explore the game pieces in real 3D',
                        'গেমের মডেলগুলো আসল ৩ডি-তে দেখুন',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: t.font,
                        fontFamilyFallback: t.fallbackFonts,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: kBoardGold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      t.choose(
                        'Drag to rotate • Pinch or scroll to zoom',
                        'ঘোরাতে টানুন • জুম করতে দুই আঙুল বা মাউস ব্যবহার করুন',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: t.font,
                        fontFamilyFallback: t.fallbackFonts,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: const Color(0xFF122729),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kBoardGold.withOpacity(.55)),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: previewHeight,
                            child: ModelViewer(
                              key: ValueKey(current.asset),
                              src: current.asset,
                              alt: current.english,
                              backgroundColor: const Color(0xFF122729),
                              cameraControls: true,
                              autoRotate: autoRotate,
                              rotationPerSecond: '15deg',
                              shadowIntensity: .8,
                              ar: false,
                              debugLogging: false,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                            child: Row(
                              children: [
                                Icon(current.icon, color: kBoardGold),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    t.choose(current.english, current.bangla),
                                    style: TextStyle(
                                      color: kBoardGold,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: t.font,
                                      fontFamilyFallback: t.fallbackFonts,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: t.choose(
                                    'Toggle rotation',
                                    'ঘূর্ণন চালু বা বন্ধ',
                                  ),
                                  onPressed: () =>
                                      setState(() => autoRotate = !autoRotate),
                                  icon: Icon(
                                    autoRotate
                                        ? Icons.pause_circle_outline
                                        : Icons.play_circle_outline,
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
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < models.length; i++)
                          ChoiceChip(
                            selected: selected == i,
                            avatar: Icon(models[i].icon, size: 18),
                            label: Text(
                              t.choose(models[i].english, models[i].bangla),
                              style: TextStyle(
                                fontFamily: t.font,
                                fontFamilyFallback: t.fallbackFonts,
                              ),
                            ),
                            onSelected: (_) => setState(() => selected = i),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      t.choose(
                        '3D model preview only. Game-board tokens remain lightweight Flutter pieces for smooth multiplayer performance.',
                        'এটি ৩ডি মডেলের প্রদর্শনী। দ্রুত মাল্টিপ্লেয়ার খেলার জন্য বোর্ডে হালকা Flutter টোকেন ব্যবহার করা হয়।',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: t.font,
                        fontFamilyFallback: t.fallbackFonts,
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

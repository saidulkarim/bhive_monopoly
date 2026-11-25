import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../core/theme/app_theme.dart';
import '../../game/ui/game_typography.dart';

/// Language-specific, bundled PDF guide for Android and Web.
/// No network request is needed to load the guide asset itself.
class PlayGuideScreen extends StatefulWidget {
  const PlayGuideScreen({super.key, required this.languageCode});

  final String languageCode;

  static String assetForLanguage(String languageCode) =>
      languageCode.toLowerCase().startsWith('bn')
      ? 'assets/guides/bhive_monopoly_play_guide_bn.pdf'
      : 'assets/guides/bhive_monopoly_play_guide_en.pdf';

  @override
  State<PlayGuideScreen> createState() => _PlayGuideScreenState();
}

class _PlayGuideScreenState extends State<PlayGuideScreen> {
  late PdfControllerPinch _pdfController;
  bool get _bn => widget.languageCode.toLowerCase().startsWith('bn');

  @override
  void initState() {
    super.initState();
    _pdfController = PdfControllerPinch(
      document: PdfDocument.openAsset(
        PlayGuideScreen.assetForLanguage(widget.languageCode),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant PlayGuideScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (PlayGuideScreen.assetForLanguage(oldWidget.languageCode) !=
        PlayGuideScreen.assetForLanguage(widget.languageCode)) {
      final oldController = _pdfController;
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openAsset(
          PlayGuideScreen.assetForLanguage(widget.languageCode),
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldController.dispose();
      });
    }
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GameTypography(
    languageCode: widget.languageCode,
    child: Scaffold(
      backgroundColor: AppTheme.obsidian,
      appBar: AppBar(
        backgroundColor: AppTheme.obsidian,
        foregroundColor: AppTheme.gold,
        title: Text(
          _bn ? 'খেলার নির্দেশিকা' : 'How to Play',
          style: TextStyle(
            fontFamily: GameTypography.family(widget.languageCode),
            fontFamilyFallback: GameTypography.fallbacks(widget.languageCode),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: AppTheme.panel,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                _bn
                    ? 'পৃষ্ঠা পরিবর্তন করতে সোয়াইপ করুন; বড় করে দেখতে দুই আঙুল ব্যবহার করুন।'
                    : 'Swipe to change pages; pinch to zoom in.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontFamily: GameTypography.family(widget.languageCode),
                  fontFamilyFallback: GameTypography.fallbacks(
                    widget.languageCode,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PdfViewPinch(
                key: ValueKey<String>(
                  PlayGuideScreen.assetForLanguage(widget.languageCode),
                ),
                controller: _pdfController,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';

import '../../core/fonts/font_preferences.dart';

/// Kept as a compatibility wrapper for existing GameSetup, Board and LAN
/// routes from Phases 2–5. Uses the user's saved default instead of
/// hardcoding Karnaphuli/Exo2 on every screen.
class GameTypography extends StatelessWidget {
  const GameTypography({
    super.key,
    required this.languageCode,
    required this.child,
  });

  final String languageCode;
  final Widget child;

  static String family(String languageCode) =>
      FontPreferences.instance.renderFamilyFor(languageCode);

  static List<String> fallbacks(String languageCode) =>
      FontPreferences.instance.renderFallbacksFor(languageCode);

  static TextStyle? style(String languageCode, TextStyle? base) =>
      base?.copyWith(
        fontFamily: family(languageCode),
        fontFamilyFallback: fallbacks(languageCode),
      );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: FontPreferences.instance,
    builder: (context, _) {
      final base = Theme.of(context);
      final selectedFont = family(languageCode);
      final fallbackFonts = fallbacks(languageCode);
      final theme = base.copyWith(
        textTheme: base.textTheme.apply(
          fontFamily: selectedFont,
          fontFamilyFallback: fallbackFonts,
        ),
        primaryTextTheme: base.primaryTextTheme.apply(
          fontFamily: selectedFont,
          fontFamilyFallback: fallbackFonts,
        ),
      );
      return Theme(
        data: theme,
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontFamily: selectedFont,
            fontFamilyFallback: fallbackFonts,
            height: languageCode == 'bn' ? 1.35 : 1.13,
          ),
          child: child,
        ),
      );
    },
  );
}

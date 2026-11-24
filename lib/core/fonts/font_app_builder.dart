import 'package:flutter/material.dart';

import 'font_catalog.dart';
import 'font_preferences.dart';

/// Put this widget in MaterialApp.builder to apply saved fonts across ALL
/// routes (Home, Profile, Rules, game, dialogs, LAN lobby), not just Home.
///
/// MaterialApp(
///   builder: (context, child) => FontAppBuilder(child: child!),
///   ...
/// )
///
/// If the app's MaterialApp.locale does not follow its language toggle,
/// pass languageCode from the existing app state explicitly.
class FontAppBuilder extends StatefulWidget {
  const FontAppBuilder({super.key, required this.child, this.languageCode});

  final Widget child;
  final String? languageCode;

  @override
  State<FontAppBuilder> createState() => _FontAppBuilderState();
}

class _FontAppBuilderState extends State<FontAppBuilder> {
  @override
  void initState() {
    super.initState();
    // Loads persisted defaults once; the listener rebuilds text themes.
    FontPreferences.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: FontPreferences.instance,
      builder: (context, _) {
        final code =
            widget.languageCode ??
            Localizations.maybeLocaleOf(context)?.languageCode ??
            'en';
        final prefs = FontPreferences.instance;
        final family = prefs.renderFamilyFor(code);
        final fallback = prefs.renderFallbacksFor(code);
        final theme = Theme.of(context);
        // Apply one modest scale adjustment for Bengali. The UI uses a
        // Unicode-safe render font even if the saved preference is MJ.
        // Nested GameTypography must not scale text a second time.
        final fontSizeFactor = code == 'bn' ? 1.08 : 1.0;
        final updated = theme.copyWith(
          textTheme: theme.textTheme.apply(
            fontFamily: family,
            fontFamilyFallback: fallback,
            fontSizeFactor: fontSizeFactor,
          ),
          primaryTextTheme: theme.primaryTextTheme.apply(
            fontFamily: family,
            fontFamilyFallback: fallback,
            fontSizeFactor: fontSizeFactor,
          ),
        );
        return Theme(
          data: updated,
          child: DefaultTextStyle.merge(
            style: TextStyle(
              fontFamily: family,
              fontFamilyFallback: fallback,
              height: code == 'bn' ? 1.35 : 1.13,
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// Use in a custom TextStyle when an old screen sets `fontFamily` explicitly:
///
/// Text('...', style: const TextStyle(...).withSelectedFont('bn'))
extension SelectedFontTextStyle on TextStyle {
  TextStyle withSelectedFont(String languageCode) {
    final prefs = FontPreferences.instance;
    final family = FontCatalog.renderFamily(
      languageCode,
      FontCatalog.validated(languageCode, prefs.familyFor(languageCode)),
    );
    return copyWith(
      fontFamily: family,
      fontFamilyFallback: prefs.renderFallbacksFor(languageCode),
    );
  }
}

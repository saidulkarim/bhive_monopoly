/// All selectable app fonts live here. To add fonts later:
/// 1. Place the licensed TTF/OTF in assets/fonts/.
/// 2. Register its family in flutter/fonts in pubspec.yaml.
/// 3. Add one FontChoice below with the EXACT family name.
/// No font binaries are distributed in this source patch.
class FontChoice {
  const FontChoice({
    required this.family,
    required this.label,
    required this.languageCode,
    this.requiresAsset = true,
  });

  /// Must match `family:` in pubspec.yaml, or a platform font (e.g. Roboto).
  final String family;
  final String label;
  final String languageCode;
  final bool requiresAsset;
}

class FontCatalog {
  const FontCatalog._();

  static const String defaultBangla = 'KarnaphuliMJ';
  static const String defaultEnglish = 'Exo2';

  /// The user's saved default remains KarnaphuliMJ. The currently bundled
  /// legacy MJ font appears unable to shape this app's Unicode Bangla text
  /// correctly (see the settings-drawer screenshots). Merely adding a font
  /// fallback does NOT fix a glyph that is present but mapped incorrectly.
  /// Until a verified Unicode-mapped Karnaphuli file is supplied, render
  /// Unicode interface copy with Nikosh while keeping the selection intact.
  /// Once a compatible Karnaphuli file has been verified, set this to true.
  static const bool karnaphuliSupportsUnicodeUi = false;

  static String renderFamily(String languageCode, String selectedFamily) {
    if (languageCode == 'bn' &&
        selectedFamily == 'KarnaphuliMJ' &&
        !karnaphuliSupportsUnicodeUi) {
      return 'Nikosh';
    }
    return selectedFamily;
  }

  static List<String> renderFallbacks(
    String languageCode,
    String selectedFamily,
  ) => fallbacks(languageCode, renderFamily(languageCode, selectedFamily));

  static const List<FontChoice> banglaFonts = <FontChoice>[
    // Requested app default. This family must match pubspec.yaml exactly.
    // A Unicode-mapped font is required to render Unicode Bangla faithfully.
    FontChoice(
      family: 'KarnaphuliMJ',
      label: 'KarnaphuliMJ (default)',
      languageCode: 'bn',
    ),
    FontChoice(family: 'Nikosh', label: 'Nikosh', languageCode: 'bn'),
    FontChoice(family: 'NikoshBAN', label: 'NikoshBAN', languageCode: 'bn'),
    FontChoice(family: 'Hadi', label: 'Hadi', languageCode: 'bn'),
    // Example after registering new asset:
    // FontChoice(family: 'MyBangla', label: 'My Bangla', languageCode: 'bn'),
  ];

  static const List<FontChoice> englishFonts = <FontChoice>[
    FontChoice(family: 'Exo2', label: 'Exo2', languageCode: 'en'),
    // Flutter Material typically uses Roboto, but exact appearance varies
    // across platforms/browser environments unless you bundle this font.
    FontChoice(
      family: 'Roboto',
      label: 'Roboto (device)',
      languageCode: 'en',
      requiresAsset: false,
    ),
    // FontChoice(family: 'MyEnglish', label: 'My English', languageCode: 'en'),
  ];

  static List<FontChoice> forLanguage(String languageCode) =>
      languageCode == 'bn' ? banglaFonts : englishFonts;

  static String defaultFor(String languageCode) =>
      languageCode == 'bn' ? defaultBangla : defaultEnglish;

  static bool isAllowed(String languageCode, String family) =>
      forLanguage(languageCode).any((choice) => choice.family == family);

  static String validated(String languageCode, String? family) =>
      family != null && isAllowed(languageCode, family)
      ? family
      : defaultFor(languageCode);

  /// Preferred fallback order for missing glyphs.
  /// Keep Unicode-capable fallbacks if the chosen face lacks glyphs.
  static List<String> fallbacks(String languageCode, String primaryFamily) {
    // The selected primary font MUST NOT appear in its fallback list.
    // Keep the fixed fallback priority while supporting future font additions.
    final allowed = forLanguage(languageCode);
    final candidates = languageCode == 'bn'
        ? const <String>['Nikosh', 'NikoshBAN']
        : const <String>['Exo2'];

    return candidates
        .where((font) {
          return font != primaryFamily &&
              allowed.any((choice) => choice.family == font);
        })
        .toList(growable: false);
  }
}

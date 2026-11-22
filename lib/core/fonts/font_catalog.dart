/// All selectable app fonts live here. To add fonts later:
/// 1. Place the licensed Unicode TTF/OTF in assets/fonts/.
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

  static const String defaultBangla = 'Karnaphuli';
  static const String defaultEnglish = 'Exo2';

  static const List<FontChoice> banglaFonts = <FontChoice>[
    FontChoice(family: 'Karnaphuli', label: 'Karnaphuli', languageCode: 'bn'),
    FontChoice(family: 'Hadi', label: 'Hadi', languageCode: 'bn'),
    FontChoice(family: 'Nikosh', label: 'Nikosh', languageCode: 'bn'),
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

  /// Preferred fallback order for missing glyphs, not aesthetic replacement.
  /// Karnaphuli is the default Bangla font; Nikosh is its fallback.
  static List<String> fallbacks(String languageCode, String primaryFamily) {
    // The selected primary font MUST NOT appear in its fallback list.
    // Keep the fixed fallback priority while supporting future font additions.
    final allowed = forLanguage(languageCode);
    final candidates = languageCode == 'bn'
        ? const <String>['Nikosh', 'Karnaphuli']
        : const <String>['Exo2'];

    return candidates
        .where((font) {
          return font != primaryFamily &&
              allowed.any((choice) => choice.family == font);
        })
        .toList(growable: false);
  }
}

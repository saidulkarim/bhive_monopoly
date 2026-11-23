import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'font_catalog.dart';

/// Shared persistent font selection for ALL app screens.
/// Each language has an independent default, surviving application restarts.
/// An invalid or removed font setting gracefully reverts to the catalog default.
class FontPreferences extends ChangeNotifier {
  FontPreferences();

  static final FontPreferences instance = FontPreferences();
  static const String _banglaKey = 'bhive_font_bangla_v1';
  static const String _englishKey = 'bhive_font_english_v1';
  // One-time upgrade of the former Hadi default on existing installations.
  static const String _karnaphuliMigrationKey =
      'bhive_font_migrated_to_karnaphuli_v1';

  String _bangla = FontCatalog.defaultBangla;
  String _english = FontCatalog.defaultEnglish;
  Future<void>? _pendingLoad;
  bool _loaded = false;

  String get banglaFamily => _bangla;
  String get englishFamily => _english;
  bool get isLoaded => _loaded;

  String familyFor(String languageCode) =>
      languageCode == 'bn' ? _bangla : _english;

  List<String> fallbacksFor(String languageCode) =>
      FontCatalog.fallbacks(languageCode, familyFor(languageCode));

  /// Safe to call repeatedly from MaterialApp and FontSettingsScreen.
  Future<void> load() {
    if (_loaded) return Future<void>.value();
    return _pendingLoad ??= _readFromStorage().whenComplete(() {
      _pendingLoad = null;
    });
  }

  Future<void> _readFromStorage() async {
    final preferences = await SharedPreferences.getInstance();
    // The old app default was Hadi. Migrate it once so existing users also
    // get Karnaphuli after upgrading, without resetting Nikosh choices.
    // Once the marker is stored, explicitly choosing Hadi stays respected.
    final hasMigrated = preferences.getBool(_karnaphuliMigrationKey) ?? false;
    var savedBangla = preferences.getString(_banglaKey);
    if (!hasMigrated) {
      if (savedBangla == 'Hadi') {
        if (!await preferences.setString(
          _banglaKey,
          FontCatalog.defaultBangla,
        )) {
          throw StateError('Could not migrate Bangla font preference');
        }
        savedBangla = FontCatalog.defaultBangla;
      }
      if (!await preferences.setBool(_karnaphuliMigrationKey, true)) {
        throw StateError('Could not store Bangla font migration');
      }
    }
    _bangla = FontCatalog.validated('bn', savedBangla);
    _english = FontCatalog.validated('en', preferences.getString(_englishKey));
    _loaded = true;
    notifyListeners();
  }

  /// Only update UI after preferences have been persisted successfully.
  Future<void> save({
    required String banglaFamily,
    required String englishFamily,
  }) async {
    if (!FontCatalog.isAllowed('bn', banglaFamily)) {
      throw ArgumentError.value(banglaFamily, 'banglaFamily', 'Unknown font');
    }
    if (!FontCatalog.isAllowed('en', englishFamily)) {
      throw ArgumentError.value(englishFamily, 'englishFamily', 'Unknown font');
    }
    // Complete a pending first load before writing, avoiding older values
    // overwriting the user's new selection.
    await load();
    final preferences = await SharedPreferences.getInstance();
    final oldBn = _bangla;
    final oldEn = _english;
    if (oldBn == banglaFamily && oldEn == englishFamily) return;
    // Two preference keys: on failure, restore any completed write.
    try {
      if (!await preferences.setString(_banglaKey, banglaFamily)) {
        throw StateError('Could not save Bangla font');
      }
      if (!await preferences.setString(_englishKey, englishFamily)) {
        throw StateError('Could not save English font');
      }
    } catch (_) {
      await preferences.setString(_banglaKey, oldBn);
      await preferences.setString(_englishKey, oldEn);
      rethrow;
    }
    _bangla = banglaFamily;
    _english = englishFamily;
    notifyListeners();
  }

  Future<void> restoreDefaults() => save(
    banglaFamily: FontCatalog.defaultBangla,
    englishFamily: FontCatalog.defaultEnglish,
  );
}

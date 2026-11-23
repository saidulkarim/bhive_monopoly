import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Currency affects display symbols only, not gameplay amounts or exchange
/// rates. Both USD and BDT may be selected in either UI language.
class CurrencyPreferences extends ChangeNotifier {
  CurrencyPreferences._();
  static final CurrencyPreferences instance = CurrencyPreferences._();
  static const storageKey = 'bhive.monopoly.currency.v1';
  String? _selectedCode;
  Future<void>? _loadFuture;

  /// A stored currency overrides the language-derived legacy default.
  String get code => _selectedCode ?? 'USD';
  String codeFor(String languageCode) =>
      _selectedCode ?? (languageCode == 'bn' ? 'BDT' : 'USD');
  Future<void> ensureLoaded() => _loadFuture ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(storageKey);
      _selectedCode = saved == 'BDT' || saved == 'USD' ? saved : null;
    } catch (error) {
      debugPrint('Currency preference could not be loaded: $error');
    }
    notifyListeners();
  }

  Future<void> setCurrency(String currencyCode) async {
    if (currencyCode != 'USD' && currencyCode != 'BDT') {
      throw ArgumentError.value(currencyCode, 'currencyCode');
    }
    await ensureLoaded();
    _selectedCode = currencyCode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, currencyCode);
  }
}

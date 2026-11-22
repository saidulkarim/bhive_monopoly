import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Visual-only token styles. Four styles have matching Phase 8 GLB models.
/// The tiny pieces on the board stay Flutter-rendered for smooth animation;
/// the settings screen displays actual interactive GLB models.
class GameTokenStyle {
  const GameTokenStyle({
    required this.key,
    required this.english,
    required this.bangla,
    required this.icon,
    this.modelAsset,
  });

  final String key;
  final String english;
  final String bangla;
  final IconData icon;
  final String? modelAsset;
}

class TokenCatalog {
  TokenCatalog._();

  static const List<GameTokenStyle> styles = <GameTokenStyle>[
    GameTokenStyle(
      key: 'car',
      english: 'Gold car',
      bangla: 'সোনালি গাড়ি',
      icon: Icons.directions_car_filled_rounded,
      modelAsset: 'assets/models/gold_car.glb',
    ),
    GameTokenStyle(
      key: 'yacht',
      english: 'Pearl yacht',
      bangla: 'মুক্তা ইয়ট',
      icon: Icons.sailing_rounded,
      modelAsset: 'assets/models/pearl_yacht.glb',
    ),
    GameTokenStyle(
      key: 'crown',
      english: 'Royal crown',
      bangla: 'রাজমুকুট',
      icon: Icons.workspace_premium_rounded,
      modelAsset: 'assets/models/royal_crown.glb',
    ),
    GameTokenStyle(
      key: 'rocket',
      english: 'Sky rocket',
      bangla: 'রকেট',
      icon: Icons.rocket_launch_rounded,
      modelAsset: 'assets/models/sky_rocket.glb',
    ),
    GameTokenStyle(
      key: 'gem',
      english: 'Diamond',
      bangla: 'হীরা',
      icon: Icons.diamond_rounded,
    ),
    GameTokenStyle(
      key: 'star',
      english: 'Golden star',
      bangla: 'সোনালি তারা',
      icon: Icons.star_rounded,
    ),
  ];
}

/// One preferred piece for each player seat (0–5).
/// Local UI choice only: NOT a game-rule input or a LAN network packet.
class TokenPreferences extends ChangeNotifier {
  TokenPreferences();

  static final TokenPreferences instance = TokenPreferences();
  static const String storageKey = 'bhive.monopoly.p9.token_styles';
  final List<int> _selected = <int>[0, 1, 2, 3, 4, 5];
  Future<void>? _loadFuture;

  int selectionFor(int playerId) {
    if (playerId < 0 || playerId >= _selected.length) return 0;
    return _selected[playerId];
  }

  GameTokenStyle styleFor(int playerId) =>
      TokenCatalog.styles[selectionFor(playerId)];

  Future<void> ensureLoaded() => _loadFuture ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(storageKey);
      if (stored != null && stored.length == _selected.length) {
        for (var i = 0; i < stored.length; i++) {
          final number = int.tryParse(stored[i]);
          if (number != null &&
              number >= 0 &&
              number < TokenCatalog.styles.length) {
            _selected[i] = number;
          }
        }
      }
    } catch (error) {
      debugPrint('Could not read saved Monopoly token choices: $error');
    }
    notifyListeners();
  }

  Future<void> select(int playerId, int styleIndex) async {
    await ensureLoaded();
    if (playerId < 0 ||
        playerId >= _selected.length ||
        styleIndex < 0 ||
        styleIndex >= TokenCatalog.styles.length) {
      throw RangeError('Invalid player seat or token style.');
    }
    _selected[playerId] = styleIndex;
    notifyListeners();
    await _save();
  }

  Future<void> restoreDefaults() async {
    await ensureLoaded();
    for (var i = 0; i < _selected.length; i++) {
      _selected[i] = i;
    }
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setStringList(
      storageKey,
      _selected.map((n) => '$n').toList(),
    );
    if (!ok) throw StateError('Failed to save token preferences.');
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Twelve distinct, modern player colours. This is a VISUAL preference;
/// property groups retain their own deed colours.
class PlayerPalette {
  PlayerPalette._();

  static const List<Color> colors = <Color>[
    Color(0xFFF3B665), // Amber
    Color(0xFF65C8F0), // Sky
    Color(0xFFED85A8), // Coral rose
    Color(0xFF87D5A3), // Mint
    Color(0xFFB99AF1), // Lavender
    Color(0xFFF2D873), // Champagne
    Color(0xFF51C4BB), // Teal
    Color(0xFFFF8F73), // Apricot
    Color(0xFF879EFA), // Periwinkle
    Color(0xFFC7D56E), // Lime
    Color(0xFFEA95D7), // Orchid
    Color(0xFFA2BAC9), // Steel blue
  ];

  static const List<String> labels = <String>[
    'Amber',
    'Sky',
    'Rose',
    'Mint',
    'Lavender',
    'Champagne',
    'Teal',
    'Apricot',
    'Periwinkle',
    'Lime',
    'Orchid',
    'Steel',
  ];

  static Color at(int index) =>
      colors[index.clamp(0, colors.length - 1).toInt()];
}

/// Device profile preference. Seat choices are unique amongst all six slots.
/// Once a game starts, the selected palette indices are copied into the
/// engine's PlayerState and saved/sent via LAN, so boards remain consistent.
class PlayerColorPreferences extends ChangeNotifier {
  PlayerColorPreferences._();
  static final PlayerColorPreferences instance = PlayerColorPreferences._();
  static const String storageKey = 'bhive.monopoly.player_colors.v1';

  final List<int> _indices = <int>[0, 1, 2, 3, 4, 5];
  Future<void>? _loadFuture;

  List<int> get selections => List<int>.unmodifiable(_indices);
  int indexFor(int seat) =>
      _indices[seat.clamp(0, _indices.length - 1).toInt()];
  Color colorFor(int seat) => PlayerPalette.at(indexFor(seat));

  bool isTaken(int index, {required int exceptSeat, int activeSeats = 6}) =>
      _indices.indexed.any(
        (entry) =>
            entry.$1 < activeSeats &&
            entry.$1 != exceptSeat &&
            entry.$2 == index,
      );

  Future<void> ensureLoaded() => _loadFuture ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(storageKey);
      if (raw != null && raw.length == 6) {
        final parsed = raw.map(int.tryParse).toList();
        if (parsed.every(
              (value) =>
                  value != null &&
                  value >= 0 &&
                  value < PlayerPalette.colors.length,
            ) &&
            parsed.toSet().length == 6) {
          for (var i = 0; i < 6; i++) {
            _indices[i] = parsed[i]!;
          }
        }
      }
    } catch (error) {
      debugPrint('Player palette could not be loaded: $error');
    }
    notifyListeners();
  }

  Future<bool> select(int seat, int paletteIndex, {int activeSeats = 6}) async {
    await ensureLoaded();
    if (seat < 0 ||
        seat >= 6 ||
        paletteIndex < 0 ||
        paletteIndex >= PlayerPalette.colors.length) {
      throw RangeError('Invalid player seat or palette index');
    }
    if (activeSeats < 1 || activeSeats > 6) {
      throw RangeError.range(activeSeats, 1, 6, 'activeSeats');
    }
    if (isTaken(paletteIndex, exceptSeat: seat, activeSeats: activeSeats)) {
      return false;
    }
    // An inactive reserved seat may own this palette entry. Swap its colour
    // with our old one, preserving uniqueness without hiding unused colours.
    final ownerSeat = _indices.indexOf(paletteIndex);
    if (ownerSeat >= 0 && ownerSeat != seat) {
      _indices[ownerSeat] = _indices[seat];
    }
    _indices[seat] = paletteIndex;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(storageKey, _indices.map((i) => '$i').toList());
    return true;
  }
}

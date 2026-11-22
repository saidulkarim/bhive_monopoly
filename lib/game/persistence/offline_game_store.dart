// ignore_for_file: unnecessary_underscores

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../ai/bot_controller.dart';
import '../engine/game_engine.dart';

/// Offline matches only. LAN matches are authoritative on the host and do not
/// use this local checkpoint; saving a guest read-only board is unsafe.
class SavedOfflineMatch {
  const SavedOfflineMatch({
    required this.game,
    required this.botDifficulties,
    required this.savedAt,
  });
  final GameEngine game;
  final Map<int, BotDifficulty> botDifficulties;
  final DateTime savedAt;
}

class OfflineGameStore {
  OfflineGameStore._();

  static const String storageKey = 'bhive.monopoly.offline.match.v1';

  // Serialize writes/removals so the final saved match is the most recent
  // completed action, even when a bot makes several quick moves.
  static Future<void> _tail = Future<void>.value();

  static Future<void> _enqueue(Future<void> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  static Future<void> save(
    GameEngine game,
    Map<int, BotDifficulty> botDifficulties,
  ) {
    final payload = jsonEncode(<String, dynamic>{
      'version': 1,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      'bots': <String, String>{
        for (final e in botDifficulties.entries) '${e.key}': e.value.name,
      },
      'engine': game.exportSave(),
    });
    return _enqueue(() async {
      final prefs = await SharedPreferences.getInstance();
      final ok = await prefs.setString(storageKey, payload);
      if (!ok) throw StateError('Unable to save game on this device.');
    });
  }

  static Future<SavedOfflineMatch?> load() async {
    await _tail;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['version'] != 1) throw const FormatException('Save version');
      final game = GameEngine.importSave(
        json['engine'] as Map<String, dynamic>,
      );
      final botsJson = (json['bots'] as Map).cast<String, dynamic>();
      final bots = <int, BotDifficulty>{};
      for (final e in botsJson.entries) {
        final id = int.parse(e.key);
        if (id < 1 || id >= game.players.length) {
          throw const FormatException('Invalid bot player ID');
        }
        bots[id] = BotDifficulty.values.byName(e.value as String);
      }
      return SavedOfflineMatch(
        game: game,
        botDifficulties: bots,
        savedAt: DateTime.parse(json['savedAt'] as String),
      );
    } catch (_) {
      throw const FormatException(
        'The stored game is corrupt or incompatible.',
      );
    }
  }

  static Future<void> clear() => _enqueue(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  });
}

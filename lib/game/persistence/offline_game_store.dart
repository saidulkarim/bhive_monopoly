// ignore_for_file: unnecessary_underscores

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/game_config.dart';
import '../ai/bot_controller.dart';
import '../engine/game_engine.dart';

/// Offline-only checkpoint. A LAN client must never persist its read-only
/// projection and try to resume it as an authoritative GameEngine.
class SavedOfflineMatch {
  const SavedOfflineMatch({
    required this.game,
    required this.botDifficulties,
    required this.savedAt,
    this.matchId,
    this.recoveredFromBackup = false,
  });

  final GameEngine game;
  final Map<int, BotDifficulty> botDifficulties;
  final DateTime savedAt;
  final String? matchId;

  /// True when the most recent primary checkpoint was corrupt and a prior
  /// checkpoint belonging to this SAME match was recovered successfully.
  final bool recoveredFromBackup;
}

class OfflineGameStore {
  OfflineGameStore._();

  // Keep the original key/schema for existing Phase 5–11 installations.
  static const String storageKey = 'bhive.monopoly.offline.match.v1';
  static const String backupKey = 'bhive.monopoly.offline.match.backup.v1';
  static const String activeMatchKey = 'bhive.monopoly.offline.match.active.v1';
  static const String backupMatchKey =
      'bhive.monopoly.offline.match.backup.id.v1';

  static Future<void> _tail = Future<void>.value();

  static Future<void> _enqueue(Future<void> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  static String _groupId(String? matchId) => matchId ?? 'legacy';

  static SavedOfflineMatch _parse(String raw, {bool recovered = false}) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['version'] != 1) {
        throw const FormatException('Unsupported save version.');
      }
      final game = GameEngine.importSave(
        data['engine'] as Map<String, dynamic>,
      );
      final botData = (data['bots'] as Map).cast<String, dynamic>();
      final bots = <int, BotDifficulty>{};
      for (final entry in botData.entries) {
        final id = int.parse(entry.key);
        if (id < 1 || id >= game.players.length) {
          throw const FormatException('Invalid AI player ID.');
        }
        bots[id] = BotDifficulty.values.byName(entry.value as String);
      }
      return SavedOfflineMatch(
        game: game,
        botDifficulties: bots,
        savedAt: DateTime.parse(data['savedAt'] as String),
        matchId: data['matchId'] as String?,
        recoveredFromBackup: recovered,
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid or incompatible offline save.');
    }
  }

  static Future<void> save(
    GameEngine game,
    Map<int, BotDifficulty> botDifficulties, {
    String? matchId,
  }) {
    final payload = jsonEncode(<String, dynamic>{
      'version': 1,
      'matchId': ?matchId,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      'bots': <String, String>{
        for (final entry in botDifficulties.entries)
          '${entry.key}': entry.value.name,
      },
      'engine': game.exportSave(),
    });
    final incomingGroup = _groupId(matchId);
    return _enqueue(() async {
      final prefs = await SharedPreferences.getInstance();
      final previous = prefs.getString(storageKey);
      SavedOfflineMatch? oldMatch;
      if (previous != null) {
        try {
          oldMatch = _parse(previous);
        } catch (_) {
          // Never promote a corrupt primary checkpoint over a good backup.
        }
      }
      if (GameConfig.skipUnchangedOfflineCheckpoints &&
          oldMatch != null &&
          _groupId(oldMatch.matchId) == incomingGroup &&
          prefs.getString(activeMatchKey) == incomingGroup &&
          _sameCheckpoint(previous!, payload)) {
        // Do not rotate the backup or update savedAt for an unchanged game.
        return;
      }
      if (oldMatch != null && _groupId(oldMatch.matchId) == incomingGroup) {
        if (!await prefs.setString(backupKey, previous!)) {
          throw StateError('Unable to write recovery checkpoint.');
        }
        if (!await prefs.setString(backupMatchKey, incomingGroup)) {
          throw StateError('Unable to finalize recovery checkpoint.');
        }
      } else if ((oldMatch != null &&
              _groupId(oldMatch.matchId) != incomingGroup) ||
          (oldMatch == null &&
              prefs.getString(activeMatchKey) != incomingGroup)) {
        // Starting a new match invalidates a previous match's recovery data.
        await prefs.remove(backupKey);
        await prefs.remove(backupMatchKey);
      }
      if (!await prefs.setString(storageKey, payload)) {
        throw StateError('Unable to save game on this device.');
      }
      if (!await prefs.setString(activeMatchKey, incomingGroup)) {
        throw StateError('Unable to finalize saved game.');
      }
    });
  }

  static bool _sameCheckpoint(String previous, String incoming) {
    try {
      final oldData = jsonDecode(previous) as Map<String, dynamic>;
      final newData = jsonDecode(incoming) as Map<String, dynamic>;
      oldData.remove('savedAt');
      newData.remove('savedAt');
      return jsonEncode(oldData) == jsonEncode(newData);
    } catch (_) {
      // A comparison failure must never suppress a real save.
      return false;
    }
  }

  static Future<SavedOfflineMatch?> load() async {
    await _tail;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) return null;
    try {
      return _parse(raw);
    } catch (_) {
      final backup = prefs.getString(backupKey);
      final active = prefs.getString(activeMatchKey);
      final backupMatch = prefs.getString(backupMatchKey);
      if (backup != null && active != null && backupMatch == active) {
        try {
          final recovered = _parse(backup, recovered: true);
          if (_groupId(recovered.matchId) == active) return recovered;
        } catch (_) {
          // Neither copy is usable: surface a clear error, not a new game.
        }
      }
      throw const FormatException(
        'The saved game is damaged and no valid backup was found.',
      );
    }
  }

  /// Delete only the matching completed match; a new game can already have
  /// started while match-history persistence finishes asynchronously.
  static Future<void> clearIfMatchId(String expectedMatchId) =>
      _enqueue(() async {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(storageKey);
        if (raw == null) return;
        bool matches = false;
        try {
          matches = _parse(raw).matchId == expectedMatchId;
        } catch (_) {
          // On a corrupt primary, use the separately tracked match identity.
          matches = prefs.getString(activeMatchKey) == expectedMatchId;
        }
        if (matches) await _removeAll(prefs);
      });

  static Future<void> _removeAll(SharedPreferences prefs) async {
    await prefs.remove(storageKey);
    await prefs.remove(backupKey);
    await prefs.remove(activeMatchKey);
    await prefs.remove(backupMatchKey);
  }

  static Future<void> clear() => _enqueue(() async {
    final prefs = await SharedPreferences.getInstance();
    await _removeAll(prefs);
  });
}

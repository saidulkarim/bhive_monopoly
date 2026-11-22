// ignore_for_file: unnecessary_underscores

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../ai/bot_controller.dart';
import '../engine/game_engine.dart';
import '../models/game_models.dart';

/// A final, immutable match record. This is independent of the auto-save file.
class MatchParticipant {
  const MatchParticipant({
    required this.name,
    required this.balance,
    required this.properties,
    required this.bankrupt,
    required this.isBot,
  });

  final String name;
  final int balance;
  final int properties;
  final bool bankrupt;
  final bool isBot;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'balance': balance,
    'properties': properties,
    'bankrupt': bankrupt,
    'isBot': isBot,
  };

  factory MatchParticipant.fromJson(Map<String, dynamic> json) =>
      MatchParticipant(
        name: json['name'] as String,
        balance: (json['balance'] as num).toInt(),
        properties: (json['properties'] as num).toInt(),
        bankrupt: json['bankrupt'] as bool,
        isBot: json['isBot'] as bool,
      );
}

class MatchRecord {
  const MatchRecord({
    required this.id,
    required this.completedAt,
    required this.turns,
    required this.winnerId,
    required this.vsComputer,
    required this.players,
    this.isLan = false,
  });

  final String id;
  final DateTime completedAt;
  final int turns;
  final int winnerId;
  final bool vsComputer;
  final bool isLan;
  final List<MatchParticipant> players;

  String get winnerName => players[winnerId].name;
  bool get playerOneWon => winnerId == 0 && !players[0].isBot;

  /// A stable matchId is persisted in the offline checkpoint to guarantee
  /// that repeated completion callbacks never add the same game twice.
  /// Legacy Phase 8 matches without an ID fall back to a final-state hash.
  factory MatchRecord.fromFinishedGame(
    GameEngine game,
    Map<int, BotDifficulty> botDifficulties, {
    DateTime? now,
    String? matchId,
    bool isLan = false,
  }) {
    if (game.phase != TurnPhase.gameOver || game.winnerId == null) {
      throw StateError('Only a finished game can enter match history.');
    }
    final encoded = jsonEncode(game.exportSave());
    // Stable legacy fallback; bounded Adler-like sums work identically in JS.
    var a = 1;
    var b = 0;
    var c = 7;
    var d = 0;
    for (final byte in utf8.encode(encoded)) {
      a = (a + byte) % 65521;
      b = (b + a) % 65521;
      c = (c + byte + 17) % 65521;
      d = (d + c) % 65521;
    }
    final id =
        '${b.toRadixString(16).padLeft(4, '0')}'
        '${a.toRadixString(16).padLeft(4, '0')}'
        '${d.toRadixString(16).padLeft(4, '0')}'
        '${c.toRadixString(16).padLeft(4, '0')}';
    return MatchRecord(
      id: matchId ?? id,
      completedAt: (now ?? DateTime.now()).toUtc(),
      turns: game.turnNumber,
      winnerId: game.winnerId!,
      vsComputer: botDifficulties.isNotEmpty,
      isLan: isLan,
      players: <MatchParticipant>[
        for (final p in game.players)
          MatchParticipant(
            name: p.name,
            balance: p.balance,
            properties: game.properties
                .where((property) => property.ownerId == p.id)
                .length,
            bankrupt: p.bankrupt,
            isBot: botDifficulties.containsKey(p.id),
          ),
      ],
    );
  }

  /// Create the same match identifier on host and guests from a completed
  /// authoritative state and PIN. A fingerprint, not the PIN itself, is stored.
  /// Identical completion notifications are therefore de-duplicated.
  factory MatchRecord.fromFinishedLanGame(
    GameEngine game, {
    required String roomPin,
    DateTime? now,
  }) {
    final base = MatchRecord.fromFinishedGame(
      game,
      const <int, BotDifficulty>{},
      now: now,
      isLan: true,
    );
    var hash = 0x811c9dc5;
    for (final char in utf8.encode('$roomPin:${base.id}')) {
      hash = ((hash ^ char) * 0x01000193) & 0xffffffff;
    }
    return MatchRecord(
      id: 'lan-${hash.toRadixString(16).padLeft(8, '0')}-${base.id}',
      completedAt: base.completedAt,
      turns: base.turns,
      winnerId: base.winnerId,
      vsComputer: false,
      isLan: true,
      players: base.players,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'completedAt': completedAt.toUtc().toIso8601String(),
    'turns': turns,
    'winnerId': winnerId,
    'vsComputer': vsComputer,
    'isLan': isLan,
    'players': players.map((p) => p.toJson()).toList(),
  };

  factory MatchRecord.fromJson(Map<String, dynamic> json) {
    final players = (json['players'] as List<dynamic>)
        .map(
          (item) =>
              MatchParticipant.fromJson((item as Map).cast<String, dynamic>()),
        )
        .toList(growable: false);
    final winnerId = (json['winnerId'] as num).toInt();
    if (players.length < 2 ||
        players.length > 6 ||
        winnerId < 0 ||
        winnerId >= players.length) {
      throw const FormatException('Invalid match participants.');
    }
    return MatchRecord(
      id: json['id'] as String,
      completedAt: DateTime.parse(json['completedAt'] as String).toUtc(),
      turns: (json['turns'] as num).toInt(),
      winnerId: winnerId,
      vsComputer: json['vsComputer'] as bool,
      isLan: json['isLan'] == true, // Old Phase 9 records remain valid.
      players: players,
    );
  }
}

/// Derived achievements. No client-supplied success counters to manipulate.
class MatchStatistics {
  MatchStatistics(List<MatchRecord> history)
    : matches = history.length,
      playerOneVictories = history.where((m) => m.playerOneWon).length,
      lanMatches = history.where((m) => m.isLan).length,
      offlineMatches = history.where((m) => !m.isLan).length,
      totalTurns = history.fold<int>(0, (total, m) => total + m.turns),
      longestMatch = history.fold<int>(
        0,
        (max, m) => m.turns > max ? m.turns : max,
      ),
      bestPropertyCount = history.fold<int>(0, (best, m) {
        final count = m.players.isEmpty ? 0 : m.players.first.properties;
        return count > best ? count : best;
      });

  final int matches;
  final int playerOneVictories;
  final int lanMatches;
  final int offlineMatches;
  final int totalTurns;
  final int longestMatch;
  final int bestPropertyCount;

  double get winRate => matches == 0 ? 0 : playerOneVictories * 100 / matches;
  bool get firstVictory => playerOneVictories >= 1;
  bool get veteran => matches >= 5;
  bool get champion => playerOneVictories >= 10;
  bool get propertyCollector => bestPropertyCount >= 10;
  bool get marathon => longestMatch >= 75;
  bool get lanPioneer => lanMatches >= 1;
  bool get lanVeteran => lanMatches >= 5;
  bool get propertyMagnate => bestPropertyCount >= 15;
  bool get endurance => longestMatch >= 150;
}

/// Completed offline and (Phase 10) LAN games seen on this device.
/// Up to 100 records kept on this device.
/// Serial queue prevents lost updates from overlapping async callbacks.
class MatchHistoryStore {
  MatchHistoryStore._();
  static const storageKey = 'bhive.monopoly.p9.match_history.v1';
  static const maxRecords = 100;
  static Future<void> _tail = Future<void>.value();

  static Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  static Future<List<MatchRecord>> load() => _serial(_loadDirect);

  static Future<List<MatchRecord>> _loadDirect() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) return <MatchRecord>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) throw const FormatException('Match history invalid.');
    return <MatchRecord>[
      for (final row in decoded)
        MatchRecord.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// Returns false when the game was already recorded.
  static Future<bool> record(MatchRecord record) => _serial(() async {
    final matches = await _loadDirect();
    if (matches.any((m) => m.id == record.id)) return false;
    matches.insert(0, record);
    if (matches.length > maxRecords) {
      matches.removeRange(maxRecords, matches.length);
    }
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(
      storageKey,
      jsonEncode(matches.map((m) => m.toJson()).toList()),
    );
    if (!ok) throw StateError('Unable to save match history.');
    return true;
  });

  static Future<void> clear() => _serial(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  });
}

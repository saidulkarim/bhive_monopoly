import '../engine/game_engine.dart';

/// UI-only snapshot of live game results, not a persisted match format and
/// not a replacement for the bankruptcy / winner rules in GameEngine.
class MatchStanding {
  const MatchStanding({
    required this.playerId,
    required this.name,
    required this.balance,
    required this.properties,
    required this.houses,
    required this.hotels,
    required this.mortgaged,
    required this.bankrupt,
    required this.winner,
  });

  final int playerId;
  final String name;
  final int balance;
  final int properties;
  final int houses;
  final int hotels;
  final int mortgaged;
  final bool bankrupt;
  final bool winner;
}

class MatchStandings {
  const MatchStandings._();

  /// Winner always ranks first. Other players are sorted by final balance,
  /// then number of properties, then stable player ID. The ranking is a
  /// presentation aid; it is not a claim about Monopoly net worth.
  static List<MatchStanding> fromGame(GameEngine game) {
    final rows = <MatchStanding>[
      for (final player in game.players)
        MatchStanding(
          playerId: player.id,
          name: player.name,
          balance: player.balance,
          properties: game.properties
              .where((property) => property.ownerId == player.id)
              .length,
          houses: game.properties
              .where(
                (property) =>
                    property.ownerId == player.id && property.development < 5,
              )
              .fold<int>(0, (sum, property) => sum + property.development),
          hotels: game.properties
              .where(
                (property) =>
                    property.ownerId == player.id && property.development == 5,
              )
              .length,
          mortgaged: game.properties
              .where(
                (property) =>
                    property.ownerId == player.id && property.mortgaged,
              )
              .length,
          bankrupt: player.bankrupt,
          winner: game.winnerId == player.id,
        ),
    ];
    rows.sort((a, b) {
      if (a.winner != b.winner) return a.winner ? -1 : 1;
      if (a.bankrupt != b.bankrupt) return a.bankrupt ? 1 : -1;
      final byCash = b.balance.compareTo(a.balance);
      if (byCash != 0) return byCash;
      final byProperties = b.properties.compareTo(a.properties);
      if (byProperties != 0) return byProperties;
      return a.playerId.compareTo(b.playerId);
    });
    return rows;
  }
}

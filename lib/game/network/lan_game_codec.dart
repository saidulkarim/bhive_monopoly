import '../engine/game_engine.dart';
import '../models/game_models.dart';
import '../validation/game_snapshot_validator.dart';

/// Read-only wire projection of the host's authoritative engine.
/// Never use a client-side restored engine to make rules decisions: private
/// card deck / pending turn internals deliberately do not cross the network.
class LanGameCodec {
  static Map<String, dynamic> encode(GameEngine game) => <String, dynamic>{
    'players': [
      for (final p in game.players)
        <String, dynamic>{
          'id': p.id,
          'name': p.name,
          'colorIndex': p.colorIndex,
          'balance': p.balance,
          'position': p.position,
          'inJail': p.inJail,
          'jailFailedRolls': p.jailFailedRolls,
          'jailCardCount': p.getOutOfJailCards,
          'bankrupt': p.bankrupt,
        },
    ],
    'properties': [
      for (final p in game.properties)
        <String, dynamic>{
          'ownerId': p.ownerId,
          'development': p.development,
          'mortgaged': p.mortgaged,
        },
    ],
    'currentPlayerId': game.currentPlayerId,
    'turnNumber': game.turnNumber,
    'phase': game.phase.name,
    'pendingPurchaseIndex': game.pendingPurchaseIndex,
    'auction': game.auction == null
        ? null
        : <String, dynamic>{
            'spaceIndex': game.auction!.spaceIndex,
            'bidderId': game.auction!.bidderId,
            'highBid': game.auction!.highBid,
            'highestBidderId': game.auction!.highestBidderId,
            'passed': game.auction!.passed.toList(),
          },
    'lastRoll': game.lastRoll == null
        ? null
        : <String, dynamic>{
            'first': game.lastRoll!.first,
            'second': game.lastRoll!.second,
          },
    'winnerId': game.winnerId,
    'debtCreditorId': game.debtCreditorId,
    'log': game.log.toList(),
    'activity': game.activityEvents.map((e) => e.toJson()).toList(),
  };

  static GameEngine decode(Map<String, dynamic> data) {
    GameSnapshotValidator.validateLan(data);
    final playersData = (data['players'] as List).cast<Map<String, dynamic>>();
    final game = GameEngine(
      playerNames: playersData.map((p) => p['name'] as String).toList(),
    );
    apply(game, data);
    return game;
  }

  /// Mutates public presentation fields only. Used exclusively by LAN guests.
  static void apply(GameEngine game, Map<String, dynamic> data) {
    // Preflight the ENTIRE snapshot before touching a single live field.
    // A malformed host packet must never leave a half-updated guest board.
    GameSnapshotValidator.validateLan(
      data,
      expectedNames: [for (final player in game.players) player.name],
    );
    final ps = (data['players'] as List).cast<Map<String, dynamic>>();
    final tiles = (data['properties'] as List).cast<Map<String, dynamic>>();
    if (ps.length != game.players.length || tiles.length != 40) {
      throw const FormatException('Invalid room snapshot dimensions');
    }
    for (var i = 0; i < ps.length; i++) {
      final wire = ps[i];
      final p = game.players[i];
      if (wire['id'] != i || wire['name'] != p.name) {
        throw const FormatException('Room players changed unexpectedly');
      }
      final color = wire['colorIndex'];
      p.colorIndex = color is int && color >= 0 && color < 12 ? color : i;
      p.balance = wire['balance'] as int;
      p.position = wire['position'] as int;
      p.inJail = wire['inJail'] as bool;
      p.jailFailedRolls = wire['jailFailedRolls'] as int;
      p.bankrupt = wire['bankrupt'] as bool;
      // Only the count is displayed. Never use the client's dummy card origins
      // to execute game actions (all rule evaluation happens on the host).
      p.jailCardOrigins
        ..clear()
        ..addAll(List<bool>.filled(wire['jailCardCount'] as int, false));
    }
    for (var i = 0; i < 40; i++) {
      final wire = tiles[i];
      final p = game.properties[i];
      p.ownerId = wire['ownerId'] as int?;
      p.development = wire['development'] as int;
      p.mortgaged = wire['mortgaged'] as bool;
    }
    game.currentPlayerId = data['currentPlayerId'] as int;
    game.turnNumber = data['turnNumber'] as int;
    game.phase = TurnPhase.values.byName(data['phase'] as String);
    game.pendingPurchaseIndex = data['pendingPurchaseIndex'] as int?;
    final wireAuction = data['auction'];
    if (wireAuction == null) {
      game.auction = null;
    } else {
      final a = wireAuction as Map<String, dynamic>;
      final auction = AuctionState(
        spaceIndex: a['spaceIndex'] as int,
        bidderId: a['bidderId'] as int,
      );
      auction.highBid = a['highBid'] as int;
      auction.highestBidderId = a['highestBidderId'] as int?;
      auction.passed.addAll((a['passed'] as List).cast<int>());
      game.auction = auction;
    }
    final roll = data['lastRoll'];
    game.lastRoll = roll == null
        ? null
        : DiceRoll(
            (roll as Map<String, dynamic>)['first'] as int,
            roll['second'] as int,
          );
    game.winnerId = data['winnerId'] as int?;
    game.debtCreditorId = data['debtCreditorId'] as int?;
    game.log
      ..clear()
      ..addAll((data['log'] as List).cast<String>());
    game.restoreActivity(data['activity']);
  }
}

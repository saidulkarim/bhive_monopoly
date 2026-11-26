import '../core/board_data.dart';
import '../../core/config/game_config.dart';
import '../models/game_models.dart';

/// Validates *untrusted serialized data* before it can change a live game.
///
/// LAN snapshots and offline saves have different representations of jail
/// cards, but share the same public board/turn invariants. This class has no
/// Flutter dependency and never mutates its input.
class GameSnapshotValidator {
  const GameSnapshotValidator._();

  static void validateLan(
    Map<String, dynamic> data, {
    List<String>? expectedNames,
  }) => _validate(data, offline: false, expectedNames: expectedNames);

  static void validateOffline(Map<String, dynamic> data) {
    if (data['schema'] != 1) {
      throw const FormatException('Unsupported save schema.');
    }
    _validate(data, offline: true);
  }

  static List<dynamic> _list(dynamic value, String field) {
    if (value is! List) throw FormatException('Invalid $field.');
    return value;
  }

  static Map<String, dynamic> _map(dynamic value, String field) {
    if (value is! Map<String, dynamic>) {
      throw FormatException('Invalid $field.');
    }
    return value;
  }

  static int _int(dynamic value, String field, {int? min, int? max}) {
    if (value is! int ||
        (min != null && value < min) ||
        (max != null && value > max)) {
      throw FormatException('Invalid $field.');
    }
    return value;
  }

  static int? _optionalId(dynamic value, String field, int count) {
    if (value == null) return null;
    return _int(value, field, min: 0, max: count - 1);
  }

  static void _isBool(dynamic value, String field) {
    if (value is! bool) throw FormatException('Invalid $field.');
  }

  static void _validate(
    Map<String, dynamic> data, {
    required bool offline,
    List<String>? expectedNames,
  }) {
    final players = _list(data['players'], 'players');
    final properties = _list(data['properties'], 'properties');
    if (players.length < 2 ||
        players.length > 6 ||
        properties.length != BoardData.spaces.length ||
        (expectedNames != null && expectedNames.length != players.length)) {
      throw const FormatException('Invalid board or player count.');
    }

    final names = <String>{};
    final bankrupt = <bool>[];
    final seenColors = <int>{};
    var totalJailCards = 0;
    for (var i = 0; i < players.length; i++) {
      final player = _map(players[i], 'player $i');
      final name = player['name'];
      if (name is! String ||
          name.trim().isEmpty ||
          name.length > 100 ||
          (!offline && !names.add(name.toLowerCase())) ||
          (expectedNames != null && name != expectedNames[i])) {
        throw FormatException('Invalid player name at $i.');
      }
      if (!offline && player['id'] != i) {
        throw FormatException('Invalid player ID at $i.');
      }
      if (player.containsKey('colorIndex')) {
        final color = _int(
          player['colorIndex'],
          'player color',
          min: 0,
          max: 11,
        );
        if (!seenColors.add(color)) {
          throw const FormatException('Player colours must be unique.');
        }
      }
      _int(player['balance'], 'player balance');
      _int(player['position'], 'player position', min: 0, max: 39);
      _int(player['jailFailedRolls'], 'jail rolls', min: 0, max: 3);
      _isBool(player['inJail'], 'inJail');
      _isBool(player['bankrupt'], 'bankrupt');
      bankrupt.add(player['bankrupt'] as bool);
      if (offline) {
        final origins = _list(player['jailCardOrigins'], 'jail card origins');
        if (origins.length > 2 || origins.any((e) => e is! bool)) {
          throw const FormatException('Invalid jail card origins.');
        }
        totalJailCards += origins.length;
      } else {
        totalJailCards += _int(
          player['jailCardCount'],
          'jail cards',
          min: 0,
          max: 2,
        );
      }
    }
    if (totalJailCards > 2 || bankrupt.every((b) => b)) {
      throw const FormatException('Invalid active players or cards.');
    }

    var houses = 0;
    var hotels = 0;
    for (var i = 0; i < properties.length; i++) {
      final property = _map(properties[i], 'property $i');
      final owner = _optionalId(
        property['ownerId'],
        'owner $i',
        players.length,
      );
      final level = _int(
        property['development'],
        'development $i',
        min: 0,
        max: 5,
      );
      _isBool(property['mortgaged'], 'mortgaged $i');
      final mortgaged = property['mortgaged'] as bool;
      final kind = BoardData.spaces[i].kind;
      if ((owner == null && (level != 0 || mortgaged)) ||
          (owner != null && bankrupt[owner]) ||
          (mortgaged && level != 0) ||
          (!BoardData.spaces[i].purchasable &&
              (owner != null || level != 0 || mortgaged)) ||
          (kind != SpaceKind.street && level != 0)) {
        throw FormatException('Invalid ownership/buildings at tile $i.');
      }
      if (level == 5) {
        hotels++;
      } else {
        houses += level;
      }
    }
    if (houses > 32 || hotels > 12) {
      throw const FormatException('Building supply exceeded.');
    }

    final current = _int(
      data['currentPlayerId'],
      'current player',
      min: 0,
      max: players.length - 1,
    );
    final turnNumber = _int(data['turnNumber'], 'turn number', min: 1);
    final maximumTurns = offline && data['maximumTurns'] != null
        ? _int(
            data['maximumTurns'],
            'match turn limit',
            min: GameConfig.customMatchMinimumTurns,
            max: GameConfig.customMatchMaximumTurns,
          )
        : null;
    if (maximumTurns != null && turnNumber > maximumTurns) {
      throw const FormatException('Match turn limit exceeded.');
    }
    final phaseName = data['phase'];
    if (phaseName is! String ||
        !TurnPhase.values.any((phase) => phase.name == phaseName)) {
      throw const FormatException('Invalid turn phase.');
    }
    final phase = TurnPhase.values.byName(phaseName);
    if (phase != TurnPhase.gameOver && bankrupt[current]) {
      throw const FormatException('Bankrupt player cannot take a turn.');
    }

    final pending = data['pendingPurchaseIndex'];
    if ((phase == TurnPhase.purchase) != (pending != null)) {
      throw const FormatException('Inconsistent purchase phase.');
    }
    if (pending != null) {
      final index = _int(pending, 'pending purchase', min: 0, max: 39);
      if (!BoardData.spaces[index].purchasable ||
          _map(properties[index], 'pending property')['ownerId'] != null ||
          _map(players[current], 'current player')['position'] != index) {
        throw const FormatException('Invalid pending purchase.');
      }
    }

    final auctionRaw = data['auction'];
    if ((phase == TurnPhase.auction) != (auctionRaw != null)) {
      throw const FormatException('Inconsistent auction phase.');
    }
    if (auctionRaw != null) {
      final auction = _map(auctionRaw, 'auction');
      final tile = _int(auction['spaceIndex'], 'auction tile', min: 0, max: 39);
      final bidder = _int(
        auction['bidderId'],
        'auction bidder',
        min: 0,
        max: players.length - 1,
      );
      final high = _int(auction['highBid'], 'auction bid', min: 0);
      final highBidder = _optionalId(
        auction['highestBidderId'],
        'highest bidder',
        players.length,
      );
      final passed = _list(auction['passed'], 'passed bidders');
      final passedIds = <int>{};
      for (final id in passed) {
        final p = _int(id, 'passed bidder', min: 0, max: players.length - 1);
        if (!passedIds.add(p)) {
          throw const FormatException('Duplicate passed bidder.');
        }
      }
      if (!BoardData.spaces[tile].purchasable ||
          _map(properties[tile], 'auction property')['ownerId'] != null ||
          bankrupt[bidder] ||
          passedIds.contains(bidder) ||
          (high == 0) != (highBidder == null) ||
          (highBidder != null &&
              (bankrupt[highBidder] || passedIds.contains(highBidder)))) {
        throw const FormatException('Invalid auction state.');
      }
    }

    final lastRoll = data['lastRoll'];
    if (lastRoll != null) {
      final roll = _map(lastRoll, 'last roll');
      _int(roll['first'], 'die 1', min: 1, max: 6);
      _int(roll['second'], 'die 2', min: 1, max: 6);
    }
    final winner = _optionalId(data['winnerId'], 'winner', players.length);
    _optionalId(data['debtCreditorId'], 'creditor', players.length);
    if (phase == TurnPhase.gameOver) {
      if (winner == null || bankrupt[winner]) {
        throw const FormatException('Invalid finished game.');
      }
      if (bankrupt.where((b) => !b).length != 1) {
        if (maximumTurns == null || turnNumber != maximumTurns) {
          throw const FormatException('Invalid finished game.');
        }
        final cash = [
          for (final p in players) _map(p, 'player')['balance'] as int,
        ];
        final worth = List<int>.of(cash);
        for (var i = 0; i < properties.length; i++) {
          final p = _map(properties[i], 'property');
          final owner = p['ownerId'] as int?;
          if (owner != null) {
            worth[owner] += propertyNetWorth(
              BoardData.spaces[i],
              p['development'] as int,
              p['mortgaged'] as bool,
            );
          }
        }
        final active =
            [
              for (var i = 0; i < players.length; i++)
                if (!bankrupt[i]) i,
            ]..sort((a, b) {
              final byWorth = worth[b].compareTo(worth[a]);
              if (byWorth != 0) return byWorth;
              final byCash = cash[b].compareTo(cash[a]);
              return byCash != 0 ? byCash : a.compareTo(b);
            });
        if (winner != active.first) {
          throw const FormatException('Invalid turn-limited winner.');
        }
      }
    } else if (winner != null) {
      throw const FormatException('Winner assigned before game completion.');
    }

    final log = _list(data['log'], 'event log');
    if (log.length > 70 ||
        log.any((entry) => entry is! String || entry.length > 2000)) {
      throw const FormatException('Invalid event log.');
    }

    if (offline) {
      // The save importer verifies private debt/deck internals, too. Keep
      // these public invariants identical for LAN and offline snapshots.
      final debts = _list(data['pendingDebts'], 'pending debts');
      if (debts.length > players.length) {
        throw const FormatException('Too many pending debts.');
      }
      final debtIds = <int>{};
      for (final raw in debts) {
        final item = _map(raw, 'pending debt');
        final id = _int(
          item['playerId'],
          'debtor',
          min: 0,
          max: players.length - 1,
        );
        _optionalId(item['creditorId'], 'debt creditor', players.length);
        if (!debtIds.add(id)) {
          throw const FormatException('Duplicate pending debt.');
        }
      }
    }
  }
}

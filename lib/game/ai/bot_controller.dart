// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:math';

import '../core/board_data.dart';
import '../engine/game_engine.dart';
import '../models/game_models.dart';

/// Local, deterministic AI policy. It never mutates the engine: the screen
/// submits a legal action to the same GameEngine API used by human players.
/// Pass a seeded Random to make simulations repeatable.
enum BotDifficulty { easy, medium, hard, expert }

enum BotAction {
  roll,
  jailRoll,
  payFine,
  useJailCard,
  buy,
  auction,
  bid,
  pass,
  build,
  sellBuilding,
  mortgage,
  unmortgage,
  bankrupt,
  endTurn,
}

class BotDecision {
  const BotDecision(this.action, {this.spaceIndex, this.amount});

  final BotAction action;
  final int? spaceIndex;
  final int? amount;
}

class BotController {
  BotController({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// A value of null means a human (rather than an AI) must act next.
  BotDecision? choose(
    GameEngine game, {
    required int playerId,
    required BotDifficulty difficulty,
  }) {
    if (playerId < 0 ||
        playerId >= game.players.length ||
        game.players[playerId].bankrupt) {
      return null;
    }
    if (game.phase == TurnPhase.gameOver) return null;

    // Auctions are controlled by the current bidder, who may differ from the
    // player that landed on the property.
    if (game.phase == TurnPhase.auction) {
      if (game.auction!.bidderId != playerId) return null;
      return _auctionDecision(game, playerId, difficulty);
    }
    if (playerId != game.currentPlayerId) return null;
    final player = game.players[playerId];
    switch (game.phase) {
      case TurnPhase.roll:
        return const BotDecision(BotAction.roll);
      case TurnPhase.jailDecision:
        if (player.getOutOfJailCards > 0) {
          return const BotDecision(BotAction.useJailCard);
        }
        if ((difficulty == BotDifficulty.hard ||
                difficulty == BotDifficulty.expert &&
                    _expectedRisk(game, playerId) < 80) &&
            player.balance > _reserve(game, playerId, difficulty) + 50) {
          return const BotDecision(BotAction.payFine);
        }
        return const BotDecision(BotAction.jailRoll);
      case TurnPhase.purchase:
        return _purchaseDecision(game, playerId, difficulty);
      case TurnPhase.debt:
        return _debtDecision(game, playerId, difficulty);
      case TurnPhase.complete:
        final recovery = _unmortgageDecision(game, playerId, difficulty);
        if (recovery != null) return recovery;
        final upgrade = _buildDecision(game, playerId, difficulty);
        return upgrade ?? const BotDecision(BotAction.endTurn);
      case TurnPhase.auction:
      case TurnPhase.gameOver:
        return null;
    }
  }

  BotDecision _purchaseDecision(
    GameEngine game,
    int playerId,
    BotDifficulty difficulty,
  ) {
    final tile = game.spaces[game.pendingPurchaseIndex!];
    final cash = game.players[playerId].balance;
    final reserve = _reserve(game, playerId, difficulty);
    final completesSet = _completesSet(game, playerId, tile);
    if (difficulty == BotDifficulty.easy && _random.nextDouble() > .58) {
      return const BotDecision(BotAction.auction);
    }
    if (difficulty == BotDifficulty.expert) {
      final strategic = completesSet || _blocksSet(game, playerId, tile);
      final buffer = strategic ? max(100, reserve ~/ 2) : reserve;
      return BotDecision(
        cash >= tile.price + buffer ? BotAction.buy : BotAction.auction,
      );
    }
    final requiredReserve = (difficulty == BotDifficulty.hard && completesSet)
        ? 110
        : reserve;
    if (cash - tile.price >= requiredReserve) {
      return const BotDecision(BotAction.buy);
    }
    return const BotDecision(BotAction.auction);
  }

  BotDecision _auctionDecision(
    GameEngine game,
    int playerId,
    BotDifficulty difficulty,
  ) {
    final auction = game.auction!;
    final tile = game.spaces[auction.spaceIndex];
    final cash = game.players[playerId].balance;
    final reserve = _reserve(game, playerId, difficulty);
    final completesSet = _completesSet(game, playerId, tile);
    double premium;
    switch (difficulty) {
      case BotDifficulty.easy:
        premium = .62;
        if (_random.nextDouble() > .57) {
          return const BotDecision(BotAction.pass);
        }
        break;
      case BotDifficulty.medium:
        premium = completesSet ? 1.08 : .88;
        break;
      case BotDifficulty.expert:
        premium = _titleValue(game, playerId, tile) / tile.price;
        break;
      case BotDifficulty.hard:
        premium = completesSet ? 1.35 : 1.10;
        if (tile.kind == SpaceKind.station) premium += .08;
        if (tile.group == ColorGroup.orange || tile.group == ColorGroup.red) {
          premium += .08;
        }
        break;
    }
    final affordable =
        cash -
        (difficulty == BotDifficulty.expert &&
                (completesSet || _blocksSet(game, playerId, tile))
            ? max(100, reserve ~/ 2)
            : completesSet && difficulty == BotDifficulty.hard
            ? 90
            : reserve);
    final maxBid = min(affordable, (tile.price * premium).floor());
    if (auction.minimumBid > maxBid) {
      return const BotDecision(BotAction.pass);
    }
    // Minimum legal bid, not an immediate jump to maximum willingness to pay.
    return BotDecision(BotAction.bid, amount: auction.minimumBid);
  }

  BotDecision? _buildDecision(
    GameEngine game,
    int playerId,
    BotDifficulty difficulty,
  ) {
    if (difficulty == BotDifficulty.easy && _random.nextDouble() > .22) {
      return null;
    }
    final reserve = _reserve(game, playerId, difficulty);
    final cash = game.players[playerId].balance;
    final eligible = <BoardSpace>[];
    for (final space in game.spaces) {
      if (space.kind != SpaceKind.street ||
          game.properties[space.index].ownerId != playerId ||
          !game.ownsFullGroup(playerId, space.group!)) {
        continue;
      }
      final group = BoardData.colorSet(space.group!);
      if (group.any((s) => game.properties[s.index].mortgaged)) continue;
      final state = game.properties[space.index];
      if (state.development == 5 || cash - space.buildCost < reserve) {
        continue;
      }
      final minDevelopment = group
          .map((s) => game.properties[s.index].development)
          .reduce(min);
      if (state.development != minDevelopment) continue;
      if (state.development == 4 && game.bankHotels <= 0) continue;
      if (state.development < 4 && game.bankHouses <= 0) continue;
      eligible.add(space);
    }
    if (eligible.isEmpty) return null;
    if (difficulty == BotDifficulty.expert) {
      eligible.sort(
        (a, b) => _buildValue(game, b).compareTo(_buildValue(game, a)),
      );
    } else if (difficulty == BotDifficulty.hard) {
      eligible.sort((a, b) {
        final scoreA =
            _groupPriority(a) +
            a.rents[game.properties[a.index].development + 1] ~/ 100;
        final scoreB =
            _groupPriority(b) +
            b.rents[game.properties[b.index].development + 1] ~/ 100;
        return scoreB.compareTo(scoreA);
      });
    }
    return BotDecision(BotAction.build, spaceIndex: eligible.first.index);
  }

  BotDecision _debtDecision(
    GameEngine game,
    int playerId,
    BotDifficulty difficulty,
  ) {
    // Liquidate hotels/houses evenly, then mortgage unimproved titles.
    final buildings = <BoardSpace>[];
    for (final space in game.spaces) {
      if (space.kind != SpaceKind.street ||
          game.properties[space.index].ownerId != playerId ||
          game.properties[space.index].development == 0)
        continue;
      final level = game.properties[space.index].development;
      if (level !=
          BoardData.colorSet(
            space.group!,
          ).map((s) => game.properties[s.index].development).reduce(max))
        continue;
      if (level == 5 && game.bankHouses < 4) continue;
      buildings.add(space);
    }
    if (buildings.isNotEmpty) {
      buildings.sort(
        (a, b) => difficulty == BotDifficulty.expert
            ? _saleLoss(game, a).compareTo(_saleLoss(game, b))
            : b.buildCost.compareTo(a.buildCost),
      );
      return BotDecision(
        BotAction.sellBuilding,
        spaceIndex: buildings.first.index,
      );
    }
    final mortgages = <BoardSpace>[];
    for (final space in game.spaces) {
      if (!space.purchasable ||
          game.properties[space.index].ownerId != playerId ||
          game.properties[space.index].mortgaged)
        continue;
      if (space.group != null &&
          BoardData.colorSet(
            space.group!,
          ).any((s) => game.properties[s.index].development != 0))
        continue;
      mortgages.add(space);
    }
    if (mortgages.isNotEmpty) {
      mortgages.sort(
        (a, b) => difficulty == BotDifficulty.expert
            ? _mortgageLoss(game, a).compareTo(_mortgageLoss(game, b))
            : b.price.compareTo(a.price),
      );
      return BotDecision(BotAction.mortgage, spaceIndex: mortgages.first.index);
    }
    return const BotDecision(BotAction.bankrupt);
  }

  int _reserve(GameEngine game, int playerId, BotDifficulty difficulty) {
    switch (difficulty) {
      case BotDifficulty.easy:
        return 400;
      case BotDifficulty.medium:
        return 300;
      case BotDifficulty.expert:
        return max(
          180,
          min(900, (160 + _expectedRisk(game, playerId) * 3).ceil()),
        );
      case BotDifficulty.hard:
        // Retain cash for one plausible opponent's largest current rent.
        var highestThreat = 0;
        for (final tile in game.spaces) {
          final state = game.properties[tile.index];
          if (state.ownerId == null ||
              state.ownerId == playerId ||
              state.mortgaged)
            continue;
          final rent = game.rentFor(tile.index, 7);
          if (rent > highestThreat) highestThreat = rent;
        }
        return max(220, min(650, highestThreat + 80));
    }
  }

  // Exact two-dice probabilities for the next ordinary move. Cards and
  // subsequent doubles are intentionally not predicted.
  double _expectedRisk(GameEngine game, int playerId) {
    final player = game.players[playerId];
    var risk = 0.0;
    for (var a = 1; a <= 6; a++) {
      for (var b = 1; b <= 6; b++) {
        final index = (player.position + a + b) % game.spaces.length;
        final tile = game.spaces[index];
        final owner = game.properties[index].ownerId;
        risk +=
            tile.tax +
            (owner != null && owner != playerId
                ? game.rentFor(index, a + b)
                : 0);
      }
    }
    return risk / 36;
  }

  bool _blocksSet(GameEngine game, int playerId, BoardSpace tile) {
    if (tile.group == null) return false;
    return game.players.any(
      (p) => !p.bankrupt && p.id != playerId && _completesSet(game, p.id, tile),
    );
  }

  double _titleValue(GameEngine game, int playerId, BoardSpace tile) {
    var multiplier = 1.0;
    if (_completesSet(game, playerId, tile)) multiplier += .65;
    if (_blocksSet(game, playerId, tile)) multiplier += .25;
    if (tile.group == ColorGroup.orange || tile.group == ColorGroup.red) {
      multiplier += .15;
    }
    if (tile.kind == SpaceKind.station || tile.kind == SpaceKind.utility) {
      final owned = game.spaces
          .where(
            (s) =>
                s.kind == tile.kind &&
                s.index != tile.index &&
                game.properties[s.index].ownerId == playerId,
          )
          .length;
      multiplier += .12 * owned;
    }
    return tile.price * multiplier;
  }

  double _landingWeight(GameEngine game, BoardSpace tile) {
    var weight = 0.0;
    for (final p in game.players) {
      if (p.bankrupt || p.id == game.currentPlayerId) continue;
      for (var a = 1; a <= 6; a++) {
        for (var b = 1; b <= 6; b++) {
          if ((p.position + a + b) % game.spaces.length == tile.index) {
            weight += 1 / 36;
          }
        }
      }
    }
    return .10 + weight;
  }

  double _buildValue(GameEngine game, BoardSpace tile) {
    final level = game.properties[tile.index].development;
    final current = level == 0 ? tile.rents[0] * 2 : tile.rents[level];
    return (tile.rents[level + 1] - current) *
        _landingWeight(game, tile) /
        tile.buildCost;
  }

  double _saleLoss(GameEngine game, BoardSpace tile) {
    final level = game.properties[tile.index].development;
    final previous = level == 1 ? tile.rents[0] * 2 : tile.rents[level - 1];
    return (tile.rents[level] - previous) *
        _landingWeight(game, tile) /
        tile.buildCost;
  }

  double _mortgageLoss(GameEngine game, BoardSpace tile) =>
      game.rentFor(tile.index, 7) * _landingWeight(game, tile) / tile.price;

  BotDecision? _unmortgageDecision(
    GameEngine game,
    int id,
    BotDifficulty difficulty,
  ) {
    if (difficulty != BotDifficulty.expert) return null;
    final cash = game.players[id].balance;
    final reserve = _reserve(game, id, difficulty);
    final candidates = game.spaces
        .where(
          (s) =>
              s.purchasable &&
              game.properties[s.index].ownerId == id &&
              game.properties[s.index].mortgaged &&
              cash - game.unmortgageCost(s.index) >= reserve,
        )
        .toList();
    candidates.sort(
      (a, b) => _titleValue(game, id, b).compareTo(_titleValue(game, id, a)),
    );
    return candidates.isEmpty
        ? null
        : BotDecision(BotAction.unmortgage, spaceIndex: candidates.first.index);
  }

  /// Recipient approval for the existing human-initiated trade UI.
  /// Does not mutate the engine or consent on behalf of a human.
  bool acceptsTrade(
    GameEngine game,
    TradeOffer offer,
    BotDifficulty difficulty,
  ) {
    try {
      game.validateTrade(offer);
    } on GameRuleException {
      return false;
    }
    final id = offer.toPlayerId;
    final cash = game.players[id].balance + offer.cashFrom - offer.cashTo;
    if (cash < _reserve(game, id, difficulty)) return false;
    double value(int index) => _titleValue(game, id, game.spaces[index]);
    final incoming =
        offer.cashFrom +
        offer.cardsFrom * 50 +
        offer.propertiesFrom.fold<double>(0, (sum, i) => sum + value(i));
    final outgoing =
        offer.cashTo +
        offer.cardsTo * 50 +
        offer.propertiesTo.fold<double>(0, (sum, i) => sum + value(i));
    if (difficulty == BotDifficulty.hard ||
        difficulty == BotDifficulty.expert) {
      if (offer.propertiesTo.any(
        (i) => _completesSet(game, offer.fromPlayerId, game.spaces[i]),
      ))
        return false;
    }
    return incoming >= outgoing;
  }

  bool _completesSet(GameEngine game, int ownerId, BoardSpace tile) {
    if (tile.group == null) return false;
    return BoardData.colorSet(tile.group!).every(
      (space) =>
          space.index == tile.index ||
          game.properties[space.index].ownerId == ownerId,
    );
  }

  int _groupPriority(BoardSpace s) {
    switch (s.group) {
      case ColorGroup.orange:
        return 18;
      case ColorGroup.red:
        return 17;
      case ColorGroup.yellow:
        return 13;
      case ColorGroup.green:
        return 12;
      case ColorGroup.pink:
        return 11;
      case ColorGroup.sky:
        return 10;
      case ColorGroup.navy:
        return 9;
      case ColorGroup.brown:
        return 8;
      case null:
        return 0;
    }
  }
}

// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:math';

import '../core/board_data.dart';
import '../engine/game_engine.dart';
import '../models/game_models.dart';

/// Local, deterministic AI policy. It never mutates the engine: the screen
/// submits a legal action to the same GameEngine API used by human players.
/// Pass a seeded Random to make simulations repeatable.
enum BotDifficulty { easy, medium, hard }

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
        if (difficulty == BotDifficulty.hard &&
            player.balance > _reserve(game, playerId, difficulty) + 50) {
          return const BotDecision(BotAction.payFine);
        }
        return const BotDecision(BotAction.jailRoll);
      case TurnPhase.purchase:
        return _purchaseDecision(game, playerId, difficulty);
      case TurnPhase.debt:
        return _debtDecision(game, playerId);
      case TurnPhase.complete:
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
        (completesSet && difficulty == BotDifficulty.hard ? 90 : reserve);
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
    if (difficulty == BotDifficulty.hard) {
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

  BotDecision _debtDecision(GameEngine game, int playerId) {
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
      buildings.sort((a, b) => b.buildCost.compareTo(a.buildCost));
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
      mortgages.sort((a, b) => b.price.compareTo(a.price));
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

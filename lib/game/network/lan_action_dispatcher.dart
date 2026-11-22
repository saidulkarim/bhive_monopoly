import 'dart:math';

import '../engine/game_engine.dart';
import '../models/game_models.dart';

/// Server-side allowlist. Network clients send *intent*, never cash, dice,
/// player identity, or an entire GameEngine. All commands are validated here.
class LanActionDispatcher {
  LanActionDispatcher({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  /// Returns roll results for an animated visual event, or null otherwise.
  DiceRoll? apply(
    GameEngine game,
    int actorId,
    String action, {
    int? index,
    int? amount,
  }) {
    if (actorId < 0 ||
        actorId >= game.players.length ||
        game.players[actorId].bankrupt) {
      throw const GameRuleException('Invalid or inactive player.');
    }
    if (game.phase == TurnPhase.gameOver) {
      throw const GameRuleException('This game is finished.');
    }
    final auctionAction = action == 'bid' || action == 'passBid';
    if (auctionAction) {
      if (game.phase != TurnPhase.auction ||
          game.auction!.bidderId != actorId) {
        throw const GameRuleException('It is not your auction bid.');
      }
    } else if (game.currentPlayerId != actorId) {
      throw const GameRuleException('Wait for your turn.');
    }
    switch (action) {
      case 'roll':
        final dice = DiceRoll(_random.nextInt(6) + 1, _random.nextInt(6) + 1);
        game.roll(dice.first, dice.second);
        return dice;
      case 'jailRoll':
        final jailDice = DiceRoll(
          _random.nextInt(6) + 1,
          _random.nextInt(6) + 1,
        );
        game.tryJailRoll(jailDice.first, jailDice.second);
        return jailDice;
      case 'payFine':
        game.payJailFine();
        return null;
      case 'useJailCard':
        game.useJailCard();
        return null;
      case 'buy':
        game.buyProperty();
        return null;
      case 'decline':
        game.declinePurchase();
        return null;
      case 'bid':
        if (amount == null) {
          throw const GameRuleException('A bid amount is required.');
        }
        game.bid(amount);
        return null;
      case 'passBid':
        game.passBid();
        return null;
      case 'endTurn':
        game.endTurn();
        return null;
      case 'build':
        game.build(_requireIndex(index));
        return null;
      case 'sellBuilding':
        game.sellBuilding(_requireIndex(index));
        return null;
      case 'mortgage':
        game.mortgage(_requireIndex(index));
        return null;
      case 'unmortgage':
        game.unmortgage(_requireIndex(index));
        return null;
      case 'bankrupt':
        game.declareBankruptcy();
        return null;
      default:
        throw const GameRuleException('Unsupported network action.');
    }
  }

  int _requireIndex(int? index) {
    if (index == null || index < 0 || index >= 40) {
      throw const GameRuleException('Invalid property index.');
    }
    return index;
  }
}

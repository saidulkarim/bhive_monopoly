import 'dart:math';

import 'package:monopoly/core/config/game_config.dart';
import 'package:monopoly/game/ai/bot_controller.dart';
import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/models/game_models.dart';
import 'package:monopoly/game/progression/match_progress.dart';
import 'package:monopoly/game/validation/game_snapshot_validator.dart';

/// Test-only driver: no widgets, animation delay, network or platform calls.
class AiSoakRunner {
  AiSoakRunner({
    required this.seed,
    required this.playerCount,
    required this.difficulty,
    this.maximumTurns,
  }) : game = GameEngine(
         playerNames: List.generate(playerCount, (i) => 'Bot ${i + 1}'),
         cardSeed: seed,
         maximumTurns: maximumTurns,
       ),
       _dice = Random(seed + 1),
       _bot = BotController(random: Random(seed + 2));

  final int seed;
  final int playerCount;
  final BotDifficulty difficulty;
  final int? maximumTurns;
  GameEngine game;
  final Random _dice;
  final BotController _bot;
  final MatchProgress _progress = MatchProgress();
  int _lastTrade = -100000;
  int actions = 0;
  int trades = 0;
  int roundTrips = 0;
  final actionCounts = <BotAction, int>{};

  bool get finished => game.phase == TurnPhase.gameOver;
  String get context =>
      'seed=$seed players=$playerCount difficulty=${difficulty.name} '
      'turn=${game.turnNumber} phase=${game.phase.name} action=$actions';

  void step() {
    if (finished) return;
    _progress.observe(game);
    final actor = game.phase == TurnPhase.auction
        ? game.auction!.bidderId
        : game.currentPlayerId;
    if (_progress.stagnant &&
        game.turnNumber - _lastTrade >= GameConfig.aiTradeCooldownTurns) {
      final offer = findReciprocalBotTrade(game, {
        for (final p in game.players) p.id,
      });
      if (offer != null) {
        game.acceptTrade(offer);
        _lastTrade = game.turnNumber;
        trades++;
        actions++;
        return;
      }
    }
    final decision = _bot.choose(game, playerId: actor, difficulty: difficulty);
    if (decision == null) throw StateError('No bot decision: $context');
    int die() => 1 + _dice.nextInt(6);
    switch (decision.action) {
      case BotAction.roll:
        game.roll(die(), die());
        break;
      case BotAction.jailRoll:
        game.tryJailRoll(die(), die());
        break;
      case BotAction.payFine:
        game.payJailFine();
        break;
      case BotAction.useJailCard:
        game.useJailCard();
        break;
      case BotAction.buy:
        game.buyProperty();
        break;
      case BotAction.auction:
        game.declinePurchase();
        break;
      case BotAction.bid:
        game.bid(decision.amount!);
        break;
      case BotAction.pass:
        game.passBid();
        break;
      case BotAction.build:
        game.build(decision.spaceIndex!);
        break;
      case BotAction.sellBuilding:
        game.sellBuilding(decision.spaceIndex!);
        break;
      case BotAction.mortgage:
        game.mortgage(decision.spaceIndex!);
        break;
      case BotAction.unmortgage:
        game.unmortgage(decision.spaceIndex!);
        break;
      case BotAction.bankrupt:
        game.declareBankruptcy();
        break;
      case BotAction.endTurn:
        game.endTurn();
        break;
    }
    actions++;
    actionCounts.update(decision.action, (n) => n + 1, ifAbsent: () => 1);
  }

  void validate() {
    GameSnapshotValidator.validateOffline(game.exportSave());
  }

  Map<String, dynamic> report() => {
    'seed': seed,
    'players': playerCount,
    'difficulty': difficulty.name,
    'turn': game.turnNumber,
    'actions': actions,
    'finished': finished,
    'winner': game.winnerId,
    'turnLimitWinner': game.finishedByTurnLimit,
    'trades': trades,
    'roundTrips': roundTrips,
    'actionCounts': {for (final e in actionCounts.entries) e.key.name: e.value},
  };
}

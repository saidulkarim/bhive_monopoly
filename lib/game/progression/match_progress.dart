import '../../core/config/game_config.dart';
import '../engine/game_engine.dart';
import '../models/game_models.dart';

/// Session-local observation of actual ownership, development and insolvency.
/// No game state mutation, background polling, or changes to the wire format.
class MatchProgress {
  String? _signature;
  int _lastChange = 0;
  int _lastNotice = -100000;
  int _lastTurn = -1;
  bool stagnant = false;

  bool observe(GameEngine game) {
    if (!GameConfig.deadlockDetectionEnabled ||
        game.phase == TurnPhase.gameOver) {
      stagnant = false;
      return false;
    }
    if (_lastTurn == game.turnNumber) return false;
    final signature = [
      for (final p in game.properties)
        '${p.ownerId}:${p.development}:${p.mortgaged}',
      for (final p in game.players) '${p.bankrupt}',
    ].join('|');
    if (_signature != signature || game.turnNumber < _lastTurn) {
      _signature = signature;
      _lastChange = game.turnNumber;
    }
    _lastTurn = game.turnNumber;
    final tiles = game.spaces.where((s) => s.purchasable).toList();
    final owned = tiles
        .where((s) => game.properties[s.index].ownerId != null)
        .length;
    stagnant =
        tiles.isNotEmpty &&
        game.turnNumber >= GameConfig.deadlockMinimumTurns &&
        game.turnNumber - _lastChange >= GameConfig.deadlockObservationTurns &&
        owned / tiles.length >= GameConfig.deadlockOwnedPropertyRatio &&
        game.players
            .where((p) => !p.bankrupt)
            .every((p) => p.balance >= GameConfig.aiMinimumCashForDeadlock);
    if (!stagnant ||
        game.turnNumber - _lastNotice <
            GameConfig.deadlockNotificationCooldownTurns) {
      return false;
    }
    _lastNotice = game.turnNumber;
    return true;
  }
}

/// A conservative reciprocal exchange: both bots complete a color set, neither
/// loses a complete set. Human recipients require explicit consent in UI.
TradeOffer? findReciprocalBotTrade(
  GameEngine game,
  Set<int> botIds, {
  Set<int>? recipientIds,
}) {
  if (!GameConfig.aiAutonomousTradingEnabled ||
      game.phase != TurnPhase.complete) {
    return null;
  }
  final a = game.currentPlayerId;
  if (!botIds.contains(a) || game.players[a].bankrupt) return null;
  bool completes(int owner, BoardSpace tile) =>
      tile.group != null &&
      game.spaces
          .where((s) => s.group == tile.group)
          .every(
            (s) =>
                s.index == tile.index ||
                game.properties[s.index].ownerId == owner,
          );
  for (final b in recipientIds ?? botIds) {
    if (b < 0 ||
        b >= game.players.length ||
        b == a ||
        game.players[b].bankrupt) {
      continue;
    }
    for (final incoming in game.spaces) {
      if (game.properties[incoming.index].ownerId != b ||
          !completes(a, incoming) ||
          game.ownsFullGroup(b, incoming.group!)) {
        continue;
      }
      for (final outgoing in game.spaces) {
        // A swap within the same group cannot complete both sets: each
        // recipient would lose the very property needed to complete it.
        if (outgoing.group == incoming.group ||
            game.properties[outgoing.index].ownerId != a ||
            !completes(b, outgoing) ||
            game.ownsFullGroup(a, outgoing.group!)) {
          continue;
        }
        final offer = TradeOffer(
          fromPlayerId: a,
          toPlayerId: b,
          propertiesFrom: [outgoing.index],
          propertiesTo: [incoming.index],
        );
        try {
          game.validateTrade(offer);
          return offer;
        } on GameRuleException {
          continue;
        }
      }
    }
  }
  return null;
}

import '../engine/game_engine.dart';
import '../models/game_models.dart';

/// A pending proposal is a request, not a bank transaction. Only accepting on
/// the host invokes the GameEngine. Client packets cannot set game balances.
class LanPendingTrade {
  const LanPendingTrade({required this.id, required this.offer});

  final int id;
  final TradeOffer offer;

  Map<String, dynamic> toWire() => <String, dynamic>{
    'id': id,
    'fromPlayerId': offer.fromPlayerId,
    'toPlayerId': offer.toPlayerId,
    'cashFrom': offer.cashFrom,
    'cashTo': offer.cashTo,
    'propertiesFrom': offer.propertiesFrom,
    'propertiesTo': offer.propertiesTo,
    'cardsFrom': offer.cardsFrom,
    'cardsTo': offer.cardsTo,
  };

  static LanPendingTrade fromWire(Map<String, dynamic> json) => LanPendingTrade(
    id: json['id'] as int,
    offer: TradeOffer(
      fromPlayerId: json['fromPlayerId'] as int,
      toPlayerId: json['toPlayerId'] as int,
      cashFrom: json['cashFrom'] as int,
      cashTo: json['cashTo'] as int,
      propertiesFrom: (json['propertiesFrom'] as List).cast<int>(),
      propertiesTo: (json['propertiesTo'] as List).cast<int>(),
      cardsFrom: json['cardsFrom'] as int,
      cardsTo: json['cardsTo'] as int,
    ),
  );
}

/// Pure Dart host-side trade state machine, independently unit testable.
class LanTradeCoordinator {
  LanPendingTrade? pending;
  int _sequence = 0;

  LanPendingTrade propose(GameEngine game, int actorId, TradeOffer offer) {
    if (pending != null) {
      throw const GameRuleException('Respond to the existing trade first.');
    }
    if (actorId != game.currentPlayerId || offer.fromPlayerId != actorId) {
      throw const GameRuleException(
        'Only the active player can offer a trade.',
      );
    }
    if (offer.propertiesFrom.isEmpty &&
        offer.propertiesTo.isEmpty &&
        offer.cashFrom == 0 &&
        offer.cashTo == 0 &&
        offer.cardsFrom == 0 &&
        offer.cardsTo == 0) {
      throw const GameRuleException('Trade must exchange something.');
    }
    game.validateTrade(offer);
    final trade = LanPendingTrade(id: ++_sequence, offer: offer);
    pending = trade;
    return trade;
  }

  void respond(
    GameEngine game,
    int actorId,
    int requestId, {
    required bool accept,
  }) {
    final current = pending;
    if (current == null || current.id != requestId) {
      throw const GameRuleException('Trade is no longer available.');
    }
    if (actorId != current.offer.toPlayerId) {
      throw const GameRuleException('Only the recipient can respond.');
    }
    if (!accept) {
      pending = null;
      return;
    }
    // Rechecks ownership, cash and building constraints at acceptance time.
    // In the current LAN flow all other actions are frozen while trade pending.
    try {
      game.acceptTrade(current.offer);
    } finally {
      pending = null; // Never leave room locked after invalidation.
    }
  }

  void cancel(int actorId, int requestId) {
    final current = pending;
    if (current == null || current.id != requestId) {
      throw const GameRuleException('Trade is no longer available.');
    }
    if (actorId != current.offer.fromPlayerId) {
      throw const GameRuleException('Only the proposer can cancel.');
    }
    pending = null;
  }

  void dismiss() => pending = null;
}

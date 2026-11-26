import '../../engine/game_engine.dart';
import '../../models/game_models.dart';

/// Existing trade rules are the sole authority on transfer eligibility.
bool canRequestProperty(GameEngine game, int buyer, int index) {
  if (index < 0 ||
      index >= game.spaces.length ||
      buyer < 0 ||
      buyer >= game.players.length) {
    return false;
  }
  final owner = game.properties[index].ownerId;
  if (owner == null || owner == buyer || game.players[buyer].balance <= 0) {
    return false;
  }
  try {
    game.validateTrade(propertyBuyOffer(buyer, owner, index, 1));
    return true;
  } on GameRuleException {
    return false;
  }
}

TradeOffer propertyBuyOffer(int buyer, int seller, int index, int price) {
  if (price <= 0) {
    throw const GameRuleException('Invalid trade amount or insufficient cash.');
  }
  return TradeOffer(
    fromPlayerId: buyer,
    toPlayerId: seller,
    cashFrom: price,
    propertiesTo: [index],
  );
}

bool completesPurchaseGroup(GameEngine game, int buyer, int index) {
  final group = game.spaces[index].group;
  return group != null &&
      game.spaces
          .where((s) => s.group == group && s.index != index)
          .every((s) => game.properties[s.index].ownerId == buyer);
}

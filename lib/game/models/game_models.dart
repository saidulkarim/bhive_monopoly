/// Domain models for bHiVE Monopoly. No Flutter imports: rules can be tested
/// independently of the Android/web user interface.
enum SpaceKind {
  go,
  street,
  station,
  utility,
  chance,
  community,
  tax,
  jail,
  freeParking,
  goToJail,
}

enum ColorGroup { brown, sky, pink, orange, red, yellow, green, navy }

enum TurnPhase {
  roll,
  jailDecision,
  purchase,
  auction,
  debt,
  complete,
  gameOver,
}

class BoardSpace {
  const BoardSpace({
    required this.index,
    required this.name,
    required this.kind,
    this.group,
    this.price = 0,
    this.buildCost = 0,
    this.rents = const [],
    this.tax = 0,
  });

  final int index;
  final String name;
  final SpaceKind kind;
  final ColorGroup? group;
  final int price;
  final int buildCost;

  /// Street rent: empty, 1 house, 2, 3, 4 houses, hotel.
  final List<int> rents;
  final int tax;

  bool get purchasable =>
      kind == SpaceKind.street ||
      kind == SpaceKind.station ||
      kind == SpaceKind.utility;
}

class PlayerState {
  PlayerState({required this.id, required this.name, int? colorIndex})
    : colorIndex = colorIndex ?? id;

  final int id;
  final String name;
  int colorIndex;
  int balance = 1500;
  int position = 0;
  bool inJail = false;
  int jailFailedRolls = 0;

  /// true: Fortune deck; false: City Chest. Origin is preserved when used.
  final List<bool> jailCardOrigins = <bool>[];
  int get getOutOfJailCards => jailCardOrigins.length;
  bool bankrupt = false;
}

class PropertyState {
  int? ownerId;

  /// 0-4 = houses; 5 = hotel.
  int development = 0;
  bool mortgaged = false;
}

class DiceRoll {
  const DiceRoll(this.first, this.second);
  final int first;
  final int second;
  int get sum => first + second;
  bool get doubles => first == second;
}

class AuctionState {
  AuctionState({required this.spaceIndex, required this.bidderId});

  final int spaceIndex;
  int bidderId;
  int highBid = 0;
  int? highestBidderId;
  final Set<int> passed = <int>{};
  int get minimumBid => highBid == 0 ? 10 : highBid + 10;
}

class TradeOffer {
  const TradeOffer({
    required this.fromPlayerId,
    required this.toPlayerId,
    this.cashFrom = 0,
    this.cashTo = 0,
    this.propertiesFrom = const <int>[],
    this.propertiesTo = const <int>[],
    this.cardsFrom = 0,
    this.cardsTo = 0,
  });
  final int fromPlayerId;
  final int toPlayerId;
  final int cashFrom;
  final int cashTo;
  final List<int> propertiesFrom;
  final List<int> propertiesTo;
  final int cardsFrom;
  final int cardsTo;
}

class GameRuleException implements Exception {
  const GameRuleException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Agreed score for turn-limited matches: printed title value less the
/// redemption cost of a mortgage, plus half the building investment.
int propertyNetWorth(BoardSpace tile, int development, bool mortgaged) {
  final redemption = mortgaged ? ((tile.price ~/ 2) * 11 + 9) ~/ 10 : 0;
  return tile.price - redemption + (tile.buildCost * development ~/ 2);
}

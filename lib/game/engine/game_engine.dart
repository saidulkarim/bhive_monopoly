import 'dart:math';

import '../core/board_data.dart';
import '../models/game_models.dart';

/// Deterministic, Flutter-independent turn engine. Roll values are injected by
/// callers so gameplay can be unit-tested without relying on random dice.
class GameEngine {
  GameEngine({required List<String> playerNames, int? cardSeed})
    : players = List<PlayerState>.generate(
        playerNames.length,
        (i) => PlayerState(id: i, name: playerNames[i].trim()),
      ),
      properties = List<PropertyState>.generate(40, (_) => PropertyState()) {
    if (players.length < 2 ||
        players.length > 6 ||
        players.any((p) => p.name.isEmpty)) {
      throw const GameRuleException('Choose 2–6 players with valid names.');
    }
    final random = Random(cardSeed);
    _chanceDeck = List<int>.generate(_chance.length, (i) => i)..shuffle(random);
    _communityDeck = List<int>.generate(_community.length, (i) => i)
      ..shuffle(random);
    log.add('Game started — ${players.first.name} rolls first.');
  }

  final List<PlayerState> players;
  final List<PropertyState> properties;
  final List<String> log = <String>[];
  late final List<int> _chanceDeck;
  late final List<int> _communityDeck;

  int currentPlayerId = 0;
  int turnNumber = 1;
  TurnPhase phase = TurnPhase.roll;
  int? pendingPurchaseIndex;
  AuctionState? auction;
  DiceRoll? lastRoll;
  int? winnerId;
  int? debtCreditorId;
  final Map<int, int?> _pendingDebts = <int, int?>{};
  TurnPhase _resumeAfterDebt = TurnPhase.complete;
  bool _extraRoll = false;
  int _consecutiveDoubles = 0;

  static const int startingCash = 1500;
  static const int goBonus = 200;
  static const int bankHouseLimit = 32;
  static const int bankHotelLimit = 12;

  PlayerState get currentPlayer => players[currentPlayerId];
  List<BoardSpace> get spaces => BoardData.spaces;

  int get housesInUse => properties.fold<int>(
    0,
    (sum, p) => sum + (p.development <= 4 ? p.development : 0),
  );
  int get hotelsInUse => properties.where((p) => p.development == 5).length;
  int get bankHouses => bankHouseLimit - housesInUse;
  int get bankHotels => bankHotelLimit - hotelsInUse;

  bool ownsFullGroup(int ownerId, ColorGroup group) => BoardData.colorSet(
    group,
  ).every((space) => properties[space.index].ownerId == ownerId);

  void _require(bool condition, String message) {
    if (!condition) throw GameRuleException(message);
  }

  void _requirePhase(TurnPhase expected) =>
      _require(phase == expected, 'Action unavailable during ${phase.name}.');

  void _log(String value) {
    log.insert(0, value);
    if (log.length > 70) log.removeLast();
  }

  void roll(int first, int second) {
    _requirePhase(TurnPhase.roll);
    _validateDice(first, second);
    final dice = DiceRoll(first, second);
    lastRoll = dice;
    _consecutiveDoubles = dice.doubles ? _consecutiveDoubles + 1 : 0;
    _extraRoll = dice.doubles;
    _log('${currentPlayer.name} rolled $first + $second = ${dice.sum}.');
    if (_consecutiveDoubles >= 3) {
      _sendToJail('Three doubles in a row');
      _endCurrentTurn();
      return;
    }
    _move(dice.sum);
  }

  void _validateDice(int first, int second) => _require(
    first >= 1 && first <= 6 && second >= 1 && second <= 6,
    'Both dice must be between 1 and 6.',
  );

  void _move(int steps) {
    final old = currentPlayer.position;
    final rawPosition = old + steps;
    if (rawPosition >= 40) {
      currentPlayer.balance += goBonus;
      _log('${currentPlayer.name} passed START and earned 200.');
    }
    currentPlayer.position = rawPosition % 40;
    _land();
  }

  void _jump(int destination, {bool awardGo = true}) {
    final old = currentPlayer.position;
    if (awardGo && destination < old) {
      currentPlayer.balance += goBonus;
      _log('${currentPlayer.name} collected 200 for passing START.');
    }
    currentPlayer.position = destination;
    _land();
  }

  void _land() {
    final tile = spaces[currentPlayer.position];
    _log('${currentPlayer.name} landed on ${tile.name}.');
    switch (tile.kind) {
      case SpaceKind.goToJail:
        _sendToJail('Landed on Go To Jail');
        _finishLanding();
        return;
      case SpaceKind.tax:
        _charge(currentPlayerId, tile.tax);
        _log('Tax paid: ${tile.tax}.');
        _finishLanding();
        return;
      case SpaceKind.street:
      case SpaceKind.station:
      case SpaceKind.utility:
        final owner = properties[tile.index].ownerId;
        if (owner == null) {
          pendingPurchaseIndex = tile.index;
          phase = TurnPhase.purchase;
        } else {
          if (owner != currentPlayerId && !properties[tile.index].mortgaged) {
            final rent = rentFor(tile.index, lastRoll?.sum ?? 7);
            _charge(currentPlayerId, rent, creditorId: owner);
            _log(
              '${currentPlayer.name} paid $rent rent to ${players[owner].name}.',
            );
          }
          _finishLanding();
        }
        return;
      case SpaceKind.chance:
      case SpaceKind.community:
        _drawCard(tile.kind == SpaceKind.chance);
        return;
      case SpaceKind.go:
      case SpaceKind.jail:
      case SpaceKind.freeParking:
        _finishLanding();
        return;
    }
  }

  int rentFor(int tileIndex, int diceSum) {
    _validateSpace(tileIndex);
    final tile = spaces[tileIndex];
    final state = properties[tileIndex];
    if (!tile.purchasable || state.mortgaged || state.ownerId == null) {
      return 0;
    }
    if (tile.kind == SpaceKind.street) {
      if (state.development > 0) return tile.rents[state.development];
      final complete = ownsFullGroup(state.ownerId!, tile.group!);
      return tile.rents.first * (complete ? 2 : 1);
    }
    if (tile.kind == SpaceKind.station) {
      final count = spaces
          .where(
            (s) =>
                s.kind == SpaceKind.station &&
                properties[s.index].ownerId == state.ownerId,
          )
          .length;
      return 25 * (1 << (count - 1));
    }
    final utilities = spaces
        .where(
          (s) =>
              s.kind == SpaceKind.utility &&
              properties[s.index].ownerId == state.ownerId,
        )
        .length;
    return (utilities == 2 ? 10 : 4) * diceSum;
  }

  void buyProperty() {
    _requirePhase(TurnPhase.purchase);
    final index = pendingPurchaseIndex!;
    final tile = spaces[index];
    _require(properties[index].ownerId == null, 'Property already owned.');
    _require(
      currentPlayer.balance >= tile.price,
      'Not enough cash. Start an auction.',
    );
    currentPlayer.balance -= tile.price;
    properties[index].ownerId = currentPlayerId;
    _log('${currentPlayer.name} purchased ${tile.name} for ${tile.price}.');
    pendingPurchaseIndex = null;
    _finishLanding();
  }

  void declinePurchase() {
    _requirePhase(TurnPhase.purchase);
    auction = AuctionState(
      spaceIndex: pendingPurchaseIndex!,
      bidderId: currentPlayerId,
    );
    _log('${currentPlayer.name} declined purchase — auction opened.');
    pendingPurchaseIndex = null;
    phase = TurnPhase.auction;
  }

  /// Bidder must offer the minimum or more, and have enough available cash.
  void bid(int amount) {
    _requirePhase(TurnPhase.auction);
    final a = auction!;
    _require(amount >= a.minimumBid, 'Minimum bid: ${a.minimumBid}.');
    _require(
      players[a.bidderId].balance >= amount,
      'Bidder cannot afford that bid.',
    );
    a.highBid = amount;
    a.highestBidderId = a.bidderId;
    _log('${players[a.bidderId].name} bids $amount.');
    _advanceAuction(a.bidderId);
  }

  void passBid() {
    _requirePhase(TurnPhase.auction);
    final a = auction!;
    a.passed.add(a.bidderId);
    _log('${players[a.bidderId].name} passed.');
    _advanceAuction(a.bidderId);
  }

  void _advanceAuction(int previousBidder) {
    final a = auction!;
    // The standing high bidder remains the winner unless outbid; do not
    // request another bid from them while their high bid still stands.
    final contenders = players
        .where(
          (p) =>
              !p.bankrupt &&
              !a.passed.contains(p.id) &&
              p.id != a.highestBidderId &&
              p.balance >= a.minimumBid,
        )
        .toList();
    if (contenders.isEmpty) {
      final winner = a.highestBidderId;
      if (winner == null) {
        _log('No bids — ${spaces[a.spaceIndex].name} stays with the bank.');
      } else {
        properties[a.spaceIndex].ownerId = winner;
        players[winner].balance -= a.highBid;
        _log(
          '${players[winner].name} won ${spaces[a.spaceIndex].name} for ${a.highBid}.',
        );
      }
      auction = null;
      _finishLanding();
      return;
    }
    for (var step = 1; step <= players.length; step++) {
      final candidate = (previousBidder + step) % players.length;
      if (contenders.any((p) => p.id == candidate)) {
        a.bidderId = candidate;
        return;
      }
    }
  }

  /// Jail turns are strictly separated from regular doubles/extra-turn rules.
  void payJailFine() {
    _requirePhase(TurnPhase.jailDecision);
    _charge(currentPlayerId, 50);
    _releaseFromJail();
    if (currentPlayer.balance < 0) {
      _resumeAfterDebt = TurnPhase.roll;
      phase = TurnPhase.debt;
    } else {
      phase = TurnPhase.roll;
    }
    _log('${currentPlayer.name} paid 50 to leave Jail.');
  }

  void useJailCard() {
    _requirePhase(TurnPhase.jailDecision);
    _require(currentPlayer.getOutOfJailCards > 0, 'No jail release card.');
    final fromChance = currentPlayer.jailCardOrigins.removeLast();
    // Return a used card to its correct original deck.
    if (fromChance) {
      _chanceDeck.add(2);
    } else {
      _communityDeck.add(3);
    }
    _releaseFromJail();
    phase = TurnPhase.roll;
    _log('${currentPlayer.name} used a Get Out of Jail card.');
  }

  void tryJailRoll(int first, int second) {
    _requirePhase(TurnPhase.jailDecision);
    _validateDice(first, second);
    final dice = DiceRoll(first, second);
    lastRoll = dice;
    _extraRoll = false; // Jail doubles never award a bonus roll.
    _consecutiveDoubles = 0;
    if (dice.doubles) {
      _releaseFromJail();
      _log('${currentPlayer.name} rolled doubles and left Jail!');
      _move(dice.sum);
      return;
    }
    currentPlayer.jailFailedRolls++;
    _log('Jail attempt ${currentPlayer.jailFailedRolls}/3 failed.');
    if (currentPlayer.jailFailedRolls == 3) {
      _charge(currentPlayerId, 50);
      _releaseFromJail();
      _log('${currentPlayer.name} paid 50 on the third failed attempt.');
      _move(dice.sum);
    } else {
      phase = TurnPhase.complete;
    }
  }

  void _releaseFromJail() {
    currentPlayer.inJail = false;
    currentPlayer.jailFailedRolls = 0;
  }

  void _sendToJail(String reason) {
    currentPlayer.position = 10;
    currentPlayer.inJail = true;
    currentPlayer.jailFailedRolls = 0;
    _extraRoll = false;
    _consecutiveDoubles = 0;
    _log('${currentPlayer.name} sent to Jail ($reason).');
  }

  void _charge(int debtorId, int amount, {int? creditorId}) {
    _require(amount >= 0, 'Invalid payment amount.');
    players[debtorId].balance -= amount;
    if (creditorId != null) players[creditorId].balance += amount;
    if (players[debtorId].balance < 0) {
      _pendingDebts[debtorId] = creditorId;
      if (debtorId == currentPlayerId) debtCreditorId = creditorId;
    } else {
      _pendingDebts.remove(debtorId);
    }
  }

  void _finishLanding() {
    final nextPhase = _extraRoll && !currentPlayer.inJail
        ? TurnPhase.roll
        : TurnPhase.complete;
    if (currentPlayer.balance < 0) {
      _resumeAfterDebt = nextPhase;
      phase = TurnPhase.debt;
      _log('${currentPlayer.name} must raise funds or declare bankruptcy.');
    } else {
      phase = nextPhase;
      debtCreditorId = null;
      _pendingDebts.remove(currentPlayerId);
    }
  }

  void _checkSolvency() {
    if (phase == TurnPhase.debt && currentPlayer.balance >= 0) {
      phase = _resumeAfterDebt;
      debtCreditorId = null;
      _pendingDebts.remove(currentPlayerId);
      _log('${currentPlayer.name} resolved their debt.');
    }
  }

  void endTurn() {
    _requirePhase(TurnPhase.complete);
    _endCurrentTurn();
  }

  void _endCurrentTurn() {
    if (players.where((p) => !p.bankrupt).length == 1) {
      _updateWinner();
      return;
    }
    do {
      currentPlayerId = (currentPlayerId + 1) % players.length;
    } while (currentPlayer.bankrupt);
    turnNumber++;
    lastRoll = null;
    pendingPurchaseIndex = null;
    auction = null;
    _extraRoll = false;
    _consecutiveDoubles = 0;
    debtCreditorId = _pendingDebts[currentPlayerId];
    _resumeAfterDebt = currentPlayer.inJail
        ? TurnPhase.jailDecision
        : TurnPhase.roll;
    phase = currentPlayer.balance < 0 ? TurnPhase.debt : _resumeAfterDebt;
    _log('${currentPlayer.name}’s turn.');
  }

  void _validateSpace(int index) =>
      _require(index >= 0 && index < 40, 'Invalid board space.');

  void _requireOwner(int index) {
    _validateSpace(index);
    _require(spaces[index].purchasable, 'This tile cannot be managed.');
    _require(
      properties[index].ownerId == currentPlayerId,
      'You do not own this property.',
    );
    _require(
      phase != TurnPhase.auction && phase != TurnPhase.gameOver,
      'Property management is unavailable now.',
    );
  }

  void build(int index) {
    _requireOwner(index);
    _require(phase != TurnPhase.debt, 'Resolve your debt first.');
    final tile = spaces[index];
    final state = properties[index];
    _require(tile.kind == SpaceKind.street, 'Only streets can have buildings.');
    _require(state.development < 5, 'Property already has a hotel.');
    _require(
      ownsFullGroup(currentPlayerId, tile.group!),
      'Own the complete color group to build.',
    );
    final group = BoardData.colorSet(tile.group!);
    _require(
      group.every((t) => !properties[t.index].mortgaged),
      'Unmortgage every property in this group first.',
    );
    final minimum = group
        .map((t) => properties[t.index].development)
        .reduce(min);
    _require(state.development == minimum, 'Build evenly across the group.');
    _require(currentPlayer.balance >= tile.buildCost, 'Not enough cash.');
    if (state.development == 4) {
      _require(bankHotels > 0, 'Bank has no available hotels.');
    } else {
      _require(bankHouses > 0, 'Bank has no available houses.');
    }
    currentPlayer.balance -= tile.buildCost;
    state.development++;
    _log('Built on ${tile.name} for ${tile.buildCost}.');
  }

  void sellBuilding(int index) {
    _requireOwner(index);
    final tile = spaces[index];
    final state = properties[index];
    _require(
      tile.kind == SpaceKind.street && state.development > 0,
      'No building to sell.',
    );
    final group = BoardData.colorSet(tile.group!);
    final maxLevel = group
        .map((t) => properties[t.index].development)
        .reduce(max);
    _require(
      state.development == maxLevel,
      'Sell buildings evenly across the color group.',
    );
    if (state.development == 5) {
      _require(
        bankHouses >= 4,
        'Bank must have 4 houses to exchange for this hotel.',
      );
    }
    state.development--;
    currentPlayer.balance += tile.buildCost ~/ 2;
    _log('Sold a building at ${tile.name} for ${tile.buildCost ~/ 2}.');
    _checkSolvency();
  }

  void mortgage(int index) {
    _requireOwner(index);
    final tile = spaces[index];
    final state = properties[index];
    _require(!state.mortgaged, 'Already mortgaged.');
    _require(state.development == 0, 'Sell buildings first.');
    if (tile.group != null) {
      _require(
        BoardData.colorSet(
          tile.group!,
        ).every((s) => properties[s.index].development == 0),
        'Sell every building in the color group first.',
      );
    }
    state.mortgaged = true;
    currentPlayer.balance += tile.price ~/ 2;
    _log('${tile.name} mortgaged for ${tile.price ~/ 2}.');
    _checkSolvency();
  }

  int unmortgageCost(int index) => ((spaces[index].price ~/ 2) * 11 + 9) ~/ 10;

  void unmortgage(int index) {
    _requireOwner(index);
    _require(phase != TurnPhase.debt, 'Resolve your debt first.');
    final state = properties[index];
    _require(state.mortgaged, 'This property is not mortgaged.');
    final cost = unmortgageCost(index);
    _require(currentPlayer.balance >= cost, 'Not enough cash to unmortgage.');
    currentPlayer.balance -= cost;
    state.mortgaged = false;
    _log('${spaces[index].name} unmortgaged for $cost.');
  }

  /// Basic two-party exchange; both parties must explicitly agree in the UI.
  /// Developed and mortgaged properties are not eligible for this phase.
  void validateTrade(TradeOffer offer) {
    _require(
      phase == TurnPhase.roll || phase == TurnPhase.complete,
      'Trades are allowed between rolls.',
    );
    _require(
      offer.fromPlayerId != offer.toPlayerId,
      'Trade requires two different players.',
    );
    _require(
      offer.fromPlayerId >= 0 &&
          offer.fromPlayerId < players.length &&
          offer.toPlayerId >= 0 &&
          offer.toPlayerId < players.length,
      'Invalid player.',
    );
    final a = players[offer.fromPlayerId];
    final b = players[offer.toPlayerId];
    _require(!a.bankrupt && !b.bankrupt, 'Bankrupt players cannot trade.');
    _require(
      offer.cashFrom >= 0 &&
          offer.cashTo >= 0 &&
          a.balance >= offer.cashFrom &&
          b.balance >= offer.cashTo,
      'Invalid trade amount or insufficient cash.',
    );
    _require(
      offer.cardsFrom >= 0 &&
          offer.cardsTo >= 0 &&
          offer.cardsFrom <= a.getOutOfJailCards &&
          offer.cardsTo <= b.getOutOfJailCards,
      'Insufficient jail cards.',
    );
    final indices = <int>{...offer.propertiesFrom, ...offer.propertiesTo};
    _require(
      indices.length == offer.propertiesFrom.length + offer.propertiesTo.length,
      'Duplicate tile in trade.',
    );
    for (final i in offer.propertiesFrom) {
      _validateTransfer(i, a.id);
    }
    for (final i in offer.propertiesTo) {
      _validateTransfer(i, b.id);
    }
  }

  /// Call only after the recipient has approved the validated offer.
  void acceptTrade(TradeOffer offer) {
    validateTrade(offer);
    final a = players[offer.fromPlayerId];
    final b = players[offer.toPlayerId];
    a.balance += offer.cashTo - offer.cashFrom;
    b.balance += offer.cashFrom - offer.cashTo;
    for (var n = 0; n < offer.cardsFrom; n++) {
      b.jailCardOrigins.add(a.jailCardOrigins.removeLast());
    }
    for (var n = 0; n < offer.cardsTo; n++) {
      a.jailCardOrigins.add(b.jailCardOrigins.removeLast());
    }
    for (final i in offer.propertiesFrom) {
      properties[i].ownerId = b.id;
    }
    for (final i in offer.propertiesTo) {
      properties[i].ownerId = a.id;
    }
    _log('${a.name} and ${b.name} completed a trade.');
  }

  void _validateTransfer(int index, int ownerId) {
    _validateSpace(index);
    final tile = spaces[index];
    _require(
      tile.purchasable && properties[index].ownerId == ownerId,
      'Trade property is not owned by the sender.',
    );
    _require(!properties[index].mortgaged, 'Unmortgage before trading.');
    if (tile.group != null) {
      _require(
        BoardData.colorSet(
          tile.group!,
        ).every((t) => properties[t.index].development == 0),
        'Sell every building in the color group before trading.',
      );
    }
  }

  void declareBankruptcy() {
    _requirePhase(TurnPhase.debt);
    final loser = currentPlayer;
    final creditor = debtCreditorId;
    for (var i = 0; i < properties.length; i++) {
      final state = properties[i];
      if (state.ownerId == loser.id) {
        state.ownerId = creditor;
        if (creditor == null) {
          state.development = 0;
          state.mortgaged = false;
        }
      }
    }
    if (creditor != null) {
      players[creditor].jailCardOrigins.addAll(loser.jailCardOrigins);
    } else {
      // Bank-debt bankruptcy returns held release cards to the decks.
      for (final fromChance in loser.jailCardOrigins) {
        if (fromChance) {
          _chanceDeck.add(2);
        } else {
          _communityDeck.add(3);
        }
      }
    }
    loser.jailCardOrigins.clear();
    _pendingDebts.remove(loser.id);
    loser.bankrupt = true;
    loser.inJail = false;
    _log('${loser.name} declared bankruptcy.');
    if (players.where((p) => !p.bankrupt).length == 1) {
      _updateWinner();
    } else {
      _endCurrentTurn();
    }
  }

  void _updateWinner() {
    winnerId = players.firstWhere((p) => !p.bankrupt).id;
    phase = TurnPhase.gameOver;
    _log('${players[winnerId!].name} wins bHiVE Monopoly!');
  }

  // Cards: monetary changes, movement, jail, and release-from-jail.
  // Draw from shuffled cyclic decks. The release card leaves the deck until used.
  static const List<_Card> _chance = <_Card>[
    _Card('Advance to START. Collect 200.', _CardType.move, 0),
    _Card('Visit Royal Crescent.', _CardType.move, 24),
    _Card('Get Out of Jail Free.', _CardType.jailFree, 0),
    _Card('Pay an express delivery fee of 50.', _CardType.money, -50),
    _Card('Bank dividend: collect 50.', _CardType.money, 50),
    _Card('Go directly to Jail.', _CardType.jail, 0),
    _Card(
      'Make city repairs: pay 25 per house and 100 per hotel.',
      _CardType.repairs,
      0,
    ),
    _Card('Go back three spaces.', _CardType.back, 3),
    _Card('A lucky investment pays 150.', _CardType.money, 150),
    _Card('Pay each other player 50.', _CardType.payEach, 50),
    _Card('Travel to Central Station.', _CardType.move, 5),
    _Card('Traffic fine: pay 15.', _CardType.money, -15),
  ];

  static const List<_Card> _community = <_Card>[
    _Card('Advance to START. Collect 200.', _CardType.move, 0),
    _Card('Receive 200 in city grants.', _CardType.money, 200),
    _Card('Health clinic fee: pay 50.', _CardType.money, -50),
    _Card('Get Out of Jail Free.', _CardType.jailFree, 0),
    _Card('Income tax refund: collect 20.', _CardType.money, 20),
    _Card('Go directly to Jail.', _CardType.jail, 0),
    _Card('Festival award: collect 100.', _CardType.money, 100),
    _Card('School fee: pay 50.', _CardType.money, -50),
    _Card('Collect 10 from each player.', _CardType.collectEach, 10),
    _Card('Community support: collect 25.', _CardType.money, 25),
    _Card(
      'Building maintenance: pay 40 per house, 115 per hotel.',
      _CardType.repairsHigh,
      0,
    ),
    _Card('Small lottery prize: collect 10.', _CardType.money, 10),
  ];

  void _drawCard(bool fromChance) {
    final deck = fromChance ? _chanceDeck : _communityDeck;
    final cards = fromChance ? _chance : _community;
    if (deck.isEmpty) {
      _log('Deck is empty.');
      _finishLanding();
      return;
    }
    final index = deck.removeAt(0);
    final card = cards[index];
    if (card.kind != _CardType.jailFree) deck.add(index);
    _log('${fromChance ? 'Fortune' : 'City Chest'}: ${card.title}');
    switch (card.kind) {
      case _CardType.money:
        if (card.value >= 0) {
          currentPlayer.balance += card.value;
        } else {
          _charge(currentPlayerId, -card.value);
        }
        _finishLanding();
        return;
      case _CardType.move:
        _jump(card.value);
        return;
      case _CardType.jail:
        _sendToJail('Event card');
        _finishLanding();
        return;
      case _CardType.jailFree:
        currentPlayer.jailCardOrigins.add(fromChance);
        _finishLanding();
        return;
      case _CardType.back:
        _jump((currentPlayer.position - card.value + 40) % 40, awardGo: false);
        return;
      case _CardType.payEach:
        for (final p in players) {
          if (!p.bankrupt && p.id != currentPlayerId) {
            _charge(currentPlayerId, card.value, creditorId: p.id);
          }
        }
        _finishLanding();
        return;
      case _CardType.collectEach:
        for (final p in players) {
          if (!p.bankrupt && p.id != currentPlayerId) {
            _charge(p.id, card.value, creditorId: currentPlayerId);
          }
        }
        _finishLanding();
        return;
      case _CardType.repairs:
      case _CardType.repairsHigh:
        final houseFee = card.kind == _CardType.repairs ? 25 : 40;
        final hotelFee = card.kind == _CardType.repairs ? 100 : 115;
        var amount = 0;
        for (var i = 0; i < 40; i++) {
          if (properties[i].ownerId != currentPlayerId) continue;
          final level = properties[i].development;
          amount += level == 5 ? hotelFee : level * houseFee;
        }
        _charge(currentPlayerId, amount);
        _finishLanding();
        return;
    }
  }

  /// Full, private offline checkpoint. Unlike [LanGameCodec], it includes
  /// turn internals, card decks and debt continuation, so it can resume play.
  /// Treat input as untrusted local data; validate before using it.
  Map<String, dynamic> exportSave() => <String, dynamic>{
    'schema': 1,
    'players': <Map<String, dynamic>>[
      for (final p in players)
        <String, dynamic>{
          'name': p.name,
          'balance': p.balance,
          'position': p.position,
          'inJail': p.inJail,
          'jailFailedRolls': p.jailFailedRolls,
          'jailCardOrigins': p.jailCardOrigins.toList(),
          'bankrupt': p.bankrupt,
        },
    ],
    'properties': <Map<String, dynamic>>[
      for (final state in properties)
        <String, dynamic>{
          'ownerId': state.ownerId,
          'development': state.development,
          'mortgaged': state.mortgaged,
        },
    ],
    'currentPlayerId': currentPlayerId,
    'turnNumber': turnNumber,
    'phase': phase.name,
    'pendingPurchaseIndex': pendingPurchaseIndex,
    'auction': auction == null
        ? null
        : <String, dynamic>{
            'spaceIndex': auction!.spaceIndex,
            'bidderId': auction!.bidderId,
            'highBid': auction!.highBid,
            'highestBidderId': auction!.highestBidderId,
            'passed': auction!.passed.toList(),
          },
    'lastRoll': lastRoll == null
        ? null
        : <String, int>{'first': lastRoll!.first, 'second': lastRoll!.second},
    'winnerId': winnerId,
    'debtCreditorId': debtCreditorId,
    'pendingDebts': [
      for (final entry in _pendingDebts.entries)
        <String, dynamic>{'playerId': entry.key, 'creditorId': entry.value},
    ],
    'resumeAfterDebt': _resumeAfterDebt.name,
    'extraRoll': _extraRoll,
    'consecutiveDoubles': _consecutiveDoubles,
    'chanceDeck': _chanceDeck.toList(),
    'communityDeck': _communityDeck.toList(),
    'log': log.toList(),
  };

  static GameEngine importSave(Map<String, dynamic> json) {
    try {
      if (json['schema'] != 1) {
        throw const FormatException('Unsupported saved game version.');
      }
      final playerData = (json['players'] as List).cast<Map<String, dynamic>>();
      final propertyData = (json['properties'] as List)
          .cast<Map<String, dynamic>>();
      if (playerData.length < 2 ||
          playerData.length > 6 ||
          propertyData.length != 40) {
        throw const FormatException('Invalid player or board count.');
      }
      final game = GameEngine(
        playerNames: playerData.map((p) => p['name'] as String).toList(),
      );
      bool validPlayerId(int? id) =>
          id == null || (id >= 0 && id < game.players.length);
      for (var i = 0; i < game.players.length; i++) {
        final wire = playerData[i];
        final p = game.players[i];
        p.balance = wire['balance'] as int;
        p.position = wire['position'] as int;
        p.inJail = wire['inJail'] as bool;
        p.jailFailedRolls = wire['jailFailedRolls'] as int;
        p.bankrupt = wire['bankrupt'] as bool;
        p.jailCardOrigins
          ..clear()
          ..addAll((wire['jailCardOrigins'] as List).cast<bool>());
        if (p.position < 0 ||
            p.position >= 40 ||
            p.jailFailedRolls < 0 ||
            p.jailFailedRolls > 3) {
          throw const FormatException('Invalid saved player state.');
        }
      }
      for (var i = 0; i < game.properties.length; i++) {
        final wire = propertyData[i];
        final state = game.properties[i];
        state.ownerId = wire['ownerId'] as int?;
        state.development = wire['development'] as int;
        state.mortgaged = wire['mortgaged'] as bool;
        if (!validPlayerId(state.ownerId) ||
            state.development < 0 ||
            state.development > 5 ||
            (state.mortgaged && state.development != 0) ||
            (state.ownerId == null &&
                (state.mortgaged || state.development > 0))) {
          throw const FormatException('Invalid saved property state.');
        }
      }
      game.currentPlayerId = json['currentPlayerId'] as int;
      game.turnNumber = json['turnNumber'] as int;
      game.phase = TurnPhase.values.byName(json['phase'] as String);
      game.pendingPurchaseIndex = json['pendingPurchaseIndex'] as int?;
      game.winnerId = json['winnerId'] as int?;
      game.debtCreditorId = json['debtCreditorId'] as int?;
      game._resumeAfterDebt = TurnPhase.values.byName(
        json['resumeAfterDebt'] as String,
      );
      game._extraRoll = json['extraRoll'] as bool;
      game._consecutiveDoubles = json['consecutiveDoubles'] as int;
      if (!validPlayerId(game.currentPlayerId) ||
          !validPlayerId(game.winnerId) ||
          !validPlayerId(game.debtCreditorId) ||
          game.turnNumber < 1 ||
          game._consecutiveDoubles < 0 ||
          game._consecutiveDoubles > 2 ||
          (game.pendingPurchaseIndex != null &&
              (game.pendingPurchaseIndex! < 0 ||
                  game.pendingPurchaseIndex! >= 40))) {
        throw const FormatException('Invalid saved turn state.');
      }
      final auctionJson = json['auction'];
      if (auctionJson != null) {
        final wire = auctionJson as Map<String, dynamic>;
        final a = AuctionState(
          spaceIndex: wire['spaceIndex'] as int,
          bidderId: wire['bidderId'] as int,
        );
        a.highBid = wire['highBid'] as int;
        a.highestBidderId = wire['highestBidderId'] as int?;
        a.passed.addAll((wire['passed'] as List).cast<int>());
        if (a.spaceIndex < 0 ||
            a.spaceIndex >= 40 ||
            !validPlayerId(a.bidderId) ||
            !validPlayerId(a.highestBidderId) ||
            a.passed.any((id) => !validPlayerId(id)) ||
            a.highBid < 0) {
          throw const FormatException('Invalid saved auction.');
        }
        game.auction = a;
      }
      final dice = json['lastRoll'];
      if (dice != null) {
        final wire = dice as Map<String, dynamic>;
        final first = wire['first'] as int;
        final second = wire['second'] as int;
        game._validateDice(first, second);
        game.lastRoll = DiceRoll(first, second);
      }
      game._pendingDebts.clear();
      for (final entry
          in (json['pendingDebts'] as List).cast<Map<String, dynamic>>()) {
        final id = entry['playerId'] as int;
        final creditorId = entry['creditorId'] as int?;
        if (!validPlayerId(id) || !validPlayerId(creditorId)) {
          throw const FormatException('Invalid saved debt.');
        }
        game._pendingDebts[id] = creditorId;
      }
      game._chanceDeck
        ..clear()
        ..addAll((json['chanceDeck'] as List).cast<int>());
      game._communityDeck
        ..clear()
        ..addAll((json['communityDeck'] as List).cast<int>());
      if (game._chanceDeck.any((i) => i < 0 || i >= _chance.length) ||
          game._communityDeck.any((i) => i < 0 || i >= _community.length) ||
          game._chanceDeck.toSet().length != game._chanceDeck.length ||
          game._communityDeck.toSet().length != game._communityDeck.length ||
          (game.phase == TurnPhase.auction) != (game.auction != null) ||
          (game.phase == TurnPhase.purchase) !=
              (game.pendingPurchaseIndex != null)) {
        throw const FormatException('Invalid saved game internals.');
      }
      game.log
        ..clear()
        ..addAll((json['log'] as List).cast<String>().take(70));
      return game;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Unable to read this saved game.');
    }
  }
}

enum _CardType {
  money,
  move,
  back,
  jail,
  jailFree,
  payEach,
  collectEach,
  repairs,
  repairsHigh,
}

class _Card {
  const _Card(this.title, this.kind, this.value);
  final String title;
  final _CardType kind;
  final int value;
}

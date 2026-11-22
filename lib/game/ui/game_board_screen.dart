// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../ai/bot_controller.dart';
import '../engine/game_engine.dart';
import '../models/game_models.dart';
import '../persistence/offline_game_store.dart';
import 'game_text.dart';
import 'widgets/game_board_view.dart';

/// Offline local game with Pass & Play or computer opponents.
/// Mobile/tablet/web layout is adaptive.
/// Deliberately has no Riverpod dependency, so it can be dropped into the
/// existing app without modifying the profile or localization providers.
class GameBoardScreen extends StatefulWidget {
  const GameBoardScreen({
    super.key,
    required this.playerNames,
    required this.languageCode,
    this.botDifficulties = const <int, BotDifficulty>{},
    this.resumedGame,
  });

  final List<String> playerNames;
  final String languageCode;
  final Map<int, BotDifficulty> botDifficulties;
  final GameEngine? resumedGame;

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen> {
  late final GameEngine game;
  late final GameText t;
  final Random _random = Random();
  final BotController _botController = BotController();
  Timer? _botTimer;
  final Map<int, int> _visiblePositions = <int, int>{};
  DiceRoll? _dicePreview;
  bool _diceRolling = false;
  bool _busy = false;
  bool _perspective = true;
  final TextEditingController bidController = TextEditingController();

  @override
  void initState() {
    super.initState();
    game = widget.resumedGame ?? GameEngine(playerNames: widget.playerNames);
    t = GameText(widget.languageCode);
    for (final player in game.players) {
      _visiblePositions[player.id] = player.position;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _queueBot();
      if (widget.resumedGame == null) _persist();
    });
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    bidController.dispose();
    super.dispose();
  }

  bool _run(void Function() action, {bool scheduleBot = true}) {
    _botTimer?.cancel();
    try {
      setState(action);
      _persist();
      if (scheduleBot) _queueBot();
      return true;
    } on GameRuleException catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF9C423C),
        ),
      );
      return false;
    }
  }

  void _persist({bool showMessage = false}) {
    final operation = game.phase == TurnPhase.gameOver
        ? OfflineGameStore.clear()
        : OfflineGameStore.save(game, widget.botDifficulties);
    unawaited(
      operation
          .then((_) {
            if (mounted && showMessage) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    t.choose(
                      'Game saved on this device.',
                      'এই ডিভাইসে খেলা সংরক্ষিত হয়েছে।',
                    ),
                  ),
                ),
              );
            }
          })
          .catchError((Object error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    t.choose(
                      'Could not save the game.',
                      'খেলা সংরক্ষণ করা যায়নি।',
                    ),
                  ),
                ),
              );
            }
          }),
    );
  }

  bool _isBot(int playerId) => widget.botDifficulties.containsKey(playerId);

  /// During an auction the bidder (not the current mover) takes the action.
  int? get _actingBotId {
    if (game.phase == TurnPhase.gameOver) return null;
    final id = game.phase == TurnPhase.auction
        ? game.auction!.bidderId
        : game.currentPlayerId;
    return _isBot(id) ? id : null;
  }

  void _queueBot() {
    _botTimer?.cancel();
    if (!mounted || _busy || _actingBotId == null) return;
    _botTimer = Timer(const Duration(milliseconds: 430), _runBot);
  }

  void _runBot() {
    if (!mounted || _busy) return;
    final id = _actingBotId;
    if (id == null) return;
    final decision = _botController.choose(
      game,
      playerId: id,
      difficulty: widget.botDifficulties[id]!,
    );
    if (decision == null) return;
    switch (decision.action) {
      case BotAction.roll:
      case BotAction.jailRoll:
        _animateRoll(jailAttempt: decision.action == BotAction.jailRoll);
        return;
      case BotAction.payFine:
        _run(game.payJailFine);
        return;
      case BotAction.useJailCard:
        _run(game.useJailCard);
        return;
      case BotAction.buy:
        _run(game.buyProperty);
        return;
      case BotAction.auction:
        _run(game.declinePurchase);
        return;
      case BotAction.bid:
        _run(() => game.bid(decision.amount!));
        return;
      case BotAction.pass:
        _run(game.passBid);
        return;
      case BotAction.build:
        _run(() => game.build(decision.spaceIndex!));
        return;
      case BotAction.sellBuilding:
        _run(() => game.sellBuilding(decision.spaceIndex!));
        return;
      case BotAction.mortgage:
        _run(() => game.mortgage(decision.spaceIndex!));
        return;
      case BotAction.bankrupt:
        _run(game.declareBankruptcy);
        return;
      case BotAction.endTurn:
        _run(game.endTurn);
        return;
    }
  }

  Future<void> _animateRoll({bool jailAttempt = false}) async {
    if (_busy || !mounted) return;
    _botTimer?.cancel();
    final movingId = game.currentPlayerId;
    final startPosition = game.currentPlayer.position;
    final finalFirst = _random.nextInt(6) + 1;
    final finalSecond = _random.nextInt(6) + 1;
    setState(() {
      _busy = true;
      _diceRolling = true;
    });
    // Dice frames are only visual; the final pair is sent once to GameEngine.
    for (var i = 0; i < 8; i++) {
      if (!mounted) return;
      setState(
        () => _dicePreview = DiceRoll(
          _random.nextInt(6) + 1,
          _random.nextInt(6) + 1,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 82));
    }
    if (!mounted) return;
    setState(() {
      _dicePreview = DiceRoll(finalFirst, finalSecond);
      _diceRolling = false;
    });
    final applied = _run(() {
      if (jailAttempt) {
        game.tryJailRoll(finalFirst, finalSecond);
      } else {
        game.roll(finalFirst, finalSecond);
      }
    }, scheduleBot: false);
    if (applied) {
      final finishPosition = game.players[movingId].position;
      final travelled = (startPosition + finalFirst + finalSecond) % 40;
      // Third doubles / jail events teleport rather than walk the dice path.
      if (travelled == finishPosition && finishPosition != startPosition) {
        for (var step = 1; step <= finalFirst + finalSecond; step++) {
          if (!mounted) return;
          setState(
            () => _visiblePositions[movingId] = (startPosition + step) % 40,
          );
          await Future<void>.delayed(const Duration(milliseconds: 74));
        }
      }
      if (!mounted) return;
      setState(() => _visiblePositions[movingId] = finishPosition);
    }
    if (!mounted) return;
    setState(() {
      _dicePreview = null;
      _busy = false;
    });
    _queueBot();
  }

  void _roll() => _animateRoll();
  void _tryJail() => _animateRoll(jailAttempt: true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBoardDark,
      appBar: AppBar(
        backgroundColor: const Color(0xFF122729),
        foregroundColor: kBoardGold,
        title: const Text(
          'bHiVE Monopoly',
          style: TextStyle(fontFamily: 'Exo2', fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: t.choose('Save game', 'খেলা সংরক্ষণ'),
            onPressed: _busy ? null : () => _persist(showMessage: true),
            icon: const Icon(Icons.save_outlined),
          ),
          IconButton(
            tooltip: t.choose(
              'Switch 3D / top-down view',
              '৩ডি / সমতল দৃশ্য পরিবর্তন',
            ),
            onPressed: () => setState(() => _perspective = !_perspective),
            icon: Icon(
              _perspective ? Icons.layers_rounded : Icons.view_in_ar_rounded,
            ),
          ),
          IconButton(
            tooltip: t.choose('Bank stock', 'ব্যাংকের ভবন'),
            onPressed: _showBankInfo,
            icon: const Icon(Icons.account_balance_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 900;
            if (wide) {
              return Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    Expanded(
                      child: GameBoardView(
                        engine: game,
                        text: t,
                        onSelect: (index) {
                          if (!_busy && _actingBotId == null) _showTile(index);
                        },
                        perspective: _perspective,
                        visiblePositions: _visiblePositions,
                        dicePreview: _dicePreview,
                        diceRolling: _diceRolling,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 350,
                      child: ListView(
                        children: [
                          _playerCards(),
                          const SizedBox(height: 14),
                          _turnPanel(),
                          const SizedBox(height: 14),
                          _eventsPanel(),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
            final boardSide = min(c.maxWidth - 24, 680.0);
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _playerCards(),
                const SizedBox(height: 12),
                SizedBox(
                  height: boardSide,
                  child: GameBoardView(
                    engine: game,
                    text: t,
                    onSelect: (index) {
                      if (!_busy && _actingBotId == null) _showTile(index);
                    },
                    perspective: _perspective,
                    visiblePositions: _visiblePositions,
                    dicePreview: _dicePreview,
                    diceRolling: _diceRolling,
                  ),
                ),
                const SizedBox(height: 12),
                _turnPanel(),
                const SizedBox(height: 12),
                _eventsPanel(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _playerCards() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.choose('PLAYERS', 'খেলোয়াড়'),
            style: TextStyle(
              fontFamily: t.font,
              color: kBoardGold,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 9),
          for (final p in game.players)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: game.currentPlayerId == p.id
                      ? const Color(0xFF255045)
                      : const Color(0xFF1D3234),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: game.currentPlayerId == p.id
                        ? kBoardGold
                        : Colors.white12,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: tokenColors[p.id],
                      child: Icon(
                        _isBot(p.id)
                            ? Icons.smart_toy_rounded
                            : Icons.person_rounded,
                        color: kBoardDark,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: t.font,
                          decoration: p.bankrupt
                              ? TextDecoration.lineThrough
                              : null,
                          color: p.bankrupt ? Colors.white38 : Colors.white,
                        ),
                      ),
                    ),
                    if (p.inJail)
                      const Padding(
                        padding: EdgeInsets.only(right: 5),
                        child: Icon(
                          Icons.lock_rounded,
                          color: Colors.orange,
                          size: 16,
                        ),
                      ),
                    Text(
                      t.money(p.balance),
                      style: const TextStyle(
                        fontFamily: 'Exo2',
                        fontWeight: FontWeight.bold,
                        color: kBoardGold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _turnPanel() {
    final player = game.currentPlayer;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.choose('CURRENT TURN', 'বর্তমান চাল'),
            style: TextStyle(
              fontFamily: t.font,
              color: kBoardGold,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            player.name,
            style: TextStyle(
              fontFamily: t.font,
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_actingBotId != null)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Row(
                children: [
                  const Icon(
                    Icons.smart_toy_rounded,
                    size: 16,
                    color: kBoardGold,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      t.choose(
                        'Computer is thinking…',
                        'কম্পিউটার চাল দিচ্ছে…',
                      ),
                      style: TextStyle(
                        color: Colors.white70,
                        fontFamily: t.font,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(color: kBoardGold, minHeight: 2),
            ),
          const SizedBox(height: 5),
          Text(
            '${t.choose('Position', 'অবস্থান')}: '
            '${t.spaceName(player.position, game.spaces[player.position].name)}',
            style: TextStyle(fontFamily: t.font, color: Colors.white70),
          ),
          if (game.lastRoll != null) ...[
            const SizedBox(height: 5),
            Text(
              '${t.choose('Dice', 'পাশা')}: '
              '${t.integer(game.lastRoll!.first)} + '
              '${t.integer(game.lastRoll!.second)} = '
              '${t.integer(game.lastRoll!.sum)}',
              style: const TextStyle(color: kBoardGold),
            ),
          ],
          const SizedBox(height: 17),
          ..._phaseActions(),
          const SizedBox(height: 10),
          Text(
            t.choose(
              'Tap any board tile to view its title deed and manage your properties.',
              'টাইল স্পর্শ করে সম্পত্তির তথ্য দেখুন বা পরিচালনা করুন।',
            ),
            style: TextStyle(
              fontFamily: t.font,
              fontSize: 12,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _phaseActions() {
    switch (game.phase) {
      case TurnPhase.roll:
        return [
          _primary(
            t.choose('ROLL DICE', 'পাশা নিক্ষেপ করুন'),
            Icons.casino_rounded,
            _roll,
          ),
        ];
      case TurnPhase.purchase:
        final tile = game.spaces[game.pendingPurchaseIndex!];
        return [
          Text(
            '${t.spaceName(tile.index, tile.name)} — ${t.money(tile.price)}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 10),
          _primary(
            t.choose('BUY PROPERTY', 'সম্পত্তি কিনুন'),
            Icons.shopping_cart_outlined,
            game.currentPlayer.balance >= tile.price
                ? () => _run(game.buyProperty)
                : null,
          ),
          const SizedBox(height: 9),
          _secondary(
            t.choose('DECLINE / AUCTION', 'নিলাম শুরু করুন'),
            () => _run(game.declinePurchase),
          ),
        ];
      case TurnPhase.auction:
        final a = game.auction!;
        final item = game.spaces[a.spaceIndex];
        final bidder = game.players[a.bidderId];
        if (bidController.text.isEmpty ||
            int.tryParse(bidController.text) == null ||
            int.parse(bidController.text) < a.minimumBid) {
          bidController.text = '${a.minimumBid}';
        }
        return [
          Text(
            t.choose('AUCTION', 'নিলাম'),
            style: const TextStyle(
              color: kBoardGold,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            t.spaceName(item.index, item.name),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 5),
          Text(
            '${t.choose('Bidder', 'দরদাতা')}: ${bidder.name}',
            style: const TextStyle(color: Colors.white70),
          ),
          Text(
            '${t.choose('Highest', 'সর্বোচ্চ')}: '
            '${t.money(a.highBid)}',
            style: const TextStyle(color: Colors.white70),
          ),
          if (a.highestBidderId != null)
            Text(
              '${t.choose('Leader', 'এগিয়ে')}: '
              '${game.players[a.highestBidderId!].name}',
              style: const TextStyle(color: Colors.white70),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: bidController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText:
                  '${t.choose('Minimum', 'সর্বনিম্ন')}: '
                  '${t.money(a.minimumBid)}',
              labelStyle: const TextStyle(color: kBoardGold),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          _primary(
            t.choose('PLACE BID', 'দর দিন'),
            Icons.gavel_rounded,
            () => _run(() => game.bid(int.tryParse(bidController.text) ?? 0)),
          ),
          const SizedBox(height: 8),
          _secondary(t.choose('PASS', 'পাস'), () => _run(game.passBid)),
        ];
      case TurnPhase.jailDecision:
        return [
          Text(
            t.choose('IN JAIL', 'কারাগারে'),
            style: const TextStyle(
              color: Colors.orangeAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _primary(
            t.choose('TRY DOUBLES', 'ডাবল পাওয়ার চেষ্টা'),
            Icons.casino_rounded,
            _tryJail,
          ),
          const SizedBox(height: 8),
          _secondary(
            '${t.choose('PAY FINE', 'জরিমানা দিন')} '
            '(${t.money(50)})',
            () => _run(game.payJailFine),
          ),
          if (game.currentPlayer.getOutOfJailCards > 0) ...[
            const SizedBox(height: 8),
            _secondary(
              t.choose('USE JAIL CARD', 'জেল মুক্তি কার্ড'),
              () => _run(game.useJailCard),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${t.choose('Failed attempts', 'ব্যর্থ চেষ্টা')}: '
            '${t.integer(game.currentPlayer.jailFailedRolls)}/${t.integer(3)}',
            style: const TextStyle(color: Colors.white70),
          ),
        ];
      case TurnPhase.debt:
        return [
          Text(
            t.choose('DEBT RESOLUTION', 'ঋণ পরিশোধ'),
            style: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            t.choose(
              'Mortgage or sell buildings until your cash is not negative. Tap an owned tile.',
              'নগদ অর্থ শূন্যের বেশি করতে বন্ধক দিন বা বাড়ি বিক্রি করুন।',
            ),
            style: TextStyle(fontFamily: t.font, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          _secondary(
            t.choose('DECLARE BANKRUPTCY', 'দেউলিয়া ঘোষণা'),
            _confirmBankruptcy,
          ),
        ];
      case TurnPhase.complete:
        return [
          _primary(
            t.choose('END TURN', 'চাল শেষ করুন'),
            Icons.navigate_next_rounded,
            () => _run(game.endTurn),
          ),
          const SizedBox(height: 8),
          _secondary(
            t.choose('MANAGE PROPERTIES', 'সম্পত্তি পরিচালনা'),
            _showMyProperties,
          ),
        ];
      case TurnPhase.gameOver:
        final winner = game.players[game.winnerId!];
        return [
          const Center(
            child: Icon(
              Icons.emoji_events_rounded,
              color: kBoardGold,
              size: 65,
            ),
          ),
          Text(
            '${winner.name} ${t.choose('WINS!', 'বিজয়ী!')}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: t.font,
              color: kBoardGold,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 9),
          _primary(
            t.choose('NEW GAME', 'নতুন খেলা'),
            Icons.refresh_rounded,
            () => Navigator.pop(context),
          ),
        ];
    }
  }

  Widget _eventsPanel() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.choose('RECENT EVENTS', 'সাম্প্রতিক ঘটনা'),
          style: TextStyle(
            fontFamily: t.font,
            color: kBoardGold,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        for (final line in game.log.take(8))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: 8, top: 7),
                  child: Icon(Icons.circle, size: 6, color: kBoardGold),
                ),
                Expanded(
                  child: Text(
                    line,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _panel({required Widget child}) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFF172A2C),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFF385B52)),
    ),
    child: child,
  );

  Widget _primary(String label, IconData icon, VoidCallback? action) =>
      FilledButton.icon(
        onPressed: _busy || _actingBotId != null ? null : action,
        style: FilledButton.styleFrom(
          backgroundColor: kBoardGold,
          foregroundColor: kBoardDark,
          minimumSize: const Size.fromHeight(51),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
        icon: Icon(icon),
        label: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: t.font, fontWeight: FontWeight.w800),
        ),
      );

  Widget _secondary(String label, VoidCallback? action) => OutlinedButton(
    onPressed: _busy || _actingBotId != null ? null : action,
    style: OutlinedButton.styleFrom(
      foregroundColor: kBoardGold,
      minimumSize: const Size.fromHeight(46),
      side: const BorderSide(color: kBoardGold),
    ),
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(fontFamily: t.font),
    ),
  );

  Future<void> _showBankInfo() => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t.choose('Bank inventory', 'ব্যাংকের মজুত')),
      content: Text(
        '${t.choose('Available houses', 'অবশিষ্ট বাড়ি')}: '
        '${t.integer(game.bankHouses)}/৩২\n'
        '${t.choose('Available hotels', 'অবশিষ্ট হোটেল')}: '
        '${t.integer(game.bankHotels)}/১২',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t.choose('CLOSE', 'বন্ধ করুন')),
        ),
      ],
    ),
  );

  void _showMyProperties() {
    if (_busy || _actingBotId != null) return;
    final owned = game.spaces
        .where((s) => game.properties[s.index].ownerId == game.currentPlayerId)
        .toList();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1B3031),
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: min(MediaQuery.sizeOf(ctx).height * .6, 500.0),
            child: Column(
              children: [
                Text(
                  t.choose('My properties', 'আমার সম্পত্তি'),
                  style: TextStyle(
                    fontFamily: t.font,
                    color: kBoardGold,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final s in owned)
                        ListTile(
                          title: Text(
                            t.spaceName(s.index, s.name),
                            style: const TextStyle(color: Colors.white),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: kBoardGold,
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _showTile(s.index);
                          },
                        ),
                      if (owned.isEmpty)
                        Text(
                          t.choose(
                            'No properties yet.',
                            'এখনো কোনো সম্পত্তি নেই।',
                          ),
                          style: TextStyle(
                            fontFamily: t.font,
                            color: Colors.white70,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTile(int index) {
    if (_busy || _actingBotId != null) return;
    final s = game.spaces[index];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B3031),
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, refreshSheet) {
          final state = game.properties[index];
          final ownedByMe = state.ownerId == game.currentPlayerId;
          final owner = state.ownerId == null
              ? t.choose('Bank / Unowned', 'ব্যাংক / অবিক্রিত')
              : game.players[state.ownerId!].name;
          void update(void Function() action) {
            _run(action);
            refreshSheet(() {});
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                22,
                16,
                22,
                max(MediaQuery.viewInsetsOf(ctx).bottom, 18.0),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(height: 7, color: groupColor(s.group)),
                      const SizedBox(height: 15),
                      Text(
                        t.spaceName(s.index, s.name),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: t.font,
                          fontFamilyFallback: t.fallbackFonts,
                          color: kBoardGold,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${t.choose('OWNER', 'মালিক')}: $owner',
                        style: TextStyle(
                          fontFamily: t.font,
                          color: Colors.white,
                        ),
                      ),
                      if (s.purchasable) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${t.choose('Price', 'দাম')}: ${t.money(s.price)}',
                          style: TextStyle(
                            fontFamily: t.font,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          '${t.choose('Mortgage value', 'বন্ধক মূল্য')}: '
                          '${t.money(s.price ~/ 2)}',
                          style: TextStyle(
                            fontFamily: t.font,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          '${t.choose('Current rent', 'বর্তমান ভাড়া')}: '
                          '${t.money(game.rentFor(index, game.lastRoll?.sum ?? 7))}',
                          style: TextStyle(
                            fontFamily: t.font,
                            color: Colors.white70,
                          ),
                        ),
                        if (s.kind == SpaceKind.street) ...[
                          Text(
                            '${t.choose('Buildings', 'ভবন')}: '
                            '${state.development == 5 ? t.choose('Hotel', 'হোটেল') : t.integer(state.development)}',
                            style: TextStyle(
                              fontFamily: t.font,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            '${t.choose('Build cost', 'নির্মাণ খরচ')}: '
                            '${t.money(s.buildCost)}',
                            style: TextStyle(
                              fontFamily: t.font,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                        if (state.mortgaged)
                          Text(
                            t.choose('MORTGAGED', 'বন্ধককৃত'),
                            style: const TextStyle(color: Colors.orangeAccent),
                          ),
                      ],
                      const SizedBox(height: 14),
                      if (ownedByMe &&
                          s.purchasable &&
                          game.phase != TurnPhase.gameOver &&
                          game.phase != TurnPhase.auction) ...[
                        if (s.kind == SpaceKind.street) ...[
                          _primary(
                            t.choose(
                              'BUILD HOUSE / HOTEL',
                              'বাড়ি / হোটেল নির্মাণ',
                            ),
                            Icons.add_home_work_outlined,
                            game.phase == TurnPhase.debt
                                ? null
                                : () => update(() => game.build(index)),
                          ),
                          const SizedBox(height: 8),
                          _secondary(
                            t.choose('SELL BUILDING', 'ভবন বিক্রি'),
                            () => update(() => game.sellBuilding(index)),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (state.mortgaged)
                          _secondary(
                            t.choose('UNMORTGAGE', 'বন্ধক ছাড়ান'),
                            game.phase == TurnPhase.debt
                                ? null
                                : () => update(() => game.unmortgage(index)),
                          )
                        else
                          _secondary(
                            t.choose('MORTGAGE', 'বন্ধক দিন'),
                            () => update(() => game.mortgage(index)),
                          ),
                        if (game.phase == TurnPhase.roll ||
                            game.phase == TurnPhase.complete) ...[
                          const SizedBox(height: 8),
                          _secondary(
                            t.choose(
                              'TRADE / SELL TO PLAYER',
                              'অন্য খেলোয়াড়কে বিক্রি',
                            ),
                            () {
                              Navigator.pop(ctx);
                              _offerTrade(index);
                            },
                          ),
                        ],
                      ],
                      const SizedBox(height: 12),
                      _secondary(
                        t.choose('CLOSE', 'বন্ধ করুন'),
                        () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _offerTrade(int index) async {
    final others = game.players
        .where((p) => !p.bankrupt && p.id != game.currentPlayerId)
        .toList();
    if (others.isEmpty) return;
    var targetId = others.first.id;
    final price = TextEditingController(text: '${game.spaces[index].price}');
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, refresh) => AlertDialog(
          title: Text(
            t.choose('Offer property trade', 'সম্পত্তি বিনিময়ের প্রস্তাব'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.spaceName(index, game.spaces[index].name)),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: targetId,
                decoration: InputDecoration(
                  labelText: t.choose('Buyer', 'ক্রেতা'),
                ),
                items: [
                  for (final p in others)
                    DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
                onChanged: (id) {
                  if (id != null) refresh(() => targetId = id);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: t.choose('Offer price', 'প্রস্তাবিত মূল্য'),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                t.choose(
                  'The receiving player must agree before confirming.',
                  'নিশ্চিত করার আগে ক্রেতার সম্মতি নিন।',
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.choose('CANCEL', 'বাতিল')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.choose('ACCEPT TRADE', 'প্রস্তাব গ্রহণ')),
            ),
          ],
        ),
      ),
    );
    if (approved == true && mounted && _actingBotId == null) {
      final cost = int.tryParse(price.text.trim()) ?? -1;
      _run(
        () => game.acceptTrade(
          TradeOffer(
            fromPlayerId: game.currentPlayerId,
            toPlayerId: targetId,
            propertiesFrom: [index],
            cashTo: cost,
          ),
        ),
      );
    }
    price.dispose();
  }

  Future<void> _confirmBankruptcy() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.choose('Declare bankruptcy?', 'দেউলিয়া ঘোষণা করবেন?')),
        content: Text(
          t.choose(
            'You will leave this match and transfer your assets.',
            'আপনি খেলা থেকে বাদ পড়বেন এবং আপনার সম্পত্তি হস্তান্তর হবে।',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.choose('CANCEL', 'বাতিল')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.choose('CONFIRM', 'নিশ্চিত করুন')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) _run(game.declareBankruptcy);
  }
}

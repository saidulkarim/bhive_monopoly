import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/game_engine.dart';
import '../models/game_models.dart';
import '../network/lan_room_controller.dart';
import 'game_text.dart';
import 'widgets/lan_avatar_badge.dart';
import 'widgets/game_board_view.dart';

/// LAN game board. Uses Phase-3 board renderer but NEVER invokes GameEngine
/// from a client. Buttons send actions to the Android/desktop host only.
class LanBoardScreen extends StatefulWidget {
  const LanBoardScreen({
    super.key,
    required this.room,
    required this.languageCode,
  });

  final LanRoomController room;
  final String languageCode;

  @override
  State<LanBoardScreen> createState() => _LanBoardScreenState();
}

class _LanBoardScreenState extends State<LanBoardScreen> {
  late final GameText t = GameText(widget.languageCode);
  final TextEditingController _bid = TextEditingController();
  final Map<int, int> _positions = <int, int>{};
  final Random _animationRandom = Random();
  DiceRoll? _dicePreview;
  bool _diceRolling = false;
  bool _perspective = true;
  int _lastSequence = 0;
  int _animationEpoch = 0;
  int _seenError = 0;

  LanRoomController get room => widget.room;
  GameEngine? get game => room.game;

  @override
  void initState() {
    super.initState();
    _lastSequence = room.lastEvent?.sequence ?? 0;
    _seenError = room.errorRevision;
    final engine = game;
    if (engine != null) {
      for (final p in engine.players) {
        _positions[p.id] = p.position;
      }
    }
    room.addListener(_update);
  }

  @override
  void dispose() {
    room.removeListener(_update);
    ++_animationEpoch;
    _bid.dispose();
    unawaited(room.shutdown());
    super.dispose();
  }

  void _update() {
    if (!mounted) return;
    if (room.errorRevision != _seenError) {
      _seenError = room.errorRevision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || room.lastError == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(room.lastError!),
            backgroundColor: const Color(0xFF9C423C),
          ),
        );
      });
    }
    final engine = game;
    if (engine != null) {
      final event = room.lastEvent;
      if (event != null && event.sequence > _lastSequence) {
        _lastSequence = event.sequence;
        final epoch = ++_animationEpoch;
        if (event.dice != null) {
          unawaited(_animate(event, epoch));
        } else {
          _diceRolling = false;
          _dicePreview = null;
          for (final p in engine.players) {
            _positions[p.id] = p.position;
          }
        }
      } else if (!_diceRolling) {
        for (final p in engine.players) {
          _positions[p.id] = p.position;
        }
      }
    }
    setState(() {});
  }

  Future<void> _animate(LanMoveEvent event, int epoch) async {
    final roll = event.dice!;
    if (!mounted) return;
    setState(() {
      _dicePreview = roll;
      _diceRolling = true;
      if (event.startPosition != null) {
        _positions[event.actorId] = event.startPosition!;
      }
    });
    // Dice visual states do not affect the host-selected roll.
    for (var frame = 0; frame < 7; frame++) {
      await Future<void>.delayed(const Duration(milliseconds: 70));
      if (!mounted || epoch != _animationEpoch) return;
      setState(
        () => _dicePreview = DiceRoll(
          _animationRandom.nextInt(6) + 1,
          _animationRandom.nextInt(6) + 1,
        ),
      );
    }
    if (!mounted || epoch != _animationEpoch) return;
    setState(() {
      _dicePreview = roll;
      _diceRolling = false;
    });
    final from = event.startPosition;
    final to = event.endPosition;
    // Teleports caused by cards/jail are not walked across the board.
    if (from != null &&
        to != null &&
        (from + roll.sum) % 40 == to &&
        from != to) {
      for (var step = 1; step <= roll.sum; step++) {
        await Future<void>.delayed(const Duration(milliseconds: 72));
        if (!mounted || epoch != _animationEpoch) return;
        setState(() => _positions[event.actorId] = (from + step) % 40);
      }
    }
    if (!mounted || epoch != _animationEpoch) return;
    setState(() {
      final engine = game;
      if (engine != null) {
        for (final p in engine.players) {
          _positions[p.id] = p.position;
        }
      }
      _dicePreview = null;
    });
  }

  void _send(String action, {int? index, int? amount}) {
    unawaited(room.sendAction(action, index: index, amount: amount));
  }

  @override
  Widget build(BuildContext context) {
    final engine = game;
    return Scaffold(
      backgroundColor: kBoardDark,
      appBar: AppBar(
        backgroundColor: const Color(0xFF122729),
        foregroundColor: kBoardGold,
        title: const Text(
          'bHiVE • LAN',
          style: TextStyle(fontFamily: 'Exo2', fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: t.choose('3D / top-down', '৩ডি / সমতল'),
            onPressed: () => setState(() => _perspective = !_perspective),
            icon: const Icon(Icons.layers_rounded),
          ),
          IconButton(
            tooltip: t.choose('Bank inventory', 'ব্যাংক মজুত'),
            onPressed: engine == null ? null : _bankDialog,
            icon: const Icon(Icons.account_balance_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: engine == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: kBoardGold),
                    const SizedBox(height: 12),
                    Text(
                      t.choose(
                        'Syncing the board with host…',
                        'হোস্টের সাথে বোর্ড সিঙ্ক হচ্ছে…',
                      ),
                      style: TextStyle(
                        fontFamily: t.font,
                        color: Colors.white70,
                      ),
                    ),
                    if (!room.connected) ...[
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => unawaited(room.reconnect()),
                        child: Text(t.choose('Reconnect', 'পুনরায় যুক্ত হন')),
                      ),
                    ],
                  ],
                ),
              )
            : LayoutBuilder(
                builder: (ctx, size) {
                  final wide = size.maxWidth >= 900;
                  final board = GameBoardView(
                    engine: engine,
                    text: t,
                    onSelect: _showTile,
                    perspective: _perspective,
                    visiblePositions: _positions,
                    dicePreview: _dicePreview,
                    diceRolling: _diceRolling,
                  );
                  if (wide) {
                    return Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(child: board),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 350,
                            child: ListView(
                              children: [
                                _roomBanner(),
                                const SizedBox(height: 12),
                                _players(),
                                const SizedBox(height: 12),
                                _controls(),
                                const SizedBox(height: 12),
                                _events(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _roomBanner(),
                      const SizedBox(height: 12),
                      _players(),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: min(size.maxWidth - 24, 680.0),
                        child: board,
                      ),
                      const SizedBox(height: 12),
                      _controls(),
                      const SizedBox(height: 12),
                      _events(),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _panel(Widget child) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFF172A2C),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFF385B52)),
    ),
    child: child,
  );

  Widget _roomBanner() {
    final offline = !room.connected || room.paused;
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                offline ? Icons.wifi_off : Icons.wifi,
                color: offline ? Colors.orangeAccent : Colors.greenAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  offline
                      ? t.choose(
                          'Match paused — connection lost',
                          'খেলা স্থগিত — সংযোগ বিচ্ছিন্ন',
                        )
                      : t.choose(
                          'LAN match • Host-authoritative',
                          'LAN খেলা • হোস্ট নিয়ন্ত্রিত',
                        ),
                  style: TextStyle(fontFamily: t.font, color: Colors.white),
                ),
              ),
              if (!room.isHost && !room.connected)
                TextButton(
                  onPressed: room.reconnecting
                      ? null
                      : () => unawaited(room.reconnect()),
                  child: Text(t.choose('Reconnect', 'পুনঃসংযোগ')),
                ),
            ],
          ),
          Text(
            room.isHost
                ? t.choose('You are the host', 'আপনি হোস্ট')
                : '${t.choose('Your player', 'আপনার খেলোয়াড়')}: '
                      '${room.playerId == null ? '—' : t.integer(room.playerId! + 1)}',
            style: TextStyle(
              fontFamily: t.font,
              color: Colors.white60,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _players() {
    final engine = game!;
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.choose('PLAYERS', 'খেলোয়াড়'),
            style: TextStyle(
              fontFamily: t.font,
              color: kBoardGold,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 9),
          for (final p in engine.players)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: engine.currentPlayerId == p.id
                      ? const Color(0xFF255045)
                      : const Color(0xFF1D3234),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: engine.currentPlayerId == p.id
                        ? kBoardGold
                        : Colors.white12,
                  ),
                ),
                child: Row(
                  children: [
                    LanAvatarBadge(
                      member: p.id < room.members.length
                          ? room.members[p.id]
                          : null,
                      color: tokenColors[p.id],
                      radius: 16,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        p.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: t.font,
                          color: p.bankrupt ? Colors.white38 : Colors.white,
                          decoration: p.bankrupt
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    if (!(room.members.length > p.id &&
                        room.members[p.id].connected))
                      const Padding(
                        padding: EdgeInsets.only(right: 5),
                        child: Icon(
                          Icons.wifi_off,
                          size: 17,
                          color: Colors.orangeAccent,
                        ),
                      ),
                    if (p.inJail)
                      const Icon(
                        Icons.lock_outline,
                        size: 17,
                        color: Colors.orangeAccent,
                      ),
                    const SizedBox(width: 6),
                    Text(
                      t.money(p.balance),
                      style: const TextStyle(
                        color: kBoardGold,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Exo2',
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

  Widget _primary(String title, IconData icon, VoidCallback? onPressed) =>
      FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: kBoardGold,
          foregroundColor: kBoardDark,
          minimumSize: const Size.fromHeight(51),
        ),
        icon: Icon(icon),
        label: Text(
          title,
          style: TextStyle(fontFamily: t.font, fontWeight: FontWeight.w800),
        ),
      );

  Widget _secondary(String title, VoidCallback? onPressed) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: kBoardGold,
      minimumSize: const Size.fromHeight(46),
      side: const BorderSide(color: kBoardGold),
    ),
    child: Text(title, style: TextStyle(fontFamily: t.font)),
  );

  Widget _controls() {
    final engine = game!;
    final active = room.isMyTurn && room.pendingTrade == null;
    final player = engine.currentPlayer;
    final auction = engine.auction;
    final bidder = auction == null ? null : engine.players[auction.bidderId];
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.choose('CURRENT TURN', 'বর্তমান চাল'),
            style: TextStyle(
              fontFamily: t.font,
              color: kBoardGold,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            player.name,
            style: TextStyle(
              fontFamily: t.font,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            t.spaceName(player.position, engine.spaces[player.position].name),
            style: const TextStyle(color: Colors.white70),
          ),
          if (engine.lastRoll != null)
            Text(
              '${t.choose('Dice', 'পাশা')}: '
              '${t.integer(engine.lastRoll!.first)} + '
              '${t.integer(engine.lastRoll!.second)}',
              style: const TextStyle(color: kBoardGold),
            ),
          const SizedBox(height: 14),
          if (room.pendingTrade != null) ...[
            _tradeStatus(),
            const SizedBox(height: 14),
          ],
          if (!room.connected || room.paused)
            Text(
              t.choose(
                'Actions are disabled until the room reconnects.',
                'পুনরায় সংযোগ না হওয়া পর্যন্ত চাল বন্ধ থাকবে।',
              ),
              style: TextStyle(fontFamily: t.font, color: Colors.orangeAccent),
            ),
          if (engine.phase == TurnPhase.roll)
            _primary(
              t.choose('ROLL DICE', 'পাশা নিক্ষেপ'),
              Icons.casino_rounded,
              active ? () => _send('roll') : null,
            ),
          if (engine.phase == TurnPhase.purchase) ...[
            Text(
              '${t.spaceName(engine.pendingPurchaseIndex!, engine.spaces[engine.pendingPurchaseIndex!].name)} — '
              '${t.money(engine.spaces[engine.pendingPurchaseIndex!].price)}',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            _primary(
              t.choose('BUY', 'কিনুন'),
              Icons.shopping_cart_outlined,
              active &&
                      player.balance >=
                          engine.spaces[engine.pendingPurchaseIndex!].price
                  ? () => _send('buy')
                  : null,
            ),
            const SizedBox(height: 8),
            _secondary(
              t.choose('DECLINE / AUCTION', 'নিলাম শুরু'),
              active ? () => _send('decline') : null,
            ),
          ],
          if (engine.phase == TurnPhase.auction && auction != null) ...[
            Text(
              '${t.choose('AUCTION', 'নিলাম')}: '
              '${t.spaceName(auction.spaceIndex, engine.spaces[auction.spaceIndex].name)}',
              style: const TextStyle(
                color: kBoardGold,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${t.choose('Bidding player', 'দরদাতা')}: ${bidder!.name}',
              style: const TextStyle(color: Colors.white),
            ),
            Text(
              '${t.choose('Current bid', 'বর্তমান দর')}: '
              '${t.money(auction.highBid)}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _bid,
              keyboardType: TextInputType.number,
              enabled: room.isMyAuctionBid,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText:
                    '${t.choose('Bid at least', 'সর্বনিম্ন দর')} '
                    '${t.money(auction.minimumBid)}',
                labelStyle: const TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 8),
            _primary(
              t.choose('PLACE BID', 'দর দিন'),
              Icons.gavel,
              room.isMyAuctionBid
                  ? () {
                      final value = int.tryParse(_bid.text.trim());
                      if (value != null && value >= auction.minimumBid) {
                        _send('bid', amount: value);
                        _bid.clear();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              t.choose(
                                'Enter a valid minimum bid.',
                                'সঠিক ন্যূনতম দর লিখুন।',
                              ),
                            ),
                          ),
                        );
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 8),
            _secondary(
              t.choose('PASS BID', 'দর ছেড়ে দিন'),
              room.isMyAuctionBid ? () => _send('passBid') : null,
            ),
          ],
          if (engine.phase == TurnPhase.jailDecision) ...[
            _primary(
              t.choose('TRY DOUBLES', 'ডাবল চেষ্টা'),
              Icons.casino_rounded,
              active ? () => _send('jailRoll') : null,
            ),
            const SizedBox(height: 8),
            _secondary(
              '${t.choose('PAY FINE', 'জরিমানা দিন')} '
              '(${t.money(50)})',
              active ? () => _send('payFine') : null,
            ),
            if (player.getOutOfJailCards > 0) ...[
              const SizedBox(height: 8),
              _secondary(
                t.choose('USE JAIL CARD', 'জেল মুক্তি কার্ড'),
                active ? () => _send('useJailCard') : null,
              ),
            ],
          ],
          if (engine.phase == TurnPhase.debt) ...[
            Text(
              t.choose(
                'Raise funds by mortgaging or selling buildings.',
                'বন্ধক বা ভবন বিক্রি করে অর্থ সংগ্রহ করুন।',
              ),
              style: TextStyle(fontFamily: t.font, color: Colors.orangeAccent),
            ),
            const SizedBox(height: 8),
            _secondary(
              t.choose('MANAGE PROPERTIES', 'সম্পত্তি পরিচালনা'),
              active ? _showMyProperties : null,
            ),
            const SizedBox(height: 8),
            _secondary(
              t.choose('DECLARE BANKRUPTCY', 'দেউলিয়া ঘোষণা'),
              active ? _bankruptcyConfirm : null,
            ),
          ],
          if (engine.phase == TurnPhase.complete) ...[
            _primary(
              t.choose('END TURN', 'চাল শেষ করুন'),
              Icons.navigate_next,
              active ? () => _send('endTurn') : null,
            ),
            const SizedBox(height: 8),
            _secondary(
              t.choose('MANAGE PROPERTIES', 'সম্পত্তি পরিচালনা'),
              active ? _showMyProperties : null,
            ),
          ],
          if ((engine.phase == TurnPhase.roll ||
                  engine.phase == TurnPhase.complete) &&
              room.pendingTrade == null) ...[
            const SizedBox(height: 8),
            _secondary(
              t.choose('OFFER TRADE', 'বিনিময়ের প্রস্তাব'),
              active ? _openTradeDialog : null,
            ),
          ],
          if (engine.phase == TurnPhase.gameOver) ...[
            const Icon(Icons.emoji_events, color: kBoardGold, size: 60),
            Text(
              '${engine.players[engine.winnerId!].name} '
              '${t.choose('WINS!', 'বিজয়ী!')}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: t.font,
                color: kBoardGold,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ],
          if (engine.phase != TurnPhase.gameOver &&
              !active &&
              !room.isMyAuctionBid) ...[
            const SizedBox(height: 10),
            Text(
              t.choose(
                'Waiting for the active player…',
                'সক্রিয় খেলোয়াড়ের অপেক্ষায়…',
              ),
              style: TextStyle(fontFamily: t.font, color: Colors.white60),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            t.choose(
              'Tap a property tile for its details and management.',
              'সম্পত্তির বিস্তারিত ও পরিচালনার জন্য টাইল স্পর্শ করুন।',
            ),
            style: TextStyle(
              fontFamily: t.font,
              color: Colors.white60,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tradeStatus() {
    final current = room.pendingTrade!;
    final offer = current.offer;
    final engine = game!;
    final mine = room.playerId;
    final isRecipient = mine == offer.toPlayerId;
    final isSender = mine == offer.fromPlayerId;
    String propertyNames(List<int> ids) => ids.isEmpty
        ? t.choose('None', 'নেই')
        : ids.map((i) => t.spaceName(i, engine.spaces[i].name)).join(', ');
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF3A3230),
        border: Border.all(color: kBoardGold),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.choose('PENDING TRADE', 'অপেক্ষমাণ বিনিময়'),
            style: TextStyle(
              fontFamily: t.font,
              fontWeight: FontWeight.bold,
              color: kBoardGold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${engine.players[offer.fromPlayerId].name} → '
            '${engine.players[offer.toPlayerId].name}',
            style: const TextStyle(color: Colors.white),
          ),
          Text(
            '${t.choose('Offers properties', 'দিচ্ছেন সম্পত্তি')}: '
            '${propertyNames(offer.propertiesFrom)}',
            style: TextStyle(fontFamily: t.font, color: Colors.white70),
          ),
          Text(
            '${t.choose('Requests properties', 'চাচ্ছেন সম্পত্তি')}: '
            '${propertyNames(offer.propertiesTo)}',
            style: TextStyle(fontFamily: t.font, color: Colors.white70),
          ),
          Text(
            '${t.choose('Offers cash', 'দিচ্ছেন টাকা')}: '
            '${t.money(offer.cashFrom)}',
            style: TextStyle(fontFamily: t.font, color: Colors.white70),
          ),
          Text(
            '${t.choose('Requests cash', 'চাচ্ছেন টাকা')}: '
            '${t.money(offer.cashTo)}',
            style: TextStyle(fontFamily: t.font, color: Colors.white70),
          ),
          const SizedBox(height: 9),
          if (isRecipient) ...[
            _primary(
              t.choose('ACCEPT TRADE', 'বিনিময় গ্রহণ'),
              Icons.check_circle_outline,
              room.connected && !room.paused
                  ? () => unawaited(
                      room.respondToTrade('acceptTrade', current.id),
                    )
                  : null,
            ),
            const SizedBox(height: 6),
            _secondary(
              t.choose('DECLINE', 'প্রত্যাখ্যান'),
              room.connected && !room.paused
                  ? () => unawaited(
                      room.respondToTrade('declineTrade', current.id),
                    )
                  : null,
            ),
          ] else if (isSender) ...[
            _secondary(
              t.choose('CANCEL OFFER', 'প্রস্তাব বাতিল'),
              room.connected && !room.paused
                  ? () => unawaited(
                      room.respondToTrade('cancelTrade', current.id),
                    )
                  : null,
            ),
          ] else
            Text(
              t.choose(
                'Waiting for the recipient to reply…',
                'গ্রহীতার উত্তরের অপেক্ষায়…',
              ),
              style: TextStyle(fontFamily: t.font, color: Colors.white70),
            ),
        ],
      ),
    );
  }

  List<BoardSpace> _tradeableSpaces(int ownerId) {
    final engine = game!;
    return engine.spaces.where((space) {
      if (!space.purchasable ||
          engine.properties[space.index].ownerId != ownerId ||
          engine.properties[space.index].mortgaged) {
        return false;
      }
      if (space.group != null &&
          engine.spaces.any(
            (other) =>
                other.group == space.group &&
                engine.properties[other.index].development != 0,
          )) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _openTradeDialog() async {
    final engine = game;
    final me = room.playerId;
    if (engine == null ||
        me == null ||
        room.pendingTrade != null ||
        !room.isMyTurn) {
      return;
    }
    final recipients = engine.players
        .where(
          (p) =>
              p.id != me &&
              !p.bankrupt &&
              p.id < room.members.length &&
              room.members[p.id].connected,
        )
        .toList();
    if (recipients.isEmpty) return;
    int target = recipients.first.id;
    final offered = <int>{};
    final requested = <int>{};
    final cashFrom = TextEditingController(text: '0');
    final cashTo = TextEditingController(text: '0');
    final owned = _tradeableSpaces(me);
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, updateDialog) {
            final theirs = _tradeableSpaces(target);

            Widget propertyPicker(
              String heading,
              List<BoardSpace> spaces,
              Set<int> selected,
            ) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$heading (${t.integer(selected.length)})',
                  style: TextStyle(
                    fontFamily: t.font,
                    color: kBoardGold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 7),
                if (spaces.isEmpty)
                  Text(
                    t.choose(
                      'No eligible properties',
                      'বিনিময়যোগ্য কোনো সম্পত্তি নেই',
                    ),
                    style: TextStyle(fontFamily: t.font, color: Colors.white60),
                  ),
                Wrap(
                  spacing: 7,
                  runSpacing: 3,
                  children: [
                    for (final space in spaces)
                      FilterChip(
                        label: Text(
                          t.spaceName(space.index, space.name),
                          style: TextStyle(fontFamily: t.font, fontSize: 12),
                        ),
                        selected: selected.contains(space.index),
                        selectedColor: const Color(0xFFAF9570),
                        onSelected: (value) => updateDialog(() {
                          if (value) {
                            selected.add(space.index);
                          } else {
                            selected.remove(space.index);
                          }
                        }),
                      ),
                  ],
                ),
              ],
            );

            return AlertDialog(
              backgroundColor: const Color(0xFF1C3332),
              title: Text(
                t.choose(
                  'Offer a multi-property trade',
                  'একাধিক সম্পত্তি বিনিময়ের প্রস্তাব',
                ),
                style: TextStyle(fontFamily: t.font, color: kBoardGold),
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        t.choose('Trade with', 'যার সাথে বিনিময়'),
                        style: TextStyle(
                          fontFamily: t.font,
                          color: Colors.white70,
                        ),
                      ),
                      DropdownButton<int>(
                        isExpanded: true,
                        value: target,
                        dropdownColor: const Color(0xFF243D3B),
                        style: TextStyle(
                          fontFamily: t.font,
                          color: Colors.white,
                        ),
                        items: [
                          for (final p in recipients)
                            DropdownMenuItem<int>(
                              value: p.id,
                              child: Text(p.name),
                            ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            updateDialog(() {
                              target = v;
                              requested.clear();
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 11),
                      Text(
                        t.choose(
                          'Select any number of eligible properties.',
                          'বিনিময়যোগ্য একাধিক সম্পত্তি নির্বাচন করুন।',
                        ),
                        style: TextStyle(
                          fontFamily: t.font,
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      propertyPicker(
                        t.choose(
                          'Properties you give',
                          'আপনি যে সম্পত্তিগুলো দেবেন',
                        ),
                        owned,
                        offered,
                      ),
                      const SizedBox(height: 15),
                      propertyPicker(
                        t.choose(
                          'Properties you request',
                          'আপনি যে সম্পত্তিগুলো চান',
                        ),
                        theirs,
                        requested,
                      ),
                      const SizedBox(height: 13),
                      TextField(
                        controller: cashFrom,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          fontFamily: t.font,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          labelText: t.choose(
                            'Cash you pay (0 or more)',
                            'আপনি যে টাকা দেবেন (০ বা বেশি)',
                          ),
                          labelStyle: TextStyle(
                            fontFamily: t.font,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      TextField(
                        controller: cashTo,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          fontFamily: t.font,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          labelText: t.choose(
                            'Cash you request (0 or more)',
                            'আপনি যে টাকা চাইবেন (০ বা বেশি)',
                          ),
                          labelStyle: TextStyle(
                            fontFamily: t.font,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(t.choose('CANCEL', 'বাতিল')),
                ),
                FilledButton(
                  onPressed: () {
                    final from = int.tryParse(cashFrom.text.trim());
                    final to = int.tryParse(cashTo.text.trim());
                    if (from == null || to == null || from < 0 || to < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            t.choose(
                              'Enter valid cash amounts.',
                              'সঠিক টাকার পরিমাণ লিখুন।',
                            ),
                          ),
                        ),
                      );
                      return;
                    }
                    if (offered.isEmpty &&
                        requested.isEmpty &&
                        from == 0 &&
                        to == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            t.choose(
                              'Choose properties or cash.',
                              'সম্পত্তি বা টাকা নির্বাচন করুন।',
                            ),
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(dialogContext);
                    unawaited(
                      room.sendTradeOffer(
                        toPlayerId: target,
                        cashFrom: from,
                        cashTo: to,
                        propertiesFrom: offered.toList()..sort(),
                        propertiesTo: requested.toList()..sort(),
                      ),
                    );
                  },
                  child: Text(t.choose('SEND OFFER', 'প্রস্তাব পাঠান')),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      cashFrom.dispose();
      cashTo.dispose();
    }
  }

  Widget _events() => _panel(
    Column(
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
        const SizedBox(height: 8),
        for (final item in game!.log.take(8))
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text(
              '• $item',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
      ],
    ),
  );

  void _showMyProperties() {
    final engine = game;
    if (engine == null) return;
    final owned = engine.spaces
        .where((s) => engine.properties[s.index].ownerId == room.playerId)
        .toList();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1B3031),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(
                t.choose('My properties', 'আমার সম্পত্তি'),
                style: const TextStyle(color: kBoardGold),
              ),
            ),
            for (final space in owned)
              ListTile(
                title: Text(
                  t.spaceName(space.index, space.name),
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: const Icon(Icons.chevron_right, color: kBoardGold),
                onTap: () {
                  Navigator.pop(ctx);
                  _showTile(space.index);
                },
              ),
            if (owned.isEmpty)
              ListTile(
                title: Text(
                  t.choose('No properties yet.', 'এখনো কোনো সম্পত্তি নেই।'),
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showTile(int index) {
    final engine = game;
    if (engine == null) return;
    final tile = engine.spaces[index];
    final property = engine.properties[index];
    final ownedByMe = property.ownerId == room.playerId;
    final allowed = room.isMyTurn && room.pendingTrade == null && ownedByMe;
    final ownerName = property.ownerId == null
        ? t.choose('Unowned', 'মালিকবিহীন')
        : engine.players[property.ownerId!].name;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B3031),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            max(MediaQuery.viewInsetsOf(ctx).bottom, 18.0),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(height: 8, color: groupColor(tile.group)),
                  const SizedBox(height: 14),
                  Text(
                    t.spaceName(tile.index, tile.name),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: t.font,
                      fontFamilyFallback: t.fallbackFonts,
                      color: kBoardGold,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${t.choose('Owner', 'মালিক')}: $ownerName',
                    style: const TextStyle(color: Colors.white),
                  ),
                  Text(
                    '${t.choose('Price', 'দাম')}: ${t.money(tile.price)}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Text(
                    '${t.choose('Buildings', 'ভবন')}: '
                    '${property.development == 5 ? t.choose('Hotel', 'হোটেল') : t.integer(property.development)}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (property.mortgaged)
                    Text(
                      t.choose('MORTGAGED', 'বন্ধক দেওয়া'),
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                  const SizedBox(height: 15),
                  // Server still validates every action, including phase and cash.
                  if (allowed &&
                      property.development < 5 &&
                      tile.kind == SpaceKind.street &&
                      engine.phase != TurnPhase.debt) ...[
                    _primary(
                      t.choose('BUILD HOUSE / HOTEL', 'বাড়ি/হোটেল নির্মাণ'),
                      Icons.add_home_work_outlined,
                      () {
                        Navigator.pop(ctx);
                        _send('build', index: index);
                      },
                    ),
                    const SizedBox(height: 7),
                  ],
                  if (allowed && property.development > 0) ...[
                    _secondary(t.choose('SELL BUILDING', 'ভবন বিক্রি'), () {
                      Navigator.pop(ctx);
                      _send('sellBuilding', index: index);
                    }),
                    const SizedBox(height: 7),
                  ],
                  if (allowed && tile.purchasable) ...[
                    if (property.mortgaged && engine.phase != TurnPhase.debt)
                      _secondary(t.choose('UNMORTGAGE', 'বন্ধক ছাড়ান'), () {
                        Navigator.pop(ctx);
                        _send('unmortgage', index: index);
                      })
                    else if (!property.mortgaged)
                      _secondary(t.choose('MORTGAGE', 'বন্ধক দিন'), () {
                        Navigator.pop(ctx);
                        _send('mortgage', index: index);
                      }),
                    const SizedBox(height: 9),
                  ],
                  _secondary(
                    t.choose('CLOSE', 'বন্ধ করুন'),
                    () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _bankruptcyConfirm() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.choose('Declare bankruptcy?', 'দেউলিয়া ঘোষণা করবেন?')),
        content: Text(
          t.choose(
            'You will be eliminated from this match.',
            'আপনি এই খেলা থেকে বাদ পড়বেন।',
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
    if (mounted && result == true) _send('bankrupt');
  }

  void _bankDialog() {
    final engine = game;
    if (engine == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.choose('Bank inventory', 'ব্যাংকের মজুত')),
        content: Text(
          '${t.choose('Houses', 'বাড়ি')}: '
          '${t.integer(engine.bankHouses)}/32\n'
          '${t.choose('Hotels', 'হোটেল')}: '
          '${t.integer(engine.bankHotels)}/12',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.choose('CLOSE', 'বন্ধ করুন')),
          ),
        ],
      ),
    );
  }
}

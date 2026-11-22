import 'package:flutter/material.dart';

import '../../engine/game_engine.dart';
import '../../models/game_models.dart';
import '../game_text.dart';
import 'dice_face.dart';

const Color _gold = Color(0xFFE9BE67);
const Color _dark = Color(0xFF0B1718);

/// The one primary board action for both regular and full-screen views.
/// This widget never calls GameEngine directly; the owning screen validates
/// turns and performs the action (or submits a request to the LAN host).
class BoardCenterAction extends StatelessWidget {
  const BoardCenterAction({
    super.key,
    required this.engine,
    required this.text,
    this.dicePreview,
    this.diceRolling = false,
    this.onRoll,
    this.onEndTurn,
    this.canAct = false,
    this.onReviewDecision,
    this.canReviewDecision = false,
    this.onViewActivity,
  });

  final GameEngine engine;
  final GameText text;
  final DiceRoll? dicePreview;
  final bool diceRolling;
  final VoidCallback? onRoll;
  final VoidCallback? onEndTurn;
  final bool canAct;
  final VoidCallback? onReviewDecision;
  final bool canReviewDecision;
  final VoidCallback? onViewActivity;

  @override
  Widget build(BuildContext context) {
    final phase = engine.phase;
    final rolling = phase == TurnPhase.roll || phase == TurnPhase.jailDecision;
    final canRoll = rolling && canAct && !diceRolling && onRoll != null;
    final canFinish =
        phase == TurnPhase.complete && canAct && onEndTurn != null;
    final last = dicePreview ?? engine.lastRoll;
    final diceOne = last?.first ?? 1;
    final diceTwo = last?.second ?? 6;
    // Auctions belong to their active bidder, not necessarily the mover.
    final current = phase == TurnPhase.auction && engine.auction != null
        ? engine.players[engine.auction!.bidderId]
        : engine.currentPlayer;
    final solventPlayers = engine.players.where((p) => !p.bankrupt).toList();
    final leader = solventPlayers.isEmpty
        ? engine.currentPlayer
        : solventPlayers.reduce((a, b) => a.balance >= b.balance ? a : b);
    // Cash figures are read from the active GameEngine on every rebuild.
    // If the current player is the cash leader, show the *difference* over
    // the next-richest player instead of repeating the same balance twice.
    final otherCashBalances = solventPlayers
        .where((p) => p.id != leader.id)
        .map((p) => p.balance)
        .toList();
    final runnerUpCash = otherCashBalances.isEmpty
        ? null
        : otherCashBalances.reduce((a, b) => a > b ? a : b);
    final latestEvent = engine.log.isEmpty ? null : engine.log.first;
    final isAction = rolling || phase == TurnPhase.complete;

    String status() {
      switch (phase) {
        case TurnPhase.roll:
          if (diceRolling) return text.choose('ROLLING…', 'পাশা ঘুরছে…');
          return canRoll
              ? text.choose('TAP THE DICE TO ROLL', 'পাশায় চাপ দিয়ে চাল দিন')
              : text.choose(
                  'WAIT FOR YOUR TURN',
                  'আপনার চালের জন্য অপেক্ষা করুন',
                );
        case TurnPhase.complete:
          return text.choose('TURN COMPLETE', 'চাল সম্পন্ন');
        case TurnPhase.purchase:
          return text.choose('BUY OR AUCTION', 'কিনুন অথবা নিলাম করুন');
        case TurnPhase.auction:
          return text.choose('PROPERTY AUCTION', 'সম্পত্তির নিলাম');
        case TurnPhase.jailDecision:
          return canRoll
              ? text.choose('TAP DICE TO TRY DOUBLES', 'ডাবল পেতে পাশায় চাপুন')
              : text.choose('JAIL OPTIONS', 'কারাগারের সিদ্ধান্ত');
        case TurnPhase.debt:
          return text.choose('SETTLE YOUR DEBT', 'ঋণ নিষ্পত্তি করুন');
        case TurnPhase.gameOver:
          return text.choose('MATCH COMPLETE', 'খেলা শেষ');
      }
    }

    // The center HUD contains the logo, scoreboards, dice and activity.
    // Its natural height can exceed the 600 px Flutter test viewport (and
    // some compact landscape layouts). Scale it DOWN as a single unit instead
    // of allowing a RenderFlex overflow. In the 1000x1000 board it retains
    // its original 580 px layout width and scales together with the board.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: SizedBox(
        width: 580,
        child: Semantics(
          container: true,
          label: canRoll
              ? text.choose('Roll two dice', 'দুটি পাশা নিক্ষেপ করুন')
              : status(),
          button: canRoll,
          enabled: canRoll,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.diamond_rounded, color: _gold, size: 46),
              const Text(
                'bHiVE',
                style: TextStyle(
                  fontFamily: 'Exo2',
                  fontSize: 47,
                  fontWeight: FontWeight.w800,
                  color: _gold,
                  letterSpacing: 3,
                ),
              ),
              const Text(
                'MONOPOLY',
                style: TextStyle(
                  fontFamily: 'Exo2',
                  fontSize: 19,
                  letterSpacing: 6,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '${text.choose('TURN', 'চাল')} ${text.integer(engine.turnNumber)}',
                style: TextStyle(
                  fontFamily: text.font,
                  fontFamilyFallback: text.fallbackFonts,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: _gold,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 490,
                child: Text(
                  current.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: text.font,
                    fontFamilyFallback: text.fallbackFonts,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _cashScoreboard(
                current.balance,
                leader.name,
                leader.balance,
                leader.id == current.id,
                phase == TurnPhase.auction,
                runnerUpCash,
              ),
              const SizedBox(height: 20),
              // A generous central hit target; dice never roll when an auction,
              // purchase or remote player's turn is pending.
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey<String>('board-dice-action'),
                  borderRadius: BorderRadius.circular(26),
                  onTap: canRoll ? onRoll : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        RollingDiceFace(
                          value: diceOne,
                          rolling: diceRolling,
                          size: 106,
                        ),
                        const SizedBox(width: 24),
                        RollingDiceFace(
                          value: diceTwo,
                          rolling: diceRolling,
                          size: 106,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  status(),
                  key: ValueKey<TurnPhase>(phase),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: text.font,
                    fontFamilyFallback: text.fallbackFonts,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: (isAction && canAct) ? _gold : Colors.white70,
                  ),
                ),
              ),
              if (latestEvent != null) ...<Widget>[
                const SizedBox(height: 16),
                _latestActivity(latestEvent),
              ],
              if (canReviewDecision &&
                  onReviewDecision != null &&
                  phase != TurnPhase.roll &&
                  phase != TurnPhase.complete &&
                  phase != TurnPhase.gameOver) ...<Widget>[
                const SizedBox(height: 14),
                SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: onReviewDecision,
                    icon: const Icon(Icons.keyboard_arrow_up_rounded),
                    label: Text(
                      text.choose('REVIEW OPTIONS', 'সিদ্ধান্তের বিকল্প দেখুন'),
                      style: TextStyle(
                        fontFamily: text.font,
                        fontFamilyFallback: text.fallbackFonts,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _gold,
                      side: const BorderSide(color: _gold, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                ),
              ],
              if (canFinish) ...<Widget>[
                const SizedBox(height: 16),
                SizedBox(
                  width: 320,
                  height: 62,
                  child: FilledButton.icon(
                    key: const ValueKey<String>('board-end-turn-action'),
                    onPressed: onEndTurn,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 22),
                    label: Text(
                      text.choose('END TURN', 'চাল শেষ করুন'),
                      style: TextStyle(
                        fontFamily: text.font,
                        fontFamilyFallback: text.fallbackFonts,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: _dark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ), // Column
        ), // Semantics
      ), // SizedBox (finite width for flexible scoreboard rows)
    ); // FittedBox
  }

  Widget _cashScoreboard(
    int currentCash,
    String leaderName,
    int leaderCash,
    bool currentIsLeader,
    bool isAuction,
    int? runnerUpCash,
  ) {
    TextStyle labelStyle() => TextStyle(
      color: Colors.white70,
      fontFamily: text.font,
      fontFamilyFallback: text.fallbackFonts,
      fontWeight: FontWeight.w600,
      fontSize: 15,
    );
    TextStyle moneyStyle() => TextStyle(
      color: _gold,
      fontFamily: text.font,
      fontFamilyFallback: text.fallbackFonts,
      fontWeight: FontWeight.w800,
      fontSize: 24,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 580),
      child: DecoratedBox(
        key: const ValueKey<String>('board-cash-scoreboard'),
        decoration: BoxDecoration(
          color: const Color(0xD9102828),
          border: Border.all(color: _gold.withValues(alpha: .62), width: 1.6),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x38000000),
              blurRadius: 18,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      isAuction
                          ? text.choose('BIDDER CASH', 'দরদাতার নগদ')
                          : text.choose('CURRENT CASH', 'বর্তমান নগদ'),
                      maxLines: 1,
                      style: labelStyle(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      text.money(currentCash),
                      key: const ValueKey<String>('board-current-cash'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: moneyStyle(),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1.4,
                height: 47,
                color: _gold.withValues(alpha: .33),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.emoji_events_rounded,
                          size: 17,
                          color: _gold,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            currentIsLeader && runnerUpCash != null
                                ? text.choose('CASH ADVANTAGE', 'নগদে এগিয়ে')
                                : text.choose('CASH LEADER', 'সর্বোচ্চ নগদ'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: labelStyle(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentIsLeader && runnerUpCash != null
                          ? text.choose(
                              'Ahead of next player',
                              'পরের খেলোয়াড়ের চেয়ে এগিয়ে',
                            )
                          : leaderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: text.font,
                        fontFamilyFallback: text.fallbackFonts,
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      currentIsLeader && runnerUpCash != null
                          ? '+${text.money(leaderCash - runnerUpCash)}'
                          : text.money(leaderCash),
                      key: const ValueKey<String>('board-leader-cash'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: moneyStyle().copyWith(fontSize: 19),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _latestActivity(String latestEvent) {
    final formatted = text.moneyInEvent(latestEvent);
    final lower = latestEvent.toLowerCase();
    final icon = lower.contains('bids') || lower.contains('auction')
        ? Icons.gavel_rounded
        : lower.contains('purchased') ||
              lower.contains('paid') ||
              lower.contains('rent')
        ? Icons.payments_outlined
        : lower.contains('rolled')
        ? Icons.casino_outlined
        : Icons.bolt_rounded;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 580),
      child: Material(
        color: const Color(0xB51C3A38),
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          key: const ValueKey<String>('board-latest-activity'),
          borderRadius: BorderRadius.circular(15),
          onTap: onViewActivity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: <Widget>[
                Icon(icon, color: _gold, size: 27),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        text.choose('LATEST ACTIVITY', 'সর্বশেষ ঘটনা'),
                        style: TextStyle(
                          fontFamily: text.font,
                          fontFamilyFallback: text.fallbackFonts,
                          color: _gold,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          formatted,
                          key: ValueKey<String>(formatted),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: text.font,
                            fontFamilyFallback: text.fallbackFonts,
                            color: Colors.white,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onViewActivity != null)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _gold,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

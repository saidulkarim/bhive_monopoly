import 'package:flutter/material.dart';
import '../../../core/config/game_config.dart';

import '../../engine/game_engine.dart';
import '../../experience/token_preferences.dart';
import '../../experience/player_palette.dart';
import '../game_text.dart';
import 'game_board_view.dart';

/// A compact, horizontally scrolling cash scoreboard. Used both above the
/// regular board and on the full-screen explorer on small devices.
/// "Cash leader" intentionally ranks CASH, not total net worth.
class CompactPlayersStrip extends StatelessWidget {
  const CompactPlayersStrip({
    super.key,
    required this.game,
    required this.text,
    this.onPlayerTap,
    this.selectedPlayerId,
    this.vertical = false,
  });

  final GameEngine game;
  final GameText text;
  final ValueChanged<int>? onPlayerTap;
  final int? selectedPlayerId;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final remaining = game.players.where((p) => !p.bankrupt).toList();
    final leader = remaining.isEmpty
        ? game.currentPlayer
        : remaining.reduce((a, b) => a.balance >= b.balance ? a : b);

    return AnimatedBuilder(
      animation: TokenPreferences.instance,
      builder: (context, _) => SizedBox(
        height: vertical ? null : 82,
        child: ListView.separated(
          scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          itemCount: game.players.length,
          separatorBuilder: (_, _) => vertical
              ? const SizedBox(height: GameConfig.landscapePlayerCardSpacing)
              : const SizedBox(width: 9),
          itemBuilder: (context, index) {
            final p = game.players[index];
            final active = p.id == game.currentPlayerId;
            final leading = !p.bankrupt && p.id == leader.id;
            final selected = selectedPlayerId == p.id;
            return Semantics(
              button: onPlayerTap != null,
              selected: onPlayerTap == null ? null : selected,
              child: GestureDetector(
                onTap: onPlayerTap == null ? null : () => onPlayerTap!(p.id),
                child: AnimatedContainer(
                  key: ValueKey<String>('player-cash-card-${p.id}'),
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeInOut,
                  width: vertical ? null : 191,
                  height: vertical ? 74 : null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: active
                          ? const [Color(0xFF306452), Color(0xFF1A403B)]
                          : const [Color(0xFF20383A), Color(0xFF162A2D)],
                    ),
                    border: Border.all(
                      color: active ? kBoardGold : Colors.white24,
                      width: active ? 1.5 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: active
                        ? const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x28000000),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ]
                        : const <BoxShadow>[],
                  ),
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: PlayerPalette.at(p.colorIndex),
                        child: Icon(
                          TokenPreferences.instance.styleFor(p.id).icon,
                          color: kBoardDark,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: text.font,
                                      fontFamilyFallback: text.fallbackFonts,
                                      color: p.bankrupt
                                          ? Colors.white38
                                          : Colors.white,
                                      fontWeight: active
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                if (selected)
                                  const Icon(
                                    Icons.check_circle,
                                    color: kBoardGold,
                                    size: 16,
                                  ),
                                if (leading)
                                  Tooltip(
                                    message: text.choose(
                                      'Highest cash balance',
                                      'সর্বোচ্চ নগদ অর্থ',
                                    ),
                                    child: const Icon(
                                      Icons.emoji_events_rounded,
                                      color: kBoardGold,
                                      size: 17,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              text.money(p.balance),
                              key: ValueKey<String>('player-cash-${p.id}'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: p.bankrupt ? Colors.white38 : kBoardGold,
                                fontFamily: text.font,
                                fontFamilyFallback: text.fallbackFonts,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (leading)
                              Text(
                                text.choose('CASH LEADER', 'সর্বোচ্চ নগদ'),
                                maxLines: 1,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontFamily: text.font,
                                  fontFamilyFallback: text.fallbackFonts,
                                  fontSize: 9,
                                  height: 1.1,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

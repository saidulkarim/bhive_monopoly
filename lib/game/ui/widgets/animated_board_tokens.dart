import 'package:flutter/material.dart';

import '../../engine/game_engine.dart';
import '../../experience/game_experience_settings.dart';
import '../../experience/token_preferences.dart';
import 'dice_face.dart';

/// Pure screen geometry; the same 1000px logical surface is used on phones,
/// tablets and browsers. Each of the 40 indexes is on the outer 11x11 ring.
class BoardTokenGeometry {
  const BoardTokenGeometry._();

  static const double cell = 1000 / 11;
  static const double tokenExtent = 29;

  static (int, int) gridPosition(int index) {
    RangeError.checkValueInInterval(index, 0, 39, 'index');
    if (index <= 10) return (10, 10 - index);
    if (index <= 20) return (20 - index, 0);
    if (index <= 30) return (0, index - 20);
    return (index - 30, 10);
  }

  /// Top-left of the icon for one player's stable six-slot tile position.
  /// Players remain individually visible when multiple tokens share a tile.
  static Offset tokenTopLeft(int index, int playerId) {
    RangeError.checkValueInInterval(playerId, 0, 5, 'playerId');
    final (row, column) = gridPosition(index);
    final dx = (playerId % 3 - 1) * 24.0;
    final dy = (playerId ~/ 3 == 0 ? -15.0 : 15.0);
    return Offset(
      (column + 0.5) * cell + dx - tokenExtent / 2,
      (row + 0.5) * cell + dy - tokenExtent / 2,
    );
  }
}

/// Lightweight moving tokens overlaid on the whole board rather than rebuilt
/// inside each tile. The authoritative positions live in GameEngine; a
/// presentation-only map supplies the intermediate position while animating.
/// No new game state is written, no LAN packets are changed.
class AnimatedBoardTokens extends StatelessWidget {
  const AnimatedBoardTokens({
    super.key,
    required this.game,
    required this.visiblePositions,
  });

  final GameEngine game;
  final Map<int, int> visiblePositions;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        GameExperienceSettings.instance.reducedMotion ||
        MediaQuery.maybeOf(context)?.disableAnimations == true;
    return IgnorePointer(
      child: Stack(
        children: [
          for (final player in game.players)
            if (!player.bankrupt)
              AnimatedPositioned(
                key: ValueKey<String>('phase11-token-${player.id}'),
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 68),
                curve: Curves.easeInOut,
                left: BoardTokenGeometry.tokenTopLeft(
                  visiblePositions[player.id] ?? player.position,
                  player.id,
                ).dx,
                top: BoardTokenGeometry.tokenTopLeft(
                  visiblePositions[player.id] ?? player.position,
                  player.id,
                ).dy,
                width: BoardTokenGeometry.tokenExtent,
                height: BoardTokenGeometry.tokenExtent,
                child: RepaintBoundary(
                  child: BoardToken(
                    color: _playerColors[player.id],
                    playerId: player.id,
                    styleIndex: TokenPreferences.instance.selectionFor(
                      player.id,
                    ),
                    isActive: player.id == game.currentPlayerId,
                    size: BoardTokenGeometry.tokenExtent,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

// Keep the established player colors; this avoids importing GameBoardView and
// creating a widget-file import cycle.
const List<Color> _playerColors = <Color>[
  Color(0xFFE8AD61),
  Color(0xFF6BC8EF),
  Color(0xFFF383AF),
  Color(0xFF93DB8A),
  Color(0xFFCD9AFE),
  Color(0xFFF6E47B),
];

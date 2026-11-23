import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/game_engine.dart';
import '../../experience/game_experience_settings.dart';
import '../../experience/token_preferences.dart';
import '../../experience/player_palette.dart';
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
                child: _TokenLocationAura(
                  key: ValueKey<String>('player-token-aura-${player.id}'),
                  color: PlayerPalette.at(player.colorIndex),
                  isCurrentTurn: player.id == game.currentPlayerId,
                  reducedMotion: reduceMotion,
                  child: BoardToken(
                    color: PlayerPalette.at(player.colorIndex),
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

/// Always-visible personal halo around EACH player's token. This is an extra
/// cue when two or more players are standing on the same board square.
class _TokenLocationAura extends StatefulWidget {
  const _TokenLocationAura({
    super.key,
    required this.color,
    required this.isCurrentTurn,
    required this.reducedMotion,
    required this.child,
  });

  final Color color;
  final bool isCurrentTurn;
  final bool reducedMotion;
  final Widget child;

  @override
  State<_TokenLocationAura> createState() => _TokenLocationAuraState();
}

class _TokenLocationAuraState extends State<_TokenLocationAura>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
    value: .30,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant _TokenLocationAura oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reducedMotion != widget.reducedMotion) _syncMotion();
  }

  void _syncMotion() {
    final disabled =
        widget.reducedMotion ||
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    if (disabled) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox(
      width: BoardTokenGeometry.tokenExtent,
      height: BoardTokenGeometry.tokenExtent,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            width: 49,
            height: 49,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => CustomPaint(
                  painter: _TokenAuraPainter(
                    color: widget.color,
                    active: widget.isCurrentTurn,
                    progress: widget.reducedMotion ? .55 : _pulse.value,
                  ),
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    ),
  );
}

class _TokenAuraPainter extends CustomPainter {
  const _TokenAuraPainter({
    required this.color,
    required this.active,
    required this.progress,
  });
  final Color color;
  final bool active;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final pulse = .5 - .5 * math.cos(2 * math.pi * progress);
    canvas.drawCircle(
      center,
      20,
      Paint()
        ..color = color.withValues(alpha: .38 + .31 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 5.2 : 3.2
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6.5),
    );
    canvas.drawCircle(
      center,
      19,
      Paint()
        ..color = color.withValues(alpha: .80 + .19 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 3.6 : 2.8,
    );
    if (active) {
      canvas.drawCircle(
        center,
        22,
        Paint()
          ..color = Colors.white.withValues(alpha: .27 + .32 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TokenAuraPainter old) =>
      color != old.color || active != old.active || progress != old.progress;
}

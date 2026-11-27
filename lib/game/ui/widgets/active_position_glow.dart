// ignore_for_file: deprecated_member_use, unnecessary_underscores

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/ui/visual_activity_scope.dart';
import '../../../core/ui/graphics_resource_policy.dart';
import 'package:flutter/foundation.dart' show listEquals;

/// A conspicuous but non-blocking position highlight for EVERY player.
///
/// Each occupied tile gets an animated player-coloured frame. When more than
/// one player occupies a tile, the perimeter is divided into their colours.
/// The current turn is brighter, but other players never lose their marker.
/// The effect is decorative and does not change board or network state.
class ActivePositionGlow extends StatefulWidget {
  const ActivePositionGlow({
    super.key,
    required this.color,
    this.colors = const <Color>[],
    this.isCurrentTurn = true,
    this.reducedMotion = false,
    this.pulseCycles = 1,
  });

  /// Primary occupant / current player colour (kept for Phase 13.4 callers).
  final Color color;

  /// All occupants' colours. An empty list means just [color].
  final List<Color> colors;
  final bool isCurrentTurn;
  final bool reducedMotion;
  final int pulseCycles;

  @override
  State<ActivePositionGlow> createState() => _ActivePositionGlowState();
}

class _ActivePositionGlowState extends State<ActivePositionGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2100),
    value: 1,
  );

  bool? _allowed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant ActivePositionGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reducedMotion != oldWidget.reducedMotion ||
        widget.pulseCycles != oldWidget.pulseCycles ||
        widget.isCurrentTurn != oldWidget.isCurrentTurn ||
        widget.color != oldWidget.color ||
        !listEquals(widget.colors, oldWidget.colors)) {
      _syncMotion(restart: true);
    }
  }

  void _syncMotion({bool restart = false}) {
    final allowed =
        !widget.reducedMotion &&
        widget.pulseCycles > 0 &&
        VisualActivityScope.isForegroundOf(context) &&
        VisualActivityScope.allowsIdleDecorationOf(context) &&
        TickerMode.of(context) &&
        ModalRoute.isCurrentOf(context) != false &&
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    final firstEvaluation = _allowed == null;
    _allowed = allowed;
    if (!allowed) {
      _controller.stop();
      _controller.value = 1;
    } else if (firstEvaluation || restart) {
      // A finite pulse, never an idle frame loop.
      _controller.duration = Duration(milliseconds: 2100 * widget.pulseCycles);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) => CustomPaint(
            painter: _PositionGlowPainter(
              colors: widget.colors.isEmpty
                  ? <Color>[widget.color]
                  : widget.colors,
              primary: widget.color,
              isCurrentTurn: widget.isCurrentTurn,
              progress: (_controller.value * widget.pulseCycles) % 1,
              staticEffect: _allowed != true || _controller.value >= 1,
              softGlow: GraphicsResourcePolicy.useSoftGlow(widget.pulseCycles),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _PositionGlowPainter extends CustomPainter {
  const _PositionGlowPainter({
    required this.colors,
    required this.primary,
    required this.isCurrentTurn,
    required this.progress,
    required this.staticEffect,
    required this.softGlow,
  });

  final List<Color> colors;
  final Color primary;
  final bool isCurrentTurn;
  final double progress;
  final bool staticEffect;
  final bool softGlow;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // The board is a 1000-px surface scaled to phone width. A thin 2-px
    // stroke vanishes at 35% scale, so the visible perimeter is 5–7 px.
    final pulse = staticEffect
        ? .6
        : .5 - .5 * math.cos(2 * math.pi * progress);
    final rect = Rect.fromLTWH(
      4,
      4,
      math.max(0, size.width - 8),
      math.max(0, size.height - 8),
    );
    if (rect.width == 0 || rect.height == 0) return;
    final frame = RRect.fromRectAndRadius(rect, const Radius.circular(7));

    // A stronger active-turn aura is visible even after the 1000px board is
    // scaled onto a small phone. Other players keep their quieter colors.
    if (isCurrentTurn && softGlow) {
      canvas.drawRRect(
        frame.inflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..color = primary.withValues(alpha: .33 + .34 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
    }

    // Soft interior colour wash. Draw over the tile *after* its text: it stays
    // visible on dark group stripes as well as special squares.
    canvas.drawRRect(
      frame,
      Paint()
        ..color = primary.withValues(
          alpha: isCurrentTurn ? .13 + .16 * pulse : .10 + .11 * pulse,
        ),
    );

    if (softGlow) {
      canvas.drawRRect(
        frame,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6.5
          ..color = primary.withValues(
            alpha: isCurrentTurn ? .42 + .32 * pulse : .28 + .24 * pulse,
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 + pulse * 4),
      );
    }

    // A moving translucent highlight across the tile for all players.
    if (!staticEffect) {
      final x = -size.width * .65 + size.width * 2.1 * progress;
      final sheen = Path()
        ..moveTo(x, 0)
        ..lineTo(x + size.width * .22, 0)
        ..lineTo(x - size.width * .16, size.height)
        ..lineTo(x - size.width * .39, size.height)
        ..close();
      canvas.save();
      canvas.clipRRect(frame);
      // The old 0.075–0.11 alpha sheen was almost invisible once the
      // 1000-px board was scaled to a phone. Higher-opacity gradient light
      // with eased entry/exit remains visible without obscuring text.
      final visibility = math.sin(math.pi * progress).clamp(0.0, 1.0);
      final peak = (isCurrentTurn ? .48 : .35) * visibility;
      canvas.drawPath(
        sheen,
        Paint()
          ..shader =
              LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: const <double>[0, .22, .50, .78, 1],
                colors: <Color>[
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: peak * .25),
                  Colors.white.withValues(alpha: peak),
                  Colors.white.withValues(alpha: peak * .22),
                  Colors.white.withValues(alpha: 0),
                ],
              ).createShader(
                Rect.fromLTWH(
                  x - size.width * .39,
                  0,
                  size.width * .61,
                  size.height,
                ),
              ),
      );
      canvas.restore();
    }

    final thickness = isCurrentTurn ? 6.5 : 5.2;
    if (colors.length <= 1) {
      canvas.drawRRect(
        frame,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness
          ..color = primary.withValues(alpha: .83 + .16 * pulse),
      );
    } else {
      // Adjacent people on one square: show *every* colour, not just the
      // currently active person. Each gets a visible perimeter segment.
      final path = Path()..addRRect(frame);
      final metric = path.computeMetrics().first;
      for (var i = 0; i < colors.length; ++i) {
        final from = metric.length * i / colors.length;
        final to = metric.length * (i + 1) / colors.length;
        canvas.drawPath(
          metric.extractPath(from, to),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = thickness
            ..color = colors[i].withValues(alpha: .83 + .16 * pulse),
        );
      }
    }
    if (isCurrentTurn) {
      canvas.drawRRect(
        frame.deflate(5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Colors.white.withValues(alpha: .43 + .35 * pulse),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PositionGlowPainter previous) {
    if (previous.progress != progress ||
        previous.primary != primary ||
        previous.staticEffect != staticEffect ||
        previous.softGlow != softGlow ||
        previous.isCurrentTurn != isCurrentTurn ||
        previous.colors.length != colors.length) {
      return true;
    }
    for (var i = 0; i < colors.length; i++) {
      if (colors[i] != previous.colors[i]) return true;
    }
    return false;
  }
}

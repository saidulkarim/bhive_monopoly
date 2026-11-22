// ignore_for_file: deprecated_member_use

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../experience/game_experience_settings.dart';

/// One-time, asset-free celebration. Ignores touches; reduced-motion users
/// see the normal trophy and winner text without moving particles.
class VictoryConfetti extends StatefulWidget {
  const VictoryConfetti({super.key});

  @override
  State<VictoryConfetti> createState() => _VictoryConfettiState();
}

class _VictoryConfettiState extends State<VictoryConfetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2900),
  );

  @override
  void initState() {
    super.initState();
    if (!GameExperienceSettings.instance.reducedMotion) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _ConfettiPainter(_controller.value),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.progress);
  final double progress;

  static const List<Color> palette = <Color>[
    Color(0xFFE9BE67),
    Color(0xFF68D2B6),
    Color(0xFFFFD48D),
    Color(0xFFE78AB6),
    Color(0xFF9CBCEB),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final opacity = (1 - progress).clamp(0.0, 1.0);
    final paint = Paint()..style = PaintingStyle.fill;
    for (var index = 0; index < 74; index++) {
      final initialX = ((index * 197 + 71) % 997) / 997;
      final speed = 0.45 + ((index * 29) % 100) / 135;
      final initialY = -0.35 - ((index * 31) % 100) / 180;
      final drift = math.sin(progress * 9 + index * 1.7) * 23;
      final x = size.width * initialX + drift;
      final y = size.height * (initialY + progress * speed * 2.1);
      if (y < -20 || y > size.height + 20) continue;
      paint.color = palette[index % palette.length].withOpacity(opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * 11 + index.toDouble());
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: 5 + index % 5,
            height: 11 + index % 8,
          ),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

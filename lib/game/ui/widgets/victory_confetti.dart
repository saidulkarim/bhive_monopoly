// ignore_for_file: deprecated_member_use

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../experience/game_experience_settings.dart';
import '../../../core/config/game_config.dart';

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
    duration: const Duration(seconds: GameConfig.victoryCelebrationSeconds),
  );

  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced =
        GameExperienceSettings.instance.effectiveReducedMotion ||
        MediaQuery.maybeOf(context)?.disableAnimations == true;
    if (reduced) {
      _controller.value = 1;
      _started = true;
    } else if (!_started) {
      _started = true;
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
        painter: _ConfettiPainter(
          _controller.value,
          switch (GameExperienceSettings.instance.powerProfile) {
            GamePowerProfile.performance =>
              GameConfig.performanceConfettiParticles,
            GamePowerProfile.balanced => GameConfig.balancedConfettiParticles,
            GamePowerProfile.batterySaver =>
              GameConfig.batterySaverConfettiParticles,
            GamePowerProfile.ultraSaver => 0,
          },
        ),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.progress, this.count);
  final int count;
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
    final fireProgress =
        progress *
        GameConfig.victoryCelebrationSeconds /
        GameConfig.victoryFireworksSeconds;
    if (count > 0 && fireProgress < 1) {
      for (var burst = 0; burst < 3; burst++) {
        final center = Offset(
          size.width * (.22 + burst * .28),
          size.height * (.24 + (burst % 2) * .14),
        );
        for (var ray = 0; ray < count ~/ 5; ray++) {
          final angle = ray * 2 * math.pi / (count ~/ 5);
          final radius = fireProgress * 85;
          final direction = Offset(math.cos(angle), math.sin(angle));
          paint.color = palette[(ray + burst) % palette.length].withValues(
            alpha: 1 - fireProgress,
          );
          paint.strokeWidth = 2;
          canvas.drawLine(
            center + direction * (radius * .75),
            center + direction * radius,
            paint,
          );
        }
      }
    }
    for (var index = 0; index < count; index++) {
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
      oldDelegate.progress != progress || oldDelegate.count != count;
}

/// Static metallic cup, no model loader or extra rendering loop.
class PremiumVictoryTrophy extends StatelessWidget {
  const PremiumVictoryTrophy({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: GameConfig.victoryTrophySize,
    height: GameConfig.victoryTrophySize,
    child: CustomPaint(painter: _TrophyPainter()),
  );
}

class _TrophyPainter extends CustomPainter {
  const _TrophyPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final gold = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFB57B24),
          Color(0xFFFFE9A1),
          Color(0xFFD9A63E),
          Color(0xFF986018),
        ],
      ).createShader(const Rect.fromLTWH(15, 0, 70, 85));
    final handle = Paint()
      ..color = const Color(0xFFE9BE67)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawOval(const Rect.fromLTWH(8, 18, 36, 35), handle);
    canvas.drawOval(const Rect.fromLTWH(56, 18, 36, 35), handle);
    final cup = Path()
      ..moveTo(25, 12)
      ..lineTo(75, 12)
      ..quadraticBezierTo(76, 52, 56, 62)
      ..lineTo(56, 76)
      ..lineTo(67, 81)
      ..lineTo(33, 81)
      ..lineTo(44, 76)
      ..lineTo(44, 62)
      ..quadraticBezierTo(24, 52, 25, 12)
      ..close();
    canvas.drawPath(cup, gold);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(26, 81, 48, 12),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF20534B),
    );
    canvas.drawRect(const Rect.fromLTWH(32, 86, 36, 3), gold);
    final diamond = Path()
      ..moveTo(50, 25)
      ..lineTo(64, 38)
      ..lineTo(50, 52)
      ..lineTo(36, 38)
      ..close();
    canvas.drawPath(diamond, Paint()..color = const Color(0xFF20534B));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TrophyPainter oldDelegate) => false;
}

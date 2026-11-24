import 'package:flutter/material.dart';

/// A small, accessible prison-cell icon for the two jail corner squares.
/// Drawn from Flutter primitives so it works offline, on Android and Web.
/// It is deliberately overlaid on the tile, not added to the text Column.
class JailTileMarker extends StatelessWidget {
  const JailTileMarker({
    super.key,
    required this.goToJail,
    this.size = 26,
    this.label,
  });

  final bool goToJail;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label ?? (goToJail ? 'Go to Jail' : 'Jail / Just Visiting'),
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xF3102325),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: const Color(0xFFE9BE67), width: 1.4),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _PrisonBarsPainter()),
              ),
              Center(
                child: Icon(
                  goToJail ? Icons.lock_rounded : Icons.lock_outline_rounded,
                  size: size * 0.43,
                  color: const Color(0xFFFFE0A0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrisonBarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE9BE67).withValues(alpha: 0.82)
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round;
    // The outer tile frame is provided by the DecoratedBox. The bars form
    // a recognizable cell even when the board is scaled on a small phone.
    for (final fraction in <double>[0.2, 0.8]) {
      final x = size.width * fraction;
      canvas.drawLine(Offset(x, 3), Offset(x, size.height - 3), paint);
    }
    final horizontal = Paint()
      ..color = const Color(0xFFE9BE67).withValues(alpha: 0.60)
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(3, size.height * 0.30),
      Offset(size.width - 3, size.height * 0.30),
      horizontal,
    );
  }

  @override
  bool shouldRepaint(covariant _PrisonBarsPainter oldDelegate) => false;
}

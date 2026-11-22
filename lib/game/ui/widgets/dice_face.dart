// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

/// Asset-free raised dice with real pip patterns (1..6). Works on Android/web.
class DiceFace extends StatelessWidget {
  const DiceFace({
    super.key,
    required this.value,
    this.size = 70,
    this.angle = 0,
  });

  final int value;
  final double size;
  final double angle;

  static const List<List<int>> _pipPositions = <List<int>>[
    <int>[],
    <int>[4],
    <int>[0, 8],
    <int>[0, 4, 8],
    <int>[0, 2, 6, 8],
    <int>[0, 2, 4, 6, 8],
    <int>[0, 2, 3, 5, 6, 8],
  ];

  @override
  Widget build(BuildContext context) {
    final pipSize = size * .13;
    final indexes = _pipPositions[value.clamp(1, 6).toInt()];
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * .18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFEFE9D8), Color(0xFFD6CDAF)],
          ),
          border: Border.all(
            color: const Color(0xFFFFFFFF),
            width: size * .025,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.55),
              blurRadius: size * .16,
              offset: Offset(size * .07, size * .11),
            ),
            BoxShadow(
              color: const Color(0xFFDCC595),
              blurRadius: size * .015,
              offset: Offset(-size * .025, -size * .025),
            ),
          ],
        ),
        child: Stack(
          children: [
            for (final index in indexes)
              Positioned(
                left: (size * (.22 + (index % 3) * .28)) - pipSize / 2,
                top: (size * (.22 + (index ~/ 3) * .28)) - pipSize / 2,
                child: Container(
                  width: pipSize,
                  height: pipSize,
                  decoration: const BoxDecoration(
                    color: Color(0xFF162B2C),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small raised token, with icon-based shape (not just a colored number).
class BoardToken extends StatelessWidget {
  const BoardToken({
    super.key,
    required this.color,
    required this.playerId,
    this.size = 25,
    this.isActive = false,
  });

  final Color color;
  final int playerId;
  final double size;
  final bool isActive;

  static const List<IconData> shapes = <IconData>[
    Icons.directions_car_filled_rounded,
    Icons.sailing_rounded,
    Icons.star_rounded,
    Icons.flight_rounded,
    Icons.diamond_rounded,
    Icons.rocket_launch_rounded,
  ];

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        center: const Alignment(-.38, -.45),
        radius: 1.1,
        colors: [Colors.white, color, color.withOpacity(.72)],
        stops: const [.0, .24, 1],
      ),
      border: Border.all(
        color: isActive ? Colors.white : const Color(0xFF253938),
        width: isActive ? 2.1 : 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.65),
          offset: const Offset(2, 4),
          blurRadius: 4,
        ),
      ],
    ),
    child: Icon(
      shapes[playerId % shapes.length],
      size: size * .56,
      color: const Color(0xFF152A2D),
    ),
  );
}

class BuildingPieces extends StatelessWidget {
  const BuildingPieces({super.key, required this.development});
  final int development;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 18,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (development == 5)
          const Icon(
            Icons.apartment_rounded,
            color: Color(0xFFEF736B),
            size: 20,
          )
        else
          for (var i = 0; i < development; i++)
            Container(
              width: 12,
              height: 13,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF78D594),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: const Color(0xFF225942), width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    offset: Offset(1, 2),
                    blurRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.home_filled,
                size: 8,
                color: Color(0xFF145D3D),
              ),
            ),
      ],
    ),
  );
}

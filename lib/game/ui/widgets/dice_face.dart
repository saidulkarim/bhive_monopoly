// ignore_for_file: deprecated_member_use

import 'dart:math' as math;

import '../../experience/game_experience_settings.dart';
import '../../experience/token_preferences.dart';

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

/// A responsive, low-cost 2.5D dice wobble. Final values remain sourced
/// exclusively from GameEngine (offline) or the authoritative LAN host.
class RollingDiceFace extends StatefulWidget {
  const RollingDiceFace({
    super.key,
    required this.value,
    required this.rolling,
    this.size = 70,
  });
  final int value;
  final bool rolling;
  final double size;

  @override
  State<RollingDiceFace> createState() => _RollingDiceFaceState();
}

class _RollingDiceFaceState extends State<RollingDiceFace>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  @override
  void initState() {
    super.initState();
    _updateAnimation();
  }

  @override
  void didUpdateWidget(covariant RollingDiceFace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rolling != widget.rolling) _updateAnimation();
  }

  void _updateAnimation() {
    if (widget.rolling && !GameExperienceSettings.instance.reducedMotion) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final theta = _controller.value * math.pi * 2;
      final matrix = Matrix4.identity()
        ..setEntry(3, 2, .002)
        ..rotateX(widget.rolling ? math.sin(theta) * .36 : 0.0)
        ..rotateY(widget.rolling ? math.cos(theta) * .31 : 0.0)
        ..rotateZ(widget.rolling ? math.sin(theta * .5) * .10 : 0.0);
      return Transform(
        alignment: Alignment.center,
        transform: matrix,
        child: child,
      );
    },
    child: DiceFace(value: widget.value, size: widget.size),
  );
}

/// Small raised token, with icon-based shape (not just a colored number).
class BoardToken extends StatefulWidget {
  const BoardToken({
    super.key,
    required this.color,
    required this.playerId,
    this.size = 25,
    this.isActive = false,
    this.styleIndex,
  });

  final Color color;
  final int playerId;
  final double size;
  final bool isActive;
  final int? styleIndex;

  static const List<IconData> shapes = <IconData>[
    Icons.directions_car_filled_rounded,
    Icons.sailing_rounded,
    Icons.star_rounded,
    Icons.flight_rounded,
    Icons.diamond_rounded,
    Icons.rocket_launch_rounded,
  ];

  @override
  State<BoardToken> createState() => _BoardTokenState();
}

class _BoardTokenState extends State<BoardToken>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrival = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );

  @override
  void initState() {
    super.initState();
    if (GameExperienceSettings.instance.reducedMotion) {
      _arrival.value = 1;
    } else {
      _arrival.forward();
    }
  }

  @override
  void dispose() {
    _arrival.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _arrival,
    builder: (context, child) {
      final v = Curves.easeOutBack.transform(_arrival.value);
      final hop = math.sin(math.pi * _arrival.value) * 7;
      return Transform.translate(
        offset: Offset(0, -hop),
        child: Transform.scale(scale: .82 + .18 * v, child: child),
      );
    },
    child: AnimatedContainer(
      duration: GameExperienceSettings.instance.reducedMotion
          ? Duration.zero
          : const Duration(milliseconds: 230),
      curve: Curves.easeOutCubic,
      width: widget.size,
      height: widget.size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-.38, -.45),
          radius: 1.1,
          colors: [Colors.white, widget.color, widget.color.withOpacity(.72)],
          stops: const [.0, .24, 1],
        ),
        border: Border.all(
          color: widget.isActive ? Colors.white : const Color(0xFF253938),
          width: widget.isActive ? 2.1 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.65),
            offset: const Offset(2, 4),
            blurRadius: 4,
          ),
          if (widget.isActive)
            BoxShadow(
              color: widget.color.withOpacity(.90),
              blurRadius: widget.size * .36,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Icon(
        TokenCatalog
            .styles[(widget.styleIndex ?? widget.playerId) %
                TokenCatalog.styles.length]
            .icon,
        size: widget.size * .56,
        color: const Color(0xFF152A2D),
      ),
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

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../experience/game_experience_settings.dart';
import '../../experience/token_preferences.dart';

/// Modern, softly bevelled porcelain die face. The pip layout is the
/// standard one-to-six arrangement, including the correct four corner pips
/// for four and two vertical columns for six.
///
/// This public widget is kept for compatibility with Phase 13 tests and
/// with callers that render a flat die elsewhere in the application.
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
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _PorcelainFacePainter(value.clamp(1, 6).toInt()),
      ),
    ),
  );
}

/// Paints a high-quality die front: ivory ceramic, delicate double rim and
/// slightly recessed dark teal pips. Pure Canvas: no images, shaders from
/// external packages or platform-specific 3D support are required.
class _PorcelainFacePainter extends CustomPainter {
  const _PorcelainFacePainter(this.value);

  final int value;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.width;
    final rect = Offset.zero & size;
    final rim = RRect.fromRectAndRadius(
      rect.deflate(side * .012),
      Radius.circular(side * .185),
    );

    // Soft porcelain with a warm highlight and a cooler shaded bottom.
    canvas.drawRRect(
      rim,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: <double>[0, .48, 1],
          colors: <Color>[
            Color(0xFFFFFFFF),
            Color(0xFFF1F3F5),
            Color(0xFFDCE0E3),
          ],
        ).createShader(rect),
    );

    // Two slim bevel strokes read as a rounded, premium ceramic edge.
    canvas.drawRRect(
      rim,
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * .022,
    );
    canvas.drawRRect(
      rim.deflate(side * .026),
      Paint()
        ..color = const Color(0x9BFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * .012,
    );

    // Diagonal gloss catches ambient light without washing out the pips.
    final sheen = Path()
      ..moveTo(side * .12, side * .28)
      ..quadraticBezierTo(side * .12, side * .12, side * .30, side * .12)
      ..lineTo(side * .58, side * .12)
      ..quadraticBezierTo(side * .42, side * .22, side * .25, side * .40)
      ..close();
    canvas.save();
    canvas.clipRRect(rim.deflate(side * .02));
    canvas.drawPath(sheen, Paint()..color = const Color(0x38FFFFFF));
    canvas.restore();

    final radius = side * .069;
    for (final index in DiceFace._pipPositions[value]) {
      final column = index % 3;
      final row = index ~/ 3;
      final center = Offset(
        side * (.27 + .23 * column),
        side * (.27 + .23 * row),
      );

      // Recessed circular socket: a pale lower rim, darker upper edge, and
      // radial ink well make the pip look engraved instead of stuck on.
      canvas.drawCircle(
        center.translate(0, side * .007),
        radius + side * .011,
        Paint()..color = const Color(0xD6FFFFFF),
      );
      canvas.drawCircle(
        center.translate(0, -side * .004),
        radius + side * .006,
        Paint()..color = const Color(0xFF647373),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.40, -.45),
            radius: 1.15,
            colors: const <Color>[Color(0xFF273034), Color(0xFF06080B)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
      canvas.drawCircle(
        center.translate(-radius * .25, -radius * .30),
        radius * .18,
        Paint()..color = const Color(0x4DFFFFFF),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PorcelainFacePainter oldDelegate) =>
      oldDelegate.value != value;
}

/// Animated physical-looking two-dice tumble. Unlike the previous gentle
/// 0.15-radian wobble, this visibly rotates all three axes, lifts and lands.
/// Actual game outcomes are NEVER generated in this widget: [value] comes
/// from the offline GameEngine or the LAN host.
class RollingDiceFace extends StatefulWidget {
  const RollingDiceFace({
    super.key,
    required this.value,
    required this.rolling,
    this.size = 70,
    this.dieIndex = 0,
  });

  final int value;
  final bool rolling;
  final double size;

  /// Gives dice #1 and #2 different tumbling paths even if they match.
  final int dieIndex;

  @override
  State<RollingDiceFace> createState() => _RollingDiceFaceState();
}

class _RollingDiceFaceState extends State<RollingDiceFace>
    with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 660),
  );
  late final AnimationController _land = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1,
  );

  bool get _motionAllowed =>
      !GameExperienceSettings.instance.effectiveReducedMotion &&
      !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);

  @override
  void initState() {
    super.initState();
    GameExperienceSettings.instance.addListener(_settingsChanged);
    // This does not access MediaQuery before didChangeDependencies.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRolling();
  }

  @override
  void didUpdateWidget(covariant RollingDiceFace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rolling != oldWidget.rolling) {
      _syncRolling();
    } else if (!widget.rolling &&
        widget.value != oldWidget.value &&
        _motionAllowed) {
      // Even an AI/LAN roll can arrive as a new final value with no local
      // 'rolling' frames. Give it a small but perceptible landing response.
      _land.forward(from: 0);
    }
  }

  void _settingsChanged() {
    if (mounted) _syncRolling();
  }

  void _syncRolling() {
    if (widget.rolling && _motionAllowed) {
      _land.stop();
      _land.value = 0;
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      final wasSpinning = _spin.isAnimating;
      _spin.stop();
      if (wasSpinning && _motionAllowed) {
        _land.forward(from: 0);
      } else if (!_motionAllowed) {
        _land.stop();
        _land.value = 1;
      }
    }
  }

  @override
  void dispose() {
    GameExperienceSettings.instance.removeListener(_settingsChanged);
    _spin.dispose();
    _land.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge(<Listenable>[_spin, _land]),
    builder: (context, _) {
      final tumbling = widget.rolling && _motionAllowed;
      if (tumbling) {
        final t = _spin.value;
        final phase = t * 2 * math.pi;
        final shift = widget.dieIndex == 0 ? 0.0 : 1.25;
        // Truly rotating cube faces: front/top/right faces exchange in
        // perspective. Each die follows a distinct, smooth roll path.
        final rotateX = -.22 + phase * (1.80 + widget.dieIndex * .26);
        final rotateY = -.24 + phase * (1.26 + widget.dieIndex * .31);
        final rotateZ = math.sin(phase + shift) * .20 + phase * .23;
        final bounce = math.sin(phase + shift).abs() * widget.size * .105;
        return Transform.translate(
          offset: Offset(0, -bounce),
          child: SizedBox.square(
            dimension: widget.size,
            child: CustomPaint(
              key: ValueKey<String>('dice-rolling-cube-${widget.dieIndex}'),
              painter: _TumblingCubePainter(
                faceValue: widget.value.clamp(1, 6).toInt(),
                x: rotateX,
                y: rotateY,
                z: rotateZ,
              ),
            ),
          ),
        );
      }
      final landing = Curves.easeOutBack.transform(_land.value);
      return Transform.translate(
        offset: Offset(0, -widget.size * .08 * (1 - _land.value)),
        child: Transform.scale(
          scale: .90 + .10 * landing,
          child: ThreeDimensionalDiceFace(
            value: widget.value,
            size: widget.size,
          ),
        ),
      );
    },
  );
}

/// Small vector type used by the painting-only 3D cube; no model engine,
/// GLB files, or extra package are needed on Flutter Android or Web.
class _DieVector {
  const _DieVector(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;
  _DieVector operator +(_DieVector b) => _DieVector(x + b.x, y + b.y, z + b.z);
  _DieVector operator *(double scale) =>
      _DieVector(x * scale, y * scale, z * scale);
}

class _DiePlane {
  const _DiePlane(this.c, this.u, this.v, this.face);
  final _DieVector c, u, v;
  final int face;
}

class _TumblingCubePainter extends CustomPainter {
  const _TumblingCubePainter({
    required this.faceValue,
    required this.x,
    required this.y,
    required this.z,
  });
  final int faceValue;
  final double x, y, z;

  _DieVector _rotate(_DieVector v) {
    final cx = math.cos(x), sx = math.sin(x);
    final cy = math.cos(y), sy = math.sin(y);
    final cz = math.cos(z), sz = math.sin(z);
    final yy = v.y * cx - v.z * sx;
    final zz = v.y * sx + v.z * cx;
    final xx2 = v.x * cy + zz * sy;
    final zz2 = -v.x * sy + zz * cy;
    return _DieVector(xx2 * cz - yy * sz, xx2 * sz + yy * cz, zz2);
  }

  Offset _point(_DieVector v, Size size) {
    final p = _rotate(v);
    final zoom = 5.0 / (5.0 - p.z);
    return Offset(
      size.width / 2 + p.x * size.width * .345 * zoom,
      size.height * .48 + p.y * size.height * .345 * zoom,
    );
  }

  Path _roundedFace(List<Offset> corners) {
    final path = Path();
    for (var i = 0; i < corners.length; i++) {
      final a = corners[(i + corners.length - 1) % corners.length];
      final b = corners[i];
      final c = corners[(i + 1) % corners.length];
      final before = Offset.lerp(b, a, .095)!;
      final after = Offset.lerp(b, c, .095)!;
      if (i == 0) {
        path.moveTo(before.dx, before.dy);
      } else {
        path.lineTo(before.dx, before.dy);
      }
      path.quadraticBezierTo(b.dx, b.dy, after.dx, after.dy);
    }
    return path..close();
  }

  Path _pipPath(
    _DiePlane f,
    double horizontal,
    double vertical,
    double radius,
    Size size,
  ) {
    final center = f.c + f.u * horizontal + f.v * vertical;
    final path = Path();
    for (var i = 0; i <= 20; i++) {
      final a = 2 * math.pi * i / 20;
      final p = _point(
        center + f.u * (math.cos(a) * radius) + f.v * (math.sin(a) * radius),
        size,
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = Offset(size.width * .50, size.height * .87);
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.width * .76,
        height: size.height * .14,
      ),
      Paint()
        ..color = const Color(0x99000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * .065),
    );
    // Side values respect opposite faces adding up to seven, so the rotating
    // image always looks like a legitimate six-sided die.
    final top = <int>[
      1,
      2,
      3,
      4,
      5,
      6,
    ].firstWhere((n) => n != faceValue && n != 7 - faceValue);
    final right = <int>[3, 4, 5, 6, 1, 2].firstWhere(
      (n) => n != faceValue && n != 7 - faceValue && n != top && n != 7 - top,
    );
    final planes = <_DiePlane>[
      _DiePlane(
        const _DieVector(0, 0, 1),
        const _DieVector(1, 0, 0),
        const _DieVector(0, 1, 0),
        faceValue,
      ),
      _DiePlane(
        const _DieVector(0, 0, -1),
        const _DieVector(-1, 0, 0),
        const _DieVector(0, 1, 0),
        7 - faceValue,
      ),
      _DiePlane(
        const _DieVector(0, -1, 0),
        const _DieVector(1, 0, 0),
        const _DieVector(0, 0, 1),
        top,
      ),
      _DiePlane(
        const _DieVector(0, 1, 0),
        const _DieVector(1, 0, 0),
        const _DieVector(0, 0, -1),
        7 - top,
      ),
      _DiePlane(
        const _DieVector(1, 0, 0),
        const _DieVector(0, 0, -1),
        const _DieVector(0, 1, 0),
        right,
      ),
      _DiePlane(
        const _DieVector(-1, 0, 0),
        const _DieVector(0, 0, 1),
        const _DieVector(0, 1, 0),
        7 - right,
      ),
    ];
    // Face u/v orientation is not necessarily wound identically. Dot product
    // of rotated face centre and the viewer direction is all we need.
    final visible = planes.where((f) => _rotate(f.c).z > .005).toList()
      ..sort((a, b) => _rotate(a.c).z.compareTo(_rotate(b.c).z));

    for (final face in visible) {
      final u = face.u, v = face.v, c = face.c;
      final corners = <Offset>[
        _point(c + u * -1 + v * -1, size),
        _point(c + u + v * -1, size),
        _point(c + u + v, size),
        _point(c + u * -1 + v, size),
      ];
      final path = _roundedFace(corners);
      final brightness = _rotate(face.c).z;
      final light = Color.lerp(
        const Color(0xFFCBCDD0),
        const Color(0xFFFFFFFF),
        brightness.clamp(0, 1).toDouble(),
      )!;
      final shade = Color.lerp(
        const Color(0xFFB4B8BB),
        const Color(0xFFE8E9E8),
        brightness.clamp(0, 1).toDouble(),
      )!;
      final bounds = path.getBounds();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [light, shade],
          ).createShader(bounds),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * .012
          ..color = const Color(0xFFDFE0DE),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * .013
          ..color = Colors.white.withValues(alpha: .40),
      );
      for (final pip in DiceFace._pipPositions[face.face]) {
        const slots = <double>[-.56, 0, .56];
        final horizontal = slots[pip % 3];
        final vertical = slots[pip ~/ 3];
        final hole = _pipPath(face, horizontal, vertical, .142, size);
        final inset = _pipPath(face, horizontal, vertical, .124, size);
        canvas.drawPath(hole, Paint()..color = const Color(0xFF8D9496));
        canvas.drawPath(
          inset,
          Paint()
            ..shader = const RadialGradient(
              colors: [Color(0xFF25373A), Color(0xFF040C10)],
            ).createShader(inset.getBounds()),
        );
        final spark = _pipPath(
          face,
          horizontal - .035,
          vertical - .038,
          .024,
          size,
        );
        canvas.drawPath(spark, Paint()..color = const Color(0xA8FFFFFF));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TumblingCubePainter old) =>
      old.x != x || old.y != y || old.z != z || old.faceValue != faceValue;
}

/// A clean porcelain face when the dice stop rolling. All extra top/right
/// geometric faces have been removed: they looked like detached white strips
/// at high board zoom. During motion [RollingDiceFace] still uses the fully
/// rotating 3D cube painter; only the final settled appearance is simplified.
class ThreeDimensionalDiceFace extends StatelessWidget {
  const ThreeDimensionalDiceFace({
    super.key,
    required this.value,
    this.size = 70,
  });

  final int value;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Padding(
      padding: EdgeInsets.all(size * .045),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF6F8F9),
          borderRadius: BorderRadius.circular(size * .17),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: .32),
              blurRadius: size * .10,
              offset: Offset(0, size * .045),
            ),
          ],
        ),
        child: DiceFace(value: value, size: size * .91),
      ),
    ),
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
    if (GameExperienceSettings.instance.effectiveReducedMotion) {
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
      duration: GameExperienceSettings.instance.effectiveReducedMotion
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
          colors: [
            Colors.white,
            widget.color,
            widget.color.withValues(alpha: .72),
          ],
          stops: const [.0, .24, 1],
        ),
        border: Border.all(
          color: widget.isActive ? Colors.white : const Color(0xFF253938),
          width: widget.isActive ? 2.1 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .65),
            offset: const Offset(2, 4),
            blurRadius: 4,
          ),
          if (widget.isActive)
            BoxShadow(
              color: widget.color.withValues(alpha: .90),
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

import 'package:flutter/material.dart';

import '../../experience/token_preferences.dart';
import '../../experience/player_palette.dart';
import 'animated_board_tokens.dart';

/// Direction of the triangular owner's pennant. Its tip always points into
/// the centre of the Monopoly board, rather than into the property tile.
enum OwnerFlagDirection { down, up, left, right }

/// Ownership is displayed by the selected player token and the player's
/// persistent seat colour. No player numbers are drawn on the board flags.
const List<Color> ownerFlagColors = <Color>[
  Color(0xFFE8AD61),
  Color(0xFF6BC8EF),
  Color(0xFFF383AF),
  Color(0xFF93DB8A),
  Color(0xFFCD9AFE),
  Color(0xFFF6E47B),
];

@immutable
class OwnerFlagPlacement {
  const OwnerFlagPlacement({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.direction,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final OwnerFlagDirection direction;
}

/// Places flags just *inside* the inner edge of each owned tile. The corners
/// are special spaces and never get an ownership flag.
class OwnerFlagGeometry {
  OwnerFlagGeometry._();

  static const double longSide = 58;
  static const double shortSide = 40;

  static OwnerFlagPlacement? forTile(int tileIndex) {
    final (row, col) = BoardTokenGeometry.gridPosition(tileIndex);
    const cell = BoardTokenGeometry.cell;

    if (row == 0 && col > 0 && col < 10) {
      return OwnerFlagPlacement(
        left: col * cell + (cell - longSide) / 2,
        top: cell - 2,
        width: longSide,
        height: shortSide,
        direction: OwnerFlagDirection.down,
      );
    }
    if (row == 10 && col > 0 && col < 10) {
      return OwnerFlagPlacement(
        left: col * cell + (cell - longSide) / 2,
        top: row * cell - shortSide + 2,
        width: longSide,
        height: shortSide,
        direction: OwnerFlagDirection.up,
      );
    }
    if (col == 0 && row > 0 && row < 10) {
      return OwnerFlagPlacement(
        left: cell - 2,
        top: row * cell + (cell - longSide) / 2,
        width: shortSide,
        height: longSide,
        direction: OwnerFlagDirection.right,
      );
    }
    if (col == 10 && row > 0 && row < 10) {
      return OwnerFlagPlacement(
        left: col * cell - shortSide + 2,
        top: row * cell + (cell - longSide) / 2,
        width: shortSide,
        height: longSide,
        direction: OwnerFlagDirection.left,
      );
    }
    return null;
  }
}

/// Keeps its original class name so existing imports stay compatible.
/// The shape now extends *toward the board centre*, with the player's
/// chosen token icon instead of a numeric label.
class OwnershipCornerBadge extends StatelessWidget {
  const OwnershipCornerBadge({
    super.key,
    required this.ownerId,
    this.direction = OwnerFlagDirection.down,
    this.ownerName,
    this.colorIndex,
  });

  final int ownerId;
  final OwnerFlagDirection direction;
  final String? ownerName;
  final int? colorIndex;

  @override
  Widget build(BuildContext context) {
    if (ownerId < 0 || ownerId >= 6) {
      return const SizedBox.shrink();
    }
    final isVertical =
        direction == OwnerFlagDirection.down ||
        direction == OwnerFlagDirection.up;
    final icon = TokenPreferences.instance.styleFor(ownerId).icon;
    final iconAlignment = switch (direction) {
      OwnerFlagDirection.down => const Alignment(0, -0.60),
      OwnerFlagDirection.up => const Alignment(0, 0.60),
      OwnerFlagDirection.left => const Alignment(0.60, 0),
      OwnerFlagDirection.right => const Alignment(-0.60, 0),
    };

    return Semantics(
      label: '${ownerName ?? 'Player ${ownerId + 1}'} owns this property',
      child: SizedBox(
        width: isVertical
            ? OwnerFlagGeometry.longSide
            : OwnerFlagGeometry.shortSide,
        height: isVertical
            ? OwnerFlagGeometry.shortSide
            : OwnerFlagGeometry.longSide,
        child: CustomPaint(
          painter: _OwnerFlagPainter(
            color: PlayerPalette.at(colorIndex ?? ownerId),
            direction: direction,
          ),
          child: Align(
            alignment: iconAlignment,
            child: ExcludeSemantics(
              child: Icon(icon, size: 21, color: const Color(0xFF122526)),
            ),
          ),
        ),
      ),
    );
  }
}

class _OwnerFlagPainter extends CustomPainter {
  const _OwnerFlagPainter({required this.color, required this.direction});

  final Color color;
  final OwnerFlagDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    final path = switch (direction) {
      OwnerFlagDirection.down =>
        Path()
          ..moveTo(0, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width / 2, size.height)
          ..close(),
      OwnerFlagDirection.up =>
        Path()
          ..moveTo(size.width / 2, 0)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close(),
      OwnerFlagDirection.left =>
        Path()
          ..moveTo(0, size.height / 2)
          ..lineTo(size.width, 0)
          ..lineTo(size.width, size.height)
          ..close(),
      OwnerFlagDirection.right =>
        Path()
          ..moveTo(0, 0)
          ..lineTo(size.width, size.height / 2)
          ..lineTo(0, size.height)
          ..close(),
    };

    canvas.drawShadow(path, Colors.black, 3, false);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFEDCF8B)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _OwnerFlagPainter oldDelegate) =>
      color != oldDelegate.color || direction != oldDelegate.direction;
}

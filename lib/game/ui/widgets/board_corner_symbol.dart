import 'package:flutter/material.dart';

import '../../models/game_models.dart';
import 'jail_tile_marker.dart';

/// Distinct symbols for the four unpurchasable board corners.
///
/// The text labels remain available via Semantics and tile details, while
/// the visible board uses compact icons at all screen sizes. The existing
/// board-number line stays intact and the game rules are never changed.
class BoardCornerSymbol extends StatelessWidget {
  const BoardCornerSymbol({
    super.key,
    required this.index,
    required this.kind,
    required this.label,
  });

  final int index;
  final SpaceKind kind;
  final String label;

  static const Color _gold = Color(0xFFE9BE67);
  static const Color _ink = Color(0xFF102525);

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case SpaceKind.go:
        return _FramedCornerIcon(
          label: label,
          icon: Icons.sports_score_rounded,
        );
      case SpaceKind.freeParking:
        return _FramedCornerIcon(
          label: label,
          icon: Icons.local_parking_rounded,
        );
      case SpaceKind.jail:
      case SpaceKind.goToJail:
        final goToJail = kind == SpaceKind.goToJail;
        // Keep the Phase 14.2.5 jail-icon keys used by existing tests.
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            JailTileMarker(
              key: ValueKey<String>('board-jail-icon-$index'),
              goToJail: goToJail,
              size: 43,
              label: label,
            ),
            if (goToJail)
              Positioned(
                right: -6,
                bottom: -4,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: _gold,
                      shape: BoxShape.circle,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(1),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 13,
                        color: _ink,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _FramedCornerIcon extends StatelessWidget {
  const _FramedCornerIcon({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      image: true,
      child: Container(
        width: 45,
        height: 43,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BoardCornerSymbol._ink,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: BoardCornerSymbol._gold, width: 1.6),
        ),
        child: Icon(icon, size: 29, color: BoardCornerSymbol._gold),
      ),
    );
  }
}

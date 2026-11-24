// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../engine/game_engine.dart';
import '../../experience/board_camera_preset.dart';
import '../../experience/gameplay_motion.dart';
import '../../experience/game_experience_settings.dart';
import '../../experience/token_preferences.dart';
import '../../experience/player_palette.dart';
import '../../models/game_models.dart';
import '../game_text.dart';
import 'animated_board_tokens.dart';
import 'active_position_glow.dart';
import 'board_center_action.dart';
import 'board_corner_symbol.dart';
import 'board_special_symbol.dart';
import 'ownership_corner_badge.dart';

const Color kBoardGold = Color(0xFFE9BE67);
const Color kBoardDark = Color(0xFF0B1718);
const Color kBoardGreen = Color(0xFF145548);

Color groupColor(ColorGroup? group) {
  switch (group) {
    case ColorGroup.brown:
      return const Color(0xFF9A6048);
    case ColorGroup.sky:
      return const Color(0xFF73C7E4);
    case ColorGroup.pink:
      return const Color(0xFFE697BF);
    case ColorGroup.orange:
      return const Color(0xFFF3A14D);
    case ColorGroup.red:
      return const Color(0xFFE86C69);
    case ColorGroup.yellow:
      return const Color(0xFFF9D978);
    case ColorGroup.green:
      return const Color(0xFF6CC48D);
    case ColorGroup.navy:
      return const Color(0xFF5574D1);
    case null:
      return kBoardGold;
  }
}

const List<Color> tokenColors = <Color>[
  Color(0xFFE8AD61),
  Color(0xFF6BC8EF),
  Color(0xFFF383AF),
  Color(0xFF93DB8A),
  Color(0xFFCD9AFE),
  Color(0xFFF6E47B),
];

/// 1000 × 1000 logical playing surface. FittedBox scales it consistently on
/// Android phones, tablets, and web browser widths. Pinch to inspect tiles.
class GameBoardView extends StatelessWidget {
  const GameBoardView({
    super.key,
    required this.engine,
    required this.text,
    required this.onSelect,
    this.perspective = true,
    this.cameraOverride,
    this.transformationController,
    this.onInteractionStart,
    this.visiblePositions = const <int, int>{},
    this.dicePreview,
    this.diceRolling = false,
    this.onRoll,
    this.onEndTurn,
    this.canAct = false,
    this.actionEnabled,
    this.onReviewDecision,
    this.decisionEnabled,
    this.onViewActivity,
  });

  final GameEngine engine;
  final GameText text;
  final void Function(int tileIndex) onSelect;
  final bool perspective;

  /// Per-screen override. Does not persist or change the global camera setting.
  final BoardCameraPreset? cameraOverride;

  /// Allows the full-screen board to provide working zoom/reset controls.
  final TransformationController? transformationController;
  final GestureScaleStartCallback? onInteractionStart;
  final Map<int, int> visiblePositions;
  final DiceRoll? dicePreview;
  final bool diceRolling;
  final VoidCallback? onRoll;
  final VoidCallback? onEndTurn;
  final bool canAct;
  final bool Function()? actionEnabled;
  final VoidCallback? onReviewDecision;
  final bool Function()? decisionEnabled;
  final VoidCallback? onViewActivity;

  static const double tile = 1000 / 11;

  static (int, int) gridPosition(int index) =>
      BoardTokenGeometry.gridPosition(index);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        GameExperienceSettings.instance,
        TokenPreferences.instance,
      ]),
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final settings = GameExperienceSettings.instance;
          final camera = perspective
              ? (cameraOverride ?? settings.cameraPreset)
              : BoardCameraPreset.topDown;
          final side = math.min(constraints.maxWidth, constraints.maxHeight);
          return Center(
            child: SizedBox(
              width: side,
              height: side,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: InteractiveViewer(
                  transformationController: transformationController,
                  onInteractionStart: onInteractionStart,
                  minScale: 1,
                  maxScale: 4.5,
                  boundaryMargin: const EdgeInsets.all(180),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: TweenAnimationBuilder<double>(
                      // Interpolate all camera parameters together, rather
                      // than snapping scale/depth/spin while tilt animates.
                      key: const ValueKey('board-camera-transition'),
                      tween: Tween<double>(end: camera.index.toDouble()),
                      duration:
                          settings.reducedMotion ||
                              MediaQuery.of(context).disableAnimations
                          ? Duration.zero
                          : GameplayMotion.cameraTransition,
                      curve: Curves.easeInOutCubic,
                      builder: (context, value, child) {
                        final lower = value.floor().clamp(0, 2).toInt();
                        final upper = value.ceil().clamp(0, 2).toInt();
                        final a = BoardCameraPreset.values[lower];
                        final b = BoardCameraPreset.values[upper];
                        final f = (value - lower).clamp(0.0, 1.0).toDouble();
                        double mix(double x, double y) => x + (y - x) * f;
                        double scale(BoardCameraPreset p) =>
                            p == BoardCameraPreset.topDown ? 1.0 : .79;
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, mix(a.depth, b.depth))
                            ..rotateX(mix(a.tilt, b.tilt))
                            ..rotateZ(mix(a.spin, b.spin))
                            ..scale(mix(scale(a), scale(b))),
                          child: child,
                        );
                      },
                      child: SizedBox(
                        height: 1000,
                        width: 1000,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: const RadialGradient(
                                    colors: [
                                      Color(0xFF1F6559),
                                      Color(0xFF0C2528),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: kBoardGold,
                                    width: 6,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: tile,
                              right: tile,
                              top: tile,
                              bottom: tile,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: kBoardGold.withValues(alpha: .65),
                                    width: 4,
                                  ),
                                  gradient: const RadialGradient(
                                    colors: [
                                      Color(0xFF1D524A),
                                      Color(0xFF102D2C),
                                    ],
                                  ),
                                ),
                                child: Center(
                                  child: BoardCenterAction(
                                    engine: engine,
                                    text: text,
                                    dicePreview: dicePreview,
                                    diceRolling: diceRolling,
                                    canAct: actionEnabled?.call() ?? canAct,
                                    onRoll: onRoll,
                                    onEndTurn: onEndTurn,
                                    onReviewDecision: onReviewDecision,
                                    canReviewDecision:
                                        decisionEnabled?.call() ?? false,
                                    onViewActivity: onViewActivity,
                                  ),
                                ),
                              ),
                            ),
                            for (final tileData in engine.spaces)
                              _positionTile(tileData),
                            // Painted on the inward-facing edge of each
                            // owned property, not over the price/name.
                            for (final tileData in engine.spaces)
                              if (engine.properties[tileData.index].ownerId !=
                                  null)
                                _positionOwnerFlag(tileData),
                            Positioned.fill(
                              child: AnimatedBoardTokens(
                                game: engine,
                                visiblePositions: visiblePositions,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _positionOwnerFlag(BoardSpace data) {
    final ownerId = engine.properties[data.index].ownerId;
    final placement = OwnerFlagGeometry.forTile(data.index);
    if (ownerId == null ||
        ownerId < 0 ||
        ownerId >= engine.players.length ||
        placement == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: placement.left,
      top: placement.top,
      width: placement.width,
      height: placement.height,
      child: IgnorePointer(
        child: OwnershipCornerBadge(
          key: ValueKey<String>('owner-flag-${data.index}'),
          ownerId: ownerId,
          ownerName: engine.players[ownerId].name,
          colorIndex: engine.players[ownerId].colorIndex,
          direction: placement.direction,
        ),
      ),
    );
  }

  Widget _positionTile(BoardSpace data) {
    final (row, col) = gridPosition(data.index);
    final state = engine.properties[data.index];
    final group = data.group;
    // All non-bankrupt players are tracked, including human and AI/LAN
    // opponents. Use the *visible* step so the glow follows movement.
    final occupants = [
      for (final player in engine.players)
        if (!player.bankrupt &&
            (visiblePositions[player.id] ?? player.position) == data.index)
          player,
    ];
    final isCurrentPosition = occupants.any(
      (player) => player.id == engine.currentPlayerId,
    );
    // When several tokens occupy a square, put the current player's colour
    // first and paint equal-length colour segments around the perimeter.
    occupants.sort((a, b) {
      if (a.id == engine.currentPlayerId) return -1;
      if (b.id == engine.currentPlayerId) return 1;
      return a.id.compareTo(b.id);
    });
    return Positioned(
      top: row * tile,
      left: col * tile,
      height: tile,
      width: tile,
      child: Material(
        color: kBoardDark,
        child: InkWell(
          onTap: () => onSelect(data.index),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: kBoardDark,
              border: Border.all(
                color: kBoardGold.withValues(alpha: 0.55),
                width: 1.5,
              ),
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    if (group != null)
                      Container(height: 17, color: groupColor(group)),
                    if (state.ownerId != null)
                      Container(
                        height: 5,
                        color: PlayerPalette.at(
                          engine.players[state.ownerId!].colorIndex,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      text.integer(data.index),
                      style: TextStyle(
                        fontFamily: text.font,
                        fontFamilyFallback: text.fallbackFonts,
                        fontSize: 23,
                        height: 1.0,
                        color: kBoardGold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child:
                            data.kind == SpaceKind.go ||
                                data.kind == SpaceKind.jail ||
                                data.kind == SpaceKind.freeParking ||
                                data.kind == SpaceKind.goToJail
                            ? BoardCornerSymbol(
                                key: ValueKey<String>(
                                  'board-corner-icon-${data.index}',
                                ),
                                index: data.index,
                                kind: data.kind,
                                label: text.spaceName(data.index, data.name),
                              )
                            : BoardSpecialSymbol.supports(data.index)
                            ? BoardSpecialSymbol(
                                index: data.index,
                                label: text.spaceName(data.index, data.name),
                                text: text,
                              )
                            : Text(
                                text.spaceName(data.index, data.name),
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: text.font,
                                  fontFamilyFallback: text.fallbackFonts,
                                  color: Colors.white,
                                  height: text.bn ? 1.23 : 1.1,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                    if (data.price > 0 || data.tax > 0)
                      Text(
                        text.money(data.price > 0 ? data.price : data.tax),
                        style: TextStyle(
                          color: kBoardGold,
                          fontSize: 13,
                          fontFamily: text.font,
                          fontFamilyFallback: text.fallbackFonts,
                        ),
                      ),
                    if (state.mortgaged)
                      const Icon(
                        Icons.lock_outline,
                        size: 12,
                        color: Colors.redAccent,
                      ),
                  ],
                ),
                // Keep houses/hotels OUTSIDE the tile's vertical Column.
                // Otherwise adding a building increases its minimum height
                // and the 90.9-px board cells overflow in Flutter's renderer.
                if (state.development > 0)
                  Positioned(
                    top: group != null ? 1 : 2,
                    right: 1,
                    child: _developmentBadge(state.development),
                  ),
                // Paint ABOVE the property content (but with low alpha).
                // Phase 13.4 put a small glow BEHIND the text for only the
                // active player, which was hard to see on Android phones.
                if (occupants.isNotEmpty)
                  Positioned.fill(
                    child: ActivePositionGlow(
                      key: ValueKey<String>(
                        isCurrentPosition
                            ? 'active-position-tile-${data.index}'
                            : 'player-position-tile-${data.index}',
                      ),
                      color: PlayerPalette.at(occupants.first.colorIndex),
                      colors: [
                        for (final player in occupants)
                          PlayerPalette.at(player.colorIndex),
                      ],
                      isCurrentTurn: isCurrentPosition,
                      reducedMotion:
                          GameExperienceSettings.instance.reducedMotion,
                    ),
                  ),
                // The four corner icons occupy the same center slot as the
                // previous text labels. They never add vertical layout height.
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Compact building badge overlays the color strip instead of taking
  /// vertical space from the title, name and price. Supports 1–4 houses
  /// and a hotel at level 5, without adding a RenderFlex child height.
  Widget _developmentBadge(int level) => Semantics(
    label: level == 5 ? 'Hotel built' : '$level houses built',
    child: Container(
      key: const ValueKey<String>('tile-development-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xEE102527),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: kBoardGold, width: .8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            level == 5 ? Icons.apartment_rounded : Icons.home_rounded,
            size: 10,
            color: level == 5
                ? const Color(0xFFEF736B)
                : const Color(0xFF78D594),
          ),
          if (level < 5) ...[
            const SizedBox(width: 1),
            Text(
              '$level',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                height: 1.0,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

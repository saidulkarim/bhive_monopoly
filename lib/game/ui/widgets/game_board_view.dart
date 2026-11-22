// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../engine/game_engine.dart';
import '../../models/game_models.dart';
import '../game_text.dart';
import 'dice_face.dart';

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
    this.visiblePositions = const <int, int>{},
    this.dicePreview,
    this.diceRolling = false,
  });

  final GameEngine engine;
  final GameText text;
  final void Function(int tileIndex) onSelect;
  final bool perspective;
  final Map<int, int> visiblePositions;
  final DiceRoll? dicePreview;
  final bool diceRolling;

  static const double tile = 1000 / 11;

  static (int, int) gridPosition(int index) {
    if (index <= 10) return (10, 10 - index);
    if (index <= 20) return (20 - index, 0);
    if (index <= 30) return (0, index - 20);
    return (index - 30, 10);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 3.5,
                boundaryMargin: const EdgeInsets.all(100),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0006)
                      ..rotateX(perspective ? -0.20 : 0),
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
                                border: Border.all(color: kBoardGold, width: 6),
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
                                  color: kBoardGold.withOpacity(.65),
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
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.diamond_rounded,
                                      color: kBoardGold,
                                      size: 95,
                                    ),
                                    const Text(
                                      'bHiVE',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'Exo2',
                                        fontSize: 78,
                                        fontWeight: FontWeight.w800,
                                        color: kBoardGold,
                                        letterSpacing: 5,
                                      ),
                                    ),
                                    const Text(
                                      'MONOPOLY',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'Exo2',
                                        fontSize: 30,
                                        letterSpacing: 9,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 60),
                                    Text(
                                      text.choose(
                                        'PROPERTY EMPIRE',
                                        'সম্পত্তির সাম্রাজ্য',
                                      ),
                                      style: TextStyle(
                                        fontFamily: text.font,
                                        fontSize: 22,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 25),
                                    if ((dicePreview ?? engine.lastRoll) !=
                                        null)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          DiceFace(
                                            value:
                                                (dicePreview ??
                                                        engine.lastRoll)!
                                                    .first,
                                            angle: diceRolling ? -.12 : 0,
                                          ),
                                          const SizedBox(width: 18),
                                          DiceFace(
                                            value:
                                                (dicePreview ??
                                                        engine.lastRoll)!
                                                    .second,
                                            angle: diceRolling ? .16 : 0,
                                          ),
                                        ],
                                      ),
                                    const SizedBox(height: 25),
                                    Text(
                                      '${text.choose('TURN', 'চাল')} ${text.integer(engine.turnNumber)}',
                                      style: TextStyle(
                                        fontFamily: text.font,
                                        fontSize: 22,
                                        color: kBoardGold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          for (final tileData in engine.spaces)
                            _positionTile(tileData),
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
    );
  }

  Widget _positionTile(BoardSpace data) {
    final (row, col) = gridPosition(data.index);
    final state = engine.properties[data.index];
    final occupants = engine.players
        .where(
          (p) =>
              !p.bankrupt &&
              (visiblePositions[p.id] ?? p.position) == data.index,
        )
        .toList();
    final group = data.group;
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
              color:
                  data.index ==
                      (visiblePositions[engine.currentPlayerId] ??
                          engine.currentPlayer.position)
                  ? const Color(0xFF294333)
                  : kBoardDark,
              border: Border.all(
                color: kBoardGold.withOpacity(0.55),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                if (group != null)
                  Container(height: 17, color: groupColor(group)),
                if (state.ownerId != null)
                  Container(height: 5, color: tokenColors[state.ownerId!]),
                const SizedBox(height: 5),
                Expanded(
                  child: Center(
                    child: Text(
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
                        fontSize:
                            data.kind == SpaceKind.go ||
                                data.kind == SpaceKind.jail ||
                                data.kind == SpaceKind.goToJail ||
                                data.kind == SpaceKind.freeParking
                            ? (text.bn ? 12.2 : 13)
                            : (text.bn ? 11.5 : 11),
                      ),
                    ),
                  ),
                ),
                if (data.price > 0)
                  Text(
                    text.money(data.price),
                    style: TextStyle(
                      color: kBoardGold,
                      fontSize: 11,
                      fontFamily: text.font,
                      fontFamilyFallback: text.fallbackFonts,
                    ),
                  ),
                if (state.development > 0)
                  BuildingPieces(development: state.development),
                if (state.mortgaged)
                  const Icon(
                    Icons.lock_outline,
                    size: 12,
                    color: Colors.redAccent,
                  ),
                if (occupants.isNotEmpty)
                  SizedBox(
                    height: 23,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final player in occupants)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                child: BoardToken(
                                  color: tokenColors[player.id],
                                  playerId: player.id,
                                  isActive: player.id == engine.currentPlayerId,
                                  size: 22,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

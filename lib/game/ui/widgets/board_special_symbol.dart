import 'package:flutter/material.dart';

import '../game_text.dart';

/// Display-only symbols for non-corner special spaces. The fixed logical
/// board cell scales with GameBoardView; FittedBox also handles owned and
/// mortgaged spaces without adding minimum height to the tile column.
class BoardSpecialSymbol extends StatelessWidget {
  const BoardSpecialSymbol({
    super.key,
    required this.index,
    required this.label,
    required this.text,
  });

  final int index;
  final String label;
  final GameText text;

  static const _symbols = <int, (IconData, Color)>{
    2: (Icons.card_giftcard_rounded, Color(0xFF5EEAD4)),
    4: (Icons.receipt_long_rounded, Color(0xFFFCA5A5)),
    5: (Icons.train_rounded, Color(0xFFCBD5E1)),
    7: (Icons.help_rounded, Color(0xFFC4B5FD)),
    12: (Icons.electric_bolt_rounded, Color(0xFFFBBF24)),
    15: (Icons.train_rounded, Color(0xFFCBD5E1)),
    17: (Icons.card_giftcard_rounded, Color(0xFF5EEAD4)),
    22: (Icons.help_rounded, Color(0xFFC4B5FD)),
    25: (Icons.train_rounded, Color(0xFFCBD5E1)),
    28: (Icons.water_drop_rounded, Color(0xFF7DD3FC)),
    33: (Icons.card_giftcard_rounded, Color(0xFF5EEAD4)),
    35: (Icons.train_rounded, Color(0xFFCBD5E1)),
    36: (Icons.help_rounded, Color(0xFFC4B5FD)),
    38: (Icons.diamond_rounded, Color(0xFFFCD34D)),
  };

  static bool supports(int index) => _symbols.containsKey(index);

  @override
  Widget build(BuildContext context) {
    final symbol = _symbols[index];
    if (symbol == null) return const SizedBox.shrink();
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 78,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  symbol.$1,
                  key: ValueKey('board-special-icon-$index'),
                  size: 23,
                  color: symbol.$2,
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: text.font,
                    fontFamilyFallback: text.fallbackFonts,
                    fontSize: 13,
                    height: text.bn ? 1.23 : 1.1,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
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

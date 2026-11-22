import 'package:flutter/material.dart';

import '../../engine/game_engine.dart';
import '../../experience/board_camera_preset.dart';
import '../../models/game_models.dart';
import '../board_explorer_screen.dart';
import '../game_text.dart';
import 'game_board_view.dart';

/// Portrait phones keep a vertical board layout; landscape phones and tablets
/// gain a board + action sidebar when there is enough horizontal room.
bool usesWideGameBoardLayout(Size size) =>
    size.width >= 900 || (size.width >= 780 && size.width > size.height * 1.25);

/// Accessible camera controls and a full-screen inspector for the shared
/// offline and LAN board. Local-only view preferences don't touch game state.
class AdaptiveBoardPanel extends StatefulWidget {
  const AdaptiveBoardPanel({
    super.key,
    required this.game,
    required this.text,
    required this.onSelect,
    this.visiblePositions = const <int, int>{},
    this.dicePreview,
    this.diceRolling = false,
    this.onRoll,
    this.onEndTurn,
    this.canAct = false,
    this.actionEnabled,
    this.onReviewDecision,
    this.decisionEnabled,
    this.diceValueProvider,
    this.isRollingProvider,
    this.boardUpdates,
    this.onViewActivity,
    this.gameProvider,
  });

  final GameEngine game;
  final GameText text;
  final ValueChanged<int> onSelect;
  final Map<int, int> visiblePositions;
  final DiceRoll? dicePreview;
  final bool diceRolling;
  final VoidCallback? onRoll;
  final VoidCallback? onEndTurn;
  final bool canAct;
  final bool Function()? actionEnabled;
  final VoidCallback? onReviewDecision;
  final bool Function()? decisionEnabled;
  final DiceRoll? Function()? diceValueProvider;
  final bool Function()? isRollingProvider;
  final Listenable? boardUpdates;
  final VoidCallback? onViewActivity;

  /// Resolve the newest LAN snapshot while the explorer is open.
  final GameEngine? Function()? gameProvider;

  @override
  State<AdaptiveBoardPanel> createState() => _AdaptiveBoardPanelState();
}

class _AdaptiveBoardPanelState extends State<AdaptiveBoardPanel> {
  bool _threeD = false; // Default to readable top-down on every phone.

  void _explore({bool list = false}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BoardExplorerScreen(
          game: widget.game,
          text: widget.text,
          onSelect: widget.onSelect,
          visiblePositions: widget.visiblePositions,
          dicePreview: widget.dicePreview,
          diceRolling: widget.diceRolling,
          initial3D: _threeD,
          initialList: list,
          onRoll: widget.onRoll,
          onEndTurn: widget.onEndTurn,
          canAct: widget.canAct,
          actionEnabled: widget.actionEnabled,
          onReviewDecision: widget.onReviewDecision,
          decisionEnabled: widget.decisionEnabled,
          diceValueProvider: widget.diceValueProvider,
          isRollingProvider: widget.isRollingProvider,
          boardUpdates: widget.boardUpdates,
          onViewActivity: widget.onViewActivity,
          gameProvider: widget.gameProvider,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.text;
    return Column(
      children: [
        SizedBox(
          height: 51,
          child: Row(
            children: [
              const Icon(Icons.grid_on_rounded, color: kBoardGold, size: 18),
              const SizedBox(width: 5),
              Text(
                t.choose('BOARD', 'বোর্ড'),
                style: TextStyle(
                  fontFamily: t.font,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: kBoardGold,
                ),
              ),
              const Spacer(),
              _mode('2D', !_threeD, () => setState(() => _threeD = false)),
              const SizedBox(width: 5),
              _mode('3D', _threeD, () => setState(() => _threeD = true)),
              IconButton(
                tooltip: t.choose('Full screen board', 'পূর্ণ পর্দায় বোর্ড'),
                onPressed: _explore,
                icon: const Icon(Icons.open_in_full_rounded, color: kBoardGold),
              ),
              IconButton(
                tooltip: t.choose('See all 40 spaces', '৪০টি ঘর দেখুন'),
                onPressed: () => _explore(list: true),
                icon: const Icon(Icons.list_alt_rounded, color: kBoardGold),
              ),
            ],
          ),
        ),
        Expanded(
          child: GameBoardView(
            engine: widget.game,
            text: t,
            onSelect: widget.onSelect,
            perspective: true,
            cameraOverride: _threeD
                ? BoardCameraPreset.tabletop
                : BoardCameraPreset.topDown,
            visiblePositions: widget.visiblePositions,
            dicePreview: widget.dicePreview,
            diceRolling: widget.diceRolling,
            onRoll: widget.onRoll,
            onEndTurn: widget.onEndTurn,
            canAct: widget.canAct,
            actionEnabled: widget.actionEnabled,
            onReviewDecision: widget.onReviewDecision,
            decisionEnabled: widget.decisionEnabled,
            onViewActivity: widget.onViewActivity,
          ),
        ),
        SizedBox(
          height: 25,
          child: Center(
            child: Text(
              t.choose(
                'Pinch to zoom · Tap a space · Expand to read',
                'বড় করে দেখুন · ঘরে চাপুন · বিস্তারিত দেখুন',
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontFamily: t.font,
                fontFamilyFallback: t.fallbackFonts,
                color: Colors.white70,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _mode(String label, bool selected, VoidCallback onPressed) => SizedBox(
    width: 44,
    height: 40,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        backgroundColor: selected ? kBoardGold : const Color(0xFF193032),
        foregroundColor: selected ? kBoardDark : kBoardGold,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    ),
  );
}

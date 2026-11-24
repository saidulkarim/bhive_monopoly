import 'package:flutter/material.dart';

import '../engine/game_engine.dart';
import '../experience/board_camera_preset.dart';
import '../experience/game_experience_settings.dart';
import '../models/game_models.dart';
import 'game_text.dart';
import 'widgets/game_board_view.dart';
import 'widgets/compact_players_strip.dart';
import 'widgets/smart_board_focus_controller.dart';

/// Full-screen, readable board inspector. The engine is only read here;
/// property operations remain on the calling game screen.
class BoardExplorerScreen extends StatefulWidget {
  const BoardExplorerScreen({
    super.key,
    required this.game,
    required this.text,
    required this.onSelect,
    this.visiblePositions = const <int, int>{},
    this.dicePreview,
    this.diceRolling = false,
    this.initial3D = false,
    this.initialList = false,
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
  final bool initial3D;
  final bool initialList;
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

  /// The authoritative LAN state can replace its GameEngine instance.
  final GameEngine? Function()? gameProvider;

  @override
  State<BoardExplorerScreen> createState() => _BoardExplorerScreenState();
}

class _BoardExplorerScreenState extends State<BoardExplorerScreen>
    with SingleTickerProviderStateMixin {
  late bool _threeD = widget.initial3D;
  late bool _showList = widget.initialList;
  late final SmartBoardFocusController _focus = SmartBoardFocusController(
    vsync: this,
  );
  TransformationController get _transform => _focus.transform;
  double _boardSide = 360;

  @override
  void initState() {
    super.initState();
    widget.boardUpdates?.addListener(_onBoardUpdate);
  }

  // Manual only: the board never pans/zooms just because a turn changed.
  // The user can still tap Find Current Player in the zoom toolbar.
  void _focusCurrent() {
    final media = MediaQuery.of(context);
    _focus.focusNow(
      game: widget.gameProvider?.call() ?? widget.game,
      visiblePositions: widget.visiblePositions,
      side: _boardSide,
      reducedMotion:
          media.disableAnimations ||
          GameExperienceSettings.instance.reducedMotion,
    );
  }

  @override
  void didUpdateWidget(covariant BoardExplorerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.boardUpdates != widget.boardUpdates) {
      oldWidget.boardUpdates?.removeListener(_onBoardUpdate);
      widget.boardUpdates?.addListener(_onBoardUpdate);
    }
  }

  void _onBoardUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.boardUpdates?.removeListener(_onBoardUpdate);
    _focus.dispose();
    super.dispose();
  }

  void _select(int index) {
    // Capture the callback before the page is popped: `widget` must not be
    // accessed from a callback after this State has been disposed.
    final select = widget.onSelect;
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => select(index));
  }

  void _setZoom(double value) {
    _focus.pause();
    final next = value.clamp(1.0, 4.5).toDouble();
    // Match the actual square GameBoardView, not the taller phone viewport.
    final distance = (1 - next) * _boardSide / 2;
    _transform.value = Matrix4.identity()
      ..translateByDouble(distance, distance, 0.0, 1.0)
      ..scaleByDouble(next, next, 1.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.text;
    final currentGame = widget.gameProvider?.call() ?? widget.game;
    final textStyle = TextStyle(
      fontFamily: t.font,
      fontFamilyFallback: t.fallbackFonts,
    );
    return Scaffold(
      backgroundColor: kBoardDark,
      appBar: AppBar(
        backgroundColor: const Color(0xFF13292A),
        foregroundColor: kBoardGold,
        title: Text(t.choose('Explore Board', 'বোর্ড দেখুন'), style: textStyle),
        actions: [
          // Decision sheets open automatically. Keep only a compact way to
          // reopen a dismissed purchase/auction/jail/debt sheet, instead of
          // the full-width banner that covered the top of the board.
          if (widget.onReviewDecision != null &&
              (widget.decisionEnabled?.call() ?? false) &&
              (currentGame.phase == TurnPhase.purchase ||
                  currentGame.phase == TurnPhase.auction ||
                  currentGame.phase == TurnPhase.jailDecision ||
                  currentGame.phase == TurnPhase.debt))
            IconButton(
              key: const ValueKey<String>('explorer-pending-decision-action'),
              tooltip: currentGame.phase == TurnPhase.auction
                  ? t.choose('Open bidding', 'দর দেওয়ার প্যানেল খুলুন')
                  : t.choose(
                      'Open pending action',
                      'সিদ্ধান্তের প্যানেল খুলুন',
                    ),
              onPressed: widget.onReviewDecision,
              icon: Badge(
                smallSize: 8,
                backgroundColor: kBoardGold,
                child: Icon(
                  currentGame.phase == TurnPhase.auction
                      ? Icons.gavel_rounded
                      : Icons.notifications_active_outlined,
                  color: kBoardGold,
                ),
              ),
            ),
          IconButton(
            tooltip: t.choose('Tile list', 'ঘরের তালিকা'),
            icon: Icon(
              _showList ? Icons.grid_view_rounded : Icons.list_alt_rounded,
            ),
            onPressed: () => setState(() => _showList = !_showList),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  _modeButton(
                    '2D',
                    !_threeD,
                    () => setState(() => _threeD = false),
                  ),
                  const SizedBox(width: 8),
                  _modeButton(
                    '3D',
                    _threeD,
                    () => setState(() => _threeD = true),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setState(() => _showList = !_showList),
                    icon: Icon(_showList ? Icons.grid_on : Icons.list),
                    label: Text(
                      t.choose(
                        _showList ? 'Board' : 'All 40',
                        _showList ? 'বোর্ড' : '৪০ ঘর',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Always-visible scrollable cash ranking in full-screen play.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Semantics(
                label: t.choose(
                  'Player cash balances and cash leader',
                  'খেলোয়াড়দের নগদ অর্থ ও সর্বোচ্চ নগদ',
                ),
                child: CompactPlayersStrip(
                  key: const ValueKey<String>('explorer-cash-leaderboard'),
                  game: currentGame,
                  text: t,
                ),
              ),
            ),
            Expanded(
              child: _showList
                  ? _tileList()
                  : LayoutBuilder(
                      builder: (context, box) {
                        _boardSide = box.biggest.shortestSide;
                        return GameBoardView(
                          engine: currentGame,
                          text: t,
                          onSelect: _select,
                          perspective: true,
                          cameraOverride: _threeD
                              ? BoardCameraPreset.tabletop
                              : BoardCameraPreset.topDown,
                          transformationController: _transform,
                          onInteractionStart: (_) => _focus.pause(),
                          visiblePositions: widget.visiblePositions,
                          dicePreview:
                              widget.diceValueProvider?.call() ??
                              widget.dicePreview,
                          diceRolling:
                              widget.isRollingProvider?.call() ??
                              widget.diceRolling,
                          onRoll: widget.onRoll,
                          onEndTurn: widget.onEndTurn,
                          canAct: widget.canAct,
                          actionEnabled: widget.actionEnabled,
                          // The inline status itself is the action button;
                          // never add a second large REVIEW OPTIONS panel.
                          onReviewDecision: widget.onReviewDecision,
                          decisionEnabled: widget.decisionEnabled,
                          onViewActivity: widget.onViewActivity,
                        );
                      },
                    ),
            ),
            if (!_showList) _zoomToolbar(t),
            if (!_showList)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 5, 12, 12),
                child: Text(
                  t.choose(
                    'Pinch to zoom • Drag to pan • Tap a space for details',
                    'দুই আঙুলে বড় করুন • সরিয়ে দেখুন • তথ্যের জন্য ঘর চাপুন',
                  ),
                  textAlign: TextAlign.center,
                  style: textStyle.copyWith(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Positioned below the board, horizontally, so it never obscures a tile.
  Widget _zoomToolbar(GameText t) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
    child: Align(
      alignment: Alignment.centerRight,
      child: DecoratedBox(
        key: const ValueKey<String>('board-zoom-toolbar'),
        decoration: BoxDecoration(
          color: const Color(0xFF1A3031),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBoardGold.withValues(alpha: .45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: t.choose('Zoom out', 'ছোট করুন'),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: const Icon(Icons.remove, color: kBoardGold),
              onPressed: () =>
                  _setZoom(_transform.value.getMaxScaleOnAxis() - .1),
            ),
            SizedBox(
              width: 62,
              child: Center(
                child: ValueListenableBuilder<Matrix4>(
                  valueListenable: _transform,
                  builder: (context, matrix, child) => Text(
                    '${(matrix.getMaxScaleOnAxis() * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Exo2',
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: t.choose('Zoom in', 'বড় করুন'),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: const Icon(Icons.add, color: kBoardGold),
              onPressed: () =>
                  _setZoom(_transform.value.getMaxScaleOnAxis() + .1),
            ),
            IconButton(
              tooltip: t.choose('Reset zoom', 'জুম আগের অবস্থায়'),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: const Icon(Icons.center_focus_strong, color: kBoardGold),
              onPressed: () => _setZoom(1),
            ),
            IconButton(
              key: const ValueKey<String>('board-smart-focus-current'),
              tooltip: t.choose(
                'Find current player',
                'বর্তমান খেলোয়াড়কে দেখুন',
              ),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: const Icon(Icons.my_location_rounded, color: kBoardGold),
              onPressed: _focusCurrent,
            ),
            // Full-screen exit remains to the right of the zoom controls.
            IconButton(
              key: const ValueKey<String>('board-exit-fullscreen'),
              tooltip: t.choose('Exit full screen', 'পূর্ণ পর্দা বন্ধ করুন'),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: const Icon(
                Icons.fullscreen_exit_rounded,
                color: kBoardGold,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _modeButton(String label, bool selected, VoidCallback action) =>
      OutlinedButton(
        onPressed: action,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(54, 44),
          backgroundColor: selected ? kBoardGold : null,
          foregroundColor: selected ? kBoardDark : kBoardGold,
          side: const BorderSide(color: kBoardGold),
        ),
        child: Text(label),
      );

  Widget _tileList() {
    final t = widget.text;
    final style = TextStyle(
      fontFamily: t.font,
      fontFamilyFallback: t.fallbackFonts,
    );
    final game = widget.gameProvider?.call() ?? widget.game;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemCount: game.spaces.length,
      itemBuilder: (context, index) {
        final tile = game.spaces[index];
        final property = game.properties[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Material(
            color: const Color(0xFF1A3333),
            borderRadius: BorderRadius.circular(11),
            child: ListTile(
              onTap: () => _select(index),
              leading: CircleAvatar(
                backgroundColor: groupColor(tile.group),
                foregroundColor: kBoardDark,
                child: Text(
                  t.integer(index),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                t.spaceName(index, tile.name),
                style: style.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                property.ownerId == null
                    ? t.choose('Unowned / special', 'মালিক নেই / বিশেষ ঘর')
                    : '${t.choose('Owner', 'মালিক')}: ${game.players[property.ownerId!].name}',
                style: style.copyWith(color: Colors.white70, fontSize: 12),
              ),
              trailing: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 98),
                child: Text(
                  tile.price > 0 ? t.money(tile.price) : '—',
                  textAlign: TextAlign.end,
                  style: style.copyWith(color: kBoardGold, fontSize: 14),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

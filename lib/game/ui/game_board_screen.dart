import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/ui/app_notices.dart';

import '../ai/bot_controller.dart';
import '../experience/game_audio.dart';
import '../experience/gameplay_motion.dart';
import '../experience/game_experience_settings.dart';
import '../experience/token_preferences.dart';
import '../experience/player_palette.dart';
import '../experience/board_camera_preset.dart';
import '../engine/game_engine.dart';
import '../models/game_models.dart';
import '../persistence/offline_game_store.dart';
import '../persistence/match_history_store.dart';
import 'game_text.dart';
import 'experience_settings_screen.dart';
import 'token_settings_screen.dart';
import 'match_history_screen.dart';
import 'widgets/victory_confetti.dart';
import 'widgets/game_board_view.dart';
import 'widgets/adaptive_board_panel.dart';
import 'widgets/compact_players_strip.dart';
import 'widgets/property_deed_card.dart';
import 'widgets/animated_deed_entrance.dart';
import 'widgets/victory_standings_sheet.dart';
import 'widgets/game_activity_sheet.dart';

/// Offline local game with Pass & Play or computer opponents.
/// Mobile/tablet/web layout is adaptive.
/// Deliberately has no Riverpod dependency, so it can be dropped into the
/// existing app without modifying the profile or localization providers.
class GameBoardScreen extends StatefulWidget {
  const GameBoardScreen({
    super.key,
    required this.playerNames,
    required this.languageCode,
    this.botDifficulties = const <int, BotDifficulty>{},
    this.resumedGame,
    this.matchId,
  });

  final List<String> playerNames;
  final String languageCode;
  final Map<int, BotDifficulty> botDifficulties;
  final GameEngine? resumedGame;
  final String? matchId;

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen> {
  late final GameEngine game;
  late final String _matchId;
  late final GameText t;
  final Random _random = Random();
  final BotController _botController = BotController();
  Timer? _botTimer;
  final Map<int, int> _visiblePositions = <int, int>{};
  DiceRoll? _dicePreview;
  bool _diceRolling = false;
  bool _busy = false;
  Future<void>? _completedHistoryWrite;
  final TextEditingController bidController = TextEditingController();
  final ValueNotifier<int> _boardUpdates = ValueNotifier<int>(0);
  final ValueNotifier<int> _decisionRevision = ValueNotifier<int>(0);
  bool _decisionOpen = false;
  String? _autoDecisionKey;
  BuildContext? _decisionContext;

  void _updateBoard() {
    _boardUpdates.value++;
  }

  bool get _needsDecision =>
      game.phase == TurnPhase.purchase ||
      game.phase == TurnPhase.auction ||
      game.phase == TurnPhase.jailDecision ||
      game.phase == TurnPhase.debt;

  String get _decisionKey =>
      '${game.turnNumber}-${game.phase}-'
      '${game.auction?.bidderId ?? -1}-'
      '${game.auction?.spaceIndex ?? -1}-'
      '${game.auction?.highBid ?? 0}-${game.auction?.minimumBid ?? 0}';

  /// Presents a dismissible modern sheet when a human needs to choose a
  /// purchase, auction bid, jail option or debt action on a compact screen.
  void _scheduleDecisionPrompt() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Applies to portrait, landscape and full-screen explorer. The sheet
      // only asks for a human decision; bidding is never automatic.
      if (!mounted ||
          _busy ||
          _decisionOpen ||
          !_needsDecision ||
          _actingBotId != null) {
        return;
      }
      if (_autoDecisionKey != _decisionKey) {
        _openDecisionSheet();
      }
    });
  }

  void _closeDecisionIfFinished() {
    if (!_decisionOpen || (_needsDecision && _actingBotId == null)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _decisionContext;
      if (ctx != null && ctx.mounted && ModalRoute.of(ctx)?.isCurrent == true) {
        Navigator.of(ctx).pop();
      }
    });
  }

  void _openDecisionSheet() {
    if (_decisionOpen || !_needsDecision || _actingBotId != null) return;
    _autoDecisionKey = _decisionKey;
    _decisionOpen = true;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF172A2C),
      barrierColor: const Color(0x99000000),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (sheetContext) {
        _decisionContext = sheetContext;
        return ValueListenableBuilder<int>(
          valueListenable: _decisionRevision,
          builder: (ctx, _, child) => AnimatedPadding(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * .78,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.notifications_active_outlined,
                          color: kBoardGold,
                          size: 23,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            t.choose(
                              'Action required',
                              'আপনার সিদ্ধান্ত প্রয়োজন',
                            ),
                            style: TextStyle(
                              fontFamily: t.font,
                              fontFamilyFallback: t.fallbackFonts,
                              color: kBoardGold,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    if (_needsDecision) ..._phaseActions(),
                    if (game.phase == TurnPhase.debt) ...<Widget>[
                      const SizedBox(height: 10),
                      _secondary(
                        t.choose('VIEW MY PROPERTIES', 'আমার সম্পত্তি দেখুন'),
                        () {
                          Navigator.of(sheetContext).pop();
                          _showMyProperties();
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: Text(
                        t.choose('VIEW BOARD', 'বোর্ড দেখুন'),
                        style: TextStyle(
                          fontFamily: t.font,
                          fontFamilyFallback: t.fallbackFonts,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      _decisionOpen = false;
      _decisionContext = null;
    });
  }

  Widget _decisionNotice() => Material(
    key: const ValueKey<String>('board-decision-notice'),
    color: const Color(0xFF234038),
    borderRadius: BorderRadius.circular(13),
    child: InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: _actingBotId == null ? _openDecisionSheet : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 15),
        child: Row(
          children: <Widget>[
            const Icon(Icons.notifications_active_outlined, color: kBoardGold),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                t.choose(
                  'Decision needed · Tap to open',
                  'সিদ্ধান্ত প্রয়োজন · খুলতে চাপুন',
                ),
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: t.font,
                  fontFamilyFallback: t.fallbackFonts,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_up, color: kBoardGold),
          ],
        ),
      ),
    ),
  );

  @override
  void initState() {
    super.initState();
    _matchId =
        widget.matchId ??
        '${DateTime.now().toUtc().microsecondsSinceEpoch}-${_random.nextInt(1 << 30)}';
    game =
        widget.resumedGame ??
        GameEngine(
          playerNames: widget.playerNames,
          colorIndices: PlayerColorPreferences.instance.selections,
        );
    t = GameText(widget.languageCode);
    unawaited(GameExperienceSettings.instance.ensureLoaded());
    unawaited(TokenPreferences.instance.ensureLoaded());
    for (final player in game.players) {
      _visiblePositions[player.id] = player.position;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _queueBot();
      _scheduleDecisionPrompt();
      if (widget.resumedGame == null) _persist();
    });
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    _boardUpdates.dispose();
    _decisionRevision.dispose();
    bidController.dispose();
    super.dispose();
  }

  bool _run(void Function() action, {bool scheduleBot = true}) {
    _botTimer?.cancel();
    try {
      final previousPhase = game.phase;
      final previousTurn = game.turnNumber;
      final previousDevelopment = <int>[
        for (final property in game.properties) property.development,
      ];
      final previousOwners = <int?>[
        for (final property in game.properties) property.ownerId,
      ];
      final previousAuctionBid = game.auction?.highBid ?? 0;
      setState(() {
        action();
        if (!_busy) {
          for (final player in game.players) {
            _visiblePositions[player.id] = player.position;
          }
        }
      });
      if (game.phase == TurnPhase.gameOver &&
          previousPhase != TurnPhase.gameOver) {
        GameAudio.instance.fire(GameSfx.victory);
      } else if (game.properties.asMap().entries.any(
        (e) => previousDevelopment[e.key] != e.value.development,
      )) {
        GameAudio.instance.fire(GameSfx.build);
      } else if (game.properties.asMap().entries.any(
        (e) => previousOwners[e.key] != e.value.ownerId,
      )) {
        GameAudio.instance.fire(GameSfx.purchase);
      } else if (game.phase == TurnPhase.jailDecision &&
          previousPhase != TurnPhase.jailDecision) {
        GameAudio.instance.fire(GameSfx.jail);
      } else if (game.phase == TurnPhase.auction &&
          (game.auction?.highBid ?? 0) > previousAuctionBid) {
        GameAudio.instance.fire(GameSfx.coin);
      } else if (game.turnNumber != previousTurn) {
        GameAudio.instance.fire(GameSfx.turn);
      }
      _persist();
      _updateBoard();
      _decisionRevision.value++;
      _closeDecisionIfFinished();
      if (scheduleBot) _queueBot();
      _scheduleDecisionPrompt();
      return true;
    } on GameRuleException catch (error) {
      if (!mounted) return false;
      AppNotices.of(context).hideCurrentSnackBar();
      AppNotices.of(context).showSnackBar(
        SnackBar(
          content: Text(t.moneyInEvent(error.message)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF9C423C),
        ),
      );
      return false;
    }
  }

  void _persist({bool showMessage = false}) {
    // Record completion BEFORE clearing the auto-save. The history store
    // de-duplicates repeated completion callbacks using the final state id.
    final Future<void> operation = game.phase == TurnPhase.gameOver
        ? MatchHistoryStore.record(
            MatchRecord.fromFinishedGame(
              game,
              widget.botDifficulties,
              matchId: _matchId,
            ),
          ).then((_) => OfflineGameStore.clearIfMatchId(_matchId))
        : OfflineGameStore.save(
            game,
            widget.botDifficulties,
            matchId: _matchId,
          );
    if (game.phase == TurnPhase.gameOver) {
      _completedHistoryWrite = operation;
    }
    unawaited(
      operation
          .then((_) {
            if (mounted && showMessage) {
              AppNotices.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    t.choose(
                      'Game saved on this device.',
                      'এই ডিভাইসে খেলা সংরক্ষিত হয়েছে।',
                    ),
                  ),
                ),
              );
            }
          })
          .catchError((Object error) {
            if (mounted) {
              AppNotices.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    t.choose(
                      'Could not save the game.',
                      'খেলা সংরক্ষণ করা যায়নি।',
                    ),
                  ),
                ),
              );
            }
          }),
    );
  }

  Future<void> _openMatchHistory() async {
    // Keep the last win visible even if the user taps History immediately
    // after the victory animation begins.
    try {
      await _completedHistoryWrite;
    } catch (_) {
      // The history page will show its own storage error if necessary.
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MatchHistoryScreen(languageCode: widget.languageCode),
      ),
    );
  }

  bool _isBot(int playerId) => widget.botDifficulties.containsKey(playerId);

  /// During an auction the bidder (not the current mover) takes the action.
  int? get _actingBotId {
    if (game.phase == TurnPhase.gameOver) return null;
    final id = game.phase == TurnPhase.auction
        ? game.auction!.bidderId
        : game.currentPlayerId;
    return _isBot(id) ? id : null;
  }

  void _queueBot() {
    _botTimer?.cancel();
    if (!mounted || _busy || _actingBotId == null) return;
    _botTimer = Timer(const Duration(milliseconds: 430), _runBot);
  }

  void _runBot() {
    if (!mounted || _busy) return;
    final id = _actingBotId;
    if (id == null) return;
    final decision = _botController.choose(
      game,
      playerId: id,
      difficulty: widget.botDifficulties[id]!,
    );
    if (decision == null) return;
    switch (decision.action) {
      case BotAction.roll:
      case BotAction.jailRoll:
        _animateRoll(jailAttempt: decision.action == BotAction.jailRoll);
        return;
      case BotAction.payFine:
        _run(game.payJailFine);
        return;
      case BotAction.useJailCard:
        _run(game.useJailCard);
        return;
      case BotAction.buy:
        _run(game.buyProperty);
        return;
      case BotAction.auction:
        _run(game.declinePurchase);
        return;
      case BotAction.bid:
        _run(() => game.bid(decision.amount!));
        return;
      case BotAction.pass:
        _run(game.passBid);
        return;
      case BotAction.build:
        _run(() => game.build(decision.spaceIndex!));
        return;
      case BotAction.sellBuilding:
        _run(() => game.sellBuilding(decision.spaceIndex!));
        return;
      case BotAction.mortgage:
        _run(() => game.mortgage(decision.spaceIndex!));
        return;
      case BotAction.unmortgage:
        _run(() => game.unmortgage(decision.spaceIndex!));
        return;
      case BotAction.bankrupt:
        _run(game.declareBankruptcy);
        return;
      case BotAction.endTurn:
        _run(game.endTurn);
        return;
    }
  }

  Future<void> _animateRoll({bool jailAttempt = false}) async {
    if (_busy || !mounted) return;
    _botTimer?.cancel();
    final movingId = game.currentPlayerId;
    final startPosition = game.currentPlayer.position;
    final finalFirst = _random.nextInt(6) + 1;
    final finalSecond = _random.nextInt(6) + 1;
    final reduceMotion =
        GameExperienceSettings.instance.reducedMotion ||
        MediaQuery.of(context).disableAnimations;
    GameAudio.instance.fire(GameSfx.dice);
    setState(() {
      _busy = true;
      _diceRolling = !reduceMotion;
    });
    _updateBoard();
    // Dice frames are only visual; the final pair is sent once to GameEngine.
    for (final delay
        in reduceMotion ? const <int>[] : GameplayMotion.diceFrames) {
      if (!mounted) return;
      setState(
        () => _dicePreview = DiceRoll(
          _random.nextInt(6) + 1,
          _random.nextInt(6) + 1,
        ),
      );
      _updateBoard();
      await Future<void>.delayed(Duration(milliseconds: delay));
    }
    if (!mounted) return;
    setState(() {
      _dicePreview = DiceRoll(finalFirst, finalSecond);
      _diceRolling = false;
    });
    _updateBoard();
    final applied = _run(() {
      if (jailAttempt) {
        game.tryJailRoll(finalFirst, finalSecond);
      } else {
        game.roll(finalFirst, finalSecond);
      }
    }, scheduleBot: false);
    if (applied) {
      final finishPosition = game.players[movingId].position;
      final path = GameplayMotion.dicePath(
        startPosition,
        finishPosition,
        finalFirst + finalSecond,
      );
      if (!reduceMotion) {
        for (final position in path) {
          if (!mounted) return;
          setState(() => _visiblePositions[movingId] = position);
          _updateBoard();
          await Future<void>.delayed(GameplayMotion.stepInterval);
        }
      }
      if (!mounted) return;
      setState(() => _visiblePositions[movingId] = finishPosition);
    }
    if (!mounted) return;
    setState(() {
      _dicePreview = null;
      _busy = false;
    });
    _updateBoard();
    _scheduleDecisionPrompt();
    _queueBot();
  }

  void _roll() => _animateRoll();
  void _tryJail() => _animateRoll(jailAttempt: true);

  bool get _canHumanAct => !_busy && _actingBotId == null;

  void _handleBoardDice() {
    if (!_canHumanAct) return;
    if (game.phase == TurnPhase.roll) {
      _roll();
    } else if (game.phase == TurnPhase.jailDecision) {
      _tryJail();
    }
  }

  void _handleBoardEndTurn() {
    if (_canHumanAct && game.phase == TurnPhase.complete) {
      _run(game.endTurn);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBoardDark,
      appBar: AppBar(
        backgroundColor: const Color(0xFF122729),
        foregroundColor: kBoardGold,
        title: const Text(
          'bHiVE',
          style: TextStyle(fontFamily: 'Exo2', fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: t.choose('Save game', 'খেলা সংরক্ষণ'),
            onPressed: _busy ? null : () => _persist(showMessage: true),
            icon: const Icon(Icons.save_outlined),
          ),
          PopupMenuButton<BoardCameraPreset>(
            tooltip: t.choose('Camera view', 'ক্যামেরা দৃশ্য'),
            icon: const Icon(Icons.view_in_ar_rounded),
            initialValue: GameExperienceSettings.instance.cameraPreset,
            onSelected: (preset) => unawaited(
              GameExperienceSettings.instance.setCameraPreset(preset),
            ),
            itemBuilder: (context) => [
              for (final preset in BoardCameraPreset.values)
                PopupMenuItem<BoardCameraPreset>(
                  value: preset,
                  child: Text(
                    preset.label(t.bn),
                    style: TextStyle(
                      fontFamily: t.font,
                      fontFamilyFallback: t.fallbackFonts,
                    ),
                  ),
                ),
            ],
          ),
          PopupMenuButton<String>(
            tooltip: t.choose('More options', 'আরও অপশন'),
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (action) {
              switch (action) {
                case 'tokens':
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TokenSettingsScreen(
                        languageCode: widget.languageCode,
                      ),
                    ),
                  );
                  break;
                case 'history':
                  unawaited(_openMatchHistory());
                  break;
                case 'sound':
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ExperienceSettingsScreen(
                        languageCode: widget.languageCode,
                      ),
                    ),
                  );
                  break;
                case 'activity':
                  GameActivitySheet.show(
                    context,
                    text: t,
                    events: List<String>.of(game.log),
                    players: game.players,
                    structuredEvents: game.activityEvents,
                  );
                  break;
                case 'bank':
                  _showBankInfo();
                  break;
              }
            },
            itemBuilder: (_) => <PopupMenuEntry<String>>[
              PopupMenuItem(
                value: 'activity',
                child: Text(t.choose('Match activity', 'খেলার কার্যক্রম')),
              ),
              PopupMenuItem(
                value: 'tokens',
                child: Text(t.choose('Player tokens', 'খেলোয়াড়ের টোকেন')),
              ),
              PopupMenuItem(
                value: 'history',
                child: Text(t.choose('Match history', 'খেলার ইতিহাস')),
              ),
              PopupMenuItem(
                value: 'sound',
                child: Text(t.choose('Game experience', 'গেম অভিজ্ঞতা')),
              ),
              PopupMenuItem(
                value: 'bank',
                child: Text(t.choose('Bank stock', 'ব্যাংকের ভবন')),
              ),
            ],
          ),
        ],
      ),
      // Primary roll/end-turn actions now live only on the board itself.
      bottomNavigationBar: null,
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                final wide = usesWideGameBoardLayout(c.biggest);
                if (wide) {
                  return Padding(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      children: [
                        Expanded(
                          child: AdaptiveBoardPanel(
                            game: game,
                            text: t,
                            onSelect: (index) {
                              if (!_busy && _actingBotId == null) {
                                _showTile(index);
                              }
                            },
                            visiblePositions: _visiblePositions,
                            dicePreview: _dicePreview,
                            diceRolling: _diceRolling,
                            onRoll: _handleBoardDice,
                            onEndTurn: _handleBoardEndTurn,
                            canAct: _canHumanAct,
                            actionEnabled: () => _canHumanAct,
                            onReviewDecision: _openDecisionSheet,
                            decisionEnabled: () =>
                                _needsDecision && _canHumanAct,
                            boardUpdates: _boardUpdates,
                            diceValueProvider: () => _dicePreview,
                            isRollingProvider: () => _diceRolling,
                            onViewActivity: () => GameActivitySheet.show(
                              context,
                              text: t,
                              events: List<String>.of(game.log),
                              players: game.players,
                              structuredEvents: game.activityEvents,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 350,
                          child: ListView(
                            children: [
                              _playerCards(),
                              const SizedBox(height: 14),
                              _turnPanel(),
                              const SizedBox(height: 14),
                              _eventsPanel(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final boardSide = min(c.maxWidth - 24, 680.0);
                final needsDecision = _needsDecision;
                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    CompactPlayersStrip(game: game, text: t),
                    if (needsDecision) ...[
                      const SizedBox(height: 10),
                      _decisionNotice(),
                    ],
                    if (game.phase == TurnPhase.gameOver) ...<Widget>[
                      const SizedBox(height: 10),
                      _turnPanel(),
                    ],
                    const SizedBox(height: 10),
                    SizedBox(
                      height: boardSide + 76,
                      child: AdaptiveBoardPanel(
                        game: game,
                        text: t,
                        onSelect: (index) {
                          if (!_busy && _actingBotId == null) _showTile(index);
                        },
                        visiblePositions: _visiblePositions,
                        dicePreview: _dicePreview,
                        diceRolling: _diceRolling,
                        onRoll: _handleBoardDice,
                        onEndTurn: _handleBoardEndTurn,
                        canAct: _canHumanAct,
                        actionEnabled: () => _canHumanAct,
                        onReviewDecision: _openDecisionSheet,
                        decisionEnabled: () => _needsDecision && _canHumanAct,
                        boardUpdates: _boardUpdates,
                        diceValueProvider: () => _dicePreview,
                        isRollingProvider: () => _diceRolling,
                        onViewActivity: () => GameActivitySheet.show(
                          context,
                          text: t,
                          events: List<String>.of(game.log),
                          players: game.players,
                          structuredEvents: game.activityEvents,
                        ),
                      ),
                    ),

                    if (game.phase == TurnPhase.roll ||
                        game.phase == TurnPhase.complete) ...<Widget>[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _busy || _actingBotId != null
                            ? null
                            : _showMyProperties,
                        icon: const Icon(Icons.real_estate_agent_outlined),
                        label: Text(
                          t.choose('MY PROPERTIES', 'আমার সম্পত্তি'),
                          style: TextStyle(
                            fontFamily: t.font,
                            fontFamilyFallback: t.fallbackFonts,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kBoardGold,
                          minimumSize: const Size.fromHeight(47),
                          side: const BorderSide(color: kBoardGold),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _eventsPanel(),
                  ],
                );
              },
            ),
          ),
          if (game.phase == TurnPhase.gameOver)
            const Positioned.fill(child: VictoryConfetti()),
        ],
      ),
    );
  }

  Widget _playerCards() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.choose('PLAYERS', 'খেলোয়াড়'),
            style: TextStyle(
              fontFamily: t.font,
              color: kBoardGold,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 9),
          for (final p in game.players)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: game.currentPlayerId == p.id
                      ? const Color(0xFF255045)
                      : const Color(0xFF1D3234),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: game.currentPlayerId == p.id
                        ? kBoardGold
                        : Colors.white12,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: PlayerPalette.at(p.colorIndex),
                      child: Icon(
                        _isBot(p.id)
                            ? Icons.smart_toy_rounded
                            : TokenPreferences.instance.styleFor(p.id).icon,
                        color: kBoardDark,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: t.font,
                          decoration: p.bankrupt
                              ? TextDecoration.lineThrough
                              : null,
                          color: p.bankrupt ? Colors.white38 : Colors.white,
                        ),
                      ),
                    ),
                    if (p.inJail)
                      const Padding(
                        padding: EdgeInsets.only(right: 5),
                        child: Icon(
                          Icons.lock_rounded,
                          color: Colors.orange,
                          size: 16,
                        ),
                      ),
                    Text(
                      t.money(p.balance),
                      style: const TextStyle(
                        fontFamily: 'Exo2',
                        fontWeight: FontWeight.bold,
                        color: kBoardGold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _turnPanel() {
    final player = game.currentPlayer;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.choose('CURRENT TURN', 'বর্তমান চাল'),
            style: TextStyle(
              fontFamily: t.font,
              color: kBoardGold,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            player.name,
            style: TextStyle(
              fontFamily: t.font,
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_actingBotId != null)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Row(
                children: [
                  const Icon(
                    Icons.smart_toy_rounded,
                    size: 16,
                    color: kBoardGold,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      t.choose(
                        'Computer is thinking…',
                        'কম্পিউটার চাল দিচ্ছে…',
                      ),
                      style: TextStyle(
                        color: Colors.white70,
                        fontFamily: t.font,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(color: kBoardGold, minHeight: 2),
            ),
          const SizedBox(height: 5),
          Text(
            '${t.choose('Position', 'অবস্থান')}: '
            '${t.spaceName(player.position, game.spaces[player.position].name)}',
            style: TextStyle(fontFamily: t.font, color: Colors.white70),
          ),
          if (game.lastRoll != null) ...[
            const SizedBox(height: 5),
            Text(
              '${t.choose('Dice', 'পাশা')}: '
              '${t.integer(game.lastRoll!.first)} + '
              '${t.integer(game.lastRoll!.second)} = '
              '${t.integer(game.lastRoll!.sum)}',
              style: const TextStyle(color: kBoardGold),
            ),
          ],
          const SizedBox(height: 17),
          ..._phaseActions(),
          const SizedBox(height: 10),
          Text(
            t.choose(
              'Tap any board tile to view its title deed and manage your properties.',
              'টাইল স্পর্শ করে সম্পত্তির তথ্য দেখুন বা পরিচালনা করুন।',
            ),
            style: TextStyle(
              fontFamily: t.font,
              fontSize: 12,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _phaseActions() {
    switch (game.phase) {
      case TurnPhase.roll:
        return const <Widget>[];
      case TurnPhase.purchase:
        final tile = game.spaces[game.pendingPurchaseIndex!];
        return [
          Text(
            '${t.spaceName(tile.index, tile.name)} — ${t.money(tile.price)}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 10),
          _primary(
            t.choose('BUY PROPERTY', 'সম্পত্তি কিনুন'),
            Icons.shopping_cart_outlined,
            game.currentPlayer.balance >= tile.price
                ? () => _run(game.buyProperty)
                : null,
          ),
          const SizedBox(height: 9),
          _secondary(
            t.choose('DECLINE / AUCTION', 'নিলাম শুরু করুন'),
            () => _run(game.declinePurchase),
          ),
        ];
      case TurnPhase.auction:
        final a = game.auction!;
        final item = game.spaces[a.spaceIndex];
        final bidder = game.players[a.bidderId];
        if (bidController.text.isEmpty ||
            int.tryParse(bidController.text) == null ||
            int.parse(bidController.text) < a.minimumBid) {
          bidController.text = '${a.minimumBid}';
        }
        return [
          Text(
            t.choose('AUCTION', 'নিলাম'),
            style: const TextStyle(
              color: kBoardGold,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            t.spaceName(item.index, item.name),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 5),
          Text(
            '${t.choose('Bidder', 'দরদাতা')}: ${bidder.name}',
            style: const TextStyle(color: Colors.white70),
          ),
          Text(
            '${t.choose('Highest', 'সর্বোচ্চ')}: '
            '${t.money(a.highBid)}',
            style: const TextStyle(color: Colors.white70),
          ),
          if (a.highestBidderId != null)
            Text(
              '${t.choose('Leader', 'এগিয়ে')}: '
              '${game.players[a.highestBidderId!].name}',
              style: const TextStyle(color: Colors.white70),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: bidController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText:
                  '${t.choose('Minimum', 'সর্বনিম্ন')}: '
                  '${t.money(a.minimumBid)}',
              labelStyle: const TextStyle(color: kBoardGold),
              prefixText: t.money(0).substring(0, 1),
              prefixStyle: const TextStyle(color: kBoardGold),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          _primary(
            t.choose('PLACE BID', 'দর দিন'),
            Icons.gavel_rounded,
            () => _run(() => game.bid(int.tryParse(bidController.text) ?? 0)),
          ),
          const SizedBox(height: 8),
          _secondary(t.choose('PASS', 'পাস'), () => _run(game.passBid)),
        ];
      case TurnPhase.jailDecision:
        return [
          Text(
            t.choose('IN JAIL', 'কারাগারে'),
            style: const TextStyle(
              color: Colors.orangeAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t.choose(
              'Close this sheet and tap the two dice on the board to try doubles.',
              'ডাবল পাওয়ার চেষ্টা করতে এই প্যানেল বন্ধ করে বোর্ডের দুটি পাশায় চাপুন।',
            ),
            style: TextStyle(
              fontFamily: t.font,
              fontFamilyFallback: t.fallbackFonts,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 10),
          _secondary(
            '${t.choose('PAY FINE', 'জরিমানা দিন')} '
            '(${t.money(50)})',
            () => _run(game.payJailFine),
          ),
          if (game.currentPlayer.getOutOfJailCards > 0) ...[
            const SizedBox(height: 8),
            _secondary(
              t.choose('USE JAIL CARD', 'জেল মুক্তি কার্ড'),
              () => _run(game.useJailCard),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${t.choose('Failed attempts', 'ব্যর্থ চেষ্টা')}: '
            '${t.integer(game.currentPlayer.jailFailedRolls)}/${t.integer(3)}',
            style: const TextStyle(color: Colors.white70),
          ),
        ];
      case TurnPhase.debt:
        return [
          Text(
            t.choose('DEBT RESOLUTION', 'ঋণ পরিশোধ'),
            style: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            t.choose(
              'Mortgage or sell buildings until your cash is not negative. Tap an owned tile.',
              'নগদ অর্থ শূন্যের বেশি করতে বন্ধক দিন বা বাড়ি বিক্রি করুন।',
            ),
            style: TextStyle(fontFamily: t.font, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          _secondary(
            t.choose('DECLARE BANKRUPTCY', 'দেউলিয়া ঘোষণা'),
            _confirmBankruptcy,
          ),
        ];
      case TurnPhase.complete:
        return [
          _secondary(
            t.choose('MANAGE PROPERTIES', 'সম্পত্তি পরিচালনা'),
            _showMyProperties,
          ),
        ];
      case TurnPhase.gameOver:
        final winner = game.players[game.winnerId!];
        return [
          const Center(
            child: Icon(
              Icons.emoji_events_rounded,
              color: kBoardGold,
              size: 65,
            ),
          ),
          Text(
            '${winner.name} ${t.choose('WINS!', 'বিজয়ী!')}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: t.font,
              color: kBoardGold,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 9),
          _secondary(
            t.choose('FINAL STANDINGS', 'চূড়ান্ত ফলাফল'),
            () => VictoryStandingsSheet.show(context, game: game, text: t),
          ),
          const SizedBox(height: 9),
          _secondary(
            t.choose('MATCH HISTORY & AWARDS', 'ইতিহাস ও অর্জন'),
            () => unawaited(_openMatchHistory()),
          ),
          const SizedBox(height: 9),
          _primary(
            t.choose('NEW GAME', 'নতুন খেলা'),
            Icons.refresh_rounded,
            () => Navigator.pop(context),
          ),
        ];
    }
  }

  Widget _eventsPanel() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                t.choose('RECENT EVENTS', 'সাম্প্রতিক ঘটনা'),
                style: TextStyle(
                  fontFamily: t.font,
                  color: kBoardGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => GameActivitySheet.show(
                context,
                text: t,
                events: List<String>.of(game.log),
                players: game.players,
                structuredEvents: game.activityEvents,
              ),
              icon: const Icon(Icons.history, size: 16),
              label: Text(
                t.choose('All', 'সব'),
                style: TextStyle(fontFamily: t.font),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final line in game.log.take(8))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: 8, top: 7),
                  child: Icon(Icons.circle, size: 6, color: kBoardGold),
                ),
                Expanded(
                  child: Text(
                    t.eventText(line),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _panel({required Widget child}) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFF172A2C),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFF385B52)),
    ),
    child: child,
  );

  Widget _primary(String label, IconData icon, VoidCallback? action) =>
      FilledButton.icon(
        onPressed: _busy || _actingBotId != null ? null : action,
        style: FilledButton.styleFrom(
          backgroundColor: kBoardGold,
          foregroundColor: kBoardDark,
          minimumSize: const Size.fromHeight(51),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
        icon: Icon(icon),
        label: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: t.font, fontWeight: FontWeight.w800),
        ),
      );

  Widget _secondary(String label, VoidCallback? action) => OutlinedButton(
    onPressed: _busy || _actingBotId != null ? null : action,
    style: OutlinedButton.styleFrom(
      foregroundColor: kBoardGold,
      minimumSize: const Size.fromHeight(46),
      side: const BorderSide(color: kBoardGold),
    ),
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(fontFamily: t.font),
    ),
  );

  Future<void> _showBankInfo() => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t.choose('Bank inventory', 'ব্যাংকের মজুত')),
      content: Text(
        '${t.choose('Available houses', 'অবশিষ্ট বাড়ি')}: '
        '${t.integer(game.bankHouses)}/${t.integer(32)}\n'
        '${t.choose('Available hotels', 'অবশিষ্ট হোটেল')}: '
        '${t.integer(game.bankHotels)}/${t.integer(12)}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t.choose('CLOSE', 'বন্ধ করুন')),
        ),
      ],
    ),
  );

  void _showMyProperties() {
    if (_busy || _actingBotId != null) return;
    final owned = game.spaces
        .where((s) => game.properties[s.index].ownerId == game.currentPlayerId)
        .toList();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1B3031),
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: min(MediaQuery.sizeOf(ctx).height * .6, 500.0),
            child: Column(
              children: [
                Text(
                  t.choose('My properties', 'আমার সম্পত্তি'),
                  style: TextStyle(
                    fontFamily: t.font,
                    color: kBoardGold,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final s in owned)
                        ListTile(
                          title: Text(
                            t.spaceName(s.index, s.name),
                            style: const TextStyle(color: Colors.white),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: kBoardGold,
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _showTile(s.index);
                          },
                        ),
                      if (owned.isEmpty)
                        Text(
                          t.choose(
                            'No properties yet.',
                            'এখনো কোনো সম্পত্তি নেই।',
                          ),
                          style: TextStyle(
                            fontFamily: t.font,
                            color: Colors.white70,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTile(int index) {
    if (_busy || _actingBotId != null) return;
    final s = game.spaces[index];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B3031),
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, refreshSheet) {
          final state = game.properties[index];
          final ownedByMe = state.ownerId == game.currentPlayerId;
          void update(void Function() action) {
            _run(action);
            refreshSheet(() {});
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                22,
                16,
                22,
                max(MediaQuery.viewInsetsOf(ctx).bottom, 18.0),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedDeedEntrance(
                        child: PropertyDeedCard(
                          game: game,
                          text: t,
                          spaceIndex: index,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (ownedByMe &&
                          s.purchasable &&
                          game.phase != TurnPhase.gameOver &&
                          game.phase != TurnPhase.auction) ...[
                        if (s.kind == SpaceKind.street) ...[
                          _primary(
                            t.choose(
                              'BUILD HOUSE / HOTEL',
                              'বাড়ি / হোটেল নির্মাণ',
                            ),
                            Icons.add_home_work_outlined,
                            game.phase == TurnPhase.debt
                                ? null
                                : () => update(() => game.build(index)),
                          ),
                          const SizedBox(height: 8),
                          _secondary(
                            t.choose('SELL BUILDING', 'ভবন বিক্রি'),
                            () => update(() => game.sellBuilding(index)),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (state.mortgaged)
                          _secondary(
                            t.choose('UNMORTGAGE', 'বন্ধক ছাড়ান'),
                            game.phase == TurnPhase.debt
                                ? null
                                : () => update(() => game.unmortgage(index)),
                          )
                        else
                          _secondary(
                            t.choose('MORTGAGE', 'বন্ধক দিন'),
                            () => update(() => game.mortgage(index)),
                          ),
                        if (game.phase == TurnPhase.roll ||
                            game.phase == TurnPhase.complete) ...[
                          const SizedBox(height: 8),
                          _secondary(
                            t.choose(
                              'TRADE / SELL TO PLAYER',
                              'অন্য খেলোয়াড়কে বিক্রি',
                            ),
                            () {
                              Navigator.pop(ctx);
                              _offerTrade(index);
                            },
                          ),
                        ],
                      ],
                      const SizedBox(height: 12),
                      _secondary(
                        t.choose('CLOSE', 'বন্ধ করুন'),
                        () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _offerTrade(int index) async {
    final others = game.players
        .where((p) => !p.bankrupt && p.id != game.currentPlayerId)
        .toList();
    if (others.isEmpty) return;
    var targetId = others.first.id;
    final price = TextEditingController(text: '${game.spaces[index].price}');
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, refresh) => AlertDialog(
          title: Text(
            t.choose('Offer property trade', 'সম্পত্তি বিনিময়ের প্রস্তাব'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.spaceName(index, game.spaces[index].name)),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: targetId,
                decoration: InputDecoration(
                  labelText: t.choose('Buyer', 'ক্রেতা'),
                ),
                items: [
                  for (final p in others)
                    DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
                onChanged: (id) {
                  if (id != null) refresh(() => targetId = id);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: t.choose('Offer price', 'প্রস্তাবিত মূল্য'),
                  prefixText: t.money(0).substring(0, 1),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                t.choose(
                  _isBot(targetId)
                      ? 'The computer will evaluate your offer.'
                      : 'The receiving player must agree before confirming.',
                  _isBot(targetId)
                      ? 'কম্পিউটার আপনার প্রস্তাব মূল্যায়ন করবে।'
                      : 'নিশ্চিত করার আগে ক্রেতার সম্মতি নিন।',
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.choose('CANCEL', 'বাতিল')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                t.choose(
                  _isBot(targetId) ? 'SEND OFFER' : 'ACCEPT TRADE',
                  _isBot(targetId) ? 'প্রস্তাব পাঠান' : 'প্রস্তাব গ্রহণ',
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (approved == true && mounted && _actingBotId == null) {
      final cost = int.tryParse(price.text.trim()) ?? -1;
      final offer = TradeOffer(
        fromPlayerId: game.currentPlayerId,
        toPlayerId: targetId,
        propertiesFrom: [index],
        cashTo: cost,
      );
      final difficulty = widget.botDifficulties[targetId];
      if (difficulty != null &&
          !_botController.acceptsTrade(game, offer, difficulty)) {
        AppNotices.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t.choose(
                'Computer player declined the offer.',
                'কম্পিউটার খেলোয়াড় প্রস্তাবটি প্রত্যাখ্যান করেছে।',
              ),
            ),
          ),
        );
      } else {
        _run(() => game.acceptTrade(offer));
      }
    }
    price.dispose();
  }

  Future<void> _confirmBankruptcy() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.choose('Declare bankruptcy?', 'দেউলিয়া ঘোষণা করবেন?')),
        content: Text(
          t.choose(
            'You will leave this match and transfer your assets.',
            'আপনি খেলা থেকে বাদ পড়বেন এবং আপনার সম্পত্তি হস্তান্তর হবে।',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.choose('CANCEL', 'বাতিল')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.choose('CONFIRM', 'নিশ্চিত করুন')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) _run(game.declareBankruptcy);
  }
}

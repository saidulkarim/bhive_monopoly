import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/ui/app_notices.dart';

import '../ai/bot_controller.dart';
import '../ai/bot_name_pool.dart';
import '../experience/player_palette.dart';
import 'widgets/player_color_picker.dart';
import '../persistence/offline_game_store.dart';
import 'game_board_screen.dart';
import 'lan_lobby_screen.dart';
import 'game_text.dart';
import 'game_typography.dart';
import 'widgets/game_board_view.dart';

/// Setup for both pass-and-play and offline solo-vs-computer play.
/// Bots share the exact same GameEngine used by human players.
class GameSetupScreen extends StatefulWidget {
  const GameSetupScreen({
    super.key,
    required this.languageCode,
    required this.playerName,
    this.avatarIndex = 0,
    this.avatarBytes,
  });

  final String languageCode;
  final String playerName;
  final int avatarIndex;
  final Uint8List? avatarBytes;

  @override
  State<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends State<GameSetupScreen> {
  late final GameText t;
  late final List<TextEditingController> names;
  int playerCount = 2;
  bool vsComputer = true;
  BotDifficulty difficulty = BotDifficulty.medium;
  SavedOfflineMatch? _resume;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    t = GameText(widget.languageCode);
    names = List<TextEditingController>.generate(
      6,
      (index) => TextEditingController(
        text: index == 0
            ? widget.playerName
            : '${t.choose('Player', 'খেলোয়াড়')} ${t.integer(index + 1)}',
      ),
    );
    _checkSavedGame();
  }

  Future<void> _checkSavedGame() async {
    try {
      final saved = await OfflineGameStore.load();
      if (mounted) {
        setState(() {
          _resume = saved;
          _loadError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _resume = null;
          _loadError = t.choose(
            'Saved match is invalid. Start a new game.',
            'সংরক্ষিত খেলা ত্রুটিপূর্ণ। নতুন খেলা শুরু করুন।',
          );
        });
      }
    }
  }

  void _continueSavedGame() {
    final saved = _resume;
    if (saved == null) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => GameTypography(
              languageCode: widget.languageCode,
              child: GameBoardScreen(
                playerNames: [for (final p in saved.game.players) p.name],
                languageCode: widget.languageCode,
                botDifficulties: saved.botDifficulties,
                resumedGame: saved.game,
                matchId: saved.matchId,
              ),
            ),
          ),
        )
        .then((_) => _checkSavedGame());
  }

  @override
  void dispose() {
    for (final controller in names) {
      controller.dispose();
    }
    super.dispose();
  }

  String _difficultyLabel(BotDifficulty level) {
    switch (level) {
      case BotDifficulty.easy:
        return t.choose('Easy', 'সহজ');
      case BotDifficulty.medium:
        return t.choose('Medium', 'মাঝারি');
      case BotDifficulty.hard:
        return t.choose('Hard', 'কঠিন');
    }
  }

  void _start() {
    final localNames = names
        .take(playerCount)
        .map((c) => c.text.trim())
        .toList();
    final configuredNames = vsComputer
        ? <String>[
            localNames.first,
            ...BotNamePool.pick(
              playerCount - 1,
              reserved: <String>[localNames.first],
            ),
          ]
        : localNames;
    if (configuredNames.any((n) => n.isEmpty)) {
      AppNotices.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t.choose(
              'Enter every player name.',
              'প্রত্যেক খেলোয়াড়ের নাম লিখুন।',
            ),
          ),
        ),
      );
      return;
    }
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => GameTypography(
              languageCode: widget.languageCode,
              child: GameBoardScreen(
                playerNames: configuredNames,
                languageCode: widget.languageCode,
                botDifficulties: vsComputer
                    ? {for (var i = 1; i < playerCount; i++) i: difficulty}
                    : const <int, BotDifficulty>{},
              ),
            ),
          ),
        )
        .then((_) => _checkSavedGame());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBoardDark,
    appBar: AppBar(
      title: Text(
        t.choose('New Game', 'নতুন গেম'),
        style: TextStyle(fontFamily: t.font, color: kBoardGold),
      ),
      backgroundColor: kBoardDark,
      foregroundColor: Colors.white,
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Icon(Icons.casino_rounded, size: 70, color: kBoardGold),
              const SizedBox(height: 14),
              Text(
                'bHiVE Monopoly',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Exo2',
                  color: kBoardGold,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 22),
              if (_resume != null) ...[
                Card(
                  color: const Color(0xFF1B3534),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          t.choose(
                            'SAVED OFFLINE MATCH',
                            'সংরক্ষিত অফলাইন খেলা',
                          ),
                          style: TextStyle(
                            fontFamily: t.font,
                            color: kBoardGold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_resume!.game.players.map((p) => p.name).join(' • ')}\n'
                          '${t.choose('Turn', 'চাল')}: ${t.integer(_resume!.game.turnNumber)}',
                          style: TextStyle(
                            fontFamily: t.font,
                            color: Colors.white70,
                          ),
                        ),
                        if (_resume!.recoveredFromBackup) ...[
                          const SizedBox(height: 10),
                          Text(
                            t.choose(
                              'Recovered the previous valid checkpoint. The latest turn may not be included.',
                              'আগের সঠিক সংরক্ষণ থেকে খেলা উদ্ধার হয়েছে। সর্বশেষ চালটি নাও থাকতে পারে।',
                            ),
                            style: TextStyle(
                              fontFamily: t.font,
                              color: Colors.orangeAccent,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _continueSavedGame,
                          icon: const Icon(Icons.restore),
                          label: Text(
                            t.choose(
                              'CONTINUE SAVED GAME',
                              'আগের খেলা চালু করুন',
                            ),
                            style: TextStyle(fontFamily: t.font),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            await OfflineGameStore.clear();
                            await _checkSavedGame();
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: Text(
                            t.choose(
                              'Delete saved game',
                              'সংরক্ষিত খেলা মুছুন',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (_loadError != null) ...[
                Text(
                  _loadError!,
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
                const SizedBox(height: 8),
              ],
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    avatar: const Icon(Icons.smart_toy_outlined, size: 18),
                    label: Text(
                      t.choose('Vs Computer', 'কম্পিউটারের সাথে'),
                      style: TextStyle(fontFamily: t.font),
                    ),
                    selected: vsComputer,
                    onSelected: (_) => setState(() => vsComputer = true),
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.groups_outlined, size: 18),
                    label: Text(
                      t.choose('Pass & Play', 'একই ডিভাইসে'),
                      style: TextStyle(fontFamily: t.font),
                    ),
                    selected: !vsComputer,
                    onSelected: (_) => setState(() => vsComputer = false),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                vsComputer
                    ? t.choose(
                        'Play offline against 1–5 AI opponents.',
                        'ইন্টারনেট ছাড়াই ১–৫ জন কম্পিউটার প্রতিপক্ষের সঙ্গে খেলুন।',
                      )
                    : t.choose(
                        'Play together with 2–6 people on one device.',
                        'একই ডিভাইসে ২–৬ জন পালাক্রমে খেলুন।',
                      ),
                style: TextStyle(color: Colors.white70, fontFamily: t.font),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                t.choose('Total players', 'মোট খেলোয়াড়'),
                style: TextStyle(
                  color: kBoardGold,
                  fontFamily: t.font,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (var n = 2; n <= 6; n++)
                    ChoiceChip(
                      label: Text(t.integer(n)),
                      selected: playerCount == n,
                      onSelected: (_) => setState(() => playerCount = n),
                    ),
                ],
              ),
              if (vsComputer) ...[
                const SizedBox(height: 16),
                Text(
                  t.choose('AI difficulty', 'AI এর কঠিনতার মাত্রা'),
                  style: TextStyle(
                    color: kBoardGold,
                    fontFamily: t.font,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final level in BotDifficulty.values)
                      ChoiceChip(
                        label: Text(_difficultyLabel(level)),
                        selected: difficulty == level,
                        onSelected: (_) => setState(() => difficulty = level),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              for (var i = 0; i < (vsComputer ? 1 : playerCount); i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: names[i],
                    maxLength: 24,
                    style: TextStyle(fontFamily: t.font, color: Colors.white),
                    decoration: InputDecoration(
                      labelText: i == 0
                          ? t.choose('Your name', 'আপনার নাম')
                          : '${t.choose('Player', 'খেলোয়াড়')} ${t.integer(i + 1)}',
                      labelStyle: TextStyle(
                        fontFamily: t.font,
                        color: Colors.white70,
                      ),
                      prefixIcon: IconButton(
                        key: ValueKey<String>('select-seat-color-$i'),
                        tooltip: t.choose(
                          'Choose player color',
                          'খেলোয়াড়ের রং বেছে নিন',
                        ),
                        onPressed: () async {
                          await showPlayerColorPicker(
                            context,
                            seat: i,
                            languageCode: widget.languageCode,
                            activeSeats: vsComputer ? 1 : playerCount,
                          );
                          if (mounted) setState(() {});
                        },
                        icon: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: PlayerColorPreferences.instance.colorFor(i),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white70,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFF172B2C),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              if (vsComputer)
                Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Text(
                    t.choose(
                      'Computer players move automatically. You control Player 1.',
                      'কম্পিউটারের চাল স্বয়ংক্রিয়ভাবে হবে। প্রথম খেলোয়াড় আপনি।',
                    ),
                    style: TextStyle(fontFamily: t.font, color: Colors.white60),
                  ),
                ),
              if (_resume != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    t.choose(
                      'Starting a new offline game replaces the saved match.',
                      'নতুন অফলাইন খেলা শুরু করলে আগের সংরক্ষিত খেলা বদলে যাবে।',
                    ),
                    style: TextStyle(
                      fontFamily: t.font,
                      color: Colors.orangeAccent,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _start,
                style: FilledButton.styleFrom(
                  backgroundColor: kBoardGold,
                  foregroundColor: kBoardDark,
                  minimumSize: const Size.fromHeight(56),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  t.choose('START GAME', 'খেলা শুরু করুন'),
                  style: TextStyle(
                    fontFamily: t.font,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () {
                  final name = names.first.text.trim();
                  if (name.isEmpty) {
                    AppNotices.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          t.choose(
                            'Enter your name first.',
                            'আগে আপনার নাম লিখুন।',
                          ),
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => GameTypography(
                        languageCode: widget.languageCode,
                        child: LanLobbyScreen(
                          playerName: name,
                          languageCode: widget.languageCode,
                          avatarIndex: widget.avatarIndex,
                          avatarBytes: widget.avatarBytes,
                        ),
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: kBoardGold,
                  side: const BorderSide(color: kBoardGold),
                  minimumSize: const Size.fromHeight(56),
                ),
                icon: const Icon(Icons.wifi_rounded),
                label: Text(
                  t.choose(
                    'WI-FI / LAN MULTIPLAYER',
                    'ওয়াই-ফাই / LAN মাল্টিপ্লেয়ার',
                  ),
                  style: TextStyle(
                    fontFamily: t.font,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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

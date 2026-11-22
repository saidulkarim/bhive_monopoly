import 'package:flutter/material.dart';

import '../persistence/match_history_store.dart';
import 'game_text.dart';
import 'widgets/game_board_view.dart';

/// Device-local statistics and achievements for completed games.
/// Includes LAN matches only if the final state reached this device.
class MatchHistoryScreen extends StatefulWidget {
  const MatchHistoryScreen({super.key, required this.languageCode});
  final String languageCode;

  @override
  State<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen> {
  late final GameText t = GameText(widget.languageCode);
  late Future<List<MatchRecord>> _records = MatchHistoryStore.load();

  void _reload() => setState(() => _records = MatchHistoryStore.load());

  Future<void> _clear() async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.choose('Delete match history?', 'খেলার ইতিহাস মুছবেন?')),
        content: Text(
          t.choose(
            'This permanently deletes completed match records and achievements from this device. Saved unfinished games will not be removed.',
            'এই ডিভাইসের সম্পন্ন খেলার ইতিহাস ও অর্জন স্থায়ীভাবে মুছে যাবে। অসম্পূর্ণ সংরক্ষিত খেলা মুছবে না।',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.choose('CANCEL', 'বাতিল')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.choose('DELETE', 'মুছুন')),
          ),
        ],
      ),
    );
    if (answer != true) return;
    try {
      await MatchHistoryStore.clear();
      if (mounted) _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t.choose('Unable to delete history.', 'ইতিহাস মুছে ফেলা যায়নি।'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBoardDark,
    appBar: AppBar(
      title: Text(
        t.choose('Match History & Awards', 'খেলার ইতিহাস ও অর্জন'),
        style: TextStyle(
          fontFamily: t.font,
          fontFamilyFallback: t.fallbackFonts,
        ),
      ),
      foregroundColor: kBoardGold,
      backgroundColor: const Color(0xFF122729),
      actions: [
        IconButton(
          tooltip: t.choose('Refresh', 'হালনাগাদ'),
          onPressed: _reload,
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: t.choose('Delete history', 'ইতিহাস মুছুন'),
          onPressed: _clear,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ],
    ),
    body: FutureBuilder<List<MatchRecord>>(
      future: _records,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.choose(
                        'Could not read match history.',
                        'খেলার ইতিহাস পড়া যায়নি।',
                      ),
                      style: TextStyle(fontFamily: t.font, color: Colors.white),
                    ),
                    TextButton(
                      onPressed: _reload,
                      child: Text(t.choose('TRY AGAIN', 'আবার চেষ্টা করুন')),
                    ),
                  ],
                ),
              ),
            );
          }
          return const Center(
            child: CircularProgressIndicator(color: kBoardGold),
          );
        }
        final matches = snapshot.data!;
        final stats = MatchStatistics(matches);
        return DefaultTabController(
          length: 3,
          child: Column(
            children: [
              TabBar(
                labelColor: kBoardGold,
                unselectedLabelColor: Colors.white70,
                indicatorColor: kBoardGold,
                isScrollable: true,
                tabs: [
                  Tab(text: t.choose('Overview', 'সারসংক্ষেপ')),
                  Tab(text: t.choose('Matches', 'খেলাসমূহ')),
                  Tab(text: t.choose('Achievements', 'অর্জনসমূহ')),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _overview(stats),
                    _matches(matches),
                    _achievements(stats),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _overview(MatchStatistics stats) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _metric(
        t.choose('Finished matches', 'সম্পন্ন খেলা'),
        t.integer(stats.matches),
        Icons.flag_outlined,
      ),
      _metric(
        t.choose('Offline matches', 'অফলাইন খেলা'),
        t.integer(stats.offlineMatches),
        Icons.sports_esports_outlined,
      ),
      _metric(
        t.choose('LAN matches', 'LAN খেলা'),
        t.integer(stats.lanMatches),
        Icons.wifi_rounded,
      ),
      _metric(
        t.choose('Player 1 victories', '১ম খেলোয়াড়ের জয়'),
        t.integer(stats.playerOneVictories),
        Icons.emoji_events_outlined,
      ),
      _metric(
        t.choose('Player 1 win rate', '১ম খেলোয়াড়ের জয়ের হার'),
        '${t.digits(stats.winRate.toStringAsFixed(1))}%',
        Icons.trending_up,
      ),
      _metric(
        t.choose('Total turns played', 'মোট চাল'),
        t.integer(stats.totalTurns),
        Icons.casino_outlined,
      ),
      _metric(
        t.choose('Most properties held', 'সর্বোচ্চ সম্পত্তি'),
        t.integer(stats.bestPropertyCount),
        Icons.home_work_outlined,
      ),
      const SizedBox(height: 12),
      Text(
        t.choose(
          'Statistics count Player 1 (seat 1), not necessarily you. Completed LAN matches are included only if this device received the final result. History is stored locally.',
          'পরিসংখ্যানে প্রথম আসনের খেলোয়াড়কে গণনা করা হয়, আপনাকে নয়। এই ডিভাইস সম্পন্ন LAN খেলার ফল পেলে তা যুক্ত হবে। ইতিহাস শুধু এই ডিভাইসে থাকে।',
        ),
        style: TextStyle(
          fontFamily: t.font,
          fontFamilyFallback: t.fallbackFonts,
          color: Colors.white60,
          fontSize: 12,
        ),
      ),
    ],
  );

  Widget _metric(String label, String value, IconData icon) => Card(
    color: const Color(0xFF1B3435),
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Icon(icon, color: kBoardGold, size: 30),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: t.font,
                fontFamilyFallback: t.fallbackFonts,
                color: Colors.white70,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: kBoardGold,
              fontSize: 23,
              fontWeight: FontWeight.bold,
              fontFamily: 'Exo2',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _matches(List<MatchRecord> records) => records.isEmpty
      ? Center(
          child: Text(
            t.choose(
              'No completed matches yet.',
              'এখনো কোনো খেলা সম্পন্ন হয়নি।',
            ),
            style: TextStyle(
              fontFamily: t.font,
              fontFamilyFallback: t.fallbackFonts,
              color: Colors.white70,
            ),
          ),
        )
      : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: records.length,
          itemBuilder: (context, i) {
            final record = records[i];
            final when = record.completedAt.toLocal().toString();
            return Card(
              color: const Color(0xFF1A3334),
              child: ExpansionTile(
                textColor: kBoardGold,
                iconColor: kBoardGold,
                collapsedTextColor: Colors.white,
                collapsedIconColor: Colors.white70,
                leading: Icon(
                  record.playerOneWon
                      ? Icons.emoji_events_rounded
                      : Icons.smart_toy_rounded,
                  color: kBoardGold,
                ),
                title: Text(
                  record.winnerName,
                  style: TextStyle(
                    fontFamily: t.font,
                    fontFamilyFallback: t.fallbackFonts,
                  ),
                ),
                subtitle: Text(
                  '${record.isLan
                      ? 'LAN'
                      : record.vsComputer
                      ? t.choose('Vs AI', 'এআই')
                      : t.choose('Local', 'লোকাল')}  •  '
                  '${when.substring(0, when.length >= 16 ? 16 : when.length)}  •  '
                  '${t.choose('Turn', 'চাল')} ${t.integer(record.turns)}',
                  style: const TextStyle(color: Colors.white60),
                ),
                children: [
                  for (final player in record.players)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        player.isBot
                            ? Icons.smart_toy_outlined
                            : Icons.person_outline,
                        color: Colors.white70,
                      ),
                      title: Text(
                        player.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: t.font,
                          fontFamilyFallback: t.fallbackFonts,
                        ),
                      ),
                      subtitle: Text(
                        '${t.choose('Properties', 'সম্পত্তি')}: '
                        '${t.integer(player.properties)}',
                        style: const TextStyle(color: Colors.white60),
                      ),
                      trailing: Text(
                        t.money(player.balance),
                        style: const TextStyle(color: kBoardGold),
                      ),
                    ),
                ],
              ),
            );
          },
        );

  Widget _achievements(MatchStatistics stats) {
    final items = <(IconData, String, String, bool)>[
      (Icons.emoji_events, 'First victory', 'প্রথম জয়', stats.firstVictory),
      (Icons.sports_score, 'Five matches', 'পাঁচটি খেলা', stats.veteran),
      (Icons.military_tech, 'Ten victories', 'দশটি জয়', stats.champion),
      (
        Icons.apartment,
        'Property collector (10)',
        'সম্পত্তি সংগ্রাহক (১০)',
        stats.propertyCollector,
      ),
      (
        Icons.hourglass_bottom,
        'Marathon (75 turns)',
        'দীর্ঘ খেলা (৭৫ চাল)',
        stats.marathon,
      ),
      (
        Icons.wifi_rounded,
        'First LAN match',
        'প্রথম LAN খেলা',
        stats.lanPioneer,
      ),
      (
        Icons.groups_rounded,
        'Five LAN matches',
        'পাঁচটি LAN খেলা',
        stats.lanVeteran,
      ),
      (
        Icons.location_city,
        'Property magnate (15)',
        'সম্পত্তি সম্রাট (১৫)',
        stats.propertyMagnate,
      ),
      (
        Icons.timelapse_rounded,
        'Endurance (150 turns)',
        'দীর্ঘতম খেলা (১৫০ চাল)',
        stats.endurance,
      ),
    ];
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        for (final item in items)
          Card(
            color: item.$4 ? const Color(0xFF285045) : const Color(0xFF1B3031),
            child: ListTile(
              leading: Icon(
                item.$1,
                color: item.$4 ? kBoardGold : Colors.white30,
                size: 32,
              ),
              title: Text(
                t.choose(item.$2, item.$3),
                style: TextStyle(
                  fontFamily: t.font,
                  fontFamilyFallback: t.fallbackFonts,
                  color: item.$4 ? Colors.white : Colors.white54,
                ),
              ),
              trailing: Icon(
                item.$4 ? Icons.check_circle : Icons.lock_outline,
                color: item.$4 ? kBoardGold : Colors.white38,
              ),
            ),
          ),
      ],
    );
  }
}

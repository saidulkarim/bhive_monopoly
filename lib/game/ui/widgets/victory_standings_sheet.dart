import 'package:flutter/material.dart';

import '../../engine/game_engine.dart';
import '../../experience/game_experience_settings.dart';
import '../../presentation/match_standings.dart';
import '../game_text.dart';
import 'victory_confetti.dart';

const _gold = Color(0xFFE9BE67);
const _background = Color(0xFF142B2D);

/// Shared end-game results for both offline and LAN screens. Nothing here
/// modifies a player, property, match history or network state.
class VictoryStandingsSheet extends StatelessWidget {
  const VictoryStandingsSheet({
    super.key,
    required this.game,
    required this.text,
  });

  final GameEngine game;
  final GameText text;

  static Future<void> show(
    BuildContext context, {
    required GameEngine game,
    required GameText text,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: _background,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * .78,
        ),
        child: VictoryStandingsSheet(game: game, text: text),
      ),
    ),
  );

  TextStyle get _label => TextStyle(
    color: Colors.white,
    fontFamily: text.font,
    fontFamilyFallback: text.fallbackFonts,
  );

  @override
  Widget build(BuildContext context) {
    final rows = MatchStandings.fromGame(game);
    MatchStanding? winner;
    for (final row in rows) {
      if (row.winner) {
        winner = row;
        break;
      }
    }
    final reducedMotion =
        GameExperienceSettings.instance.effectiveReducedMotion ||
        MediaQuery.maybeOf(context)?.disableAnimations == true;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.83, end: 1),
                duration: reducedMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 460),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: const PremiumVictoryTrophy(),
              ),
              const SizedBox(height: 10),
              Text(
                text.choose('FINAL STANDINGS', 'চূড়ান্ত ফলাফল'),
                textAlign: TextAlign.center,
                style: _label.copyWith(
                  color: _gold,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (winner != null) ...[
                const SizedBox(height: 5),
                Text(
                  '${winner.name} ${text.choose('wins!', 'বিজয়ী!')}',
                  textAlign: TextAlign.center,
                  style: _label.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 19),
              for (var rank = 0; rank < rows.length; rank++) ...[
                _standingCard(rows[rank], rank + 1),
                const SizedBox(height: 9),
              ],
              const SizedBox(height: 7),
              Text(
                game.finishedByTurnLimit
                    ? text.choose(
                        'Turn limit reached. Highest net worth wins; ties use cash, then seat order.',
                        'চালের সীমা পূর্ণ হয়েছে। সর্বোচ্চ নিট সম্পদ বিজয় নির্ধারণ করে; সমান হলে নগদ, পরে আসনক্রম বিবেচিত হয়।',
                      )
                    : text.choose(
                        'The winner is determined by the game rules. Other players are ordered by final cash, not net worth.',
                        'বিজয়ী গেমের নিয়ম অনুযায়ী নির্ধারিত। অন্য খেলোয়াড়দের চূড়ান্ত নগদ অর্থ অনুযায়ী সাজানো হয়েছে, মোট সম্পদ অনুযায়ী নয়।',
                      ),
                textAlign: TextAlign.center,
                style: _label.copyWith(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(text.choose('CLOSE', 'বন্ধ করুন'), style: _label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _standingCard(MatchStanding row, int rank) {
    final accented = row.winner;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: accented ? const Color(0xFF254438) : const Color(0xFF1B3535),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accented ? _gold : Colors.white24,
          width: accented ? 1.7 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: accented ? _gold : Colors.white12,
                child: accented
                    ? const Icon(
                        Icons.emoji_events,
                        color: _background,
                        size: 18,
                      )
                    : Text(text.integer(rank), style: _label),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _label.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    decoration: row.bankrupt
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
              if (row.winner)
                Text(
                  text.choose('WINNER', 'বিজয়ী'),
                  style: _label.copyWith(color: _gold, fontSize: 12),
                ),
              if (row.bankrupt)
                Text(
                  text.choose('OUT', 'বাদ'),
                  style: _label.copyWith(color: Colors.white54, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _metric(
                Icons.account_balance_wallet_outlined,
                text.choose('Cash', 'নগদ'),
                text.money(row.balance),
              ),
              _metric(
                Icons.assessment_outlined,
                text.choose('Net worth', 'নিট সম্পদ'),
                text.money(game.netWorth(row.playerId)),
              ),
              _metric(
                Icons.home_work_outlined,
                text.choose('Properties', 'সম্পত্তি'),
                text.integer(row.properties),
              ),
              _metric(
                Icons.house_outlined,
                text.choose('Houses', 'বাড়ি'),
                text.integer(row.houses),
              ),
              _metric(
                Icons.apartment_outlined,
                text.choose('Hotels', 'হোটেল'),
                text.integer(row.hotels),
              ),
              if (row.mortgaged > 0)
                _metric(
                  Icons.lock_outline,
                  text.choose('Mortgaged', 'বন্ধকী'),
                  text.integer(row.mortgaged),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(IconData icon, String label, String value) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: _gold),
      const SizedBox(width: 4),
      Text('$label: $value', style: _label.copyWith(fontSize: 12)),
    ],
  );
}

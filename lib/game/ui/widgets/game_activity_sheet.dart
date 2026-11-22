// ignore_for_file: unnecessary_underscores

import 'package:flutter/material.dart';

import '../game_text.dart';
import 'game_board_view.dart';

/// Complete recent activity list (up to 70 entries provided by GameEngine).
/// Host and guests see logs from the synchronized engine, not a client log.
class GameActivitySheet extends StatelessWidget {
  const GameActivitySheet({
    super.key,
    required this.text,
    required this.events,
  });

  final GameText text;
  final List<String> events;

  static Future<void> show(
    BuildContext context, {
    required GameText text,
    required List<String> events,
  }) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF152C2D),
    isScrollControlled: true,
    builder: (ctx) => FractionallySizedBox(
      heightFactor: .78,
      child: GameActivitySheet(text: text, events: events),
    ),
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 8, 9),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, color: kBoardGold),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      text.choose('Match activity', 'খেলার কার্যক্রম'),
                      style: TextStyle(
                        fontFamily: text.font,
                        fontFamilyFallback: text.fallbackFonts,
                        color: kBoardGold,
                        fontWeight: FontWeight.bold,
                        fontSize: 21,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: text.choose('Close', 'বন্ধ করুন'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                text.choose(
                  'Newest first · up to 70 game-engine events',
                  'সর্বশেষ ঘটনা আগে · সর্বোচ্চ ৭০টি গেম ইভেন্ট',
                ),
                style: TextStyle(
                  color: Colors.white54,
                  fontFamily: text.font,
                  fontFamilyFallback: text.fallbackFonts,
                ),
              ),
            ),
            const Divider(color: Colors.white24),
            Expanded(
              child: events.isEmpty
                  ? Center(
                      child: Text(
                        text.choose('No events yet.', 'এখনো কোনো ঘটনা নেই।'),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
                      itemCount: events.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 7),
                      itemBuilder: (ctx, i) => Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: const Color(0xFF1D3737),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 15,
                            backgroundColor: const Color(0xFF2C4F48),
                            child: Text(
                              text.integer(events.length - i),
                              style: const TextStyle(
                                fontSize: 10,
                                color: kBoardGold,
                              ),
                            ),
                          ),
                          title: Text(
                            text.moneyInEvent(events[i]),
                            style: TextStyle(
                              fontFamily: text.font,
                              fontFamilyFallback: text.fallbackFonts,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}

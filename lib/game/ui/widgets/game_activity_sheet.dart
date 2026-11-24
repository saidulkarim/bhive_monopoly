import 'package:flutter/material.dart';

import '../../core/board_data.dart';
import '../../experience/player_palette.dart';
import '../../models/activity_event.dart';
import '../../models/game_models.dart';
import '../game_text.dart';
import 'game_board_view.dart';

class GameActivitySheet extends StatefulWidget {
  const GameActivitySheet({
    super.key,
    required this.text,
    required this.events,
    this.players = const [],
    this.structuredEvents,
  });
  final GameText text;
  final List<String> events;
  final List<PlayerState> players;
  final List<ActivityEvent>? structuredEvents;

  static Future<void> show(
    BuildContext context, {
    required GameText text,
    required List<String> events,
    List<PlayerState> players = const [],
    List<ActivityEvent>? structuredEvents,
  }) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF152C2D),
    isScrollControlled: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: .85,
      child: GameActivitySheet(
        text: text,
        events: events,
        players: players,
        structuredEvents: structuredEvents,
      ),
    ),
  );

  @override
  State<GameActivitySheet> createState() => _GameActivitySheetState();
}

class _GameActivitySheetState extends State<GameActivitySheet> {
  ActivityKind? category;
  String? player;
  GameText get t => widget.text;

  (IconData, Color, String, String) style(ActivityKind kind) => switch (kind) {
    ActivityKind.turn => (Icons.sync_rounded, Colors.blueGrey, 'Turn', 'পালা'),
    ActivityKind.dice => (
      Icons.casino_rounded,
      Colors.purpleAccent,
      'Dice',
      'পাশা',
    ),
    ActivityKind.movement => (
      Icons.directions_walk_rounded,
      Colors.lightBlueAccent,
      'Movement',
      'চলাচল',
    ),
    ActivityKind.purchase => (
      Icons.home_work_rounded,
      Colors.greenAccent,
      'Purchase',
      'ক্রয়',
    ),
    ActivityKind.rent => (
      Icons.payments_rounded,
      Colors.orangeAccent,
      'Rent',
      'ভাড়া',
    ),
    ActivityKind.tax => (
      Icons.receipt_long_rounded,
      Colors.redAccent,
      'Tax',
      'কর',
    ),
    ActivityKind.reward => (
      Icons.flag_rounded,
      Colors.greenAccent,
      'Reward',
      'পুরস্কার',
    ),
    ActivityKind.auction => (
      Icons.gavel_rounded,
      Colors.amberAccent,
      'Auction',
      'নিলাম',
    ),
    ActivityKind.building => (
      Icons.apartment_rounded,
      Colors.tealAccent,
      'Building',
      'ভবন',
    ),
    ActivityKind.mortgage => (
      Icons.account_balance_rounded,
      Colors.orangeAccent,
      'Mortgage',
      'বন্ধক',
    ),
    ActivityKind.trade => (
      Icons.handshake_rounded,
      Colors.lightBlueAccent,
      'Trade',
      'লেনদেন',
    ),
    ActivityKind.jail => (Icons.lock_rounded, Colors.redAccent, 'Jail', 'জেল'),
    ActivityKind.debt => (
      Icons.warning_amber_rounded,
      Colors.redAccent,
      'Debt',
      'ঋণ',
    ),
    ActivityKind.card => (
      Icons.card_giftcard_rounded,
      Colors.purpleAccent,
      'Card',
      'কার্ড',
    ),
    ActivityKind.winner => (
      Icons.emoji_events_rounded,
      kBoardGold,
      'Winner',
      'বিজয়ী',
    ),
    ActivityKind.other => (
      Icons.history_rounded,
      Colors.white54,
      'Other',
      'অন্যান্য',
    ),
  };

  Widget filter<T>(
    T? value,
    List<DropdownMenuItem<T>> items,
    ValueChanged<T?> onChanged,
    String hint,
  ) => Expanded(
    child: DropdownButton<T>(
      isExpanded: true,
      value: value,
      hint: Text(hint, overflow: TextOverflow.ellipsis),
      items: items,
      onChanged: onChanged,
      dropdownColor: const Color(0xFF1D3737),
      style: TextStyle(
        color: Colors.white,
        fontFamily: t.font,
        fontFamilyFallback: t.fallbackFonts,
        fontSize: 13,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final all =
        widget.structuredEvents ??
        widget.events.map(ActivityEvent.fromLog).toList();
    final names = <String>{
      ...widget.players.map((p) => p.name),
      ...all.expand((e) => e.actors),
    };
    final visible = all
        .where(
          (e) =>
              (category == null || e.kind == category) &&
              (player == null || e.actors.contains(player)),
        )
        .toList();
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 8, 2),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded, color: kBoardGold),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        t.choose('Match activity', 'খেলার কার্যক্রম'),
                        style: TextStyle(
                          fontFamily: t.font,
                          fontFamilyFallback: t.fallbackFonts,
                          color: kBoardGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 21,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: t.choose('Close', 'বন্ধ করুন'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    filter<ActivityKind>(
                      category,
                      [
                        DropdownMenuItem<ActivityKind>(
                          child: Text(t.choose('All events', 'সব ঘটনা')),
                        ),
                        for (final k in ActivityKind.values)
                          DropdownMenuItem(
                            value: k,
                            child: Text(t.choose(style(k).$3, style(k).$4)),
                          ),
                      ],
                      (v) => setState(() => category = v),
                      t.choose('All events', 'সব ঘটনা'),
                    ),
                    const SizedBox(width: 16),
                    filter<String>(
                      player,
                      [
                        DropdownMenuItem<String>(
                          child: Text(t.choose('All players', 'সব খেলোয়াড়')),
                        ),
                        for (final name in names)
                          DropdownMenuItem(
                            value: name,
                            child: Text(name, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      (v) => setState(() => player = v),
                      t.choose('All players', 'সব খেলোয়াড়'),
                    ),
                  ],
                ),
              ),
              Text(
                '${t.choose('Newest first', 'সর্বশেষ ঘটনা আগে')} · ${t.integer(visible.length)}/${t.integer(all.length)}',
                style: const TextStyle(color: Colors.white54),
              ),
              const Divider(color: Colors.white24),
              Expanded(
                child: visible.isEmpty
                    ? Center(
                        child: Text(
                          t.choose(
                            'No events found.',
                            'কোনো ঘটনা পাওয়া যায়নি।',
                          ),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 7),
                        itemBuilder: (_, i) => eventTile(visible[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget eventTile(ActivityEvent e) {
    final (defaultIcon, color, en, bn) = style(e.kind);
    final amountColor = switch (e.flow) {
      ActivityFlow.income => Colors.greenAccent,
      ActivityFlow.expense => Colors.redAccent,
      ActivityFlow.transfer => Colors.orangeAccent,
      ActivityFlow.neutral => Colors.white70,
    };
    final tile = e.tileIndex == null ? null : BoardData.spaces[e.tileIndex!];
    final icon = e.kind == ActivityKind.purchase && tile != null
        ? switch (tile.kind) {
            SpaceKind.station => Icons.train_rounded,
            SpaceKind.utility =>
              tile.index == 12
                  ? Icons.electric_bolt_rounded
                  : Icons.water_drop_rounded,
            _ => defaultIcon,
          }
        : defaultIcon;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1D3737),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .15),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          t.activityText(e),
          style: TextStyle(
            fontFamily: t.font,
            fontFamilyFallback: t.fallbackFonts,
            color: Colors.white,
            fontSize: 13,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 9,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                t.choose(en, bn),
                style: TextStyle(color: color, fontSize: 11),
              ),
              for (final name in e.actors.toSet())
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: 14,
                      color: widget.players.any((p) => p.name == name)
                          ? PlayerPalette.at(
                              widget.players
                                  .firstWhere((p) => p.name == name)
                                  .colorIndex,
                            )
                          : Colors.white54,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              if (tile != null)
                Text(
                  t.spaceName(tile.index, tile.name),
                  style: const TextStyle(color: kBoardGold, fontSize: 11),
                ),
              if (e.amount != null)
                Text(
                  '${e.flow == ActivityFlow.income
                      ? '+'
                      : e.flow == ActivityFlow.expense
                      ? '−'
                      : ''}${t.money(e.amount!)}',
                  style: TextStyle(
                    color: amountColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

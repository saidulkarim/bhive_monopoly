// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../engine/game_engine.dart';
import '../../models/game_models.dart';
import '../game_text.dart';
import 'game_board_view.dart';

/// Reusable, read-only title-deed information for offline and LAN matches.
/// This widget never performs an action or mutates the authoritative engine.
class PropertyDeedCard extends StatelessWidget {
  const PropertyDeedCard({
    super.key,
    required this.game,
    required this.text,
    required this.spaceIndex,
  });

  final GameEngine game;
  final GameText text;
  final int spaceIndex;

  @override
  Widget build(BuildContext context) {
    final space = game.spaces[spaceIndex];
    final owned = game.properties[spaceIndex];
    final name = text.spaceName(space.index, space.name);
    final ownerName = owned.ownerId == null
        ? text.choose('Bank / Unowned', 'ব্যাংক / অবিক্রিত')
        : game.players[owned.ownerId!].name;
    final color = groupColor(space.group);
    final isStreet = space.kind == SpaceKind.street;
    final isStation = space.kind == SpaceKind.station;
    final isUtility = space.kind == SpaceKind.utility;
    final acquired = owned.ownerId != null;
    final ownerHasGroup =
        isStreet &&
        acquired &&
        game.ownsFullGroup(owned.ownerId!, space.group!);

    final lastDice = game.lastRoll?.sum;
    final visibleRent = acquired && !owned.mortgaged
        ? game.rentFor(spaceIndex, lastDice ?? 7)
        : 0;
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFF102729),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color.withOpacity(.88), width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              color: color.withOpacity(.92),
              child: Column(
                children: [
                  Text(
                    text.choose('TITLE DEED', 'সম্পত্তির দলিল'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: text.font,
                      fontFamilyFallback: text.fallbackFonts,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: const Color(0xFF101D20),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: text.font,
                      fontFamilyFallback: text.fallbackFonts,
                      color: const Color(0xFF0C2122),
                      fontWeight: FontWeight.w800,
                      fontSize: 23,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _line(
                    text.choose('Owner', 'মালিক'),
                    ownerName,
                    emphasis: acquired,
                  ),
                  if (!space.purchasable) ...[
                    const SizedBox(height: 8),
                    Text(
                      _specialLabel(space),
                      style: _style(color: Colors.white70),
                    ),
                    if (space.tax > 0)
                      _line(text.choose('Tax', 'কর'), text.money(space.tax)),
                  ] else ...[
                    _line(
                      text.choose('Purchase price', 'ক্রয়মূল্য'),
                      text.money(space.price),
                    ),
                    _line(
                      text.choose('Mortgage value', 'বন্ধক মূল্য'),
                      text.money(space.price ~/ 2),
                    ),
                    if (acquired)
                      _line(
                        text.choose('Unmortgage cost', 'বন্ধক ছাড়ানোর খরচ'),
                        text.money(game.unmortgageCost(spaceIndex)),
                      ),
                    if (owned.mortgaged)
                      Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text(
                          text.choose(
                            'MORTGAGED — NO RENT',
                            'বন্ধক দেওয়া — ভাড়া নেই',
                          ),
                          textAlign: TextAlign.center,
                          style: _style(color: Colors.orangeAccent, bold: true),
                        ),
                      ),
                    const Divider(color: Colors.white24, height: 24),
                    if (isStreet) ...[
                      if (ownerHasGroup)
                        Text(
                          text.choose(
                            'Full colour set owned. Base rent is doubled without buildings.',
                            'সম্পূর্ণ রঙের সেটের মালিক। ভবন না থাকলে মূল ভাড়া দ্বিগুণ।',
                          ),
                          textAlign: TextAlign.center,
                          style: _style(color: kBoardGold, size: 12),
                        ),
                      for (var i = 0; i < space.rents.length; i++)
                        _rentLine(
                          i == 0
                              ? text.choose('Site only', 'খালি জমি')
                              : i == 5
                              ? text.choose('Hotel', 'হোটেল')
                              : '${text.integer(i)} ${text.choose('house${i == 1 ? '' : 's'}', 'বাড়ি')}',
                          text.money(
                            i == 0 && ownerHasGroup
                                ? space.rents[0] * 2
                                : space.rents[i],
                          ),
                          active:
                              acquired &&
                              !owned.mortgaged &&
                              owned.development == i,
                        ),
                      const SizedBox(height: 9),
                      _line(
                        text.choose(
                          'Cost per house / hotel',
                          'প্রতি বাড়ি / হোটেল নির্মাণ ব্যয়',
                        ),
                        text.money(space.buildCost),
                      ),
                      _line(
                        text.choose('Current buildings', 'বর্তমান ভবন'),
                        owned.development == 5
                            ? text.choose('Hotel', 'হোটেল')
                            : text.integer(owned.development),
                      ),
                    ] else if (isStation) ...[
                      Text(
                        text.choose(
                          'RENT BY STATIONS OWNED',
                          'মালিকানাধীন স্টেশনের সংখ্যা অনুযায়ী ভাড়া',
                        ),
                        style: _style(color: kBoardGold, bold: true),
                      ),
                      for (var count = 1; count <= 4; count++)
                        _rentLine(
                          '${text.integer(count)} ${text.choose('station${count == 1 ? '' : 's'}', 'স্টেশন')}',
                          text.money(25 * (1 << (count - 1))),
                          active:
                              acquired &&
                              !owned.mortgaged &&
                              _ownedCount(SpaceKind.station, owned.ownerId!) ==
                                  count,
                        ),
                    ] else if (isUtility) ...[
                      Text(
                        text.choose(
                          'RENT DEPENDS ON DICE',
                          'পাশার সংখ্যার উপর ভাড়া নির্ভরশীল',
                        ),
                        style: _style(color: kBoardGold, bold: true),
                      ),
                      _rentLine(
                        text.choose('One utility', 'একটি ইউটিলিটি'),
                        text.choose('Dice × 4', 'পাশা × ৪'),
                        active:
                            acquired &&
                            !owned.mortgaged &&
                            _ownedCount(SpaceKind.utility, owned.ownerId!) == 1,
                      ),
                      _rentLine(
                        text.choose('Both utilities', 'দুটি ইউটিলিটি'),
                        text.choose('Dice × 10', 'পাশা × ১০'),
                        active:
                            acquired &&
                            !owned.mortgaged &&
                            _ownedCount(SpaceKind.utility, owned.ownerId!) == 2,
                      ),
                    ],
                    const Divider(color: Colors.white24, height: 24),
                    _line(
                      text.choose('Current charge', 'বর্তমান ভাড়া'),
                      text.money(visibleRent),
                      emphasis: true,
                    ),
                    if (isUtility)
                      Text(
                        lastDice == null
                            ? text.choose(
                                'Shown using a sample dice sum of 7; actual rent uses the landing roll.',
                                'নমুনা পাশার যোগফল ৭ ধরে দেখানো হয়েছে; আসল ভাড়া চলতি পাশা অনুযায়ী।',
                              )
                            : text.choose(
                                'Using last dice sum: ${text.integer(lastDice)}',
                                'সর্বশেষ পাশার যোগফল: ${text.integer(lastDice)}',
                              ),
                        style: _style(color: Colors.white54, size: 11),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _ownedCount(SpaceKind kind, int ownerId) => game.spaces
      .where(
        (s) => s.kind == kind && game.properties[s.index].ownerId == ownerId,
      )
      .length;

  String _specialLabel(BoardSpace space) {
    switch (space.kind) {
      case SpaceKind.go:
        return text.choose(
          'Pass or land here to receive salary.',
          'এখানে এলে বা পার হলে বেতন পাবেন।',
        );
      case SpaceKind.jail:
        return text.choose('Jail / Just visiting', 'জেল / দর্শন');
      case SpaceKind.goToJail:
        return text.choose('Go directly to Jail.', 'সরাসরি জেলে যান।');
      case SpaceKind.freeParking:
        return text.choose(
          'Free parking; no cash reward.',
          'বিনামূল্যে পার্কিং; নগদ পুরস্কার নেই।',
        );
      case SpaceKind.chance:
      case SpaceKind.community:
        return text.choose(
          'Draw a card when landing here.',
          'এখানে এলে একটি কার্ড তুলুন।',
        );
      case SpaceKind.tax:
        return text.choose(
          'Pay the specified tax.',
          'নির্ধারিত কর পরিশোধ করুন।',
        );
      default:
        return '';
    }
  }

  TextStyle _style({
    Color color = Colors.white70,
    bool bold = false,
    double size = 13,
  }) => TextStyle(
    fontFamily: text.font,
    fontFamilyFallback: text.fallbackFonts,
    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
    color: color,
    fontSize: size,
  );

  Widget _line(String label, String value, {bool emphasis = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: _style())),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: _style(
              color: emphasis ? kBoardGold : Colors.white,
              bold: emphasis,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _rentLine(
    String label,
    String value, {
    bool active = false,
  }) => Container(
    margin: const EdgeInsets.only(top: 3),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: active ? const Color(0xFF27594B) : Colors.white.withOpacity(.035),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: active ? kBoardGold : Colors.transparent),
    ),
    child: Row(
      children: [
        if (active)
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(Icons.arrow_right_rounded, size: 16, color: kBoardGold),
          ),
        Expanded(child: Text(label, style: _style(size: 12))),
        Text(
          value,
          style: _style(
            color: active ? kBoardGold : Colors.white,
            bold: active,
            size: 12,
          ),
        ),
      ],
    ),
  );
}

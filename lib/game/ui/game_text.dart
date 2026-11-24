import '../core/board_data.dart';
import '../../core/fonts/font_preferences.dart';
import '../../core/utils/money_formatter.dart';

/// Lightweight bilingual labels. No changes required to generated ARB files.
class GameText {
  const GameText(this.languageCode);
  final String languageCode;
  bool get bn => languageCode == 'bn';
  String choose(String english, String bangla) => bn ? bangla : english;

  String digits(String input) {
    if (!bn) return input;
    const latin = '0123456789';
    const bangla = '০১২৩৪৫৬৭৮৯';
    return input.split('').map((character) {
      final i = latin.indexOf(character);
      return i < 0 ? character : bangla[i];
    }).join();
  }

  /// The game's single currency formatter, shared with the home screen.
  /// Currency choice is independent of language, with legacy defaults
  /// English/USD and Bangla/BDT until the player explicitly chooses one.
  String money(int value) =>
      MoneyFormatter.format(value, languageCode: languageCode);

  /// A turn announcement is already represented by the turn/player HUD.
  /// Keep the latest-activity panel for actual events (rolls, purchases,
  /// rent, auctions, building, etc.). Logs are newest-first in GameEngine.
  /// Skips both straight and curly apostrophes from saved/remote games.
  static String? latestMeaningfulActivity(Iterable<String> events) {
    for (final event in events) {
      final value = event.trim();
      if (value.isEmpty || _turnOnlyMessage.hasMatch(value)) continue;
      return value;
    }
    return null;
  }

  static final RegExp _turnOnlyMessage = RegExp(
    r"^.+['’]s\s+turn[.!]?\s*$",
    caseSensitive: false,
  );

  /// Localize amounts in existing GameEngine activity/error strings.
  ///
  /// Engine logs are stored and sent over LAN as plain, stable text. We only
  /// decorate known money amounts for display. Dice values, player numbers,
  /// turns, tile numbers, and card movement distances are left unchanged.
  /// This also formats messages from older saved games and remote LAN hosts.
  String moneyInEvent(String raw) {
    var result = raw;
    for (final rule in _moneyEventRules) {
      result = result.replaceAllMapped(rule, (match) {
        final prefix = match.group(1)!;
        final amount = int.tryParse(match.group(2)!);
        return amount == null ? match.group(0)! : '$prefix${money(amount)}';
      });
    }
    return result;
  }

  /// Only match amounts in known monetary phrases. Never match bare numbers.
  static final List<RegExp> _moneyEventRules = <RegExp>[
    // Rent, salary, card payments, bids, fines and dividends.
    RegExp(
      r'(\b(?:earned|collected|paid|bids|pays|pay|collect|receive|receives)\s+)([0-9]+)\b',
      caseSensitive: false,
    ),
    // Purchases, auctions, house builds, sales, mortgages and unmortgages.
    RegExp(r'(\b(?:for|at)\s+)([0-9]+)(?=[.!?]?\s*$)', caseSensitive: false),
    // Tax and validation error messages from older game states.
    RegExp(
      r'(\b(?:tax paid|minimum bid|balance|amount|price|rent|fine|cost|bid)\s*:\s*)([0-9]+)\b',
      caseSensitive: false,
    ),
    // Special card text: "Pay each other player 50".
    RegExp(r'(\beach other player\s+)([0-9]+)\b', caseSensitive: false),
    // Repairs card: "pay 25 per house and 100 per hotel".
    RegExp(
      r'(\band\s+)([0-9]+)(?=\s+per\s+(?:house|hotel)\b)',
      caseSensitive: false,
    ),
    // Delivery fee and similar card effects.
    RegExp(r'(\bfee of\s+)([0-9]+)\b', caseSensitive: false),
  ];

  /// Render canonical engine logs in the viewer's language, without changing
  /// saved games, network messages or player names.
  String eventText(String raw) {
    String place(String name) {
      for (final tile in BoardData.spaces) {
        if (tile.name == name ||
            spaceNameForEnglish(tile.index, tile.name) == name) {
          return spaceName(tile.index, tile.name);
        }
      }
      return name;
    }

    String amount(String value) => money(int.parse(value));
    String number(String value) => digits(value);
    String? match(String pattern, String Function(RegExpMatch) render) {
      final m = RegExp(pattern).firstMatch(raw);
      return m == null ? null : render(m);
    }

    final property =
        match(
          r'^(.+) landed on (.+)\.$',
          (m) => choose(
            '${m[1]} landed on ${place(m[2]!)}.',
            '${m[1]} ${place(m[2]!)} ঘরে এসেছেন।',
          ),
        ) ??
        match(
          r'^(.+) (purchased|won) (.+) for ([0-9]+)\.$',
          (m) => choose(
            '${m[1]} ${m[2]} ${place(m[3]!)} for ${amount(m[4]!)}.',
            '${m[1]} ${amount(m[4]!)} দিয়ে ${place(m[3]!)} ${m[2] == 'won' ? 'নিলামে জিতেছেন' : 'কিনেছেন'}।',
          ),
        ) ??
        match(
          r'^No bids — (.+) stays with the bank\.$',
          (m) => choose(
            'No bids — ${place(m[1]!)} stays with the bank.',
            'কেউ দর দেননি — ${place(m[1]!)} ব্যাংকের কাছেই থাকল।',
          ),
        ) ??
        match(
          r'^Built on (.+) for ([0-9]+)\.$',
          (m) => choose(
            'Built on ${place(m[1]!)} for ${amount(m[2]!)}.',
            '${place(m[1]!)}-এ ${amount(m[2]!)} দিয়ে ভবন নির্মাণ করা হয়েছে।',
          ),
        ) ??
        match(
          r'^Sold a building at (.+) for ([0-9]+)\.$',
          (m) => choose(
            'Sold a building at ${place(m[1]!)} for ${amount(m[2]!)}.',
            '${place(m[1]!)}-এর ভবন ${amount(m[2]!)}-এ বিক্রি হয়েছে।',
          ),
        ) ??
        match(
          r'^(.+) (mortgaged|unmortgaged) for ([0-9]+)\.$',
          (m) => choose(
            '${place(m[1]!)} ${m[2]} for ${amount(m[3]!)}.',
            '${place(m[1]!)} ${amount(m[3]!)}-এ ${m[2] == 'mortgaged' ? 'বন্ধক রাখা হয়েছে' : 'বন্ধকমুক্ত করা হয়েছে'}।',
          ),
        );
    if (property != null) return property;
    final card = RegExp(
      r'^(Fortune|City Chest|Chance|Community Chest): (.+)$',
    ).firstMatch(raw);
    if (card != null) {
      final chance = card[1] == 'Fortune' || card[1] == 'Chance';
      final title = card[2]!;
      final prefix = spaceName(
        chance ? 7 : 2,
        chance ? 'Fortune' : 'City Chest',
      );
      if (bn && _bnCardEvents.containsKey(title)) {
        final translated = _bnCardEvents[title]!;
        return '$prefix: ${translated.replaceAllMapped(RegExp(r"\{([0-9]+)\}"), (m) => amount(m[1]!))}';
      }
      final display = title == 'Travel to Central Station.'
          ? 'Travel to ${place('Central Station')}.'
          : title;
      return '$prefix: ${moneyInEvent(display)}';
    }
    if (!bn) return moneyInEvent(raw);
    return match(
          r'^Game started — (.+) rolls first\.$',
          (m) => 'খেলা শুরু — ${m[1]} প্রথমে পাশা ফেলবেন।',
        ) ??
        match(
          r'^(.+) rolled ([0-9]+) \+ ([0-9]+) = ([0-9]+)\.$',
          (m) =>
              '${m[1]} পাশা ফেলেছেন: ${number(m[2]!)} + ${number(m[3]!)} = ${number(m[4]!)}।',
        ) ??
        match(
          r'^(.+) passed START and earned ([0-9]+)\.$',
          (m) => '${m[1]} শুরু ঘর অতিক্রম করে ${amount(m[2]!)} পেয়েছেন।',
        ) ??
        match(
          r'^(.+) collected ([0-9]+) for passing START\.$',
          (m) => '${m[1]} শুরু ঘর অতিক্রম করে ${amount(m[2]!)} পেয়েছেন।',
        ) ??
        match(
          r'^Tax paid: ([0-9]+)\.$',
          (m) => 'কর পরিশোধ: ${amount(m[1]!)}।',
        ) ??
        match(
          r'^(.+) paid ([0-9]+) rent to (.+)\.$',
          (m) => '${m[1]} ${m[3]}-কে ${amount(m[2]!)} ভাড়া দিয়েছেন।',
        ) ??
        match(r"^(.+)['’]s turn\.$", (m) => 'এখন ${m[1]}-এর পালা।') ??
        match(
          r'^(.+) declined purchase — auction opened\.$',
          (m) => '${m[1]} কিনতে রাজি হননি — নিলাম শুরু হয়েছে।',
        ) ??
        match(
          r'^(.+) bids ([0-9]+)\.$',
          (m) => '${m[1]} ${amount(m[2]!)} দর দিয়েছেন।',
        ) ??
        match(
          r'^(.+) passed\.$',
          (m) => '${m[1]} দর দেওয়া থেকে বিরত থেকেছেন।',
        ) ??
        match(
          r'^(.+) paid ([0-9]+) to leave Jail\.$',
          (m) => '${m[1]} জেল থেকে বের হতে ${amount(m[2]!)} দিয়েছেন।',
        ) ??
        match(
          r'^(.+) used a Get Out of Jail card\.$',
          (m) => '${m[1]} জেল থেকে মুক্তির কার্ড ব্যবহার করেছেন।',
        ) ??
        match(
          r'^(.+) rolled doubles and left Jail!$',
          (m) => '${m[1]} পাশায় সমান সংখ্যা পেয়ে জেল থেকে বের হয়েছেন!',
        ) ??
        match(
          r'^Jail attempt ([0-9]+)/([0-9]+) failed\.$',
          (m) =>
              'জেল থেকে বের হওয়ার চেষ্টা ${number(m[1]!)}/${number(m[2]!)} ব্যর্থ হয়েছে।',
        ) ??
        match(
          r'^(.+) paid ([0-9]+) on the third failed attempt\.$',
          (m) => '${m[1]} তৃতীয় ব্যর্থ চেষ্টার পর ${amount(m[2]!)} দিয়েছেন।',
        ) ??
        match(
          r'^(.+) sent to Jail \((.+)\)\.$',
          (m) =>
              '${m[1]}-কে জেলে পাঠানো হয়েছে (${_bnJailReasons[m[2]] ?? m[2]})।',
        ) ??
        match(
          r'^(.+) must raise funds or declare bankruptcy\.$',
          (m) =>
              '${m[1]}-কে অর্থ সংগ্রহ করতে হবে অথবা দেউলিয়া ঘোষণা করতে হবে।',
        ) ??
        match(
          r'^(.+) resolved their debt\.$',
          (m) => '${m[1]} ঋণ পরিশোধ করেছেন।',
        ) ??
        match(
          r'^(.+) and (.+) completed a trade\.$',
          (m) => '${m[1]} ও ${m[2]} লেনদেন সম্পন্ন করেছেন।',
        ) ??
        match(
          r'^(.+) declared bankruptcy\.$',
          (m) => '${m[1]} দেউলিয়া ঘোষণা করেছেন।',
        ) ??
        match(
          r'^(.+) wins bHiVE Monopoly!$',
          (m) => '${m[1]} bHiVE Monopoly জিতেছেন!',
        ) ??
        (raw == 'Deck is empty.' ? 'কার্ডের স্তূপ খালি।' : moneyInEvent(raw));
  }

  static String spaceNameForEnglish(int index, String fallback) =>
      _englishDisplayOverrides[index] ?? fallback;

  static const _bnJailReasons = <String, String>{
    'Three doubles in a row': 'পরপর তিনবার পাশায় সমান সংখ্যা',
    'Landed on Go To Jail': 'জেলে যান ঘরে এসেছেন',
    'Event card': 'ইভেন্ট কার্ড',
  };

  static const _bnCardEvents = <String, String>{
    'Advance to START. Collect 200.': 'শুরু ঘরে যান। {200} সংগ্রহ করুন।',
    'Visit Royal Crescent.': 'কক্সবাজারে যান।',
    'Get Out of Jail Free.': 'বিনা খরচে জেল থেকে মুক্তি।',
    'Pay an express delivery fee of 50.': 'দ্রুত সরবরাহের ফি {50} দিন।',
    'Bank dividend: collect 50.': 'ব্যাংকের লভ্যাংশ: {50} সংগ্রহ করুন।',
    'Go directly to Jail.': 'সরাসরি জেলে যান।',
    'Make city repairs: pay 25 per house and 100 per hotel.':
        'শহর মেরামত: প্রতি বাড়ির জন্য {25} এবং প্রতি হোটেলের জন্য {100} দিন।',
    'Go back three spaces.': 'তিন ঘর পিছিয়ে যান।',
    'A lucky investment pays 150.': 'বিনিয়োগ থেকে {150} লাভ হয়েছে।',
    'Pay each other player 50.': 'অন্য প্রত্যেক খেলোয়াড়কে {50} দিন।',
    'Travel to Central Station.': 'কমলাপুরে যান।',
    'Traffic fine: pay 15.': 'ট্রাফিক জরিমানা: {15} দিন।',
    'Receive 200 in city grants.': 'শহরের অনুদান হিসেবে {200} গ্রহণ করুন।',
    'Health clinic fee: pay 50.': 'চিকিৎসা ফি: {50} দিন।',
    'Income tax refund: collect 20.': 'আয়কর ফেরত: {20} সংগ্রহ করুন।',
    'Festival award: collect 100.': 'উৎসব পুরস্কার: {100} সংগ্রহ করুন।',
    'School fee: pay 50.': 'বিদ্যালয়ের ফি: {50} দিন।',
    'Collect 10 from each player.':
        'প্রত্যেক অন্য খেলোয়াড়ের কাছ থেকে {10} সংগ্রহ করুন।',
    'Community support: collect 25.': 'সামাজিক সহায়তা: {25} সংগ্রহ করুন।',
    'Building maintenance: pay 40 per house, 115 per hotel.':
        'ভবন রক্ষণাবেক্ষণ: প্রতি বাড়ির জন্য {40}, প্রতি হোটেলের জন্য {115} দিন।',
    'Small lottery prize: collect 10.': 'লটারির পুরস্কার: {10} সংগ্রহ করুন।',
  };

  String integer(int value) => digits(value.toString());
  String get font => FontPreferences.instance.renderFamilyFor(languageCode);
  List<String> get fallbackFonts =>
      FontPreferences.instance.renderFallbacksFor(languageCode);

  /// These are display-only translations. Engine, saves and LAN packets still
  /// keep their stable English property names/indices.
  String spaceName(int index, String englishName) {
    if (bn && index >= 0 && index < _bnSpaces.length) {
      return _bnSpaces[index];
    }
    return _englishDisplayOverrides[index] ?? englishName;
  }

  static const Map<int, String> _englishDisplayOverrides = {
    2: 'Community Chest',
    4: 'Income Tax',
    5: 'Central Railway',
    7: 'Chance',
    10: 'JAIL / JUST VISITING',
    12: 'Electric Company',
    15: 'Airport Railway',
    17: 'Community Chest',
    22: 'Chance',
    25: 'Eastern Railway',
    33: 'Community Chest',
    35: 'Western Railway',
    36: 'Chance',
  };

  static const List<String> _bnSpaces = <String>[
    'শুরু', // 0
    'সদরঘাট', // 1
    'সামাজিক তহবিল', // 2
    'শাঁখারীবাজার', // 3
    'আয়কর', // 4
    'কমলাপুর', // 5
    'বরিশাল', // 6
    'ভাগ্য পরীক্ষা', // 7
    'খুলনা', // 8
    'পটুয়াখালী', // 9
    'জেল / দর্শনার্থী', // 10
    'নোয়াখালী', // 11
    'বিদ্যুৎ বিতরণ', // 12
    'চাঁদপুর', // 13
    'কুমিল্লা', // 14
    'বিমানবন্দর', // 15
    'রাজশাহী', // 16
    'সামাজিক তহবিল', // 17
    'ময়মনসিংহ', // 18
    'বগুড়া', // 19
    'ফ্রি পার্কিং', // 20
    'চট্টগ্রাম', // 21
    'ভাগ্য পরীক্ষা', // 22
    'সিলেট', // 23
    'কক্সবাজার', // 24
    'চট্টগ্রাম', // 25
    'উত্তরা', // 26
    'ধানমন্ডি', // 27
    'পানি সরবরাহ', // 28
    'বসুন্ধরা', // 29
    'জেলে যান', // 30
    'গুলশান-১', // 31
    'গুলশান-২', // 32
    'সামাজিক তহবিল', // 33
    'বনানী', // 34
    'খুলনা', // 35
    'ভাগ্য পরীক্ষা', // 36
    'নিকেতন', // 37
    'বিলাসিতা কর', // 38
    'বারিধারা', // 39
  ];
}

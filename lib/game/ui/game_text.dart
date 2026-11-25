import '../core/board_data.dart';
import '../models/activity_event.dart';
import '../../core/fonts/font_preferences.dart';
import '../../core/utils/money_formatter.dart';

/// Lightweight bilingual labels. No changes required to generated ARB files.
class GameText {
  const GameText(this.languageCode);
  final String languageCode;
  bool get bn => languageCode == 'bn';
  String choose(String english, String bangla) => bn ? bangla : english;

  /// Localize errors at the display boundary, not in saved/network data.
  String errorMessage(String raw) {
    final message = raw.trim().replaceFirst(
      RegExp(
        r'^(?:Bad state|Invalid argument(?:\(s\))?|FormatException|Unsupported operation|Exception):\s*',
      ),
      '',
    );
    final bid = RegExp(r'^Minimum bid: (\d+)\.?$').firstMatch(message);
    if (bid != null) {
      final amount = int.tryParse(bid.group(1)!);
      if (amount != null) {
        return '${choose('Minimum bid', 'ন্যূনতম দর')}: ${money(amount)}';
      }
    }
    if (message.startsWith('Action unavailable during ')) {
      return choose(
        'This action is not available right now.',
        'এখন এই কাজটি করা যাবে না।',
      );
    }
    final translated = _errorMessages[message];
    if (translated != null) return bn ? translated : message;
    if (message.startsWith('Bluetooth connection failed:')) {
      return choose(
        'Bluetooth connection failed. Try again.',
        'ব্লুটুথ সংযোগ ব্যর্থ হয়েছে। আবার চেষ্টা করুন।',
      );
    }
    if (message.startsWith('Could not connect to ')) {
      return choose(
        'Could not connect to the host.',
        'হোস্টের সঙ্গে সংযোগ স্থাপন করা যায়নি।',
      );
    }
    if (message.startsWith('Wi-Fi ') ||
        message.startsWith('Cannot scan local Wi-Fi')) {
      return choose(
        'Wi-Fi discovery is unavailable. Try again or enter the host IP.',
        'ওয়াই-ফাই রুম খোঁজা যাচ্ছে না। আবার চেষ্টা করুন অথবা হোস্টের আইপি লিখুন।',
      );
    }
    return choose(
      'This action could not be completed. Please try again.',
      'কাজটি সম্পন্ন করা যায়নি। আবার চেষ্টা করুন।',
    );
  }

  static const _errorMessages = <String, String>{
    "Choose 2–6 players with valid names.":
        "সঠিক নামসহ ২–৬ জন খেলোয়াড় নির্বাচন করুন।",
    "Player colours must be distinct.": "খেলোয়াড়দের রং আলাদা হতে হবে।",
    "Both dice must be between 1 and 6.": "উভয় পাশার মান ১ থেকে ৬ হতে হবে।",
    "Property already owned.": "সম্পত্তিটির ইতিমধ্যে মালিক আছে।",
    "Not enough cash. Start an auction.": "পর্যাপ্ত টাকা নেই। নিলাম শুরু করুন।",
    "Bidder cannot afford that bid.": "দরদাতার কাছে পর্যাপ্ত টাকা নেই।",
    "No jail release card.": "জেল থেকে মুক্তির কার্ড নেই।",
    "Invalid payment amount.": "পরিশোধের পরিমাণ সঠিক নয়।",
    "Invalid board space.": "বোর্ডের ঘরটি সঠিক নয়।",
    "This tile cannot be managed.": "এই ঘরটি পরিচালনা করা যাবে না।",
    "You do not own this property.": "আপনি এই সম্পত্তির মালিক নন।",
    "Property management is unavailable now.":
        "এখন সম্পত্তি পরিচালনা করা যাবে না।",
    "Resolve your debt first.": "আগে ঋণ পরিশোধ করুন।",
    "Only streets can have buildings.":
        "শুধু রাস্তার সম্পত্তিতে ভবন নির্মাণ করা যায়।",
    "Property already has a hotel.": "সম্পত্তিতে ইতিমধ্যে হোটেল আছে।",
    "Own the complete color group to build.":
        "নির্মাণের জন্য একই রঙের সব সম্পত্তির মালিক হতে হবে।",
    "Unmortgage every property in this group first.":
        "আগে এই গ্রুপের সব সম্পত্তির বন্ধক ছাড়ান।",
    "Build evenly across the group.":
        "গ্রুপের সম্পত্তিগুলোতে সমানভাবে নির্মাণ করুন।",
    "Not enough cash.": "পর্যাপ্ত টাকা নেই।",
    "Bank has no available hotels.": "ব্যাংকে কোনো হোটেল অবশিষ্ট নেই।",
    "Bank has no available houses.": "ব্যাংকে কোনো বাড়ি অবশিষ্ট নেই।",
    "No building to sell.": "বিক্রির জন্য কোনো ভবন নেই।",
    "Sell buildings evenly across the color group.":
        "একই রঙের গ্রুপে সমানভাবে ভবন বিক্রি করুন।",
    "Bank must have 4 houses to exchange for this hotel.":
        "হোটেল বদলের জন্য ব্যাংকে ৪টি বাড়ি থাকতে হবে।",
    "Already mortgaged.": "ইতিমধ্যে বন্ধক দেওয়া হয়েছে।",
    "Sell buildings first.": "আগে ভবন বিক্রি করুন।",
    "Sell every building in the color group first.":
        "আগে একই রঙের গ্রুপের সব ভবন বিক্রি করুন।",
    "This property is not mortgaged.": "সম্পত্তিটি বন্ধক দেওয়া নেই।",
    "Not enough cash to unmortgage.": "বন্ধক ছাড়ানোর জন্য পর্যাপ্ত টাকা নেই।",
    "Trades are allowed between rolls.":
        "পাশা নিক্ষেপের মধ্যবর্তী সময়ে বিনিময় করা যায়।",
    "Trade requires two different players.":
        "বিনিময়ের জন্য দুজন আলাদা খেলোয়াড় প্রয়োজন।",
    "Invalid player.": "খেলোয়াড় সঠিক নয়।",
    "Bankrupt players cannot trade.": "দেউলিয়া খেলোয়াড় বিনিময় করতে পারবেন না।",
    "Invalid trade amount or insufficient cash.":
        "বিনিময়ের পরিমাণ সঠিক নয় অথবা পর্যাপ্ত টাকা নেই।",
    "Insufficient jail cards.": "পর্যাপ্ত জেলমুক্তির কার্ড নেই।",
    "Duplicate tile in trade.": "বিনিময়ে একই সম্পত্তি একাধিকবার রয়েছে।",
    "Trade property is not owned by the sender.":
        "প্রেরক বিনিময়ের সম্পত্তিটির মালিক নন।",
    "Unmortgage before trading.": "বিনিময়ের আগে বন্ধক ছাড়ান।",
    "Sell every building in the color group before trading.":
        "বিনিময়ের আগে একই রঙের গ্রুপের সব ভবন বিক্রি করুন।",
    "Invalid or inactive player.": "খেলোয়াড় সঠিক নয় অথবা সক্রিয় নেই।",
    "This game is finished.": "এই খেলা শেষ হয়েছে।",
    "It is not your auction bid.": "এখন আপনার দর দেওয়ার পালা নয়।",
    "Wait for your turn.": "আপনার পালার জন্য অপেক্ষা করুন।",
    "A bid amount is required.": "দরের পরিমাণ লিখুন।",
    "Unsupported network action.": "নেটওয়ার্কে এই কাজটি সমর্থিত নয়।",
    "Invalid property index.": "সম্পত্তির নম্বর সঠিক নয়।",
    "Invalid action.": "কাজটি সঠিক নয়।",
    "Respond to the pending trade first.": "আগে অপেক্ষমাণ বিনিময়ের উত্তর দিন।",
    "Invalid command parameters.": "কাজটির তথ্য সঠিক নয়।",
    "The trade recipient is unavailable.": "বিনিময়ের প্রাপক এখন উপলব্ধ নেই।",
    "Unknown trade action.": "বিনিময়ের কাজটি পরিচিত নয়।",
    "Invalid trade response.": "বিনিময়ের উত্তর সঠিক নয়।",
    "Respond to the existing trade first.": "আগে বিদ্যমান বিনিময়ের উত্তর দিন।",
    "Only the active player can offer a trade.":
        "শুধু সক্রিয় খেলোয়াড় বিনিময়ের প্রস্তাব দিতে পারেন।",
    "Trade must exchange something.":
        "বিনিময়ের জন্য সম্পত্তি বা টাকা নির্বাচন করুন।",
    "Trade is no longer available.": "বিনিময়ের প্রস্তাবটি আর উপলব্ধ নেই।",
    "Only the recipient can respond.": "শুধু প্রাপক উত্তর দিতে পারেন।",
    "Only the proposer can cancel.": "শুধু প্রস্তাবদাতা বাতিল করতে পারেন।",
    "Room unavailable or waiting for another player to reconnect.":
        "রুম উপলব্ধ নেই অথবা অন্য খেলোয়াড়ের পুনঃসংযোগের অপেক্ষায় আছে।",
    "Connection failed. Rejoin the room.":
        "সংযোগ ব্যর্থ হয়েছে। আবার রুমে যোগ দিন।",
    "Host connection lost. Reconnect to continue.":
        "হোস্টের সংযোগ বিচ্ছিন্ন হয়েছে। খেলা চালাতে পুনঃসংযোগ করুন।",
    "Unknown network error.": "নেটওয়ার্কে অজানা সমস্যা হয়েছে।",
    "Received an invalid game update from the host.":
        "হোস্ট থেকে ভুল খেলার তথ্য এসেছে।",
    "Cannot join relay room.": "রিলে রুমে যোগ দেওয়া যাচ্ছে না।",
    "Relay disconnected. The host must create a new room.":
        "রিলে সংযোগ বিচ্ছিন্ন হয়েছে। হোস্টকে নতুন রুম তৈরি করতে হবে।",
    "At least two connected players are required.":
        "অন্তত দুজন সংযুক্ত খেলোয়াড় প্রয়োজন।",
    "Enter a name and choose 2–6 player slots.":
        "নাম লিখুন এবং ২–৬ জন খেলোয়াড়ের স্থান নির্বাচন করুন।",
    "Name, host IP and room PIN are required.":
        "নাম, হোস্টের আইপি ও রুমের পিন প্রয়োজন।",
    "Enter a player name and 6-digit room PIN.":
        "খেলোয়াড়ের নাম ও ৬ সংখ্যার রুম পিন লিখুন।",
    "Please enter your player name.": "আপনার নাম লিখুন।",
    "Enter the 8-character room code.": "৮ অক্ষরের রুম কোড লিখুন।",
    "Bluetooth hosting is available on Android only.":
        "শুধু অ্যান্ড্রয়েডে ব্লুটুথ হোস্ট করা যায়।",
    "Bluetooth joining is available on Android only.":
        "শুধু অ্যান্ড্রয়েডে ব্লুটুথের মাধ্যমে যোগ দেওয়া যায়।",
    "Allow Nearby devices permission to use Bluetooth.":
        "ব্লুটুথ ব্যবহারের জন্য নিকটবর্তী ডিভাইসের অনুমতি দিন।",
    "Turn on Bluetooth in Android settings and try again.":
        "অ্যান্ড্রয়েড সেটিংসে ব্লুটুথ চালু করে আবার চেষ্টা করুন।",
    "Bluetooth connection closed.": "ব্লুটুথ সংযোগ বন্ধ হয়েছে।",
    "Invalid Bluetooth device address.": "ব্লুটুথ ডিভাইসের ঠিকানা সঠিক নয়।",
    "LAN hosting requires Android or a desktop OS.":
        "স্থানীয় নেটওয়ার্কে হোস্ট করতে অ্যান্ড্রয়েড বা ডেস্কটপ প্রয়োজন।",
  };

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
  /// Prefer typed engine data where available. Other event descriptions use
  /// the established bilingual templates, including legacy saves and cards.
  String activityText(ActivityEvent event) {
    final tile = event.tileIndex == null
        ? null
        : BoardData.spaces[event.tileIndex!];
    final place = tile == null ? null : spaceName(tile.index, tile.name);
    final actor = event.actors.isEmpty ? null : event.actors.first;
    final amount = event.amount == null ? null : money(event.amount!);
    switch (event.kind) {
      case ActivityKind.movement:
        if (actor != null && place != null) {
          return choose(
            '$actor landed on $place.',
            '$actor $place ঘরে এসেছেন।',
          );
        }
        break;
      case ActivityKind.purchase:
        if (actor != null && place != null && amount != null) {
          return choose(
            '$actor purchased $place for $amount.',
            '$actor $amount দিয়ে $place কিনেছেন।',
          );
        }
        break;
      case ActivityKind.rent:
        if (actor != null && event.actors.length == 2 && amount != null) {
          final receiver = event.actors[1];
          return choose(
            '$actor paid $amount rent to $receiver.',
            '$actor $receiver-কে $amount ভাড়া দিয়েছেন।',
          );
        }
        break;
      case ActivityKind.tax:
        if (amount != null) {
          return choose('Tax paid: $amount.', 'কর পরিশোধ: $amount।');
        }
        break;
      case ActivityKind.trade:
        if (actor != null && event.actors.length == 2) {
          final other = event.actors[1];
          return choose(
            '$actor and $other completed a trade.',
            '$actor ও $other লেনদেন সম্পন্ন করেছেন।',
          );
        }
        break;
      default:
        break;
    }
    return eventText(event.raw);
  }

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

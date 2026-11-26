import '../../core/config/game_config.dart';

/// Localized additions to the existing rules. Developer defaults are read
/// directly from GameConfig rather than copied into UI strings.
List<(String, String)> updatedRules(String languageCode) {
  final bn = languageCode == 'bn';
  String n(int value) => bn
      ? value.toString().replaceAllMapped(
          RegExp(r'[0-9]'),
          (m) => '০১২৩৪৫৬৭৮৯'[int.parse(m[0]!)],
        )
      : value.toString();
  return [
    (
      bn ? 'খেলা শুরু ও ধরন নির্বাচন' : 'Start a match and choose a mode',
      bn
          ? 'হোম স্ক্রিনে স্লোগানের নিচে সোনালি খেলা শুরু করুন বোতাম চাপুন। কম্পিউটারের বিপক্ষে একজন মানুষ ও ১–৫ জন কম্পিউটার প্রতিপক্ষ খেলতে পারেন। একই ডিভাইসে ২–৬ জন পালাক্রমে খেলতে পারেন। পৃথক ডিভাইসে খেলতে অনলাইন/ওয়াই-ফাই মাল্টিপ্লেয়ার থেকে অনলাইন সার্ভার, স্থানীয় ওয়াই-ফাই বা ব্লুটুথ নির্বাচন করুন। অনলাইনে সচল রিলে ও ৮ অক্ষরের রুম কোড, ওয়াই-ফাইয়ে একই নেটওয়ার্ক ও হোস্টের আইপি/৬ সংখ্যার পিন এবং ব্লুটুথে আগে জোড়া লাগানো অ্যান্ড্রয়েড ডিভাইস ও ৬ সংখ্যার পিন প্রয়োজন। ওয়েব থেকে সমর্থিত ওয়াই-ফাই রুমে আইপি দিয়ে যোগ দেওয়া যায়; ব্লুটুথ শুধু অ্যান্ড্রয়েডে।'
          : 'On Home, tap the gold START GAME button below the tagline. Choose Vs Computer (one human and 1–5 AI opponents) or Pass & Play (2–6 people sharing a device). For network play, open Online / Wi-Fi Multiplayer and choose Online / Server, Local Wi-Fi or Bluetooth. Online requires a reachable relay and an 8-character room code; Wi-Fi uses a shared network and host IP/6-digit PIN; Bluetooth requires paired Android devices and a 6-digit PIN. Web can join supported Wi-Fi rooms by IP; Bluetooth is Android-only.',
    ),
    (
      bn ? 'খেলার সময়সীমা ও বিজয়ী' : 'Match duration and winner',
      bn
          ? 'ক্লাসিক খেলায় সময়সীমা নেই; একজন খেলোয়াড় দেউলিয়া না হয়ে টিকে থাকলে তিনি জয়ী হন। অফলাইন খেলায় দ্রুত (${n(GameConfig.quickMatchMaximumTurns)}), সাধারণ (${n(GameConfig.standardMatchMaximumTurns)}), দীর্ঘ (${n(GameConfig.extendedMatchMaximumTurns)}) অথবা নির্ধারিত (${n(GameConfig.customMatchMinimumTurns)}–${n(GameConfig.customMatchMaximumTurns)}) সংখ্যক চাল বেছে নেওয়া যায়। সীমা পূর্ণ হলে সর্বোচ্চ নিট সম্পদের খেলোয়াড় জয়ী হন। আনুমানিক নিট সম্পদ = নগদ + সম্পত্তির নির্ধারিত মূল্য + নির্মাণ ব্যয়ের অর্ধেক − বন্ধকমুক্ত করার খরচ। সমান হলে নগদ, এরপর আসনক্রম বিবেচিত হয়। নেটওয়ার্ক খেলায় এই সময়সীমা এখনো নেই।'
          : 'Classic is unlimited and ends when only one solvent player remains. In offline setup, Quick (${n(GameConfig.quickMatchMaximumTurns)}), Standard (${n(GameConfig.standardMatchMaximumTurns)}), Extended (${n(GameConfig.extendedMatchMaximumTurns)}) or Custom (${n(GameConfig.customMatchMinimumTurns)}–${n(GameConfig.customMatchMaximumTurns)}) set the maximum completed turns. At the limit, the highest net worth wins. Estimated net worth = cash + printed property prices + half building investment − mortgage redemption costs. Ties use cash, then seat order. Network matches do not yet offer these duration presets.',
    ),
    (
      bn ? 'স্মার্ট চাল সহায়তা' : 'Smart turn assistance',
      bn
          ? 'পাশা ছুড়ে প্রয়োজনীয় সিদ্ধান্ত শেষ করে চাল শেষ করুন চাপুন। চাল শেষ করার সুযোগ থাকলে এবং সহায়তা চালু থাকলে ${n(GameConfig.endTurnReminderSeconds)} সেকেন্ড নিষ্ক্রিয় থাকার পর স্মরণবার্তা আসে। অফলাইনে স্বয়ংক্রিয়ভাবে চাল শেষ করা ডেভেলপারের সেটিং (সাধারণভাবে বন্ধ); চালু থাকলে ${n(GameConfig.autoEndTurnSeconds)} সেকেন্ডের সীমার ${n(GameConfig.autoEndTurnCountdownSeconds)} সেকেন্ড আগে সতর্কতা আসে। অসম্পূর্ণ সিদ্ধান্ত, অতিরিক্ত পাশা, ঋণ বা খোলা ডায়ালগ এড়িয়ে চাল শেষ করা উচিত নয়। মাল্টিপ্লেয়ার ও বোর্ড দেখুন পর্দায় শুধু স্মরণবার্তা থাকে; মানুষের চাল স্বয়ংক্রিয়ভাবে শেষ হয় না।'
          : 'Roll dice, resolve all required decisions, then tap End Turn. If enabled, a reminder appears after ${n(GameConfig.endTurnReminderSeconds)} seconds of inactivity when End Turn is legal. Offline automatic completion is a developer setting (off by default): if enabled, it warns ${n(GameConfig.autoEndTurnCountdownSeconds)} seconds before the ${n(GameConfig.autoEndTurnSeconds)}-second limit. Pending decisions, extra rolls, debt, dialogs and backgrounding must not be bypassed. Multiplayer and Explore Board provide reminders only; they do not automatically advance a human turn.',
    ),
    (
      bn ? 'কেনার প্রস্তাব ও দর-কষাকষি' : 'Buy requests and negotiation',
      bn
          ? 'অন্য খেলোয়াড়ের সম্পত্তিতে চাপ দিয়ে সুযোগ থাকলে কেনার প্রস্তাব দিন নির্বাচন করুন। নগদ টাকার মধ্যে ধনাত্মক মূল্য লিখে প্রস্তাব পাঠান। মালিক গ্রহণ বা প্রত্যাখ্যান করতে পারেন; কম্পিউটার মালিক বেশি মূল্য চাইতে পারে। একই রঙের সেট পূর্ণ করার জন্য দর-কষাকষি করুন। যেমন ৩১ ও ৩২ নম্বর সম্পত্তি থাকলে ৩৪ নম্বরটি গুরুত্বপূর্ণ। মানুষের সম্মতি আবশ্যক। বর্তমান নিয়মে বন্ধক রাখা সম্পত্তি বা ভবন থাকা রঙের সেটের সম্পত্তি হস্তান্তর করা যায় না। নেটওয়ার্কে হোস্ট পরিচালিত লেনদেন ব্যবস্থা ব্যবহৃত হয়; মানুষের বা নেটওয়ার্কের পাল্টা প্রস্তাব এখনো নেই।'
          : 'Tap another player’s property and select Request to Buy when available. Enter a positive offer within your cash balance and send it. The owner can accept or decline; a computer owner may suggest a higher price. A complete color group is a useful reason to negotiate. For example, owning 31 and 32 makes property 34 strategically valuable. Human consent is required. Mortgaged properties and developed color groups cannot be transferred under the current trade restrictions. Network requests reuse the host-managed trade workflow; human/network counteroffers are not yet available.',
    ),
    (
      bn
          ? 'কৌশলগত স্থবিরতা ও কম্পিউটারের লেনদেন'
          : 'Strategic deadlock and AI trading',
      bn
          ? 'অধিকাংশ সম্পত্তির মালিক থাকলেও লেনদেন ও নির্মাণ বন্ধ হয়ে গেলে খেলা স্থবির হতে পারে। প্রতিটি চালের সীমায় মালিকানা, নির্মাণ, বন্ধক, দেউলিয়া অবস্থা ও নগদ অর্থ বিবেচনা করা হয়। প্রাথমিক মান: অন্তত ${n(GameConfig.deadlockMinimumTurns)} চাল, ${n(GameConfig.deadlockObservationTurns)} চাল ধরে কৌশলগত পরিবর্তন না হওয়া এবং ${n((GameConfig.deadlockOwnedPropertyRatio * 100).round())}% সম্পত্তির মালিক থাকা। কম্পিউটারের বৈধ পারস্পরিক বিনিময়ে উভয়ের রঙের সেট পূর্ণ হতে পারে; মানুষের সম্মতি আবশ্যক। শুধু মানুষের খেলায় পরামর্শ দেওয়া হয়, বাধ্যতামূলক লেনদেন নয়। পাশার ফল বা সম্পত্তির দাম বদলানো হয় না এবং খেলা শেষ হওয়ার নিশ্চয়তা দেওয়া যায় না।'
          : 'A match may stagnate when properties are widely owned but trading and building stop. The detector considers ownership, development, mortgages, bankruptcy and cash, at turn boundaries. Defaults: at least ${n(GameConfig.deadlockMinimumTurns)} turns, ${n(GameConfig.deadlockObservationTurns)} turns without strategic change, and ${n((GameConfig.deadlockOwnedPropertyRatio * 100).round())}% ownership. In AI matches, eligible reciprocal exchanges may complete both players’ color groups; human proposals require consent. Human-only matches receive strategic suggestions, never forced trades. Detection does not change dice or property prices and cannot guarantee a finish.',
    ),
    (
      bn ? 'বন্ধক রাখা সম্পত্তি চেনার উপায়' : 'Mortgaged property visibility',
      bn
          ? 'বন্ধক রাখা ঘরে স্বচ্ছ লাল পটভূমি (প্রাথমিক অস্বচ্ছতা ${n((GameConfig.mortgageOverlayOpacity * 100).round())}%) এবং বড় তালার চিহ্ন দেখা যায়। মালিকের চিহ্ন ও মূল রঙের সেট শনাক্ত করা যায়। বন্ধক রাখা সম্পত্তি থেকে ভাড়া পাওয়া যায় না। নিজের সম্পত্তির বিবরণ খুলে বন্ধকমুক্ত করার নির্ধারিত মূল্য পরিশোধ করুন। বন্ধক মুক্ত হলে লাল চিহ্ন সরে যাবে।'
          : 'A mortgaged tile has a translucent red background (default ${n((GameConfig.mortgageOverlayOpacity * 100).round())}% opacity) and a larger lock icon. The owner marker and original group color remain identifiable. Mortgaged property collects no rent. To restore it, open your property details and pay the required redemption amount. The highlight disappears when the mortgage is cleared.',
    ),
    (
      bn
          ? 'বোর্ড দেখা ও মালিক অনুযায়ী তালিকা'
          : 'Explore Board and property filtering',
      bn
          ? 'বোর্ড দেখুন থেকে ২ডি/৩ডি বদলান, দুই আঙুল বা +/− দিয়ে বড়-ছোট করুন, টেনে সরান এবং ঘরে চাপ দিয়ে বিস্তারিত দেখুন। সকল ৪০টি ঘরের তালিকা খুলুন। কোনো খেলোয়াড়ের কার্ড চাপলে শুধু তার সম্পত্তি দেখাবে; আবার একই কার্ড বা সব দেখুন চাপলে পূর্ণ তালিকা ফিরে আসবে। পর্যাপ্ত চওড়া ল্যান্ডস্কেপ বা ব্রাউজারে খেলোয়াড়ের কার্ড বাম পাশে উল্লম্বভাবে থাকে এবং বোর্ড অবশিষ্ট স্থানে মানিয়ে যায়। জুম নিয়ন্ত্রণ সাধারণত বাম পাশেই থাকে। সরু পর্দায় আগের বিন্যাস থাকে।'
          : 'Open Explore Board to switch 2D/3D, pinch or use +/− to zoom, drag to pan and tap a space for details. Select All 40 to list board spaces. Tap a player card to show only that player’s properties; tap the same card again or Show All to restore the full list. In a sufficiently wide landscape or browser viewport, player cards move to a vertical sidebar and the board fits the remaining space. Zoom controls are in the sidebar by default. Narrow screens retain the portrait arrangement.',
    ),
    (
      bn ? 'ব্যাটারি, বিজয় ও পুনরুদ্ধার' : 'Power, victory and recovery',
      bn
          ? 'গেম অভিজ্ঞতা থেকে উচ্চ পারফরম্যান্স, ভারসাম্যপূর্ণ, ব্যাটারি সাশ্রয় বা সর্বোচ্চ সাশ্রয় নির্বাচন করুন। দীর্ঘ সময় খেলতে কম বিদ্যুৎ ব্যবহারের ধরন বা অ্যানিমেশন কমানোর সুবিধা ব্যবহার করুন। বিজয়ীর জন্য নতুন সোনালি ট্রফি ও স্বল্প সময়ের আতশবাজি এবং কনফেটি দেখানো হয়; কম অ্যানিমেশন ও সর্বোচ্চ সাশ্রয়ে সাজসজ্জার চলমান প্রভাব বন্ধ থাকে। চূড়ান্ত ফলে নিট সম্পদ দেখা যায়। অফলাইন খেলায় সংরক্ষণ চিহ্ন ব্যবহার করুন এবং সংরক্ষিত খেলা চালিয়ে যান নির্বাচন করুন; নতুন অফলাইন খেলা আগের সংরক্ষণ বদলে দেয়। কাজ ব্যর্থ হলে স্থানীয় ভাষার বার্তা পড়ুন এবং বৈধ অবস্থায় আবার চেষ্টা করুন। সব অপ্রত্যাশিত ত্রুটি থেকে পুনরুদ্ধারের নিশ্চয়তা নেই।'
          : 'Game Experience offers Performance, Balanced, Battery Saver and Ultra Saver. Choose a lower power profile or Reduce Motion for longer sessions. The winner sees a redesigned gold trophy with brief, power-aware fireworks and confetti; reduced motion and Ultra Saver suppress decorative effects. Final Results includes net worth. Use the save icon in offline games, and Continue Saved Game to resume; starting another offline match replaces the saved match. If an action fails, read the localized message and retry only when the game is in a valid state. Not every unexpected error is recoverable.',
    ),
  ];
}

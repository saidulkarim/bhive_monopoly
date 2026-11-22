// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get tagline => 'সম্পত্তি কিনুন। গড়ে তুলুন আপনার সাম্রাজ্য।';

  @override
  String get player => 'খেলোয়াড়';

  @override
  String welcome(String name) {
    return 'স্বাগতম, $name';
  }

  @override
  String get profileIntro => 'খেলার জন্য আপনার নাম ও অ্যাভাটার বেছে নিন।';

  @override
  String get editProfile => 'আমার প্রোফাইল';

  @override
  String get startingBalance => 'শুরুর মূলধন';

  @override
  String get balanceExplanation =>
      'সব খেলোয়াড় সমান মূলধন নিয়ে শুরু করেন। ভাষা বদলালে শুধু প্রদর্শনের ধরন বদলাবে, খেলার অর্থের পরিমাণ একই থাকবে।';

  @override
  String get howToPlay => 'খেলার নিয়ম';

  @override
  String get displayName => 'প্রদর্শিত নাম';

  @override
  String get nameValidation => '২ থেকে ৪০ অক্ষরের একটি নাম লিখুন।';

  @override
  String get chooseAvatar => 'আপনার অ্যাভাটার বেছে নিন';

  @override
  String avatarName(int number) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return 'অ্যাভাটার $numberString';
  }

  @override
  String get choosePhoto => 'ছবি বাছাই করুন';

  @override
  String get takePhoto => 'ছবি তুলুন';

  @override
  String get removePhoto => 'ছবি সরান';

  @override
  String get photoHint =>
      'সর্বোচ্চ ১০ মেগাবাইটের JPG বা PNG ছবি বেছে নিন। ছবিটি বর্গাকারে কেটে এই ডিভাইসে সংরক্ষণ করা হবে।';

  @override
  String get photoError =>
      'ছবিটি খোলা যায়নি। ১০ মেগাবাইটের কম JPG বা PNG ছবি ব্যবহার করুন এবং ছবি বা ক্যামেরার অনুমতি পরীক্ষা করুন।';

  @override
  String get saveProfile => 'প্রোফাইল সংরক্ষণ করুন';

  @override
  String get profileSaved => 'প্রোফাইল সংরক্ষণ করা হয়েছে।';

  @override
  String get saveError => 'পরিবর্তন সংরক্ষণ করা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get ruleGoalTitle => 'খেলার লক্ষ্য';

  @override
  String get ruleGoal =>
      'সম্পত্তি কিনুন, ভাড়া আদায় করুন এবং দেউলিয়া হওয়া এড়িয়ে চলুন। অন্য সবাই দেউলিয়া হওয়ার পর টিকে থাকা শেষ খেলোয়াড় বিজয়ী হবেন।';

  @override
  String get ruleTurnTitle => 'পালা ও চলাচল';

  @override
  String get ruleTurn =>
      'দুটি পাশা ছুড়ে ঘড়ির কাঁটার দিকে এগোন। GO পার হলে বা সেখানে থামলে ৳২০০ পাবেন। দুটি পাশায় একই সংখ্যা এলে ঘরের কাজ শেষ করে আবার পাশা ছোড়া যাবে। টানা তিনবার এমন হলে সরাসরি জেলে যেতে হবে; GO-এর অর্থ পাওয়া যাবে না।';

  @override
  String get rulePropertyTitle => 'সম্পত্তি ও ভাড়া';

  @override
  String get ruleProperty =>
      'মালিকবিহীন সম্পত্তি নির্ধারিত দামে কিনুন অথবা ৳১০ থেকে নিলাম শুরু করুন। সব সক্রিয় খেলোয়াড় নিলামে অংশ নিতে পারবেন। দলিল অনুযায়ী ভাড়া নির্ধারিত হবে। একই রঙের সব সম্পত্তি থাকলে সাধারণত ভবনবিহীন সম্পত্তির ভাড়া দ্বিগুণ হয়। বন্ধক রাখা সম্পত্তি থেকে ভাড়া পাওয়া যায় না।';

  @override
  String get ruleBuildingsTitle => 'বাড়ি ও হোটেল';

  @override
  String get ruleBuildings =>
      'একই রঙের সব সম্পত্তির মালিক হলে সমানভাবে বাড়ি তৈরি করুন। ওই রঙের কোনো সম্পত্তি বন্ধক থাকলে নির্মাণ করা যাবে না। হোটেল তৈরির আগে প্রতিটি সম্পত্তিতে চারটি বাড়ি থাকতে হবে। ব্যাংকে মোট ৩২টি বাড়ি ও ১২টি হোটেল থাকে। ভবন সমানভাবে ব্যাংকে অর্ধেক দামে বিক্রি করা যায়।';

  @override
  String get ruleJailTitle => 'জেল';

  @override
  String get ruleJail =>
      '৳৫০ দিয়ে, জেল থেকে মুক্তির কার্ড ব্যবহার করে অথবা সর্বোচ্চ তিন পালায় পাশায় একই সংখ্যা তুলে জেল থেকে বের হতে পারবেন। একই সংখ্যা তুলে বের হলে সেই সংখ্যায় এগোবেন, তবে অতিরিক্তবার পাশা ছোড়া যাবে না। তৃতীয়বারও ব্যর্থ হলে ৳৫০ দিয়ে শেষবারের সংখ্যায় এগোতে হবে। জেলে থেকেও ভাড়া আদায় ও সম্পত্তির লেনদেন করা যায়।';

  @override
  String get ruleDebtTitle => 'ঋণ ও লেনদেন';

  @override
  String get ruleDebt =>
      'দেউলিয়া হওয়ার আগে বৈধ লেনদেন, ভবন বিক্রি বা বন্ধকের মাধ্যমে অর্থ সংগ্রহ করুন। কোনো সম্পত্তি বন্ধক বা লেনদেন করার আগে একই রঙের সব ভবন বিক্রি করতে হবে। বন্ধক ছাড়াতে বন্ধকী মূল্যের সঙ্গে ১০% সুদ দিতে হয়। খেলোয়াড়রা একে অন্যকে অর্থ ধার দিতে পারবেন না।';

  @override
  String get ruleParkingTitle => 'ফ্রি পার্কিং';

  @override
  String get ruleParking =>
      'ফ্রি পার্কিংয়ে কোনো অর্থ পুরস্কার নেই। কর ও জরিমানার অর্থ ব্যাংকে জমা হয়; বোর্ডের মাঝে কোনো পুরস্কারের তহবিল তৈরি হয় না।';
}

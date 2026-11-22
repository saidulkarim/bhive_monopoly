import '../../core/fonts/font_preferences.dart';

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

  String money(int value) {
    final negative = value < 0;
    final numeric = value.abs().toString();
    final comma = numeric.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );
    return '${negative ? '−' : ''}${bn ? '৳' : r'$'}${digits(comma)}';
  }

  String integer(int value) => digits(value.toString());
  String get font => FontPreferences.instance.familyFor(languageCode);
  List<String> get fallbackFonts =>
      FontPreferences.instance.fallbacksFor(languageCode);

  /// These are display-only translations. Engine, saves and LAN packets still
  /// keep their stable English property names/indices.
  String spaceName(int index, String englishName) =>
      bn && index >= 0 && index < _bnSpaces.length
      ? _bnSpaces[index]
      : englishName;

  static const List<String> _bnSpaces = <String>[
    'শুরু', // 0
    'নদীর পাড়', // 1
    'সিটি চেস্ট', // 2
    'খাল সড়ক', // 3
    'নগর কর', // 4
    'কেন্দ্রীয় স্টেশন', // 5
    'ব্লুবার্ড লেন', // 6
    'ভাগ্য', // 7
    'লেকভিউ সড়ক', // 8
    'হারবার স্কয়ার', // 9
    'জেল / দর্শন', // 10
    'পদ্ম সড়ক', // 11
    'বিদ্যুৎ গ্রিড', // 12
    'গার্ডেন প্লেস', // 13
    'রোজউড সড়ক', // 14
    'উত্তর স্টেশন', // 15
    'সূর্যোদয় কোর্ট', // 16
    'সিটি চেস্ট', // 17
    'সিডার ক্রিসেন্ট', // 18
    'অ্যাম্বার সড়ক', // 19
    'বিনামূল্যে পার্কিং', // 20
    'ক্রিমসন সড়ক', // 21
    'ভাগ্য', // 22
    'ম্যাপল সড়ক', // 23
    'রয়্যাল ক্রিসেন্ট', // 24
    'পূর্ব স্টেশন', // 25
    'গোল্ডেন টেরেস', // 26
    'অর্কিড পার্ক', // 27
    'পানি সরবরাহ', // 28
    'সূর্যমুখী সড়ক', // 29
    'জেলে যান', // 30
    'এমেরাল্ড সড়ক', // 31
    'মেডো হাইটস', // 32
    'সিটি চেস্ট', // 33
    'পাম গার্ডেনস', // 34
    'পশ্চিম স্টেশন', // 35
    'ভাগ্য', // 36
    'স্কাইলাইন প্লাজা', // 37
    'বিলাস কর', // 38
    'গ্র্যান্ড প্রোমেনাড', // 39
  ];
}

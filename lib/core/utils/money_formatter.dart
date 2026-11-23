import 'currency_preferences.dart';

/// Presentation only: the integer game balance never changes with language.
class MoneyFormatter {
  MoneyFormatter._();

  static String format(
    int amount, {
    String languageCode = 'en',
    String? currencyCode,
  }) {
    final digits = amount.abs().toString();
    var grouped = digits;
    if (digits.length > 3) {
      final tail = digits.substring(digits.length - 3);
      var head = digits.substring(0, digits.length - 3);
      final groups = <String>[];
      while (head.length > 2) {
        groups.insert(0, head.substring(head.length - 2));
        head = head.substring(0, head.length - 2);
      }
      if (head.isNotEmpty) groups.insert(0, head);
      grouped = '${groups.join(',')},$tail';
    }
    final bangla = languageCode == 'bn';
    if (bangla) {
      const banglaDigits = '০১২৩৪৫৬৭৮৯';
      grouped = grouped.replaceAllMapped(
        RegExp('[0-9]'),
        (match) => banglaDigits[int.parse(match.group(0)!)],
      );
    }
    final symbol =
        (currencyCode ?? CurrencyPreferences.instance.codeFor(languageCode)) ==
            'BDT'
        ? '৳'
        : r'$';
    return '${amount < 0 ? '-' : ''}$symbol$grouped';
  }
}

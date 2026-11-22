import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/core/utils/money_formatter.dart';

void main() {
  test('English uses dollar symbols and South Asian grouping', () {
    expect(MoneyFormatter.format(0), r'$0');
    expect(MoneyFormatter.format(999), r'$999');
    expect(MoneyFormatter.format(1000), r'$1,000');
    expect(MoneyFormatter.format(1500), r'$1,500');
    expect(MoneyFormatter.format(100000), r'$1,00,000');
    expect(MoneyFormatter.format(125000), r'$1,25,000');
    expect(MoneyFormatter.format(12345678), r'$1,23,45,678');
  });

  test('Bangla changes the symbol and digits without changing the amount', () {
    expect(MoneyFormatter.format(0, languageCode: 'bn'), '৳০');
    expect(MoneyFormatter.format(1500, languageCode: 'bn'), '৳১,৫০০');
    expect(MoneyFormatter.format(125000, languageCode: 'bn'), '৳১,২৫,০০০');
    expect(MoneyFormatter.format(12345678, languageCode: 'bn'), '৳১,২৩,৪৫,৬৭৮');
  });

  test('Negative balances keep the sign before the currency symbol', () {
    expect(MoneyFormatter.format(-1500), r'-$1,500');
    expect(MoneyFormatter.format(-1500, languageCode: 'bn'), '-৳১,৫০০');
  });
}

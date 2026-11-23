import 'dart:math';

/// Friendly, unique AI opponent names. A new game shuffles the pool;
/// existing saved matches retain their own names unchanged.
class BotNamePool {
  BotNamePool._();

  static const List<String> names = <String>[
    'Atlas',
    'Nova',
    'Orion',
    'Luna',
    'Jasper',
    'Sage',
    'Ember',
    'Milo',
    'Aria',
    'Felix',
    'Zara',
    'Theo',
    'Iris',
    'Leo',
    'Maya',
    'Finn',
    'Cleo',
    'River',
    'Axel',
    'Skye',
  ];

  static List<String> pick(
    int count, {
    Iterable<String> reserved = const <String>[],
    Random? random,
  }) {
    if (count < 0 || count > 5) {
      throw RangeError.range(count, 0, 5, 'count');
    }
    final occupied = reserved.map((name) => name.trim().toLowerCase()).toSet();
    final options =
        names.where((name) => !occupied.contains(name.toLowerCase())).toList()
          ..shuffle(random ?? Random());
    if (options.length < count) {
      throw StateError('Not enough unique AI names.');
    }
    return options.take(count).toList(growable: false);
  }
}

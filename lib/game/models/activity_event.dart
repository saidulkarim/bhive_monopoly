import '../core/board_data.dart';

enum ActivityKind {
  turn,
  dice,
  movement,
  purchase,
  rent,
  tax,
  reward,
  auction,
  building,
  mortgage,
  trade,
  jail,
  debt,
  card,
  winner,
  other,
}

enum ActivityFlow { neutral, income, expense, transfer }

/// Structured presentation record for a canonical log entry. The legacy
/// log remains the transport and persistence format for existing clients.
class ActivityEvent {
  const ActivityEvent({
    required this.raw,
    required this.kind,
    this.actors = const [],
    this.tileIndex,
    this.amount,
    this.flow = ActivityFlow.neutral,
  });
  final String raw;
  final ActivityKind kind;
  final List<String> actors;
  final int? tileIndex;
  final int? amount;
  final ActivityFlow flow;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'actors': actors,
    'tileIndex': tileIndex,
    'amount': amount,
    'flow': flow.name,
  };

  /// Optional metadata is presentation-only. Invalid or missing metadata
  /// never prevents opening a valid old save or joining a room.
  static ActivityEvent restore(String raw, Object? data) {
    if (data is! Map) return ActivityEvent.fromLog(raw);
    try {
      final actors = (data['actors'] as List).cast<String>();
      final tile = data['tileIndex'] as int?;
      final amount = data['amount'] as int?;
      if (actors.length > 6 ||
          actors.any((a) => a.length > 2000) ||
          (tile != null && (tile < 0 || tile >= 40)) ||
          (amount != null && amount < 0)) {
        return ActivityEvent.fromLog(raw);
      }
      return ActivityEvent(
        raw: raw,
        kind: ActivityKind.values.byName(data['kind'] as String),
        actors: List.unmodifiable(actors),
        tileIndex: tile,
        amount: amount,
        flow: ActivityFlow.values.byName(data['flow'] as String),
      );
    } catch (_) {
      return ActivityEvent.fromLog(raw);
    }
  }

  factory ActivityEvent.fromLog(String raw) {
    ActivityEvent? parse(
      String pattern,
      ActivityKind kind, {
      List<int> actors = const [],
      int? tile,
      int? amount,
      ActivityFlow flow = ActivityFlow.neutral,
    }) {
      final m = RegExp(pattern).firstMatch(raw);
      if (m == null) return null;
      int? index;
      if (tile != null) {
        for (final space in BoardData.spaces) {
          if (space.name == m[tile]) {
            index = space.index;
            break;
          }
        }
      }
      return ActivityEvent(
        raw: raw,
        kind: kind,
        actors: List.unmodifiable(actors.map((i) => m[i]!)),
        tileIndex: index,
        amount: amount == null ? null : int.tryParse(m[amount]!),
        flow: flow,
      );
    }

    return parse(
          r'^Game started — (.+) rolls first\.$',
          ActivityKind.turn,
          actors: [1],
        ) ??
        parse(r"^(.+)['’]s turn\.$", ActivityKind.turn, actors: [1]) ??
        parse(
          r'^(.+) rolled [0-9]+ \+ [0-9]+ = [0-9]+\.$',
          ActivityKind.dice,
          actors: [1],
        ) ??
        parse(
          r'^(.+) landed on (.+)\.$',
          ActivityKind.movement,
          actors: [1],
          tile: 2,
        ) ??
        parse(
          r'^(.+) purchased (.+) for ([0-9]+)\.$',
          ActivityKind.purchase,
          actors: [1],
          tile: 2,
          amount: 3,
          flow: ActivityFlow.expense,
        ) ??
        parse(
          r'^(.+) paid ([0-9]+) rent to (.+)\.$',
          ActivityKind.rent,
          actors: [1, 3],
          amount: 2,
          flow: ActivityFlow.transfer,
        ) ??
        parse(
          r'^Tax paid: ([0-9]+)\.$',
          ActivityKind.tax,
          amount: 1,
          flow: ActivityFlow.expense,
        ) ??
        parse(
          r'^(.+) passed START and earned ([0-9]+)\.$',
          ActivityKind.reward,
          actors: [1],
          amount: 2,
          flow: ActivityFlow.income,
        ) ??
        parse(
          r'^(.+) collected ([0-9]+) for passing START\.$',
          ActivityKind.reward,
          actors: [1],
          amount: 2,
          flow: ActivityFlow.income,
        ) ??
        parse(
          r'^(.+) won (.+) for ([0-9]+)\.$',
          ActivityKind.auction,
          actors: [1],
          tile: 2,
          amount: 3,
          flow: ActivityFlow.expense,
        ) ??
        parse(
          r'^(.+) bids ([0-9]+)\.$',
          ActivityKind.auction,
          actors: [1],
          amount: 2,
        ) ??
        parse(
          r'^(.+) (?:declined purchase — auction opened|passed)\.$',
          ActivityKind.auction,
          actors: [1],
        ) ??
        parse(
          r'^No bids — (.+) stays with the bank\.$',
          ActivityKind.auction,
          tile: 1,
        ) ??
        parse(
          r'^Built on (.+) for ([0-9]+)\.$',
          ActivityKind.building,
          tile: 1,
          amount: 2,
          flow: ActivityFlow.expense,
        ) ??
        parse(
          r'^Sold a building at (.+) for ([0-9]+)\.$',
          ActivityKind.building,
          tile: 1,
          amount: 2,
          flow: ActivityFlow.income,
        ) ??
        parse(
          r'^(.+) unmortgaged for ([0-9]+)\.$',
          ActivityKind.mortgage,
          tile: 1,
          amount: 2,
          flow: ActivityFlow.expense,
        ) ??
        parse(
          r'^(.+) mortgaged for ([0-9]+)\.$',
          ActivityKind.mortgage,
          tile: 1,
          amount: 2,
          flow: ActivityFlow.income,
        ) ??
        parse(
          r'^(.+) and (.+) completed a trade\.$',
          ActivityKind.trade,
          actors: [1, 2],
        ) ??
        parse(
          r'^(.+) paid ([0-9]+) (?:to leave Jail|on the third failed attempt)\.$',
          ActivityKind.jail,
          actors: [1],
          amount: 2,
          flow: ActivityFlow.expense,
        ) ??
        parse(
          r'^(.+) (?:sent to Jail \(.+\)\.|used a Get Out of Jail card\.|rolled doubles and left Jail!)$',
          ActivityKind.jail,
          actors: [1],
        ) ??
        parse(r'^Jail attempt [0-9]+/[0-9]+ failed\.$', ActivityKind.jail) ??
        parse(
          r'^(.+) (?:must raise funds or declare bankruptcy|resolved their debt|declared bankruptcy)\.$',
          ActivityKind.debt,
          actors: [1],
        ) ??
        parse(
          r'^(?:Fortune|City Chest|Chance|Community Chest): .+$',
          ActivityKind.card,
        ) ??
        parse(
          r'^(.+) wins bHiVE Monopoly!$',
          ActivityKind.winner,
          actors: [1],
        ) ??
        ActivityEvent(raw: raw, kind: ActivityKind.other);
  }
}

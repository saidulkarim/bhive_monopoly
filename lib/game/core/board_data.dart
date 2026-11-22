import '../models/game_models.dart';

/// Original city names and visual branding, following a 40-position board.
/// Figures intentionally mirror familiar classic property-game economics.
class BoardData {
  BoardData._();

  static BoardSpace street(
    int index,
    String name,
    ColorGroup group,
    int price,
    int buildCost,
    List<int> rents,
  ) => BoardSpace(
    index: index,
    name: name,
    kind: SpaceKind.street,
    group: group,
    price: price,
    buildCost: buildCost,
    rents: rents,
  );

  static BoardSpace special(
    int index,
    String name,
    SpaceKind kind, {
    int tax = 0,
  }) => BoardSpace(index: index, name: name, kind: kind, tax: tax);

  static BoardSpace station(int i, String name) =>
      BoardSpace(index: i, name: name, kind: SpaceKind.station, price: 200);

  static BoardSpace utility(int i, String name) =>
      BoardSpace(index: i, name: name, kind: SpaceKind.utility, price: 150);

  static final List<BoardSpace> spaces = List<BoardSpace>.unmodifiable([
    special(0, 'START', SpaceKind.go),
    street(1, 'River Walk', ColorGroup.brown, 60, 50, [
      2,
      10,
      30,
      90,
      160,
      250,
    ]),
    special(2, 'City Chest', SpaceKind.community),
    street(3, 'Canal Street', ColorGroup.brown, 60, 50, [
      4,
      20,
      60,
      180,
      320,
      450,
    ]),
    special(4, 'City Tax', SpaceKind.tax, tax: 200),
    station(5, 'Central Station'),
    street(6, 'Bluebird Lane', ColorGroup.sky, 100, 50, [
      6,
      30,
      90,
      270,
      400,
      550,
    ]),
    special(7, 'Fortune', SpaceKind.chance),
    street(8, 'Lakeview Road', ColorGroup.sky, 100, 50, [
      6,
      30,
      90,
      270,
      400,
      550,
    ]),
    street(9, 'Harbor Square', ColorGroup.sky, 120, 50, [
      8,
      40,
      100,
      300,
      450,
      600,
    ]),
    special(10, 'JAIL / VISIT', SpaceKind.jail),
    street(11, 'Lotus Avenue', ColorGroup.pink, 140, 100, [
      10,
      50,
      150,
      450,
      625,
      750,
    ]),
    utility(12, 'Power Grid'),
    street(13, 'Garden Place', ColorGroup.pink, 140, 100, [
      10,
      50,
      150,
      450,
      625,
      750,
    ]),
    street(14, 'Rosewood Drive', ColorGroup.pink, 160, 100, [
      12,
      60,
      180,
      500,
      700,
      900,
    ]),
    station(15, 'North Station'),
    street(16, 'Sunrise Court', ColorGroup.orange, 180, 100, [
      14,
      70,
      200,
      550,
      750,
      950,
    ]),
    special(17, 'City Chest', SpaceKind.community),
    street(18, 'Cedar Crescent', ColorGroup.orange, 180, 100, [
      14,
      70,
      200,
      550,
      750,
      950,
    ]),
    street(19, 'Amber Street', ColorGroup.orange, 200, 100, [
      16,
      80,
      220,
      600,
      800,
      1000,
    ]),
    special(20, 'FREE PARKING', SpaceKind.freeParking),
    street(21, 'Crimson Road', ColorGroup.red, 220, 150, [
      18,
      90,
      250,
      700,
      875,
      1050,
    ]),
    special(22, 'Fortune', SpaceKind.chance),
    street(23, 'Maple Boulevard', ColorGroup.red, 220, 150, [
      18,
      90,
      250,
      700,
      875,
      1050,
    ]),
    street(24, 'Royal Crescent', ColorGroup.red, 240, 150, [
      20,
      100,
      300,
      750,
      925,
      1100,
    ]),
    station(25, 'East Station'),
    street(26, 'Golden Terrace', ColorGroup.yellow, 260, 150, [
      22,
      110,
      330,
      800,
      975,
      1150,
    ]),
    street(27, 'Orchid Park', ColorGroup.yellow, 260, 150, [
      22,
      110,
      330,
      800,
      975,
      1150,
    ]),
    utility(28, 'Water Works'),
    street(29, 'Sunflower Way', ColorGroup.yellow, 280, 150, [
      24,
      120,
      360,
      850,
      1025,
      1200,
    ]),
    special(30, 'GO TO JAIL', SpaceKind.goToJail),
    street(31, 'Emerald Boulevard', ColorGroup.green, 300, 200, [
      26,
      130,
      390,
      900,
      1100,
      1275,
    ]),
    street(32, 'Meadow Heights', ColorGroup.green, 300, 200, [
      26,
      130,
      390,
      900,
      1100,
      1275,
    ]),
    special(33, 'City Chest', SpaceKind.community),
    street(34, 'Palm Gardens', ColorGroup.green, 320, 200, [
      28,
      150,
      450,
      1000,
      1200,
      1400,
    ]),
    station(35, 'West Station'),
    special(36, 'Fortune', SpaceKind.chance),
    street(37, 'Skyline Plaza', ColorGroup.navy, 350, 200, [
      35,
      175,
      500,
      1100,
      1300,
      1500,
    ]),
    special(38, 'Luxury Tax', SpaceKind.tax, tax: 100),
    street(39, 'Grand Promenade', ColorGroup.navy, 400, 200, [
      50,
      200,
      600,
      1400,
      1700,
      2000,
    ]),
  ]);

  static List<BoardSpace> colorSet(ColorGroup color) =>
      spaces.where((s) => s.group == color).toList(growable: false);
}

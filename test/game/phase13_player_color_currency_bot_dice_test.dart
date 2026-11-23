import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/core/utils/money_formatter.dart';
import 'package:monopoly/game/ai/bot_name_pool.dart';
import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/experience/player_palette.dart';
import 'package:monopoly/game/network/lan_game_codec.dart';
import 'package:monopoly/game/ui/widgets/dice_face.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Twelve unique, non-transparent player palette colors exist', () {
    expect(PlayerPalette.colors, hasLength(12));
    expect(PlayerPalette.colors.toSet(), hasLength(12));
    expect(PlayerPalette.labels, hasLength(12));
    for (final color in PlayerPalette.colors) {
      expect(color.a, 1);
    }
  });

  test(
    'Color selection swaps inactive reservations, but never active players',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final palette = PlayerColorPreferences.instance;
      await palette.ensureLoaded();
      final oldColor = palette.indexFor(0);
      final reservedByInactive = palette.indexFor(5);
      expect(
        await palette.select(0, reservedByInactive, activeSeats: 1),
        isTrue,
      );
      expect(palette.indexFor(0), reservedByInactive);
      expect(palette.indexFor(5), oldColor);
      expect(
        await palette.select(1, reservedByInactive, activeSeats: 2),
        isFalse,
      );
      expect(palette.selections.toSet(), hasLength(6));
    },
  );

  test('AI picks five unique names and never reuses the human name', () {
    expect(BotNamePool.names, hasLength(20));
    expect(BotNamePool.names.toSet(), hasLength(20));
    final picked = BotNamePool.pick(
      5,
      reserved: const <String>['Atlas'],
      random: Random(42),
    );
    expect(picked.toSet(), hasLength(5));
    expect(picked, isNot(contains('Atlas')));
  });

  test('Currency selection works independently of app language', () {
    expect(
      MoneyFormatter.format(1500, languageCode: 'en', currencyCode: 'BDT'),
      '৳1,500',
    );
    expect(
      MoneyFormatter.format(1500, languageCode: 'bn', currencyCode: 'USD'),
      '\$১,৫০০',
    );
    expect(
      MoneyFormatter.format(1500, languageCode: 'en', currencyCode: 'USD'),
      '\$1,500',
    );
    expect(
      MoneyFormatter.format(1500, languageCode: 'bn', currencyCode: 'BDT'),
      '৳১,৫০০',
    );
  });

  test('Player colors survive save restoration and LAN codec', () {
    final game = GameEngine(
      playerNames: const <String>['Maya', 'Nova'],
      colorIndices: const <int>[10, 7],
    );
    expect(game.players.map((p) => p.colorIndex), <int>[10, 7]);

    final offline = GameEngine.importSave(game.exportSave());
    expect(offline.players.map((p) => p.colorIndex), <int>[10, 7]);

    final lan = LanGameCodec.decode(LanGameCodec.encode(game));
    expect(lan.players.map((p) => p.colorIndex), <int>[10, 7]);
  });

  test('Duplicate seat colours are rejected by the engine', () {
    expect(
      () => GameEngine(
        playerNames: const <String>['A', 'B'],
        colorIndices: const <int>[3, 3],
      ),
      throwsA(isA<Exception>()),
    );
  });

  testWidgets('3D-style dice still show the authoritative pip value', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: ThreeDimensionalDiceFace(value: 5, size: 90)),
        ),
      ),
    );
    expect(find.byType(ThreeDimensionalDiceFace), findsOneWidget);
    expect(tester.widget<DiceFace>(find.byType(DiceFace)).value, 5);
    expect(tester.takeException(), isNull);
  });
}

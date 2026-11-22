// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lib/game/ai/bot_controller.dart';
import '../../lib/game/engine/game_engine.dart';
import '../../lib/game/persistence/offline_game_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SharedPreferences saves an offline match and AI difficulty', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final game = GameEngine(playerNames: ['Human', 'Computer']);
    game.roll(1, 2);
    await OfflineGameStore.save(game, <int, BotDifficulty>{
      1: BotDifficulty.hard,
    });
    final loaded = await OfflineGameStore.load();
    expect(loaded, isNotNull);
    expect(loaded!.game.exportSave(), game.exportSave());
    expect(loaded.botDifficulties[1], BotDifficulty.hard);
    await OfflineGameStore.clear();
    expect(await OfflineGameStore.load(), isNull);
  });
}

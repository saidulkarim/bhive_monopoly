import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_state.dart';

final appControllerProvider = AsyncNotifierProvider<AppController, AppState>(
  AppController.new,
);

class AppController extends AsyncNotifier<AppState> {
  static const storageKey = 'bhive.monopoly.profile.v1';
  final _preferences = SharedPreferencesAsync();

  @override
  Future<AppState> build() async {
    final raw = await _preferences.getString(storageKey);
    if (raw == null) return const AppState();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return AppState.fromJson(decoded);
    } on FormatException {
      // A malformed record must not prevent the player from opening the app.
    }
    return const AppState();
  }

  Future<void> setLanguage(String code) {
    if (code != 'en' && code != 'bn') {
      throw ArgumentError.value(code, 'code', 'Unsupported language');
    }
    return _persist(state.requireValue.withLanguage(code));
  }

  Future<void> saveProfile(String name, int preset, String? photo) {
    final normalized = name.trim();
    if (normalized.runes.length < 2 || normalized.runes.length > 40) {
      throw ArgumentError('Display name must contain 2 to 40 characters');
    }
    if (preset < 0 || preset >= 6) throw ArgumentError('Invalid avatar');
    return _persist(state.requireValue.withProfile(normalized, preset, photo));
  }

  Future<void> _persist(AppState next) async {
    final previous = state.requireValue;
    if (previous.isSaving) throw StateError('A save is already in progress');
    state = AsyncData(previous.saving());
    try {
      // A single record keeps the name, avatar, and language consistent.
      await _preferences.setString(storageKey, jsonEncode(next.toJson()));
      state = AsyncData(next);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }
}

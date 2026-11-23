import 'dart:async';

import 'package:flutter/material.dart';

import '../../engine/game_engine.dart';
import 'animated_board_tokens.dart';

/// Camera math for the square board shown inside an InteractiveViewer.
/// Coordinates here are *viewport logical pixels*, not the 1000x1000 model.
class SmartBoardCamera {
  const SmartBoardCamera._();

  static Matrix4 matrixForTile(int tile, double side, {double zoom = 1.75}) {
    final (row, column) = BoardTokenGeometry.gridPosition(tile);
    final pointX = (column + 0.5) * side / 11;
    final pointY = (row + 0.5) * side / 11;
    return Matrix4.identity()
      ..translateByDouble(
        side / 2 - pointX * zoom,
        side / 2 - pointY * zoom,
        0,
        1,
      )
      ..scaleByDouble(zoom, zoom, 1, 1);
  }
}

/// Presentation-only active-player tracking; never mutates the GameEngine,
/// dice rolls, save files, or packets. User gestures pause following until
/// the next player's turn. A short return to overview leaves dice accessible.
class SmartBoardFocusController {
  SmartBoardFocusController({required TickerProvider vsync}) {
    _movement = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 430),
    )..addListener(_onTick);
  }

  final TransformationController transform = TransformationController();
  late final AnimationController _movement;
  Matrix4 _from = Matrix4.identity();
  Matrix4 _to = Matrix4.identity();
  Timer? _overviewTimer;
  int? _trackedPlayer;
  int? _trackedPosition;
  bool _manuallyExploring = false;
  bool _disposed = false;

  void _onTick() {
    if (_disposed) return;
    final matrix = Matrix4Tween(begin: _from, end: _to).lerp(_movement.value);
    transform.value = matrix;
  }

  void _animateTo(Matrix4 matrix, {required bool reducedMotion}) {
    _movement.stop();
    if (reducedMotion) {
      transform.value = matrix;
      return;
    }
    _from = transform.value.clone();
    _to = matrix;
    _movement.forward(from: 0);
  }

  void _showTile(int tile, double side, {required bool reducedMotion}) {
    _overviewTimer?.cancel();
    if (reducedMotion) {
      return; // No automatic camera motion in accessibility mode.
    }
    _animateTo(
      SmartBoardCamera.matrixForTile(tile, side),
      reducedMotion: false,
    );
    // Moving the viewport indefinitely would hide the central dice. Return
    // once the viewer has seen the current tile, unless they start panning.
    _overviewTimer = Timer(const Duration(milliseconds: 1650), () {
      if (_disposed || _manuallyExploring) return;
      _animateTo(Matrix4.identity(), reducedMotion: false);
    });
  }

  void follow({
    required GameEngine game,
    required Map<int, int> visiblePositions,
    required double side,
    required bool enabled,
    required bool reducedMotion,
  }) {
    if (!enabled || side <= 0 || game.players.isEmpty || _disposed) return;
    final player = game.currentPlayer;
    if (player.bankrupt) return;
    final tile = visiblePositions[player.id] ?? player.position;
    if (reducedMotion) {
      _overviewTimer?.cancel();
      _movement.stop();
      if (!_manuallyExploring) transform.value = Matrix4.identity();
      _trackedPlayer = player.id;
      _trackedPosition = tile;
      return;
    }
    final changedTurn = player.id != _trackedPlayer;
    if (changedTurn) _manuallyExploring = false;
    if (_manuallyExploring ||
        (_trackedPlayer == player.id && _trackedPosition == tile)) {
      return;
    }
    _trackedPlayer = player.id;
    _trackedPosition = tile;
    _showTile(tile, side, reducedMotion: reducedMotion);
  }

  void focusNow({
    required GameEngine game,
    required Map<int, int> visiblePositions,
    required double side,
    required bool reducedMotion,
  }) {
    if (_disposed || side <= 0 || game.players.isEmpty) return;
    _manuallyExploring = false;
    final player = game.currentPlayer;
    _trackedPlayer = player.id;
    _trackedPosition = visiblePositions[player.id] ?? player.position;
    if (reducedMotion) {
      // Accessible instant jump for an explicitly requested focus action.
      _overviewTimer?.cancel();
      _movement.stop();
      transform.value = SmartBoardCamera.matrixForTile(_trackedPosition!, side);
    } else {
      _showTile(_trackedPosition!, side, reducedMotion: false);
    }
  }

  /// Called only for explicit human pan/zoom gestures or toolbar controls.
  void pause() {
    _manuallyExploring = true;
    _overviewTimer?.cancel();
    _movement.stop();
  }

  void reset({bool reducedMotion = false}) {
    pause();
    _animateTo(Matrix4.identity(), reducedMotion: reducedMotion);
  }

  void dispose() {
    _disposed = true;
    _overviewTimer?.cancel();
    _movement.removeListener(_onTick);
    _movement.dispose();
    transform.dispose();
  }
}

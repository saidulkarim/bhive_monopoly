import 'package:flutter/material.dart';

import '../../engine/game_engine.dart';
import 'animated_board_tokens.dart';

/// Coordinates for the optional, manually triggered Find Current Player action.
/// No part of this file starts tracking turns or player movement automatically.
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

/// User-controlled zoom helper. It deliberately has NO turn listener,
/// no timer, and no automatic recentering. The camera only moves when
/// the user taps Find Current Player, Reset Zoom, or drags/pinches the board.
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
  bool _disposed = false;

  void _onTick() {
    if (_disposed) return;
    transform.value = Matrix4Tween(
      begin: _from,
      end: _to,
    ).lerp(_movement.value);
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

  void focusNow({
    required GameEngine game,
    required Map<int, int> visiblePositions,
    required double side,
    required bool reducedMotion,
  }) {
    if (_disposed || side <= 0 || game.players.isEmpty) return;
    final player = game.currentPlayer;
    final tile = visiblePositions[player.id] ?? player.position;
    _animateTo(
      SmartBoardCamera.matrixForTile(tile, side),
      reducedMotion: reducedMotion,
    );
  }

  void pause() => _movement.stop();

  void reset({bool reducedMotion = false}) {
    _animateTo(Matrix4.identity(), reducedMotion: reducedMotion);
  }

  void dispose() {
    _disposed = true;
    _movement.removeListener(_onTick);
    _movement.dispose();
    transform.dispose();
  }
}

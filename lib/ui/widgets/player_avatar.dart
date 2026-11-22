// ignore_for_file: unnecessary_underscores

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

const playerAvatarIcons = <IconData>[
  Icons.directions_car_rounded,
  Icons.sailing_rounded,
  Icons.diamond_rounded,
  Icons.flight_rounded,
  Icons.bolt_rounded,
  Icons.business_rounded,
];

class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.preset,
    this.bytes,
    this.size = 80,
  });

  final int preset;
  final Uint8List? bytes;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      playerAvatarIcons[preset.clamp(0, playerAvatarIcons.length - 1).toInt()],
      color: AppTheme.gold,
      size: size * 0.46,
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.emerald,
        border: Border.all(color: AppTheme.gold, width: 2),
      ),
      child: bytes == null
          ? icon
          : Image.memory(
              bytes!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => icon,
            ),
    );
  }
}

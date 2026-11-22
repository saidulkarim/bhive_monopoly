import 'package:flutter/material.dart';

import '../../network/lan_room_controller.dart';

/// Displays the shared profile JPEG/PNG or a deterministic six-icon preset.
/// Also works when a peer uses Phase 6 without a custom photo.
class LanAvatarBadge extends StatelessWidget {
  const LanAvatarBadge({
    super.key,
    required this.member,
    required this.color,
    this.radius = 22,
  });

  final LanMember? member;
  final Color color;
  final double radius;

  static const List<IconData> icons = <IconData>[
    Icons.directions_car_filled_rounded,
    Icons.stars_rounded,
    Icons.sailing_rounded,
    Icons.rocket_launch_rounded,
    Icons.diamond_rounded,
    Icons.sports_esports_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final bytes = member?.avatarBytes;
    final index = (member?.avatarIndex ?? 0) % icons.length;
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: ClipOval(
        child: SizedBox.square(
          dimension: radius * 1.85,
          child: bytes == null
              ? Icon(
                  icons[index],
                  size: radius * 1.25,
                  color: const Color(0xFF142728),
                )
              : Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Icon(
                    icons[index],
                    size: radius * 1.25,
                    color: const Color(0xFF142728),
                  ),
                ),
        ),
      ),
    );
  }
}

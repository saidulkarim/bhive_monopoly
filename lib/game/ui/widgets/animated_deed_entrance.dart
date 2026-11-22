import 'package:flutter/material.dart';

import '../../experience/game_experience_settings.dart';

/// A small, accessible entrance motion for existing interactive title deeds.
/// The content itself remains the Phase 10 PropertyDeedCard.
class AnimatedDeedEntrance extends StatelessWidget {
  const AnimatedDeedEntrance({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced =
        GameExperienceSettings.instance.reducedMotion ||
        MediaQuery.maybeOf(context)?.disableAnimations == true;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0.0, 1.0).toDouble(),
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: Transform.scale(scale: 0.97 + 0.03 * value, child: child),
        ),
      ),
      child: child,
    );
  }
}

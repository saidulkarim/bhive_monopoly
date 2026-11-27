import 'package:flutter/material.dart';

import '../config/game_config.dart';

/// Presentation-only policy. No timers, listeners or private image cache.
abstract final class GraphicsResourcePolicy {
  /// Round up the display's physical pixel requirement to a stable bucket.
  /// Null means keep the original provider (disabled or invalid dimensions).
  static int? decodeSide(double logicalSide, double devicePixelRatio) {
    if (!GameConfig.displaySizedImageDecodingEnabled ||
        !logicalSide.isFinite ||
        logicalSide <= 0 ||
        !devicePixelRatio.isFinite ||
        devicePixelRatio <= 0) {
      return null;
    }
    const bucket = GameConfig.imageDecodeBucketPixels;
    const maximum = GameConfig.smallImageDecodeMaximumPixels;
    final physical = logicalSide * devicePixelRatio;
    if (physical >= maximum) return maximum;
    return ((physical / bucket).ceil() * bucket).clamp(bucket, maximum).toInt();
  }

  /// Request a bounded aspect-preserving decode without upscaling.
  /// Flutter retains ownership of caching and image lifecycle management.
  static ImageProvider<Object> smallImage(
    BuildContext context,
    ImageProvider<Object> source,
    double logicalSide,
  ) {
    final side = decodeSide(
      logicalSide,
      MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0,
    );
    if (side == null) return source;
    return ResizeImage(
      source,
      width: side,
      height: side,
      policy: ResizeImagePolicy.fit,
      allowUpscaling: false,
    );
  }

  /// Zero glow cycles is the existing Battery Saver / Ultra Saver policy.
  /// Keep the main colored outline independently of this optional blur.
  static bool useSoftGlow(int glowCycles) =>
      !GameConfig.lowPowerSimplifiedBoardEffectsEnabled || glowCycles > 0;
}

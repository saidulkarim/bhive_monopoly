/// Shared developer defaults. Rebuild Android and Web after changing them.
abstract final class GameConfig {
  /// Enable reminders and optional safe completion for eligible human turns.
  static const smartTurnAssistEnabled = true;

  /// Allow offline human auto-end only after all required decisions. Default: off.
  static const humanAutoEndTurnEnabled = false;

  /// Inactivity before an eligible End Turn reminder, in seconds.
  static const endTurnReminderSeconds = 30;

  /// Total eligible inactivity before automatic completion, if enabled.
  static const autoEndTurnSeconds = 60;

  /// Warning lead time in seconds; must be positive and below autoEndTurnSeconds.
  static const autoEndTurnCountdownSeconds = 10;

  /// Enable strategic stagnation observation at turn boundaries.
  static const deadlockDetectionEnabled = true;

  /// Minimum match turn number for deadlock consideration.
  static const deadlockMinimumTurns = 80;

  /// Minimum turns without a strategic state change before detection.
  static const deadlockObservationTurns = 40;

  /// Minimum turns between repeated strategic recommendations.
  static const deadlockNotificationCooldownTurns = 30;

  /// Minimum fraction of purchasable spaces owned, from 0.0 to 1.0.
  static const deadlockOwnedPropertyRatio = .85;

  /// Allow eligible AI reciprocal trade proposals, with human consent when applicable.
  static const aiAutonomousTradingEnabled = true;

  /// Turn-based cooldown used for autonomous AI trade attempts.
  static const aiTradeCooldownTurns = 5;

  /// Fractions of reference price evaluated by the existing AI sell-offer logic.
  static const aiCounterOfferFractions = <double>[.9, .75, .6];

  /// Minimum solvent-player cash for the deadlock condition, in game units.
  static const aiMinimumCashForDeadlock = 300;

  /// Delay between applicable AI actions; changes pacing, not intelligence.
  static const aiActionDelayMilliseconds = 430;

  /// ARGB red color for mortgaged tile highlights.
  static const mortgageOverlayColor = 0xFFEF4444;

  /// Mortgage overlay opacity, from 0.0 to 1.0.
  static const mortgageOverlayOpacity = .50;

  /// Multiplier for the mortgage lock icon size.
  static const mortgageIconScale = 1.8;

  /// Maximum completed turns in Quick offline matches.
  static const quickMatchMaximumTurns = 100;

  /// Maximum completed turns in Standard offline matches.
  static const standardMatchMaximumTurns = 250;

  /// Maximum completed turns in Extended offline matches.
  static const extendedMatchMaximumTurns = 500;

  /// Lowest permitted custom offline turn limit.
  static const customMatchMinimumTurns = 50;

  /// Highest permitted custom offline turn limit; Classic is unlimited.
  static const customMatchMaximumTurns = 2000;

  /// Total finite victory animation duration, in seconds.
  static const victoryCelebrationSeconds = 5;

  /// Fireworks duration; should not exceed victoryCelebrationSeconds.
  static const victoryFireworksSeconds = 3;

  /// Victory trophy size in logical pixels.
  static const victoryTrophySize = 100.0;

  /// Particle count for the Performance profile.
  static const performanceConfettiParticles = 100;

  /// Particle count for the Balanced profile.
  static const balancedConfettiParticles = 60;

  /// Reduced particle count for Battery Saver.
  static const batterySaverConfettiParticles = 20;
  // Direct property acquisition and portfolio filtering.
  /// Enable requests to buy properties owned by another player.
  static const propertyBuyRequestEnabled = true;

  /// Enable direct purchase requests involving AI sellers.
  static const aiPropertyBuyRequestEnabled = true;

  /// Enable direct purchase requests involving human sellers.
  static const humanPropertyBuyRequestEnabled = true;

  /// Permit AI seller counteroffers.
  static const propertyBuyCounterOfferEnabled = true;
  // Multipliers applied to rejected AI purchase offers (higher asking prices).
  static const propertyBuyCounterOfferMultipliers = <double>[1.25, 1.5, 2.0];

  /// Offline cooldown before the same buyer requests the same property again.
  static const propertyBuyRequestCooldownTurns = 3;

  /// Show when a proposed purchase would complete a color group.
  static const colorGroupRecommendationEnabled = true;

  /// Enable owner-based filtering in the board list.
  static const playerPropertyFilterEnabled = true;

  /// Show the selected owner and number of matching properties.
  static const playerPropertySummaryEnabled = true;
  // ==========================================================
  // RESPONSIVE EXPLORE BOARD LAYOUT
  // ==========================================================
  /// Enable the vertical player sidebar on wide viewports.
  static const responsiveBoardLayoutEnabled = true;

  /// Minimum usable width in logical pixels, not physical pixels.
  static const landscapeBoardMinimumWidth = 640.0;

  /// Minimum usable body height for the sidebar and board controls.
  static const landscapeBoardMinimumHeight = 260.0;

  /// Preferred sidebar width, clamped to the configured bounds.
  static const landscapePlayerSidebarWidth = 200.0;
  static const landscapePlayerSidebarMinimumWidth = 160.0;
  static const landscapePlayerSidebarMaximumWidth = 240.0;

  /// Vertical gap between player cards, in logical pixels.
  static const landscapePlayerCardSpacing = 8.0;

  /// Place zoom controls in the sidebar rather than below the board.
  static const landscapeSidebarZoomControlsEnabled = true;
  // ==========================================================
  // HOME SCREEN - PRIMARY START GAME BUTTON
  // ==========================================================
  /// Minimum button height in logical pixels; grows for large text.
  static const homeStartButtonHeight = 54.0;

  /// Rounded corner radius in logical pixels.
  static const homeStartButtonBorderRadius = 16.0;

  /// Maximum button width on wide screens.
  static const homeStartButtonMaximumWidth = 720.0;

  /// Gap between the tagline and primary action.
  static const homeStartButtonTopSpacing = 16.0;

  /// Gap between the primary action and profile/balance panels.
  static const homeStartButtonBottomSpacing = 20.0;

  /// Primary action label font size in logical pixels.
  static const homeStartButtonFontSize = 18.0;

  /// Primary action icon size in logical pixels.
  static const homeStartButtonIconSize = 24.0;
  // ==========================================================
  // PHASE 15.9A - DECORATIVE RENDERING & STORAGE OPTIMIZATION
  // ==========================================================
  /// Stop decorative effects when the app is not visible. Does not
  /// suspend match rules, network messages or authoritative turns.
  static const advancedBatteryOptimizationEnabled = true;

  /// Maximum number of visual dice spin cycles per rolling episode.
  /// A stuck presentation flag cannot keep the GPU spinning forever.
  /// This does not limit the actual roll or change its outcome.
  static const maximumDecorativeDiceSpinCycles = 4;

  /// Only auto-rotate 3D token previews in Performance power mode.
  /// Other modes still allow manual camera controls and 3D preview.
  static const tokenAutoRotationPerformanceOnly = true;

  /// Skip identical offline saves while retaining the previous distinct
  /// validated checkpoint and existing serialized write ordering.
  static const skipUnchangedOfflineCheckpoints = true;
}

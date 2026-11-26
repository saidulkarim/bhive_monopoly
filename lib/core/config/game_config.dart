/// ============================================================
/// bHiVE Monopoly - Global Game Configuration
/// ============================================================
///
/// Centralized developer-defined configuration for the application.
///
/// Supported platforms:
///   - Android
///   - Web
///
/// Purpose:
///   - Control gameplay behaviour.
///   - Manage automatic turn completion.
///   - Configure strategic deadlock detection.
///   - Control intelligent AI trading.
///   - Customize mortgage property visualization.
///   - Configure match duration limits.
///   - Manage victory celebrations.
///   - Maintain battery-efficient animations.
///
/// IMPORTANT:
///   1. Change configurable values from this file.
///   2. Rebuild Android and Web after modifying these values.
///   3. Avoid hardcoding these values in individual screens.
///   4. Do not bypass existing game-engine validations.
///   5. Preserve multiplayer synchronization and saved-game integrity.
///
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

abstract final class GameConfig {
  // ==========================================================
  // 01. SMART TURN MANAGEMENT
  // ==========================================================

  /// Enables the Smart Turn Assist system.
  ///
  /// Helps players remember to end their turn after completing
  /// all mandatory gameplay actions.
  ///
  /// true  = Enable turn assistance and reminders.
  /// false = Disable turn assistance.
  static const smartTurnAssistEnabled = true;

  /// Enables automatic turn completion for human players
  /// in supported offline matches.
  ///
  /// true  = Automatically end an eligible inactive turn.
  /// false = Players must manually press End Turn.
  ///
  /// Automatic completion must not bypass pending purchases,
  /// auctions, debt settlement, additional dice rolls or
  /// other mandatory gameplay decisions.
  static const humanAutoEndTurnEnabled = false;

  /// Number of inactive seconds before displaying an End Turn
  /// reminder to the current player.
  ///
  /// Example:
  /// 30 = Display a reminder after 30 seconds of inactivity.
  ///
  /// Recommended range: 15–60 seconds.
  static const endTurnReminderSeconds = 30;

  /// Total inactivity duration before automatically ending
  /// an eligible human player's turn.
  ///
  /// Only effective when humanAutoEndTurnEnabled is true.
  ///
  /// Example:
  /// 60 = Automatically end the turn after 60 seconds.
  ///
  /// Recommended range: 30–120 seconds.
  static const autoEndTurnSeconds = 60;

  /// Number of seconds before automatic turn completion
  /// when the final warning message is displayed.
  ///
  /// Example:
  /// autoEndTurnSeconds = 60
  /// autoEndTurnCountdownSeconds = 10
  ///
  /// The warning appears at:
  /// 60 - 10 = 50 seconds.
  ///
  /// English:
  /// "Your turn will end automatically in 10 seconds."
  ///
  /// Bangla:
  /// "আপনার চাল ১০ সেকেন্ডের মধ্যে স্বয়ংক্রিয়ভাবে শেষ হবে।"
  ///
  /// This value must be greater than zero and smaller than
  /// autoEndTurnSeconds.
  static const autoEndTurnCountdownSeconds = 10;

  // ==========================================================
  // 02. STRATEGIC DEADLOCK DETECTION
  // ==========================================================

  /// Enables strategic deadlock detection.
  ///
  /// Identifies matches where players continue playing without
  /// sufficient strategic or financial progression.
  ///
  /// Applies to supported AI and human gameplay modes.
  ///
  /// AI matches:
  /// Encourages strategic property exchanges.
  ///
  /// Human matches:
  /// Provides strategic recommendations without forcing trades.
  static const deadlockDetectionEnabled = true;

  /// Minimum number of turns required before the system
  /// starts considering a match strategically stagnant.
  ///
  /// Example:
  /// 80 = Do not classify the early game as a deadlock
  /// before reaching the minimum turn threshold.
  ///
  /// Lower values detect stagnation earlier.
  /// Higher values allow more natural gameplay progression.
  ///
  /// Recommended range: 60–150 turns.
  static const deadlockMinimumTurns = 80;

  /// Number of recent turns used to observe meaningful
  /// strategic progression.
  ///
  /// Relevant activities may include:
  ///   - Property ownership changes.
  ///   - Property exchanges.
  ///   - House and hotel construction.
  ///   - Mortgage status changes.
  ///   - Player bankruptcy.
  ///
  /// Example:
  /// 40 = Evaluate strategic progression over a
  /// 40-turn observation window.
  ///
  /// Recommended range: 20–60 turns.
  static const deadlockObservationTurns = 40;

  /// Minimum number of turns between repeated deadlock
  /// notifications.
  ///
  /// Prevents the application from repeatedly interrupting
  /// players with the same strategic recommendation.
  ///
  /// Example:
  /// 30 = Allow at least 30 turns between notifications.
  ///
  /// Recommended range: 20–50 turns.
  static const deadlockNotificationCooldownTurns = 30;

  /// Proportion of purchasable properties that must be owned
  /// before the property-ownership deadlock condition is met.
  ///
  /// Value range: 0.0–1.0
  ///
  /// 0.70 = 70% of purchasable properties owned.
  /// 0.85 = 85% of purchasable properties owned.
  /// 1.00 = 100% of purchasable properties owned.
  ///
  /// Lower values allow earlier deadlock detection.
  /// Higher values make detection more conservative.
  static const deadlockOwnedPropertyRatio = .85;

  // ==========================================================
  // 03. INTELLIGENT AI TRADING & GAMEPLAY
  // ==========================================================

  /// Enables autonomous strategic property trading by AI players.
  ///
  /// Allows computer opponents to identify suitable property
  /// exchange opportunities with other players.
  ///
  /// Intended objectives:
  ///   - Complete property color groups.
  ///   - Create construction opportunities.
  ///   - Improve rental income.
  ///   - Reduce strategic deadlock.
  ///
  /// Human-owned properties must never be exchanged without
  /// the human player's explicit approval.
  static const aiAutonomousTradingEnabled = true;

  /// Minimum number of turns between eligible autonomous
  /// AI trade attempts, according to the trading logic.
  ///
  /// Prevents excessively frequent trade proposals and
  /// unnecessary repeated AI evaluations.
  ///
  /// Example:
  /// 5 = Apply a five-turn trading cooldown.
  ///
  /// Lower values make AI trading more frequent.
  /// Higher values make AI trading less frequent.
  ///
  /// Recommended range: 3–10 turns.
  static const aiTradeCooldownTurns = 5;

  /// Price fractions used when generating AI counteroffers.
  ///
  /// The AI can evaluate alternative prices based on the
  /// reference price used by the negotiation logic.
  ///
  /// Example, if the reference price is $400:
  ///
  /// 0.90 = 90% = $360
  /// 0.75 = 75% = $300
  /// 0.60 = 60% = $240
  ///
  /// The actual counteroffer must still satisfy the existing
  /// AI valuation, ownership and financial validations.
  ///
  /// Higher fractions produce offers closer to the
  /// original reference price.
  static const aiCounterOfferFractions = <double>[.9, .75, .6];

  /// Minimum available cash threshold used by the AI
  /// deadlock-related progression logic.
  ///
  /// Helps prevent financially vulnerable computer players
  /// from participating in unsuitable strategic transactions.
  ///
  /// Example:
  /// 300 = Apply a minimum cash threshold of 300 game units.
  ///
  /// This is a gameplay amount, regardless of whether the
  /// selected display currency is Dollar or Taka.
  ///
  /// Lower values encourage more aggressive AI behaviour.
  /// Higher values encourage more conservative AI behaviour.
  ///
  /// Recommended range: 200–500.
  static const aiMinimumCashForDeadlock = 300;

  /// Delay between applicable automated AI gameplay actions.
  ///
  /// Measured in milliseconds.
  ///
  /// Examples:
  /// 250  = Faster AI gameplay.
  /// 430  = Balanced AI action speed.
  /// 750  = Slower, easier-to-follow AI gameplay.
  /// 1000 = One-second delay.
  ///
  /// This controls action pacing, not AI intelligence.
  ///
  /// Very low values may make AI activities difficult
  /// for human players to follow.
  ///
  /// Recommended range: 250–1000 milliseconds.
  static const aiActionDelayMilliseconds = 430;

  // ==========================================================
  // 04. MORTGAGED PROPERTY VISUALIZATION
  // ==========================================================

  /// ARGB color used for mortgaged property highlighting.
  ///
  /// Format: 0xAARRGGBB
  ///
  /// FF = Full base color alpha.
  /// EF = Red component.
  /// 44 = Green component.
  /// 44 = Blue component.
  ///
  /// Current color: Red (#EF4444).
  ///
  /// Alternative examples:
  /// 0xFFFF0000 = Pure red.
  /// 0xFFDC2626 = Strong red.
  /// 0xFFB91C1C = Dark red.
  ///
  /// The final transparency is controlled separately by
  /// mortgageOverlayOpacity.
  static const mortgageOverlayColor = 0xFFEF4444;

  /// Transparency level of the red mortgage overlay
  /// covering the property tile background.
  ///
  /// Value range: 0.0–1.0
  ///
  /// 0.00 = Fully transparent.
  /// 0.25 = 25% opacity.
  /// 0.50 = 50% opacity.
  /// 0.75 = 75% opacity.
  /// 1.00 = Fully opaque.
  ///
  /// Property names, prices, ownership indicators and
  /// color-group information should remain readable.
  ///
  /// Recommended range: 0.40–0.60.
  static const mortgageOverlayOpacity = .50;

  /// Scaling multiplier for the mortgage lock icon.
  ///
  /// 1.0 = Original icon size.
  /// 1.5 = 150% of the original size.
  /// 1.8 = 180% of the original size.
  /// 2.0 = Double the original size.
  ///
  /// Example:
  /// Original icon size: 12 logical pixels.
  /// Scale: 1.8
  /// Resulting icon size: 21.6 logical pixels.
  ///
  /// Excessive scaling may cause property text overflow,
  /// particularly on smaller mobile screens.
  ///
  /// Recommended range: 1.5–2.0.
  static const mortgageIconScale = 1.8;

  // ==========================================================
  // 05. PREDEFINED MATCH DURATION MODES
  // ==========================================================

  /// Maximum number of turns allowed in Quick Match mode.
  ///
  /// When the limit is reached at an eligible turn-completion
  /// boundary, the winner is determined using the applicable
  /// net-worth calculation.
  ///
  /// Recommended for players who prefer shorter matches.
  ///
  /// Classic Match is not affected by this limit.
  static const quickMatchMaximumTurns = 100;

  /// Maximum number of turns allowed in Standard Match mode.
  ///
  /// Provides a balance between shorter gameplay and
  /// long-term property investment strategies.
  ///
  /// Classic Match is not affected by this limit.
  static const standardMatchMaximumTurns = 250;

  /// Maximum number of turns allowed in Extended Match mode.
  ///
  /// Provides more time for property trading, construction,
  /// mortgage management and advanced financial strategies.
  ///
  /// Classic Match is not affected by this limit.
  static const extendedMatchMaximumTurns = 500;

  /// Minimum permitted turn limit when a player creates
  /// a Custom Match.
  ///
  /// Prevents extremely short custom matches that may not
  /// provide enough time for meaningful property acquisition
  /// and strategic gameplay.
  ///
  /// Must not exceed customMatchMaximumTurns.
  static const customMatchMinimumTurns = 50;

  /// Maximum permitted turn limit for a Custom Match.
  ///
  /// Prevents unreasonable custom turn-limit values.
  ///
  /// This does not restrict Classic Match, which retains
  /// its original unlimited-duration rules.
  ///
  /// Must be greater than or equal to customMatchMinimumTurns.
  static const customMatchMaximumTurns = 2000;

  // ==========================================================
  // 06. VICTORY CELEBRATION
  // ==========================================================

  /// Total duration of the animated victory celebration.
  ///
  /// Measured in seconds.
  ///
  /// Controls the overall celebration animation period.
  ///
  /// After the animation finishes, the winner interface
  /// should remain visible without continuously rendering
  /// decorative effects.
  ///
  /// Recommended range: 3–8 seconds.
  static const victoryCelebrationSeconds = 5;

  /// Duration allocated to victory fireworks.
  ///
  /// Measured in seconds.
  ///
  /// Fireworks should stop automatically after the configured
  /// duration to reduce unnecessary CPU and GPU activity.
  ///
  /// Must not exceed victoryCelebrationSeconds.
  ///
  /// Recommended range: 2–5 seconds.
  static const victoryFireworksSeconds = 3;

  /// Display size of the premium victory trophy.
  ///
  /// Measured in Flutter logical pixels, not physical pixels.
  ///
  /// Examples:
  /// 80.0  = Compact trophy.
  /// 100.0 = Standard trophy.
  /// 120.0 = Large trophy.
  /// 150.0 = Extra-large trophy.
  ///
  /// Larger values should be tested on smaller Android phones
  /// and narrow Web browser layouts to avoid overflow.
  ///
  /// Recommended range: 80.0–140.0.
  static const victoryTrophySize = 100.0;

  // ==========================================================
  // 07. POWER-AWARE CONFETTI & ANIMATION SETTINGS
  // ==========================================================

  /// Number of confetti particles in Performance power mode.
  ///
  /// Provides the richest victory celebration.
  ///
  /// Higher particle counts may increase temporary GPU
  /// rendering and battery consumption.
  ///
  /// Recommended range: 80–150 particles.
  static const performanceConfettiParticles = 100;

  /// Number of confetti particles in Balanced power mode.
  ///
  /// Provides a premium celebration while limiting
  /// unnecessary graphical workload.
  ///
  /// Balanced is the recommended default power profile.
  ///
  /// Recommended range: 40–80 particles.
  static const balancedConfettiParticles = 60;

  /// Number of confetti particles in Battery Saver mode.
  ///
  /// Provides a lightweight celebration for users who
  /// prefer reduced battery consumption.
  ///
  /// Recommended range: 10–30 particles.
  ///
  /// Ultra Saver and Reduce Motion should suppress decorative
  /// particle animations according to their existing logic.
  static const batterySaverConfettiParticles = 20;

  // ==========================================================
  // 08. END OF GLOBAL CONFIGURATION
  // ==========================================================
}

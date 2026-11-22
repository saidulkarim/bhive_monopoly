// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tagline => 'Own the streets. Build your empire.';

  @override
  String get player => 'Player';

  @override
  String welcome(String name) {
    return 'Welcome, $name';
  }

  @override
  String get profileIntro =>
      'Choose a name and avatar for your seat at the table.';

  @override
  String get editProfile => 'My profile';

  @override
  String get startingBalance => 'Starting balance';

  @override
  String get balanceExplanation =>
      'Every player starts with the same balance. Your language changes the display, while game values stay the same.';

  @override
  String get howToPlay => 'How to play';

  @override
  String get displayName => 'Display name';

  @override
  String get nameValidation => 'Enter a name with 2 to 40 characters.';

  @override
  String get chooseAvatar => 'Choose your avatar';

  @override
  String avatarName(int number) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return 'Avatar $numberString';
  }

  @override
  String get choosePhoto => 'Choose photo';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get photoHint =>
      'Choose a JPG or PNG image up to 10 MB. Your photo is cropped to a square and saved on this device.';

  @override
  String get photoError =>
      'Could not open that photo. Try a JPG or PNG under 10 MB, and check photo or camera access.';

  @override
  String get saveProfile => 'Save profile';

  @override
  String get profileSaved => 'Profile saved.';

  @override
  String get saveError => 'Could not save your changes. Please try again.';

  @override
  String get ruleGoalTitle => 'The goal';

  @override
  String get ruleGoal =>
      'Buy property, collect rent, and remain solvent. The last player left after all opponents become bankrupt wins.';

  @override
  String get ruleTurnTitle => 'Turns and movement';

  @override
  String get ruleTurn =>
      'Roll two dice and move clockwise. Collect \$200 when passing or landing on GO. Doubles give another roll after the landing action; three consecutive doubles send you directly to Jail without a GO payment.';

  @override
  String get rulePropertyTitle => 'Property and rent';

  @override
  String get ruleProperty =>
      'Buy an unowned property at its printed price or send it to auction, starting at \$10. All active players may bid. Rent follows the title deed. An undeveloped street in a complete color set normally earns double rent. Mortgaged property earns none.';

  @override
  String get ruleBuildingsTitle => 'Houses and hotels';

  @override
  String get ruleBuildings =>
      'Build evenly across a complete color set, with no mortgages in that set. Four houses on every street are required before upgrading to hotels. There are 32 houses and 12 hotels. Sell buildings evenly to the bank for half their purchase cost.';

  @override
  String get ruleJailTitle => 'Jail';

  @override
  String get ruleJail =>
      'Pay \$50, use a Get Out of Jail Free card, or try to roll doubles for up to three turns. Escape doubles allow movement but no extra roll. After a third failed attempt, pay \$50 and move using that roll. You can still collect rent and manage property while in Jail.';

  @override
  String get ruleDebtTitle => 'Debt and trading';

  @override
  String get ruleDebt =>
      'Raise money through legal deals, building sales, or mortgages before declaring bankruptcy. Remove all buildings in a color set before trading or mortgaging a street. Unmortgaging costs the mortgage value plus 10%. Players cannot lend each other money.';

  @override
  String get ruleParkingTitle => 'Free Parking';

  @override
  String get ruleParking =>
      'Free Parking has no cash reward. Taxes and fines go to the bank, with no jackpot in the center of the board.';
}

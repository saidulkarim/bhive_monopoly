import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
  ];

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Own the streets. Build your empire.'**
  String get tagline;

  /// No description provided for @player.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get player;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}'**
  String welcome(String name);

  /// No description provided for @profileIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose a name and avatar for your seat at the table.'**
  String get profileIntro;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'My profile'**
  String get editProfile;

  /// No description provided for @startingBalance.
  ///
  /// In en, this message translates to:
  /// **'Starting balance'**
  String get startingBalance;

  /// No description provided for @balanceExplanation.
  ///
  /// In en, this message translates to:
  /// **'Every player starts with the same balance. Your language changes the display, while game values stay the same.'**
  String get balanceExplanation;

  /// No description provided for @howToPlay.
  ///
  /// In en, this message translates to:
  /// **'How to play'**
  String get howToPlay;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @nameValidation.
  ///
  /// In en, this message translates to:
  /// **'Enter a name with 2 to 40 characters.'**
  String get nameValidation;

  /// No description provided for @chooseAvatar.
  ///
  /// In en, this message translates to:
  /// **'Choose your avatar'**
  String get chooseAvatar;

  /// No description provided for @avatarName.
  ///
  /// In en, this message translates to:
  /// **'Avatar {number}'**
  String avatarName(int number);

  /// No description provided for @choosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get choosePhoto;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// No description provided for @photoHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a JPG or PNG image up to 10 MB. Your photo is cropped to a square and saved on this device.'**
  String get photoHint;

  /// No description provided for @photoError.
  ///
  /// In en, this message translates to:
  /// **'Could not open that photo. Try a JPG or PNG under 10 MB, and check photo or camera access.'**
  String get photoError;

  /// No description provided for @saveProfile.
  ///
  /// In en, this message translates to:
  /// **'Save profile'**
  String get saveProfile;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved.'**
  String get profileSaved;

  /// No description provided for @saveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save your changes. Please try again.'**
  String get saveError;

  /// No description provided for @ruleGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'The goal'**
  String get ruleGoalTitle;

  /// No description provided for @ruleGoal.
  ///
  /// In en, this message translates to:
  /// **'Buy property, collect rent, and remain solvent. The last player left after all opponents become bankrupt wins.'**
  String get ruleGoal;

  /// No description provided for @ruleTurnTitle.
  ///
  /// In en, this message translates to:
  /// **'Turns and movement'**
  String get ruleTurnTitle;

  /// No description provided for @ruleTurn.
  ///
  /// In en, this message translates to:
  /// **'Roll two dice and move clockwise. Collect \$200 when passing or landing on GO. Doubles give another roll after the landing action; three consecutive doubles send you directly to Jail without a GO payment.'**
  String get ruleTurn;

  /// No description provided for @rulePropertyTitle.
  ///
  /// In en, this message translates to:
  /// **'Property and rent'**
  String get rulePropertyTitle;

  /// No description provided for @ruleProperty.
  ///
  /// In en, this message translates to:
  /// **'Buy an unowned property at its printed price or send it to auction, starting at \$10. All active players may bid. Rent follows the title deed. An undeveloped street in a complete color set normally earns double rent. Mortgaged property earns none.'**
  String get ruleProperty;

  /// No description provided for @ruleBuildingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Houses and hotels'**
  String get ruleBuildingsTitle;

  /// No description provided for @ruleBuildings.
  ///
  /// In en, this message translates to:
  /// **'Build evenly across a complete color set, with no mortgages in that set. Four houses on every street are required before upgrading to hotels. There are 32 houses and 12 hotels. Sell buildings evenly to the bank for half their purchase cost.'**
  String get ruleBuildings;

  /// No description provided for @ruleJailTitle.
  ///
  /// In en, this message translates to:
  /// **'Jail'**
  String get ruleJailTitle;

  /// No description provided for @ruleJail.
  ///
  /// In en, this message translates to:
  /// **'Pay \$50, use a Get Out of Jail Free card, or try to roll doubles for up to three turns. Escape doubles allow movement but no extra roll. After a third failed attempt, pay \$50 and move using that roll. You can still collect rent and manage property while in Jail.'**
  String get ruleJail;

  /// No description provided for @ruleDebtTitle.
  ///
  /// In en, this message translates to:
  /// **'Debt and trading'**
  String get ruleDebtTitle;

  /// No description provided for @ruleDebt.
  ///
  /// In en, this message translates to:
  /// **'Raise money through legal deals, building sales, or mortgages before declaring bankruptcy. Remove all buildings in a color set before trading or mortgaging a street. Unmortgaging costs the mortgage value plus 10%. Players cannot lend each other money.'**
  String get ruleDebt;

  /// No description provided for @ruleParkingTitle.
  ///
  /// In en, this message translates to:
  /// **'Free Parking'**
  String get ruleParkingTitle;

  /// No description provided for @ruleParking.
  ///
  /// In en, this message translates to:
  /// **'Free Parking has no cash reward. Taxes and fines go to the bank, with no jackpot in the center of the board.'**
  String get ruleParking;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

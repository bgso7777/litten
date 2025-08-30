import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_bn.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fa.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ha.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_id.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_mr.dart';
import 'app_localizations_ms.dart';
import 'app_localizations_nl.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_ps.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ro.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_sw.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_te.dart';
import 'app_localizations_th.dart';
import 'app_localizations_tl.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_uk.dart';
import 'app_localizations_ur.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('ar'),
    Locale('bn'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fa'),
    Locale('fr'),
    Locale('ha'),
    Locale('hi'),
    Locale('id'),
    Locale('it'),
    Locale('ja'),
    Locale('ko'),
    Locale('mr'),
    Locale('ms'),
    Locale('nl'),
    Locale('pl'),
    Locale('ps'),
    Locale('pt'),
    Locale('ro'),
    Locale('ru'),
    Locale('sw'),
    Locale('ta'),
    Locale('te'),
    Locale('th'),
    Locale('tl'),
    Locale('tr'),
    Locale('uk'),
    Locale('ur'),
    Locale('zh'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Litten'**
  String get appTitle;

  /// Home tab title
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTitle;

  /// Recording tab title
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get recordingTitle;

  /// Writing tab title
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get writingTitle;

  /// Settings tab title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Button to create new litten
  ///
  /// In en, this message translates to:
  /// **'Create Litten'**
  String get createLitten;

  /// Empty state title when no litten is selected
  ///
  /// In en, this message translates to:
  /// **'Create or select a Litten'**
  String get emptyLittenTitle;

  /// Empty state description
  ///
  /// In en, this message translates to:
  /// **'Use the \'Create Litten\' button below to start your first note'**
  String get emptyLittenDescription;

  /// Button to start audio recording
  ///
  /// In en, this message translates to:
  /// **'Start Recording'**
  String get startRecording;

  /// Button to stop audio recording
  ///
  /// In en, this message translates to:
  /// **'Stop Recording'**
  String get stopRecording;

  /// Recording status text
  ///
  /// In en, this message translates to:
  /// **'Recording...'**
  String get recording;

  /// Text writing mode
  ///
  /// In en, this message translates to:
  /// **'Text Writing'**
  String get textWriting;

  /// Handwriting mode
  ///
  /// In en, this message translates to:
  /// **'Handwriting'**
  String get handwriting;

  /// Save button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Delete button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Upgrade button
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get upgrade;

  /// Remove ads button
  ///
  /// In en, this message translates to:
  /// **'Remove Ads'**
  String get removeAds;

  /// Free version label
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get freeVersion;

  /// Standard version label
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get standardVersion;

  /// Premium version label
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premiumVersion;

  /// Theme setting
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// Language setting
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Classic Blue theme
  ///
  /// In en, this message translates to:
  /// **'Classic Blue'**
  String get classicBlue;

  /// Dark Mode theme
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// Nature Green theme
  ///
  /// In en, this message translates to:
  /// **'Nature Green'**
  String get natureGreen;

  /// Sunset Orange theme
  ///
  /// In en, this message translates to:
  /// **'Sunset Orange'**
  String get sunsetOrange;

  /// Monochrome Grey theme
  ///
  /// In en, this message translates to:
  /// **'Monochrome Grey'**
  String get monochromeGrey;

  /// Account and subscription section title
  ///
  /// In en, this message translates to:
  /// **'Account & Subscription'**
  String get accountAndSubscription;

  /// User status setting
  ///
  /// In en, this message translates to:
  /// **'User Status'**
  String get userStatus;

  /// Usage statistics setting
  ///
  /// In en, this message translates to:
  /// **'Usage Statistics'**
  String get usageStatistics;

  /// App settings section title
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get appSettings;

  /// Start screen setting
  ///
  /// In en, this message translates to:
  /// **'Start Screen'**
  String get startScreen;

  /// Recording settings section title
  ///
  /// In en, this message translates to:
  /// **'Recording Settings'**
  String get recordingSettings;

  /// Maximum recording time setting
  ///
  /// In en, this message translates to:
  /// **'Max Recording Time'**
  String get maxRecordingTime;

  /// Audio quality setting
  ///
  /// In en, this message translates to:
  /// **'Audio Quality'**
  String get audioQuality;

  /// Writing settings section title
  ///
  /// In en, this message translates to:
  /// **'Writing Settings'**
  String get writingSettings;

  /// Auto save interval setting
  ///
  /// In en, this message translates to:
  /// **'Auto Save Interval'**
  String get autoSaveInterval;

  /// Default font setting
  ///
  /// In en, this message translates to:
  /// **'Default Font'**
  String get defaultFont;

  /// Free version with ads description
  ///
  /// In en, this message translates to:
  /// **'Free (with ads)'**
  String get freeWithAds;

  /// Standard version monthly price
  ///
  /// In en, this message translates to:
  /// **'Standard (\$4.99/month)'**
  String get standardMonthly;

  /// Premium version monthly price
  ///
  /// In en, this message translates to:
  /// **'Premium (\$9.99/month)'**
  String get premiumMonthly;

  /// Count of littens
  ///
  /// In en, this message translates to:
  /// **'littens'**
  String get littensCount;

  /// Count of files
  ///
  /// In en, this message translates to:
  /// **'files'**
  String get filesCount;

  /// Premium upgrade benefit description
  ///
  /// In en, this message translates to:
  /// **'Remove ads and unlimited features'**
  String get removeAdsAndUnlimited;

  /// Maximum recording time value
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get maxRecordingTimeValue;

  /// Standard audio quality
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get standardQuality;

  /// Auto save interval value
  ///
  /// In en, this message translates to:
  /// **'3 minutes'**
  String get autoSaveIntervalValue;

  /// System font option
  ///
  /// In en, this message translates to:
  /// **'System Font'**
  String get systemFont;

  /// App version information
  ///
  /// In en, this message translates to:
  /// **'Litten v1.0.0'**
  String get appVersion;

  /// App description
  ///
  /// In en, this message translates to:
  /// **'Cross-platform integrated note app'**
  String get appDescription;

  /// Close button
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Free user limits section title
  ///
  /// In en, this message translates to:
  /// **'Free user limits:'**
  String get freeUserLimits;

  /// Maximum littens for free users
  ///
  /// In en, this message translates to:
  /// **'• Litten'**
  String get maxLittens;

  /// Maximum recording files for free users
  ///
  /// In en, this message translates to:
  /// **'• Recording files'**
  String get maxRecordingFiles;

  /// Maximum text files for free users
  ///
  /// In en, this message translates to:
  /// **'• Text files'**
  String get maxTextFiles;

  /// Maximum handwriting files for free users
  ///
  /// In en, this message translates to:
  /// **'• Handwriting files'**
  String get maxHandwritingFiles;

  /// Maximum limit for littens
  ///
  /// In en, this message translates to:
  /// **'Max 5'**
  String get maxLittensLimit;

  /// Maximum limit for recording files
  ///
  /// In en, this message translates to:
  /// **'Max 10'**
  String get maxRecordingFilesLimit;

  /// Maximum limit for text files
  ///
  /// In en, this message translates to:
  /// **'Max 5'**
  String get maxTextFilesLimit;

  /// Maximum limit for handwriting files
  ///
  /// In en, this message translates to:
  /// **'Max 5'**
  String get maxHandwritingFilesLimit;

  /// Upgrade to standard plan dialog title
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Standard Plan?'**
  String get upgradeToStandard;

  /// Upgrade benefits description
  ///
  /// In en, this message translates to:
  /// **'• Remove ads\n• Unlimited littens and files\n• \$4.99/month'**
  String get upgradeBenefits;

  /// Upgrade success message
  ///
  /// In en, this message translates to:
  /// **'Upgraded to Standard Plan! (Simulation)'**
  String get upgradedToStandard;

  /// Theme selection dialog title
  ///
  /// In en, this message translates to:
  /// **'Select Theme'**
  String get selectTheme;

  /// Language selection dialog title
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// Total files count
  ///
  /// In en, this message translates to:
  /// **'Total files'**
  String get totalFiles;

  /// Message when no litten is selected
  ///
  /// In en, this message translates to:
  /// **'Please select a Litten'**
  String get noLittenSelected;

  /// Description when no litten is selected
  ///
  /// In en, this message translates to:
  /// **'To start listening, first select or create a Litten from the Home tab.'**
  String get selectLittenFirst;

  /// Button to go to home tab
  ///
  /// In en, this message translates to:
  /// **'Go to Home'**
  String get goToHome;

  /// Title when no audio files exist
  ///
  /// In en, this message translates to:
  /// **'No audio files yet'**
  String get noAudioFilesYet;

  /// Description to start first recording
  ///
  /// In en, this message translates to:
  /// **'Click the button below to start your first recording'**
  String get startFirstRecording;

  /// Message to select litten first
  ///
  /// In en, this message translates to:
  /// **'Please select or create a Litten first.'**
  String get selectLittenFirstMessage;

  /// Message when recording is stopped and saved
  ///
  /// In en, this message translates to:
  /// **'Recording stopped and file saved.'**
  String get recordingStoppedAndSaved;

  /// Message when recording starts
  ///
  /// In en, this message translates to:
  /// **'Recording started.'**
  String get recordingStarted;

  /// Message when recording fails
  ///
  /// In en, this message translates to:
  /// **'Failed to start recording. Please check permissions.'**
  String get recordingFailed;

  /// Message when audio playback fails
  ///
  /// In en, this message translates to:
  /// **'Playback failed.'**
  String get playbackFailed;

  /// Delete file dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete File'**
  String get deleteFile;

  /// Confirm delete file message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the file {fileName}?'**
  String confirmDeleteFile(String fileName);

  /// Message when file is deleted
  ///
  /// In en, this message translates to:
  /// **'File deleted.'**
  String get fileDeleted;

  /// Playback speed selection dialog title
  ///
  /// In en, this message translates to:
  /// **'Select Playback Speed'**
  String get selectPlaybackSpeed;

  /// Playback speed tooltip
  ///
  /// In en, this message translates to:
  /// **'Playback Speed'**
  String get playbackSpeed;

  /// Recording in progress text
  ///
  /// In en, this message translates to:
  /// **'Recording...'**
  String get recordingInProgress;

  /// Created date label
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get created;

  /// Title input label
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// Create button
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Message when title is empty
  ///
  /// In en, this message translates to:
  /// **'Please enter a title.'**
  String get pleaseEnterTitle;

  /// Message when litten is created
  ///
  /// In en, this message translates to:
  /// **'{title} litten has been created.'**
  String littenCreated(String title);

  /// Error label
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Rename litten dialog title
  ///
  /// In en, this message translates to:
  /// **'Rename Litten'**
  String get renameLitten;

  /// New name input label
  ///
  /// In en, this message translates to:
  /// **'New Name'**
  String get newName;

  /// Change button
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// Message when litten is renamed
  ///
  /// In en, this message translates to:
  /// **'Litten name has been changed to \'{newName}\'.'**
  String littenRenamed(String newName);

  /// Delete litten dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Litten'**
  String get deleteLitten;

  /// Confirm delete litten message
  ///
  /// In en, this message translates to:
  /// **'\'{title}\' litten will be deleted.\n\nThis action cannot be undone and all related files will be deleted together.'**
  String confirmDeleteLitten(String title);

  /// Message for free user limit
  ///
  /// In en, this message translates to:
  /// **'Free users can only create up to 5 littens. Upgrade to create unlimited!'**
  String get freeUserLimitMessage;

  /// Message when litten is deleted
  ///
  /// In en, this message translates to:
  /// **'{title} litten has been deleted.'**
  String littenDeleted(String title);

  /// Confirm delete litten message content
  ///
  /// In en, this message translates to:
  /// **'\'{title}\' litten will be deleted.\n\nThis action cannot be undone and all related files will be deleted together.'**
  String confirmDeleteLittenMessage(String title);

  /// Default litten title for new users
  ///
  /// In en, this message translates to:
  /// **'Default Litten'**
  String get defaultLitten;

  /// Lecture litten title for new users
  ///
  /// In en, this message translates to:
  /// **'Lecture'**
  String get lecture;

  /// Meeting litten title for new users
  ///
  /// In en, this message translates to:
  /// **'Meeting'**
  String get meeting;

  /// Description for default litten
  ///
  /// In en, this message translates to:
  /// **'Default space for files created without selecting a litten.'**
  String get defaultLittenDescription;

  /// Description for lecture litten
  ///
  /// In en, this message translates to:
  /// **'Store files related to lectures here.'**
  String get lectureDescription;

  /// Description for meeting litten
  ///
  /// In en, this message translates to:
  /// **'Store files related to meetings here.'**
  String get meetingDescription;

  /// Language selection description in onboarding
  ///
  /// In en, this message translates to:
  /// **'Please select the language to use in the app'**
  String get selectLanguageDescription;

  /// Theme recommendation message in onboarding
  ///
  /// In en, this message translates to:
  /// **'A recommended theme has been automatically selected based on your chosen language'**
  String get themeRecommendationMessage;

  /// Recommended label for themes
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get recommended;

  /// Previous button in onboarding
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// Next button in onboarding
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// Get started button in onboarding
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// Welcome page description in onboarding
  ///
  /// In en, this message translates to:
  /// **'Smart note app that integrates\nlisten, write, and draw'**
  String get welcomeDescription;

  /// Listen feature title
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get listen;

  /// Listen feature description
  ///
  /// In en, this message translates to:
  /// **'Voice recording and playback'**
  String get listenDescription;

  /// Write feature title
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get write;

  /// Write feature description
  ///
  /// In en, this message translates to:
  /// **'Text creation and editing'**
  String get writeDescription;

  /// Draw feature title
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get draw;

  /// Draw feature description
  ///
  /// In en, this message translates to:
  /// **'Handwriting on images'**
  String get drawDescription;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'bn',
    'de',
    'en',
    'es',
    'fa',
    'fr',
    'ha',
    'hi',
    'id',
    'it',
    'ja',
    'ko',
    'mr',
    'ms',
    'nl',
    'pl',
    'ps',
    'pt',
    'ro',
    'ru',
    'sw',
    'ta',
    'te',
    'th',
    'tl',
    'tr',
    'uk',
    'ur',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'bn':
      return AppLocalizationsBn();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fa':
      return AppLocalizationsFa();
    case 'fr':
      return AppLocalizationsFr();
    case 'ha':
      return AppLocalizationsHa();
    case 'hi':
      return AppLocalizationsHi();
    case 'id':
      return AppLocalizationsId();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'mr':
      return AppLocalizationsMr();
    case 'ms':
      return AppLocalizationsMs();
    case 'nl':
      return AppLocalizationsNl();
    case 'pl':
      return AppLocalizationsPl();
    case 'ps':
      return AppLocalizationsPs();
    case 'pt':
      return AppLocalizationsPt();
    case 'ro':
      return AppLocalizationsRo();
    case 'ru':
      return AppLocalizationsRu();
    case 'sw':
      return AppLocalizationsSw();
    case 'ta':
      return AppLocalizationsTa();
    case 'te':
      return AppLocalizationsTe();
    case 'th':
      return AppLocalizationsTh();
    case 'tl':
      return AppLocalizationsTl();
    case 'tr':
      return AppLocalizationsTr();
    case 'uk':
      return AppLocalizationsUk();
    case 'ur':
      return AppLocalizationsUr();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

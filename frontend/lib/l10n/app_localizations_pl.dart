// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get appTitle => 'Litten';

  @override
  String get homeTitle => 'Główna';

  @override
  String get recordingTitle => 'Słuchaj';

  @override
  String get writingTitle => 'Notatka';

  @override
  String get settingsTitle => 'Ustawienia';

  @override
  String get createLitten => 'Utwórz Litten';

  @override
  String get emptyLittenTitle => 'Utwórz lub wybierz Litten';

  @override
  String get emptyLittenDescription =>
      'Użyj przycisku \'Utwórz Litten\' poniżej, aby rozpocząć swoją pierwszą notatkę';

  @override
  String get startRecording => 'Rozpocznij nagrywanie';

  @override
  String get stopRecording => 'Zatrzymaj nagrywanie';

  @override
  String get recording => 'Nagrywanie...';

  @override
  String get textWriting => 'Pisanie tekstu';

  @override
  String get handwriting => 'Pismo ręczne';

  @override
  String get save => 'Zapisz';

  @override
  String get delete => 'Usuń';

  @override
  String get upgrade => 'Ulepsz';

  @override
  String get removeAds => 'Usuń reklamy';

  @override
  String get freeVersion => 'Darmowa';

  @override
  String get standardVersion => 'Standardowa';

  @override
  String get premiumVersion => 'Premium';

  @override
  String get theme => 'Motyw';

  @override
  String get language => 'Język';

  @override
  String get classicBlue => 'Klasyczny niebieski';

  @override
  String get darkMode => 'Tryb ciemny';

  @override
  String get natureGreen => 'Zieleń natury';

  @override
  String get sunsetOrange => 'Pomarańcz zachodu';

  @override
  String get monochromeGrey => 'Szary monochromatyczny';

  @override
  String get accountAndSubscription => 'Account & Subscription';

  @override
  String get userStatus => 'User Status';

  @override
  String get usageStatistics => 'Usage Statistics';

  @override
  String get appSettings => 'App Settings';

  @override
  String get startScreen => 'Start Screen';

  @override
  String get recordingSettings => 'Recording Settings';

  @override
  String get maxRecordingTime => 'Max Recording Time';

  @override
  String get audioQuality => 'Audio Quality';

  @override
  String get writingSettings => 'Writing Settings';

  @override
  String get autoSaveInterval => 'Auto Save Interval';

  @override
  String get defaultFont => 'Default Font';

  @override
  String get freeWithAds => 'Free (with ads)';

  @override
  String get standardMonthly => 'Standard (\$4.99/month)';

  @override
  String get premiumMonthly => 'Premium (\$9.99/month)';

  @override
  String get littensCount => 'littens';

  @override
  String get filesCount => 'files';

  @override
  String get removeAdsAndUnlimited => 'Remove ads and unlimited features';

  @override
  String get maxRecordingTimeValue => '1 hour';

  @override
  String get standardQuality => 'Standard';

  @override
  String get autoSaveIntervalValue => '3 minutes';

  @override
  String get systemFont => 'System Font';

  @override
  String get appVersion => 'Litten v1.0.0';

  @override
  String get appDescription => 'Cross-platform integrated note app';

  @override
  String get close => 'Close';

  @override
  String get cancel => 'Cancel';

  @override
  String get addSchedule => 'Add Schedule';

  @override
  String get selectDate => 'Select Date';

  @override
  String get selectStartTime => 'Select Start Time';

  @override
  String get selectEndTime => 'Select End Time';

  @override
  String get startTime => 'Start Time';

  @override
  String get endTime => 'End Time';

  @override
  String get date => 'Date';

  @override
  String get notes => 'Notes';

  @override
  String get scheduleNotesHint => 'Enter notes for this schedule (optional)';

  @override
  String get confirm => 'Confirm';

  @override
  String get enableNotifications => 'Enable Notifications';

  @override
  String get frequency => 'Frequency';

  @override
  String get enabledNotifications => 'Enabled Notifications';

  @override
  String get notifications => 'Notifications';

  @override
  String get noNotifications => 'No notifications';

  @override
  String get clearAll => 'Clear All';

  @override
  String get freeUserLimits => 'Free user limits:';

  @override
  String get maxLittens => '• Litten';

  @override
  String get maxRecordingFiles => '• Recording files';

  @override
  String get maxTextFiles => '• Text files';

  @override
  String get maxHandwritingFiles => '• Handwriting files';

  @override
  String get maxLittensLimit => 'Max 5';

  @override
  String get maxRecordingFilesLimit => 'Max 10';

  @override
  String get maxTextFilesLimit => 'Max 5';

  @override
  String get maxHandwritingFilesLimit => 'Max 5';

  @override
  String get upgradeToStandard => 'Upgrade to Standard Plan?';

  @override
  String get upgradeBenefits =>
      '• Remove ads\n• Unlimited littens and files\n• \$4.99/month';

  @override
  String get upgradedToStandard => 'Upgraded to Standard Plan! (Simulation)';

  @override
  String get selectTheme => 'Select Theme';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get totalFiles => 'Total files';

  @override
  String get noLittenSelected => 'Please select a Litten';

  @override
  String get selectLittenFirst =>
      'To start listening, first select or create a Litten from the Home tab.';

  @override
  String get goToHome => 'Go to Home';

  @override
  String get noAudioFilesYet => 'No audio files yet';

  @override
  String get startFirstRecording =>
      'Click the button below to start your first recording';

  @override
  String get selectLittenFirstMessage =>
      'Please select or create a Litten first.';

  @override
  String get recordingStoppedAndSaved => 'Recording stopped and file saved.';

  @override
  String get recordingStarted => 'Recording started.';

  @override
  String get recordingFailed =>
      'Failed to start recording. Please check permissions.';

  @override
  String get playbackFailed => 'Playback failed.';

  @override
  String get deleteFile => 'Delete File';

  @override
  String confirmDeleteFile(String fileName) {
    return 'Are you sure you want to delete the file $fileName?';
  }

  @override
  String get fileDeleted => 'File deleted.';

  @override
  String get selectPlaybackSpeed => 'Select Playback Speed';

  @override
  String get playbackSpeed => 'Playback Speed';

  @override
  String get recordingInProgress => 'Recording...';

  @override
  String get created => 'Created';

  @override
  String get title => 'Title';

  @override
  String get create => 'Create';

  @override
  String get pleaseEnterTitle => 'Please enter a title.';

  @override
  String littenCreated(String title) {
    return '$title litten has been created.';
  }

  @override
  String get error => 'Error';

  @override
  String get renameLitten => 'Rename Litten';

  @override
  String get newName => 'New Name';

  @override
  String get change => 'Change';

  @override
  String littenRenamed(String newName) {
    return 'Litten name has been changed to \'$newName\'.';
  }

  @override
  String get deleteLitten => 'Delete Litten';

  @override
  String confirmDeleteLitten(String title) {
    return '\'$title\' litten will be deleted.\n\nThis action cannot be undone and all related files will be deleted together.';
  }

  @override
  String get freeUserLimitMessage =>
      'Free users can only create up to 5 littens. Upgrade to create unlimited!';

  @override
  String littenDeleted(String title) {
    return '$title litten has been deleted.';
  }

  @override
  String confirmDeleteLittenMessage(String title) {
    return '\'$title\' litten will be deleted.\n\nThis action cannot be undone and all related files will be deleted together.';
  }

  @override
  String get defaultLitten => 'Default Litten';

  @override
  String get lecture => 'Lecture';

  @override
  String get meeting => 'Meeting';

  @override
  String get defaultLittenDescription =>
      'Default space for files created without selecting a litten.';

  @override
  String get lectureDescription => 'Store files related to lectures here.';

  @override
  String get meetingDescription => 'Store files related to meetings here.';

  @override
  String get selectLanguageDescription =>
      'Please select the language to use in the app';

  @override
  String get themeRecommendationMessage =>
      'A recommended theme has been automatically selected based on your chosen language';

  @override
  String get recommended => 'Recommended';

  @override
  String get previous => 'Previous';

  @override
  String get next => 'Next';

  @override
  String get getStarted => 'Get Started';

  @override
  String get welcomeDescription =>
      'Smart note app that integrates\nlisten, write, and draw';

  @override
  String get listen => 'Listen';

  @override
  String get listenDescription => 'Voice recording and playback';

  @override
  String get write => 'Write';

  @override
  String get writeDescription => 'Text creation and editing';

  @override
  String get draw => 'Draw';

  @override
  String get drawDescription => 'Handwriting on images';

  @override
  String get selectSubscriptionPlan => 'Select Subscription Plan';

  @override
  String get subscriptionDescription => 'Choose your preferred plan';

  @override
  String get unlimitedLittens => 'Unlimited littens';

  @override
  String get unlimitedFiles => 'Unlimited files';

  @override
  String get allStandardFeatures => 'All Standard features';

  @override
  String get cloudSync => 'Cloud sync';

  @override
  String get multiDeviceSupport => 'Multi-device support';

  @override
  String get comingSoon => 'Coming Soon';

  @override
  String get login => 'Login';

  @override
  String get loginComingSoon => 'Login feature coming soon';

  @override
  String get welcomeBack => 'Welcome Back';

  @override
  String get loginDescription =>
      'Login to your account to securely store files in the cloud';

  @override
  String get email => 'Email';

  @override
  String get emailHint => 'example@email.com';

  @override
  String get emailRequired => 'Please enter your email';

  @override
  String get emailInvalid => 'Invalid email format';

  @override
  String get password => 'Password';

  @override
  String get passwordHint => 'Enter your password';

  @override
  String get passwordRequired => 'Please enter your password';

  @override
  String get passwordTooShort => 'Password must be at least 6 characters';

  @override
  String get forgotPassword => 'Forgot your password?';

  @override
  String get orLoginWith => 'Or login with';

  @override
  String get loginWithGoogle => 'Login with Google';

  @override
  String get loginWithApple => 'Login with Apple';

  @override
  String get noAccount => 'Don\'t have an account?';

  @override
  String get signUp => 'Sign Up';

  @override
  String get manageSubscription => 'Manage Subscription';

  @override
  String get currentPlan => 'Current Plan';

  @override
  String get availablePlans => 'Available Plans';

  @override
  String get subscriptionChanged => 'Subscription changed';

  @override
  String get signUpComingSoon => 'Sign up feature coming soon';

  @override
  String get createAccount => 'Create Account';

  @override
  String get signUpDescription => 'Create your free account and get started';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get confirmPasswordHint => 'Re-enter your password';

  @override
  String get confirmPasswordRequired => 'Please confirm your password';

  @override
  String get passwordMismatch => 'Passwords do not match';

  @override
  String get orSignUpWith => 'Or sign up with';

  @override
  String get signUpWithGoogle => 'Sign up with Google';

  @override
  String get signUpWithApple => 'Sign up with Apple';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get signUpEmailNote =>
      'Please provide your own email for smooth service usage';

  @override
  String get forgotPasswordDescription =>
      'Enter your registered email address and\nwe\'ll send you a password reset link';

  @override
  String get sendResetLink => 'Send Reset Link';

  @override
  String get backToLogin => 'Back to Login';

  @override
  String get emailSent => 'Email Sent';

  @override
  String resetEmailSentDescription(String email) {
    return 'We\'ve sent a password reset link to $email.\n\nPlease check your email and click the link\nto set a new password.';
  }

  @override
  String get resetEmailNote =>
      'If you don\'t see the email, please check your spam folder';

  @override
  String get resendEmail => 'Resend Email';

  @override
  String get changePassword => 'Change Password';

  @override
  String get changePasswordDescription => 'Change your account password';

  @override
  String get changePasswordInfo =>
      'Please change your password regularly for security';

  @override
  String get currentPassword => 'Current Password';

  @override
  String get currentPasswordHint => 'Enter your current password';

  @override
  String get currentPasswordRequired => 'Please enter your current password';

  @override
  String get newPassword => 'New Password';

  @override
  String get newPasswordHint => 'Enter your new password';

  @override
  String get newPasswordRequired => 'Please enter your new password';

  @override
  String get newPasswordSameAsCurrent =>
      'New password is the same as current password';

  @override
  String get confirmNewPassword => 'Confirm New Password';

  @override
  String get confirmNewPasswordHint => 'Re-enter your new password';

  @override
  String get passwordChanged => 'Password has been changed';

  @override
  String get passwordChangeComingSoon => 'Password change feature coming soon';
}

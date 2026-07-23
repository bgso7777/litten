// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Litten';

  @override
  String get homeTitle => 'ホーム';

  @override
  String get recordingTitle => '聴く';

  @override
  String get writingTitle => 'ノート';

  @override
  String get settingsTitle => '設定';

  @override
  String get createLitten => 'リトゥン作成';

  @override
  String get emptyLittenTitle => 'リッテンを作成または選択';

  @override
  String get emptyLittenDescription => '下の「リッテンを作成」ボタンを使用して最初のノートを開始してください';

  @override
  String get startRecording => '録音開始';

  @override
  String get stopRecording => '録音停止';

  @override
  String get recording => '録音中...';

  @override
  String get textWriting => 'テキスト入力';

  @override
  String get handwriting => '手書き';

  @override
  String get save => '保存';

  @override
  String get delete => '削除';

  @override
  String get upgrade => 'アップグレード';

  @override
  String get removeAds => '広告を削除';

  @override
  String get freeVersion => '無料';

  @override
  String get standardVersion => 'スタンダード';

  @override
  String get premiumVersion => 'プレミアム';

  @override
  String get theme => 'テーマ';

  @override
  String get language => '言語';

  @override
  String get classicBlue => 'クラシックブルー';

  @override
  String get darkMode => 'ダークモード';

  @override
  String get natureGreen => 'ネイチャーグリーン';

  @override
  String get sunsetOrange => 'サンセットオレンジ';

  @override
  String get monochromeGrey => 'モノクロームグレー';

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
  String get maxRecordingTimeValue => 'Unlimited';

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
  String get close => '閉じる';

  @override
  String get cancel => 'キャンセル';

  @override
  String get addSchedule => '予定を追加';

  @override
  String get selectDate => '日付を選択';

  @override
  String get selectStartTime => 'Select Start Time';

  @override
  String get selectEndTime => 'Select End Time';

  @override
  String get startTime => '開始時刻';

  @override
  String get endTime => '終了時刻';

  @override
  String get date => '日付';

  @override
  String get notes => 'メモ';

  @override
  String get scheduleNotesHint => 'Enter notes for this schedule (optional)';

  @override
  String get confirm => '確認';

  @override
  String get enableNotifications => '通知を有効にする';

  @override
  String get frequency => '頻度';

  @override
  String get enabledNotifications => 'Enabled Notifications';

  @override
  String get notifications => '通知';

  @override
  String get noNotifications => '通知なし';

  @override
  String get clearAll => 'すべて消去';

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
  String get selectTheme => 'テーマを選択';

  @override
  String get selectLanguage => '言語を選択';

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
  String get deleteFile => 'ファイルを削除';

  @override
  String confirmDeleteFile(String fileName) {
    return 'Are you sure you want to delete the file $fileName?';
  }

  @override
  String get fileDeleted => 'ファイルを削除しました';

  @override
  String get selectPlaybackSpeed => 'Select Playback Speed';

  @override
  String get playbackSpeed => 'Playback Speed';

  @override
  String get recordingInProgress => 'Recording...';

  @override
  String get created => 'Created';

  @override
  String get title => 'タイトル';

  @override
  String get create => '作成';

  @override
  String get pleaseEnterTitle => 'タイトルを入力してください';

  @override
  String littenCreated(String title) {
    return '$title litten has been created.';
  }

  @override
  String get error => 'エラー';

  @override
  String get renameLitten => 'Rename Litten';

  @override
  String get newName => 'New Name';

  @override
  String get change => '変更';

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
  String get selectLanguageDescription => 'アプリで使用する言語を選択してください';

  @override
  String get themeRecommendationMessage => '選択した言語に推奨されるテーマが自動的に選択されました';

  @override
  String get recommended => '推奨';

  @override
  String get previous => '前へ';

  @override
  String get next => '次へ';

  @override
  String get getStarted => '始める';

  @override
  String get welcomeDescription => 'リスニング、ライティング、描画を統合した\nスマートノートアプリ';

  @override
  String get listen => 'リスニング';

  @override
  String get listenDescription => '音声録音と再生';

  @override
  String get write => 'ライティング';

  @override
  String get writeDescription => 'テキスト作成と編集';

  @override
  String get draw => '描画';

  @override
  String get drawDescription => '画像上での手書き入力';

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
  String get login => 'ログイン';

  @override
  String get loginComingSoon => 'Login feature coming soon';

  @override
  String get welcomeBack => 'Welcome Back';

  @override
  String get loginDescription =>
      'Login to your account to securely store files in the cloud';

  @override
  String get email => 'メール';

  @override
  String get emailHint => 'example@email.com';

  @override
  String get emailRequired => 'Please enter your email';

  @override
  String get emailInvalid => 'Invalid email format';

  @override
  String get password => 'パスワード';

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
  String get signUp => '新規登録';

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

  @override
  String get textTab => 'テキスト';

  @override
  String get handwritingTab => '手書き';

  @override
  String get audioTab => '録音';

  @override
  String get browserTab => '検索';

  @override
  String get subscription => 'サブスクリプション';

  @override
  String get subscriptionPlan => 'Subscription Plan';

  @override
  String get free => '無料';

  @override
  String get standard => 'スタンダード';

  @override
  String get premium => 'プレミアム';

  @override
  String get account => 'アカウント';

  @override
  String get loggedOut => 'Logged out';

  @override
  String get loggedIn => 'Logged in';

  @override
  String get logout => 'ログアウト';

  @override
  String get logoutConfirmTitle => 'Logout';

  @override
  String get logoutConfirmMessage => 'Are you sure you want to logout?';

  @override
  String get logoutConfirmPremiumMessage =>
      'If you logout while on Premium, you won\'t be able to share files.\nAre you sure you want to logout?';

  @override
  String get logoutSuccess => 'Logged out successfully.';

  @override
  String logoutFailed(String error) {
    return 'Logout failed: $error';
  }

  @override
  String get loginToAccount => 'Login to your account';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountSubtitle => 'Permanently delete your account';

  @override
  String get deleteAccountTitle => 'Delete Account';

  @override
  String get deleteAccountConfirm =>
      'Are you sure you want to delete your account?';

  @override
  String get deleteAccountWarningTitle => 'Please note the following:';

  @override
  String get deleteAccountWarning1 => '• All data will be permanently deleted';

  @override
  String get deleteAccountWarning2 =>
      '• All files on the server will be deleted';

  @override
  String get deleteAccountWarning3 => '• Account recovery is not possible';

  @override
  String get deleteAccountWarning4 =>
      '• Subscription will be automatically cancelled';

  @override
  String get deleteAccountWarning5 =>
      '• Cells you created are deleted, and shares you sent are marked as \'withdrawn\' to others';

  @override
  String get deleteAccountWarning6 =>
      '• Schedules synced to the server are deleted (local schedules are kept)';

  @override
  String get deleteAccountButton => 'Delete Account';

  @override
  String get deleteAccountFinalConfirmTitle => 'Final Confirmation';

  @override
  String get deleteAccountFinalConfirmMessage =>
      'Are you sure you want to delete your account?\nThis action cannot be undone.';

  @override
  String get deleteAccountFinalConfirmHint =>
      'Press \"Confirm Delete\" to proceed';

  @override
  String get deleteAccountConfirmButton => 'Confirm Delete';

  @override
  String get deleteAccountProgress => 'Deleting account...';

  @override
  String get deleteAccountSuccess =>
      'Account deleted. Local files are preserved and plan changed to Free.';

  @override
  String deleteAccountFailed(String error) {
    return 'Failed to delete account: $error';
  }

  @override
  String get selectPlan => 'プランを選択';

  @override
  String get planFree => 'Free';

  @override
  String get planStandard => 'Standard';

  @override
  String get planPremium => 'Premium';

  @override
  String get planFreeDescription => 'With ads, limited to 5 littens';

  @override
  String get planStandardDescription => '\$4.99/month - No ads, unlimited';

  @override
  String get planPremiumDescription => '\$9.99/month - Cloud sync';

  @override
  String get planPremiumDescriptionLoginRequired =>
      '\$9.99/month - Cloud sync (Login required)';

  @override
  String planChanged(String plan) {
    return 'Changed to $plan plan';
  }

  @override
  String get planSelect => 'Select';

  @override
  String get planCurrent => 'Current';

  @override
  String get premiumRequiresLogin => 'Premium requires login';

  @override
  String get changePasswordSubtitle => 'Change your account password';

  @override
  String get editSchedule => '予定を編集';

  @override
  String get scheduleTitle => '予定タイトル';

  @override
  String get addScheduleTab => '予定追加';

  @override
  String get notificationSettingTab => '通知';

  @override
  String get setScheduleFirst => 'Please set a schedule first';

  @override
  String get setScheduleToEnableNotification =>
      'Set a schedule in the Add Schedule tab\nto enable notification settings';

  @override
  String get startTimeCannotBeAfterEndTime =>
      'Start time cannot be after end time.';

  @override
  String littenUpdated(String title) {
    return '$title has been updated.';
  }

  @override
  String get subscriptionPlanTitle => 'Subscription Plan';

  @override
  String get createSchedule => 'Create Schedule';

  @override
  String littenAlreadyExists(String dateStr, String title) {
    return 'A litten with the same name already exists on $dateStr: \"$title\"';
  }

  @override
  String get noTextFiles => 'No text files';

  @override
  String get noHandwritingFiles => 'No handwriting files';

  @override
  String get enterSearchTerm => 'Enter search term...';

  @override
  String get noSearchHistory => 'No search history yet';

  @override
  String get trySearching => 'Try entering a search term';

  @override
  String dragTabHere(String position) {
    return 'Drag tab here ($position)';
  }

  @override
  String get adUpgradeStandard => 'Standard Plan - \$4.99/month';

  @override
  String get adUpgradePremium => 'Premium Plan - \$9.99/month';

  @override
  String get adBenefitRemoveAds => '✓ Remove ads';

  @override
  String get adBenefitUnlimitedLittens => '✓ Unlimited littens';

  @override
  String get adBenefitUnlimitedFiles => '✓ Unlimited files';

  @override
  String get adBenefitAllStandard => '✓ All Standard plan features';

  @override
  String get adBenefitCloudSync => '✓ Cloud synchronization';

  @override
  String get adBenefitLargeFiles => '✓ Large file support';

  @override
  String get adBenefitPrioritySupport => '✓ Priority customer support';

  @override
  String get standardPlanUpgraded => 'Upgraded to Standard plan! (Simulation)';

  @override
  String get adLoadingError => 'Unable to load ad';

  @override
  String get adLoading => 'Loading ad...';

  @override
  String get positionTopLeft => 'Top Left';

  @override
  String get positionTopRight => 'Top Right';

  @override
  String get positionBottomLeft => 'Bottom Left';

  @override
  String get positionBottomRight => 'Bottom Right';

  @override
  String loginFailed(String error) {
    return 'Login failed: $error';
  }

  @override
  String get calendarTab => 'カレンダー';

  @override
  String get noteOption => 'ノート';

  @override
  String get quizLabel => 'クイズ';

  @override
  String quizCount(int count) {
    return 'Quiz $count';
  }

  @override
  String get noVoiceMemos => 'No voice memos.\nTap below to start.';

  @override
  String get noFilesPrompt => 'No files.\nTap below to add.';

  @override
  String get notSynced => 'Not synced';

  @override
  String get menuTooltip => 'Menu';

  @override
  String get editLabel => '編集';

  @override
  String get viewSummary => '要約を表示';

  @override
  String get noSummary => '要約なし';

  @override
  String get share => '共有';

  @override
  String characterCount(int count) {
    return '$count chars';
  }

  @override
  String pageCount(int count) {
    return '$count pages';
  }

  @override
  String get summaryUnsupported => 'Summary unavailable';

  @override
  String get memoLabel => 'メモ';

  @override
  String recordingStatus(String time) {
    return 'Recording... $time';
  }

  @override
  String get voiceMemoLabel => 'ボイスメモ';

  @override
  String get allFilesLabel => 'All';

  @override
  String get sttMemoLabel => 'Voice Memo';

  @override
  String get noneLabel => 'None';

  @override
  String get visibleAreas => 'Visible Areas';

  @override
  String get noteTabView => 'Note Tab View';

  @override
  String get allTabFab => 'All Tab Button';

  @override
  String get showAds => 'Show Ads';

  @override
  String get paidPlanNoAds => 'Paid plan - ads off by default';

  @override
  String get freeShowAds => 'Show banner ad';

  @override
  String get availableInPaidPlans => 'Available in Standard & Premium plans';

  @override
  String get loginForCloudSync => 'Login for cloud sync';

  @override
  String get topLeftOnly => 'Top left only';

  @override
  String topLeftWith(String areas) {
    return 'Top left + $areas';
  }

  @override
  String get rename => '名前を変更';

  @override
  String get fileNameHint => 'File name';

  @override
  String get noQuizItems => 'Extract from summaries\nand they\'ll appear here';

  @override
  String cloudSyncPlanChanged(String plan) {
    return 'Changed to $plan plan.\n\nTo use cloud sync, please login at Settings > Account.';
  }

  @override
  String get viewScheduleList => '予定リストを表示';

  @override
  String get startDate => '開始日';

  @override
  String get endDate => '終了日';

  @override
  String get notSelected => 'Not selected';

  @override
  String durationMinutes(int minutes) {
    return 'Total $minutes min';
  }

  @override
  String durationHours(int hours) {
    return 'Total $hours hr';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return 'Total $hours hr $minutes min';
  }

  @override
  String get selectWeekdays => '曜日を選択';

  @override
  String get daySun => '日';

  @override
  String get dayMon => '月';

  @override
  String get dayTue => '火';

  @override
  String get dayWed => '水';

  @override
  String get dayThu => '木';

  @override
  String get dayFri => '金';

  @override
  String get daySat => '土';

  @override
  String get renameFile => 'Rename File';

  @override
  String get newFileName => 'New file name';

  @override
  String get fileNameInputHint => 'Enter file name';

  @override
  String confirmDeleteFileMessage(String name) {
    return 'Delete \"$name\"?\n\nThis action cannot be undone.';
  }

  @override
  String fileRenameSuccessName(String name) {
    return 'File renamed to \"$name\".';
  }

  @override
  String get fileRenameSuccess => 'File renamed.';

  @override
  String fileRenameFailed(String error) {
    return 'Failed to rename file: $error';
  }

  @override
  String fileDeleteSuccess(String name) {
    return '$name deleted.';
  }

  @override
  String fileDeleteFailed(String error) {
    return 'Failed to delete file: $error';
  }

  @override
  String get planChange => 'Plan Change';

  @override
  String get changeAndLogout => 'Change & Logout';

  @override
  String get allTabFixed => 'All Tab (fixed)';

  @override
  String downgradeFromPremiumMessage(String plan) {
    return 'Switching from Premium to $plan plan will stop cloud sync and automatically log you out.\n\nDo you want to continue?';
  }

  @override
  String planChangedAndLoggedOut(String plan) {
    return 'Changed to $plan plan. Logged out.';
  }

  @override
  String get voiceMemoSettings => 'Voice Memo Settings';

  @override
  String get transcriptionLanguage => 'Transcription Language';

  @override
  String get summaryLanguage => 'Summary Language';

  @override
  String get summaryLevel => 'Summary Level';

  @override
  String get summaryLevelOneLiner => 'One-line Summary';

  @override
  String get summaryLevelBrief => 'Brief Summary';

  @override
  String get summaryLevelNormal => 'Normal Summary';

  @override
  String get summaryLevelDetailed => 'Detailed Summary';

  @override
  String get summaryLevelFull => 'Nearly Full';

  @override
  String get summaryLevelDesc1 => 'Key topics and conclusions only · ~10%';

  @override
  String get summaryLevelDesc2 => 'Main points and key discussions · ~25%';

  @override
  String get summaryLevelDesc3 => 'Practical flow and design intent · ~40–50%';

  @override
  String get summaryLevelDesc4 => 'Most of the discussion flow · ~70%';

  @override
  String get summaryLevelDesc5 => 'Maximum context preserved · ~90%';

  @override
  String get autoSummaryInterval => 'Auto Summary Interval';

  @override
  String intervalMin(int n) {
    return '${n}min';
  }

  @override
  String get intervalOnStop => 'On Stop';

  @override
  String get intervalOff => 'Off';

  @override
  String get startButton => 'Start';

  @override
  String get aiSummary => 'AI要約';

  @override
  String get summarizing => '要約中...';

  @override
  String autoSummaryEveryMinutes(int minutes) {
    return 'Auto summary every $minutes min after recording starts.';
  }

  @override
  String get autoSummaryOnStop => 'Auto summary when recording stops.';

  @override
  String get autoSummaryDisabled => 'Auto summary is disabled.';

  @override
  String summaryFailed(String error) {
    return 'Summary failed: $error';
  }

  @override
  String get summaryLevelShortOneLiner => '1-line';

  @override
  String get summaryLevelShortBrief => 'Brief';

  @override
  String get summaryLevelShortNormal => 'Normal';

  @override
  String get summaryLevelShortDetailed => 'Detail';

  @override
  String get summaryLevelShortFull => 'Full';

  @override
  String get summaryHistory => 'Summary History';

  @override
  String get targetLanguage => 'Target Language';

  @override
  String get aiSummarizing => 'AI is summarizing...';

  @override
  String get summarize => '要約する';

  @override
  String get summarizeAgain => 'Re-summarize';

  @override
  String get summaryAdded => 'Summary added to file.';

  @override
  String summaryAddedWithQuiz(int count) {
    return 'Summary added. $count quiz(s) created.';
  }

  @override
  String summarySaveFailed(String error) {
    return 'Failed to save summary: $error';
  }

  @override
  String get cell => 'セル';

  @override
  String get cellName => 'セル名';

  @override
  String get newCell => '新しいセル';

  @override
  String get noCellsYet =>
      'No Cells yet.\nTap the + button below to create a Cell or share a file.';

  @override
  String get startCell => 'セルを始める';

  @override
  String get cellLoginRequired =>
      'Signing up and logging in is required to use Cells.';

  @override
  String myCell(String name) {
    return 'My Cell: $name';
  }

  @override
  String get createMyCell => '自分のセルを作成';

  @override
  String get myCellDescription =>
      'A Cell you use on your own.\nJot things down freely, like a memo. (multiple allowed)';

  @override
  String get oneToOneCell => '1:1セル';

  @override
  String get aiCell => 'AI Cell';

  @override
  String get aiCellDescription =>
      'Set a topic and chat with AI. It remembers your past conversation when you return.';

  @override
  String get aiCellTopicLabel => 'Chat topic';

  @override
  String get aiCellTopicHint =>
      'e.g. English study, trip planning, coding help';

  @override
  String get aiCellCreate => 'Start AI chat';

  @override
  String get aiCellLoginRequired => 'Log in to use AI Cell.';

  @override
  String get groupCell => 'グループセル';

  @override
  String get myOwnCell => '自分だけのセル';

  @override
  String get createCell => 'セルを作成';

  @override
  String get createNewCell => '新しいセルを作成';

  @override
  String get cellGroupManagement => 'セルグループ管理';

  @override
  String get allowMemberSchedule => 'Members can create schedules';

  @override
  String get allowMemberScheduleHint =>
      'When off, only the owner can create schedules.';
}

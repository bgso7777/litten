// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Litten';

  @override
  String get homeTitle => 'Início';

  @override
  String get recordingTitle => 'Ouvir';

  @override
  String get writingTitle => 'Escrever';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get createLitten => 'Criar Litten';

  @override
  String get emptyLittenTitle => 'Criar ou selecionar Litten';

  @override
  String get emptyLittenDescription =>
      'Use o botão \'Criar Litten\' abaixo para começar sua primeira nota';

  @override
  String get startRecording => 'Iniciar Gravação';

  @override
  String get stopRecording => 'Parar Gravação';

  @override
  String get recording => 'Gravando...';

  @override
  String get textWriting => 'Escrita de Texto';

  @override
  String get handwriting => 'Escrita à Mão';

  @override
  String get save => 'Salvar';

  @override
  String get delete => 'Excluir';

  @override
  String get upgrade => 'Atualizar';

  @override
  String get removeAds => 'Remover Anúncios';

  @override
  String get freeVersion => 'Gratuito';

  @override
  String get standardVersion => 'Padrão';

  @override
  String get premiumVersion => 'Premium';

  @override
  String get theme => 'Tema';

  @override
  String get language => 'Idioma';

  @override
  String get classicBlue => 'Azul Clássico';

  @override
  String get darkMode => 'Modo Escuro';

  @override
  String get natureGreen => 'Verde Natural';

  @override
  String get sunsetOrange => 'Laranja Pôr do Sol';

  @override
  String get monochromeGrey => 'Cinza Monocromático';

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
  String get selectTheme => 'Selecionar tema';

  @override
  String get selectLanguage => 'Selecionar idioma';

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
      'Por favor, selecione o idioma para usar no aplicativo';

  @override
  String get themeRecommendationMessage =>
      'O tema recomendado para o idioma selecionado foi escolhido automaticamente';

  @override
  String get recommended => 'Recomendado';

  @override
  String get previous => 'Anterior';

  @override
  String get next => 'Próximo';

  @override
  String get getStarted => 'Começar';

  @override
  String get welcomeDescription =>
      'App inteligente de notas que integra\nouvir, escrever e desenhar';

  @override
  String get listen => 'Ouvir';

  @override
  String get listenDescription => 'Gravação e reprodução de voz';

  @override
  String get write => 'Escrever';

  @override
  String get writeDescription => 'Criação e edição de texto';

  @override
  String get draw => 'Desenhar';

  @override
  String get drawDescription => 'Escrita à mão em imagens';
}

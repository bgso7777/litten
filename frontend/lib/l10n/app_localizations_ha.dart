// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hausa (`ha`).
class AppLocalizationsHa extends AppLocalizations {
  AppLocalizationsHa([String locale = 'ha']) : super(locale);

  @override
  String get appName => 'Litten';

  @override
  String get home => 'Gida';

  @override
  String get listen => 'Saurara';

  @override
  String get write => 'Rubuta';

  @override
  String get settings => 'Saitunan';

  @override
  String get createNote => 'Kirkiro Litten';

  @override
  String get newNote => 'Sabon Litten';

  @override
  String get title => 'Taken';

  @override
  String get description => 'Bayanin';

  @override
  String get optional => '(Na zaɓi)';

  @override
  String get cancel => 'Soke';

  @override
  String get create => 'Kirkiro';

  @override
  String get delete => 'Share';

  @override
  String get search => 'Nema';

  @override
  String get searchNotes => 'Nemo bayanai...';

  @override
  String get noNotesTitle => 'Kirkiro Litten na farko';

  @override
  String get noNotesSubtitle =>
      'Sarrafa murya, rubutu, da rubutun hannu\na wuri guda mai haɗuwa';

  @override
  String get noSearchResults => 'Babu sakamakon bincike';

  @override
  String noSearchResultsSubtitle(String query) {
    return 'Babu bayanai da suka dace da \"$query\"';
  }

  @override
  String get clearSearch => 'Share binciken';

  @override
  String get deleteNote => 'Share Bayanin';

  @override
  String get deleteNoteConfirm =>
      'Ka tabbata kana son share wannan bayanin?\nDukkan fayiloli za a share tare.';

  @override
  String get noteDeleted => 'An share bayanin';

  @override
  String noteCreated(String title) {
    return 'An kirkiro \'$title\'';
  }

  @override
  String noteSelected(String title) {
    return 'An zaɓi $title';
  }

  @override
  String freeLimitReached(int limit) {
    return 'Sigar kyauta tana ba da izini har zuwa bayanai $limit kawai.';
  }

  @override
  String get upgradeToStandard => 'Inganta zuwa Standard';

  @override
  String get upgradeFeatures =>
      'Inganta zuwa Standard ka sami:\n\n• Kirkiro bayanai mara iyaka\n• Ajiyar fayiloli mara iyaka\n• Cire tallace-tallace\n• Daidaitawar gajimare';

  @override
  String get later => 'Daga baya';

  @override
  String get upgrade => 'Inganta';

  @override
  String get adBannerText => 'Yankin Talla - Cire da ingantawar Standard';

  @override
  String get enterTitle => 'Don Allah shigar da taken';

  @override
  String createNoteFailed(String error) {
    return 'Kirkiro bayanin ya kasa: $error';
  }

  @override
  String deleteNoteFailed(String error) {
    return 'Share bayanin ya kasa: $error';
  }

  @override
  String get upgradeComingSoon => 'Fasalin ingantawa zai samu nan gaba';
}

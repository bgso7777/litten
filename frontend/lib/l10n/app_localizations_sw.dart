// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swahili (`sw`).
class AppLocalizationsSw extends AppLocalizations {
  AppLocalizationsSw([String locale = 'sw']) : super(locale);

  @override
  String get appName => 'Litten';

  @override
  String get home => 'Nyumbani';

  @override
  String get listen => 'Sikiliza';

  @override
  String get write => 'Andika';

  @override
  String get settings => 'Mipangilio';

  @override
  String get createNote => 'Unda Litten';

  @override
  String get newNote => 'Litten Mpya';

  @override
  String get title => 'Kichwa';

  @override
  String get description => 'Maelezo';

  @override
  String get optional => '(Si lazima)';

  @override
  String get cancel => 'Ghairi';

  @override
  String get create => 'Unda';

  @override
  String get delete => 'Futa';

  @override
  String get search => 'Tafuta';

  @override
  String get searchNotes => 'Tafuta notisi...';

  @override
  String get noNotesTitle => 'Unda Litten yako ya kwanza';

  @override
  String get noNotesSubtitle =>
      'Simamia sauti, maandishi, na maandishi ya mkono\nkatika nafasi moja ya ushirikiano';

  @override
  String get noSearchResults => 'Hakuna matokeo ya utafutaji';

  @override
  String noSearchResultsSubtitle(String query) {
    return 'Hakuna notisi zilizopatikana zinazolingana na \"$query\"';
  }

  @override
  String get clearSearch => 'Futa utafutaji';

  @override
  String get deleteNote => 'Futa Notisi';

  @override
  String get deleteNoteConfirm =>
      'Je, una uhakika unataka kufuta notisi hii?\nFaili zote zitafutwa pamoja.';

  @override
  String get noteDeleted => 'Notisi imefutwa';

  @override
  String noteCreated(String title) {
    return '\'$title\' imeundwa';
  }

  @override
  String noteSelected(String title) {
    return '$title imechaguliwa';
  }

  @override
  String freeLimitReached(int limit) {
    return 'Toleo la bure linaruhusu hadi notisi $limit tu.';
  }

  @override
  String get upgradeToStandard => 'Pandisha hadi Kiwango cha Kawaida';

  @override
  String get upgradeFeatures =>
      'Pandisha hadi Kiwango cha Kawaida na upate:\n\n• Uundaji wa notisi usio na kikomo\n• Uhifadhi wa faili usio na kikomo\n• Ondosha matangazo\n• Ulandanishi wa wingu';

  @override
  String get later => 'Baadaye';

  @override
  String get upgrade => 'Pandisha';

  @override
  String get adBannerText =>
      'Eneo la Tangazo - Ondoa kwa kupandisha Kiwango cha Kawaida';

  @override
  String get enterTitle => 'Tafadhali ingiza kichwa';

  @override
  String createNoteFailed(String error) {
    return 'Imeshindwa kuunda notisi: $error';
  }

  @override
  String deleteNoteFailed(String error) {
    return 'Imeshindwa kufuta notisi: $error';
  }

  @override
  String get upgradeComingSoon =>
      'Kipengele cha kupandisha kitapatikana hivi karibuni';
}

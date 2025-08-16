// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tagalog (`tl`).
class AppLocalizationsTl extends AppLocalizations {
  AppLocalizationsTl([String locale = 'tl']) : super(locale);

  @override
  String get appName => 'Litten';

  @override
  String get home => 'Home';

  @override
  String get listen => 'Pakinggan';

  @override
  String get write => 'Sumulat';

  @override
  String get settings => 'Mga Setting';

  @override
  String get createNote => 'Gumawa ng Litten';

  @override
  String get newNote => 'Bagong Litten';

  @override
  String get title => 'Pamagat';

  @override
  String get description => 'Paglalarawan';

  @override
  String get optional => '(Opsyonal)';

  @override
  String get cancel => 'Kanselahin';

  @override
  String get create => 'Gumawa';

  @override
  String get delete => 'Burahin';

  @override
  String get search => 'Hanapin';

  @override
  String get searchNotes => 'Hanapin ang mga note...';

  @override
  String get noNotesTitle => 'Gumawa ng inyong unang Litten';

  @override
  String get noNotesSubtitle =>
      'Pamahalain ang boses, teksto, at sulat kamay\nsa isang pinagsama na espasyo';

  @override
  String get noSearchResults => 'Walang resulta ng paghahanap';

  @override
  String noSearchResultsSubtitle(String query) {
    return 'Walang nahanap na mga note na tumugma sa \"$query\"';
  }

  @override
  String get clearSearch => 'I-clear ang paghahanap';

  @override
  String get deleteNote => 'Burahin ang Note';

  @override
  String get deleteNoteConfirm =>
      'Sigurado ka ba na gusto mong burahin ang note na ito?\nLahat ng mga file ay mababura nang sama-sama.';

  @override
  String get noteDeleted => 'Nabura ang note';

  @override
  String noteCreated(String title) {
    return 'Nagawa ang \'$title\'';
  }

  @override
  String noteSelected(String title) {
    return 'Napili ang $title';
  }

  @override
  String freeLimitReached(int limit) {
    return 'Ang libreng bersyon ay pinapahintulutan lamang hanggang $limit notes.';
  }

  @override
  String get upgradeToStandard => 'I-upgrade sa Standard';

  @override
  String get upgradeFeatures =>
      'I-upgrade sa Standard at makakuha ng:\n\n• Walang limitasyong paggawa ng note\n• Walang limitasyong file storage\n• Pagtanggal ng ads\n• Cloud synchronization';

  @override
  String get later => 'Mamaya na';

  @override
  String get upgrade => 'I-upgrade';

  @override
  String get adBannerText => 'Ad Area - Tanggalin gamit ang Standard upgrade';

  @override
  String get enterTitle => 'Pakisuyo na maglagay ng pamagat';

  @override
  String createNoteFailed(String error) {
    return 'Hindi nagawa ang note: $error';
  }

  @override
  String deleteNoteFailed(String error) {
    return 'Hindi nabura ang note: $error';
  }

  @override
  String get upgradeComingSoon =>
      'Ang upgrade feature ay malapit nang maging available';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Telugu (`te`).
class AppLocalizationsTe extends AppLocalizations {
  AppLocalizationsTe([String locale = 'te']) : super(locale);

  @override
  String get appName => 'Litten';

  @override
  String get home => 'హోమ్';

  @override
  String get listen => 'వినండి';

  @override
  String get write => 'వ్రాయండి';

  @override
  String get settings => 'సెట్టింగ్స్';

  @override
  String get createNote => 'Litten సృష్టించండి';

  @override
  String get newNote => 'కొత్త Litten';

  @override
  String get title => 'శీర్షిక';

  @override
  String get description => 'వివరణ';

  @override
  String get optional => '(ఐచ్ఛికం)';

  @override
  String get cancel => 'రద్దు చేయండి';

  @override
  String get create => 'సృష్టించండి';

  @override
  String get delete => 'తొలగించండి';

  @override
  String get search => 'వెతకండి';

  @override
  String get searchNotes => 'నోట్స్ వెతకండి...';

  @override
  String get noNotesTitle => 'మీ మొదటి Litten సృష్టించండి';

  @override
  String get noNotesSubtitle =>
      'వాయిస్, టెక్స్ట్ మరియు హస్తలేఖనాన్ని\nఒక సమీకృత స్థలంలో నిర్వహించండి';

  @override
  String get noSearchResults => 'శోధన ఫలితాలు లేవు';

  @override
  String noSearchResultsSubtitle(String query) {
    return '\"$query\"తో సరిపోలే నోట్స్ కనుగొనబడలేదు';
  }

  @override
  String get clearSearch => 'శోధనను క్లియర్ చేయండి';

  @override
  String get deleteNote => 'నోట్ తొలగించండి';

  @override
  String get deleteNoteConfirm =>
      'మీరు ఈ నోట్ను తొలగించాలని ఖచ్చితంగా అనుకుంటున్నారా?\nఅన్ని ఫైల్స్ కలిసి తొలగించబడతాయి.';

  @override
  String get noteDeleted => 'నోట్ తొలగించబడింది';

  @override
  String noteCreated(String title) {
    return '\'$title\' సృష్టించబడింది';
  }

  @override
  String noteSelected(String title) {
    return '$title ఎంపిక చేయబడింది';
  }

  @override
  String freeLimitReached(int limit) {
    return 'ఉచిత వెర్షన్ కేవలం $limit నోట్స్ను మాత్రమే అనుమతిస్తుంది.';
  }

  @override
  String get upgradeToStandard => 'స్టాండర్డ్కు అప్గ్రేడ్ చేయండి';

  @override
  String get upgradeFeatures =>
      'స్టాండర్డ్కు అప్గ్రేడ్ చేసి పొందండి:\n\n• అపరిమిత నోట్ సృష్టి\n• అపరిమిత ఫైల్ స్టోరేజ్\n• ప్రకటనలు తీసివేత\n• క్లౌడ్ సింక్రోనైజేషన్';

  @override
  String get later => 'తర్వాత';

  @override
  String get upgrade => 'అప్గ్రేడ్';

  @override
  String get adBannerText =>
      'ప్రకటన ప్రాంతం - స్టాండర్డ్ అప్గ్రేడ్తో తీసివేయండి';

  @override
  String get enterTitle => 'దయచేసి శీర్షిక నమోదు చేయండి';

  @override
  String createNoteFailed(String error) {
    return 'నోట్ సృష్టించడంలో విఫలమైంది: $error';
  }

  @override
  String deleteNoteFailed(String error) {
    return 'నోట్ తొలగించడంలో విఫలమైంది: $error';
  }

  @override
  String get upgradeComingSoon => 'అప్గ్రేడ్ ఫీచర్ త్వరలో అందుబాటులో ఉంటుంది';
}

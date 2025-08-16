// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tamil (`ta`).
class AppLocalizationsTa extends AppLocalizations {
  AppLocalizationsTa([String locale = 'ta']) : super(locale);

  @override
  String get appName => 'Litten';

  @override
  String get home => 'முகப்பு';

  @override
  String get listen => 'கேளுங்கள்';

  @override
  String get write => 'எழுதுங்கள்';

  @override
  String get settings => 'அமைப்புகள்';

  @override
  String get createNote => 'Litten உருவாக்குங்கள்';

  @override
  String get newNote => 'புதிய Litten';

  @override
  String get title => 'தலைப்பு';

  @override
  String get description => 'விளக்கம்';

  @override
  String get optional => '(விருப்பம்)';

  @override
  String get cancel => 'ரத்து செய்யுங்கள்';

  @override
  String get create => 'உருவாக்குங்கள்';

  @override
  String get delete => 'அழிக்கவும்';

  @override
  String get search => 'தேடுங்கள்';

  @override
  String get searchNotes => 'குறிப்புகளைத் தேடுங்கள்...';

  @override
  String get noNotesTitle => 'உங்கள் முதல் Litten ஐ உருவாக்குங்கள்';

  @override
  String get noNotesSubtitle =>
      'குரல், உரை மற்றும் கையெழுத்தை\nஒரு ஒருங்கிணைந்த இடத்தில் நிர்வகிக்கவும்';

  @override
  String get noSearchResults => 'தேடல் முடிவுகள் இல்லை';

  @override
  String noSearchResultsSubtitle(String query) {
    return '\"$query\" உடன் பொருந்தும் குறிப்புகள் எதுவும் கிடைக்கவில்லை';
  }

  @override
  String get clearSearch => 'தேடலை அழிக்கவும்';

  @override
  String get deleteNote => 'குறிப்பை அழிக்கவும்';

  @override
  String get deleteNoteConfirm =>
      'இந்த குறிப்பை நீங்கள் நிச்சயமாக அழிக்க விரும்புகிறீர்களா?\nஅனைத்து கோப்புகளும் ஒன்றாக அழிக்கப்படும்.';

  @override
  String get noteDeleted => 'குறிப்பு அழிக்கப்பட்டது';

  @override
  String noteCreated(String title) {
    return '\'$title\' உருவாக்கப்பட்டது';
  }

  @override
  String noteSelected(String title) {
    return '$title தேர்ந்தெடுக்கப்பட்டது';
  }

  @override
  String freeLimitReached(int limit) {
    return 'இலவச பதிப்பு $limit குறிப்புகள் வரை மட்டுமே அனுமதிக்கிறது.';
  }

  @override
  String get upgradeToStandard => 'நிலையானதற்கு மேம்படுத்துங்கள்';

  @override
  String get upgradeFeatures =>
      'நிலையானதற்கு மேம்படுத்தி பெறுங்கள்:\n\n• வரம்பற்ற குறிப்பு உருவாக்கம்\n• வரம்பற்ற கோப்பு சேமிப்பு\n• விளம்பர நீக்கம்\n• கிளவுட் ஒத்திசைவு';

  @override
  String get later => 'பின்னர்';

  @override
  String get upgrade => 'மேம்படுத்துங்கள்';

  @override
  String get adBannerText => 'விளம்பர பகுதி - நிலையான மேம்பாட்டுடன் நீக்கவும்';

  @override
  String get enterTitle => 'தயவுசெய்து தலைப்பு உள்ளிடவும்';

  @override
  String createNoteFailed(String error) {
    return 'குறிப்பு உருவாக்க முடியவில்லை: $error';
  }

  @override
  String deleteNoteFailed(String error) {
    return 'குறிப்பு அழிக்க முடியவில்லை: $error';
  }

  @override
  String get upgradeComingSoon => 'மேம்படுத்தும் அம்சம் விரைவில் கிடைக்கும்';
}

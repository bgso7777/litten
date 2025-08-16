// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Pushto Pashto (`ps`).
class AppLocalizationsPs extends AppLocalizations {
  AppLocalizationsPs([String locale = 'ps']) : super(locale);

  @override
  String get appName => 'Litten';

  @override
  String get home => 'کور';

  @override
  String get listen => 'واورېږئ';

  @override
  String get write => 'ولیکئ';

  @override
  String get settings => 'تنظیمات';

  @override
  String get createNote => 'Litten جوړ کړئ';

  @override
  String get newNote => 'نوی Litten';

  @override
  String get title => 'سرلیک';

  @override
  String get description => 'تشریح';

  @override
  String get optional => '(اختیاری)';

  @override
  String get cancel => 'لغو کړئ';

  @override
  String get create => 'جوړ کړئ';

  @override
  String get delete => 'ړنګ کړئ';

  @override
  String get search => 'پلټنه';

  @override
  String get searchNotes => 'نوټونه پلټئ...';

  @override
  String get noNotesTitle => 'خپل لومړی Litten جوړ کړئ';

  @override
  String get noNotesSubtitle =>
      'غږ، متن، او لاسي لیکنه\nپه یو مربوط ځای کې اداره کړئ';

  @override
  String get noSearchResults => 'د پلټنې پایلې نشته';

  @override
  String noSearchResultsSubtitle(String query) {
    return '\"$query\" سره سمون لرونکې نوټونه ونه موندل شول';
  }

  @override
  String get clearSearch => 'پلټنه پاکه کړئ';

  @override
  String get deleteNote => 'نوټ ړنګ کړئ';

  @override
  String get deleteNoteConfirm =>
      'ایا تاسو ډاډه یاست چې دا نوټ ړنګول غواړئ؟\nټولې دوتنې یوځای به ړنګې شي.';

  @override
  String get noteDeleted => 'نوټ ړنګ شو';

  @override
  String noteCreated(String title) {
    return '\'$title\' جوړ شو';
  }

  @override
  String noteSelected(String title) {
    return '$title غوره شو';
  }

  @override
  String freeLimitReached(int limit) {
    return 'وړیا نسخه یوازې د $limit نوټونو پورې اجازه ورکوي.';
  }

  @override
  String get upgradeToStandard => 'معیاري ته پورته کړئ';

  @override
  String get upgradeFeatures =>
      'معیاري ته پورته کړئ او ترلاسه کړئ:\n\n• د نوټونو نامحدود جوړونه\n• د دوتنو نامحدود ساتنه\n• د اعلاناتو لرې کول\n• د بادل همغږي';

  @override
  String get later => 'وروسته';

  @override
  String get upgrade => 'پورته کړئ';

  @override
  String get adBannerText => 'د اعلان ساحه - د معیاري پورته کولو سره لرې کړئ';

  @override
  String get enterTitle => 'مهرباني وکړئ سرلیک ولیکئ';

  @override
  String createNoteFailed(String error) {
    return 'د نوټ جوړول ناکام شو: $error';
  }

  @override
  String deleteNoteFailed(String error) {
    return 'د نوټ ړنګول ناکام شو: $error';
  }

  @override
  String get upgradeComingSoon => 'د پورته کولو ځانګړتیا سمدلاسه شتون لري';
}

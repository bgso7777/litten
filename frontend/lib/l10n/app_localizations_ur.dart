// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppLocalizationsUr extends AppLocalizations {
  AppLocalizationsUr([String locale = 'ur']) : super(locale);

  @override
  String get appName => 'لیٹن';

  @override
  String get home => 'ہوم';

  @override
  String get listen => 'سنیں';

  @override
  String get write => 'لکھیں';

  @override
  String get settings => 'سیٹنگز';

  @override
  String get createNote => 'لیٹن بنائیں';

  @override
  String get newNote => 'نیا لیٹن';

  @override
  String get title => 'عنوان';

  @override
  String get description => 'تفصیل';

  @override
  String get optional => '(اختیاری)';

  @override
  String get cancel => 'منظور';

  @override
  String get create => 'بنائیں';

  @override
  String get delete => 'حذف کریں';

  @override
  String get search => 'تلاش';

  @override
  String get searchNotes => 'نوٹس میں تلاش کریں...';

  @override
  String get noNotesTitle => 'اپنا پہلا لیٹن بنائیں';

  @override
  String get noNotesSubtitle =>
      'آواز، متن اور خطاطی\nایک متحد جگہ میں مینج کریں';

  @override
  String get noSearchResults => 'تلاش کے نتائج نہیں ملے';

  @override
  String noSearchResultsSubtitle(String query) {
    return '\"$query\" کے مطابق کوئی نوٹ نہیں ملا';
  }

  @override
  String get clearSearch => 'تلاش صاف کریں';

  @override
  String get deleteNote => 'نوٹ حذف کریں';

  @override
  String get deleteNoteConfirm =>
      'کیا آپ واقعی یہ نوٹ حذف کرنا چاہتے ہیں؟\nتمام فائلیں اکساتھ حذف ہو جائیں گی۔';

  @override
  String get noteDeleted => 'نوٹ حذف ہو گیا';

  @override
  String noteCreated(String title) {
    return '\'$title\' بنایا گیا';
  }

  @override
  String noteSelected(String title) {
    return '$title منتخب';
  }

  @override
  String freeLimitReached(int limit) {
    return 'فری ورژن صرف $limit نوٹس کی اجازت دیتا ہے۔';
  }

  @override
  String get upgradeToStandard => 'سٹینڈرڈ میں اپ گریڈ کریں';

  @override
  String get upgradeFeatures =>
      'سٹینڈرڈ میں اپ گریڈ کریں اور حاصل کریں:\n\n• بے حد نوٹ بنانا\n• بے حد فائل سٹوریج\n• اشتہارات کا ازالہ\n• کلاؤڈ سنکرونائزیشن';

  @override
  String get later => 'بعد میں';

  @override
  String get upgrade => 'اپ گریڈ';

  @override
  String get adBannerText => 'اشتہار کا علاقہ - سٹینڈرڈ اپ گریڈ کے ساتھ ہٹائیں';

  @override
  String get enterTitle => 'براہ کرم عنوان داخل کریں';

  @override
  String createNoteFailed(String error) {
    return 'نوٹ بنانے میں ناکام: $error';
  }

  @override
  String deleteNoteFailed(String error) {
    return 'نوٹ حذف کرنے میں ناکام: $error';
  }

  @override
  String get upgradeComingSoon => 'اپ گریڈ فیچر جلد دستیاب ہوگا';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get appName => 'Litten';

  @override
  String get home => 'خانه';

  @override
  String get listen => 'گوش دهید';

  @override
  String get write => 'بنویسید';

  @override
  String get settings => 'تنظیمات';

  @override
  String get createNote => 'Litten ایجاد کنید';

  @override
  String get newNote => 'Litten جدید';

  @override
  String get title => 'عنوان';

  @override
  String get description => 'توضیحات';

  @override
  String get optional => '(اختیاری)';

  @override
  String get cancel => 'لغو';

  @override
  String get create => 'ایجاد';

  @override
  String get delete => 'حذف';

  @override
  String get search => 'جستجو';

  @override
  String get searchNotes => 'جستجوی یادداشت‌ها...';

  @override
  String get noNotesTitle => 'اولین Litten خود را ایجاد کنید';

  @override
  String get noNotesSubtitle =>
      'صدا، متن و دست‌نویس را\nدر یک فضای یکپارچه مدیریت کنید';

  @override
  String get noSearchResults => 'نتیجه‌ای یافت نشد';

  @override
  String noSearchResultsSubtitle(String query) {
    return 'هیچ یادداشتی با \"$query\" مطابقت ندارد';
  }

  @override
  String get clearSearch => 'پاک کردن جستجو';

  @override
  String get deleteNote => 'حذف یادداشت';

  @override
  String get deleteNoteConfirm =>
      'آیا مطمئن هستید که می‌خواهید این یادداشت را حذف کنید؟\nتمام فایل‌ها با هم حذف خواهند شد.';

  @override
  String get noteDeleted => 'یادداشت حذف شد';

  @override
  String noteCreated(String title) {
    return '\'$title\' ایجاد شد';
  }

  @override
  String noteSelected(String title) {
    return '$title انتخاب شد';
  }

  @override
  String freeLimitReached(int limit) {
    return 'نسخه رایگان فقط تا $limit یادداشت اجازه می‌دهد.';
  }

  @override
  String get upgradeToStandard => 'به نسخه استاندارد ارتقا دهید';

  @override
  String get upgradeFeatures =>
      'به نسخه استاندارد ارتقا دهید و دریافت کنید:\n\n• ایجاد یادداشت نامحدود\n• ذخیره‌سازی فایل نامحدود\n• حذف تبلیغات\n• همگام‌سازی ابری';

  @override
  String get later => 'بعداً';

  @override
  String get upgrade => 'ارتقا';

  @override
  String get adBannerText => 'منطقه تبلیغات - با ارتقای استاندارد حذف کنید';

  @override
  String get enterTitle => 'لطفاً عنوانی وارد کنید';

  @override
  String createNoteFailed(String error) {
    return 'ایجاد یادداشت ناموفق: $error';
  }

  @override
  String deleteNoteFailed(String error) {
    return 'حذف یادداشت ناموفق: $error';
  }

  @override
  String get upgradeComingSoon => 'قابلیت ارتقا به زودی در دسترس خواهد بود';
}

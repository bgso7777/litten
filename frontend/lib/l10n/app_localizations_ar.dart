// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'ليتن';

  @override
  String get home => 'الرئيسية';

  @override
  String get listen => 'استمع';

  @override
  String get write => 'اكتب';

  @override
  String get settings => 'الإعدادات';

  @override
  String get createNote => 'إنشاء ليتن';

  @override
  String get newNote => 'ليتن جديد';

  @override
  String get title => 'العنوان';

  @override
  String get description => 'الوصف';

  @override
  String get optional => '(اختياري)';

  @override
  String get cancel => 'إلغاء';

  @override
  String get create => 'إنشاء';

  @override
  String get delete => 'حذف';

  @override
  String get search => 'بحث';

  @override
  String get searchNotes => 'البحث في الملاحظات...';

  @override
  String get noNotesTitle => 'أنشئ أول ليتن';

  @override
  String get noNotesSubtitle =>
      'إدارة الصوت والنص والكتابة اليدوية\nفي مساحة متكاملة';

  @override
  String get noSearchResults => 'لا توجد نتائج بحث';

  @override
  String noSearchResultsSubtitle(String query) {
    return 'لم يتم العثور على ملاحظات تطابق \"$query\"';
  }

  @override
  String get clearSearch => 'مسح البحث';

  @override
  String get deleteNote => 'حذف الملاحظة';

  @override
  String get deleteNoteConfirm =>
      'هل أنت متأكد من أنك تريد حذف هذه الملاحظة؟\nسيتم حذف جميع الملفات معًا.';

  @override
  String get noteDeleted => 'تم حذف الملاحظة';

  @override
  String noteCreated(String title) {
    return 'تم إنشاء \'$title\'';
  }

  @override
  String noteSelected(String title) {
    return 'تم تحديد $title';
  }

  @override
  String freeLimitReached(int limit) {
    return 'الإصدار المجاني يسمح بـ $limit ملاحظات فقط.';
  }

  @override
  String get upgradeToStandard => 'الترقية إلى المعيار';

  @override
  String get upgradeFeatures =>
      'ارتقِ إلى المعيار واحصل على:\n\n• إنشاء ملاحظات غير محدود\n• تخزين ملفات غير محدود\n• إزالة الإعلانات\n• مزامنة السحابة';

  @override
  String get later => 'لاحقًا';

  @override
  String get upgrade => 'ترقية';

  @override
  String get adBannerText => 'منطقة الإعلانات - إزالة مع ترقية المعيار';

  @override
  String get enterTitle => 'يرجى إدخال عنوان';

  @override
  String createNoteFailed(String error) {
    return 'فشل في إنشاء الملاحظة: $error';
  }

  @override
  String deleteNoteFailed(String error) {
    return 'فشل في حذف الملاحظة: $error';
  }

  @override
  String get upgradeComingSoon => 'ستتوفر ميزة الترقية قريبًا';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class AppLocalizationsTh extends AppLocalizations {
  AppLocalizationsTh([String locale = 'th']) : super(locale);

  @override
  String get appName => 'Litten';

  @override
  String get home => 'หน้าหลัก';

  @override
  String get listen => 'ฟัง';

  @override
  String get write => 'เขียน';

  @override
  String get settings => 'การตั้งค่า';

  @override
  String get createNote => 'สร้าง Litten';

  @override
  String get newNote => 'Litten ใหม่';

  @override
  String get title => 'หัวเรื่อง';

  @override
  String get description => 'คำอธิบาย';

  @override
  String get optional => '(ทางเลือก)';

  @override
  String get cancel => 'ยกเลิก';

  @override
  String get create => 'สร้าง';

  @override
  String get delete => 'ลบ';

  @override
  String get search => 'ค้นหา';

  @override
  String get searchNotes => 'ค้นหาโน้ต...';

  @override
  String get noNotesTitle => 'สร้าง Litten แรกของคุณ';

  @override
  String get noNotesSubtitle =>
      'จัดการเสียง ข้อความ และลายมือ\nในพื้นที่รวมเดียว';

  @override
  String get noSearchResults => 'ไม่มีผลการค้นหา';

  @override
  String noSearchResultsSubtitle(String query) {
    return 'ไม่พบโน้ตที่ตรงกับ \"$query\"';
  }

  @override
  String get clearSearch => 'ล้างการค้นหา';

  @override
  String get deleteNote => 'ลบโน้ต';

  @override
  String get deleteNoteConfirm =>
      'คุณแน่ใจหรือว่าต้องการลบโน้ตนี้?\nไฟล์ทั้งหมดจะถูกลบด้วย';

  @override
  String get noteDeleted => 'ลบโน้ตแล้ว';

  @override
  String noteCreated(String title) {
    return 'สร้าง \'$title\' แล้ว';
  }

  @override
  String noteSelected(String title) {
    return 'เลือก $title แล้ว';
  }

  @override
  String freeLimitReached(int limit) {
    return 'เวอร์ชันฟรีอนุญาตเฉพาะ $limit โน้ตเท่านั้น';
  }

  @override
  String get upgradeToStandard => 'อัปเกรดเป็น Standard';

  @override
  String get upgradeFeatures =>
      'อัปเกรดเป็น Standard และรับ:\n\n• สร้างโน้ตได้ไม่จำกัด\n• เก็บไฟล์ได้ไม่จำกัด\n• ลบโฆษณา\n• ซิงค์คลาวด์';

  @override
  String get later => 'ทีหลัง';

  @override
  String get upgrade => 'อัปเกรด';

  @override
  String get adBannerText => 'พื้นที่โฆษณา - ลบด้วยการอัปเกรด Standard';

  @override
  String get enterTitle => 'โปรดใส่หัวเรื่อง';

  @override
  String createNoteFailed(String error) {
    return 'สร้างโน้ตไม่สำเร็จ: $error';
  }

  @override
  String deleteNoteFailed(String error) {
    return 'ลบโน้ตไม่สำเร็จ: $error';
  }

  @override
  String get upgradeComingSoon => 'ฟีเจอร์อัปเกรดจะพร้อมใช้งานเร็วๆ นี้';
}

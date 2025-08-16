// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Malay (`ms`).
class AppLocalizationsMs extends AppLocalizations {
  AppLocalizationsMs([String locale = 'ms']) : super(locale);

  @override
  String get appName => 'Litten';

  @override
  String get home => 'Utama';

  @override
  String get listen => 'Dengar';

  @override
  String get write => 'Tulis';

  @override
  String get settings => 'Tetapan';

  @override
  String get createNote => 'Cipta Litten';

  @override
  String get newNote => 'Litten Baru';

  @override
  String get title => 'Tajuk';

  @override
  String get description => 'Penerangan';

  @override
  String get optional => '(Pilihan)';

  @override
  String get cancel => 'Batal';

  @override
  String get create => 'Cipta';

  @override
  String get delete => 'Padam';

  @override
  String get search => 'Cari';

  @override
  String get searchNotes => 'Cari nota...';

  @override
  String get noNotesTitle => 'Cipta Litten pertama anda';

  @override
  String get noNotesSubtitle =>
      'Urus suara, teks, dan tulisan tangan\ndalam satu ruang bersepadu';

  @override
  String get noSearchResults => 'Tiada keputusan carian';

  @override
  String noSearchResultsSubtitle(String query) {
    return 'Tiada nota ditemui yang sepadan dengan \"$query\"';
  }

  @override
  String get clearSearch => 'Kosongkan carian';

  @override
  String get deleteNote => 'Padam Nota';

  @override
  String get deleteNoteConfirm =>
      'Adakah anda pasti mahu memadam nota ini?\nSemua fail akan dipadamkan bersama.';

  @override
  String get noteDeleted => 'Nota dipadamkan';

  @override
  String noteCreated(String title) {
    return '\'$title\' dicipta';
  }

  @override
  String noteSelected(String title) {
    return '$title dipilih';
  }

  @override
  String freeLimitReached(int limit) {
    return 'Versi percuma hanya membenarkan sehingga $limit nota.';
  }

  @override
  String get upgradeToStandard => 'Naik taraf ke Standard';

  @override
  String get upgradeFeatures =>
      'Naik taraf ke Standard dan dapatkan:\n\n• Penciptaan nota tanpa had\n• Penyimpanan fail tanpa had\n• Penyingkiran iklan\n• Penyegerakan awan';

  @override
  String get later => 'Kemudian';

  @override
  String get upgrade => 'Naik taraf';

  @override
  String get adBannerText => 'Kawasan Iklan - Buang dengan naik taraf Standard';

  @override
  String get enterTitle => 'Sila masukkan tajuk';

  @override
  String createNoteFailed(String error) {
    return 'Gagal mencipta nota: $error';
  }

  @override
  String deleteNoteFailed(String error) {
    return 'Gagal memadam nota: $error';
  }

  @override
  String get upgradeComingSoon =>
      'Ciri naik taraf akan tersedia tidak lama lagi';
}

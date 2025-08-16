// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appName => 'Litten';

  @override
  String get home => 'Beranda';

  @override
  String get listen => 'Dengarkan';

  @override
  String get write => 'Tulis';

  @override
  String get settings => 'Pengaturan';

  @override
  String get createNote => 'Buat Litten';

  @override
  String get newNote => 'Litten Baru';

  @override
  String get title => 'Judul';

  @override
  String get description => 'Deskripsi';

  @override
  String get optional => '(Opsional)';

  @override
  String get cancel => 'Batal';

  @override
  String get create => 'Buat';

  @override
  String get delete => 'Hapus';

  @override
  String get search => 'Cari';

  @override
  String get searchNotes => 'Cari catatan...';

  @override
  String get noNotesTitle => 'Buat Litten pertama Anda';

  @override
  String get noNotesSubtitle =>
      'Kelola suara, teks, dan tulisan tangan\ndalam satu ruang terintegrasi';

  @override
  String get noSearchResults => 'Tidak ada hasil pencarian';

  @override
  String noSearchResultsSubtitle(String query) {
    return 'Tidak ditemukan catatan yang sesuai dengan \"$query\"';
  }

  @override
  String get clearSearch => 'Bersihkan pencarian';

  @override
  String get deleteNote => 'Hapus Catatan';

  @override
  String get deleteNoteConfirm =>
      'Apakah Anda yakin ingin menghapus catatan ini?\nSemua file akan dihapus bersama.';

  @override
  String get noteDeleted => 'Catatan dihapus';

  @override
  String noteCreated(String title) {
    return '\'$title\' dibuat';
  }

  @override
  String noteSelected(String title) {
    return '$title dipilih';
  }

  @override
  String freeLimitReached(int limit) {
    return 'Versi gratis hanya mengizinkan $limit catatan.';
  }

  @override
  String get upgradeToStandard => 'Upgrade ke Standard';

  @override
  String get upgradeFeatures =>
      'Upgrade ke Standard dan dapatkan:\n\n• Pembuatan catatan tak terbatas\n• Penyimpanan file tak terbatas\n• Penghapusan iklan\n• Sinkronisasi cloud';

  @override
  String get later => 'Nanti';

  @override
  String get upgrade => 'Upgrade';

  @override
  String get adBannerText => 'Area iklan - Hapus dengan upgrade Standard';

  @override
  String get enterTitle => 'Silakan masukkan judul';

  @override
  String createNoteFailed(String error) {
    return 'Gagal membuat catatan: $error';
  }

  @override
  String deleteNoteFailed(String error) {
    return 'Gagal menghapus catatan: $error';
  }

  @override
  String get upgradeComingSoon => 'Fitur upgrade akan segera tersedia';
}

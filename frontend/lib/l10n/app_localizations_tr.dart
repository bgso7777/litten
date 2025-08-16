// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appName => 'Litten';

  @override
  String get home => 'Ana Sayfa';

  @override
  String get listen => 'Dinle';

  @override
  String get write => 'Yaz';

  @override
  String get settings => 'Ayarlar';

  @override
  String get createNote => 'Litten Oluştur';

  @override
  String get newNote => 'Yeni Litten';

  @override
  String get title => 'Başlık';

  @override
  String get description => 'Açıklama';

  @override
  String get optional => '(İsteğe bağlı)';

  @override
  String get cancel => 'İptal';

  @override
  String get create => 'Oluştur';

  @override
  String get delete => 'Sil';

  @override
  String get search => 'Ara';

  @override
  String get searchNotes => 'Notları ara...';

  @override
  String get noNotesTitle => 'İlk Litten\'ınızı oluşturun';

  @override
  String get noNotesSubtitle =>
      'Ses, metin ve el yazısını\ntek entegre alanda yönetin';

  @override
  String get noSearchResults => 'Arama sonucu bulunamadı';

  @override
  String noSearchResultsSubtitle(String query) {
    return '\"$query\" ile eşleşen not bulunamadı';
  }

  @override
  String get clearSearch => 'Aramayı temizle';

  @override
  String get deleteNote => 'Notu Sil';

  @override
  String get deleteNoteConfirm =>
      'Bu notu silmek istediğinizden emin misiniz?\nTüm dosyalar birlikte silinecektir.';

  @override
  String get noteDeleted => 'Not silindi';

  @override
  String noteCreated(String title) {
    return '\'$title\' oluşturuldu';
  }

  @override
  String noteSelected(String title) {
    return '$title seçildi';
  }

  @override
  String freeLimitReached(int limit) {
    return 'Ücretsiz sürüm yalnızca $limit nota kadar izin verir.';
  }

  @override
  String get upgradeToStandard => 'Standart\'a Yükselt';

  @override
  String get upgradeFeatures =>
      'Standart\'a yükseltin ve şunları elde edin:\n\n• Sınırsız not oluşturma\n• Sınırsız dosya depolama\n• Reklam kaldırma\n• Bulut senkronizasyonu';

  @override
  String get later => 'Sonra';

  @override
  String get upgrade => 'Yükselt';

  @override
  String get adBannerText => 'Reklam Alanı - Standart yükseltme ile kaldırın';

  @override
  String get enterTitle => 'Lütfen bir başlık girin';

  @override
  String createNoteFailed(String error) {
    return 'Not oluşturma başarısız: $error';
  }

  @override
  String deleteNoteFailed(String error) {
    return 'Not silme başarısız: $error';
  }

  @override
  String get upgradeComingSoon =>
      'Yükseltme özelliği yakında kullanılabilir olacak';
}

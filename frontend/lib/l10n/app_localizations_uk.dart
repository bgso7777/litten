// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appName => 'Litten';

  @override
  String get home => 'Головна';

  @override
  String get listen => 'Слухати';

  @override
  String get write => 'Писати';

  @override
  String get settings => 'Налаштування';

  @override
  String get createNote => 'Створити Litten';

  @override
  String get newNote => 'Новий Litten';

  @override
  String get title => 'Назва';

  @override
  String get description => 'Опис';

  @override
  String get optional => '(Необов\'язково)';

  @override
  String get cancel => 'Скасувати';

  @override
  String get create => 'Створити';

  @override
  String get delete => 'Видалити';

  @override
  String get search => 'Пошук';

  @override
  String get searchNotes => 'Пошук нотаток...';

  @override
  String get noNotesTitle => 'Створіть свій перший Litten';

  @override
  String get noNotesSubtitle =>
      'Керуйте голосом, текстом та рукописом\nв одному інтегрованому просторі';

  @override
  String get noSearchResults => 'Результатів пошуку немає';

  @override
  String noSearchResultsSubtitle(String query) {
    return 'Нотаток, що відповідають \"$query\", не знайдено';
  }

  @override
  String get clearSearch => 'Очистити пошук';

  @override
  String get deleteNote => 'Видалити нотатку';

  @override
  String get deleteNoteConfirm =>
      'Ви впевнені, що хочете видалити цю нотатку?\nВсі файли будуть видалені разом.';

  @override
  String get noteDeleted => 'Нотатку видалено';

  @override
  String noteCreated(String title) {
    return '\'$title\' створено';
  }

  @override
  String noteSelected(String title) {
    return '$title вибрано';
  }

  @override
  String freeLimitReached(int limit) {
    return 'Безкоштовна версія дозволяє лише $limit нотаток.';
  }

  @override
  String get upgradeToStandard => 'Оновити до Стандарт';

  @override
  String get upgradeFeatures =>
      'Оновіться до Стандарт і отримайте:\n\n• Необмежене створення нотаток\n• Необмежене сховище файлів\n• Видалення реклами\n• Хмарна синхронізація';

  @override
  String get later => 'Пізніше';

  @override
  String get upgrade => 'Оновити';

  @override
  String get adBannerText =>
      'Рекламна область - Видаліть з оновленням Стандарт';

  @override
  String get enterTitle => 'Будь ласка, введіть назву';

  @override
  String createNoteFailed(String error) {
    return 'Не вдалося створити нотатку: $error';
  }

  @override
  String deleteNoteFailed(String error) {
    return 'Не вдалося видалити нотатку: $error';
  }

  @override
  String get upgradeComingSoon => 'Функція оновлення буде доступна незабаром';
}

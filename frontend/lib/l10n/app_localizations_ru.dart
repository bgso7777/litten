// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'Litten';

  @override
  String get home => 'Главная';

  @override
  String get listen => 'Слушать';

  @override
  String get write => 'Писать';

  @override
  String get settings => 'Настройки';

  @override
  String get createNote => 'Создать Litten';

  @override
  String get newNote => 'Новый Litten';

  @override
  String get title => 'Заголовок';

  @override
  String get description => 'Описание';

  @override
  String get optional => '(Необязательно)';

  @override
  String get cancel => 'Отмена';

  @override
  String get create => 'Создать';

  @override
  String get delete => 'Удалить';

  @override
  String get search => 'Поиск';

  @override
  String get searchNotes => 'Поиск заметок...';

  @override
  String get noNotesTitle => 'Создайте свой первый Litten';

  @override
  String get noNotesSubtitle =>
      'Управляйте голосом, текстом и рукописным вводом\nв едином интегрированном пространстве';

  @override
  String get noSearchResults => 'Нет результатов поиска';

  @override
  String noSearchResultsSubtitle(String query) {
    return 'Не найдено заметок, соответствующих \"$query\"';
  }

  @override
  String get clearSearch => 'Очистить поиск';

  @override
  String get deleteNote => 'Удалить заметку';

  @override
  String get deleteNoteConfirm =>
      'Вы уверены, что хотите удалить эту заметку?\nВсе файлы будут удалены вместе.';

  @override
  String get noteDeleted => 'Заметка удалена';

  @override
  String noteCreated(String title) {
    return '\'$title\' создано';
  }

  @override
  String noteSelected(String title) {
    return '$title выбрано';
  }

  @override
  String freeLimitReached(int limit) {
    return 'Бесплатная версия позволяет только $limit заметок.';
  }

  @override
  String get upgradeToStandard => 'Обновить до Стандарт';

  @override
  String get upgradeFeatures =>
      'Обновитесь до Стандарт и получите:\n\n• Неограниченное создание заметок\n• Неограниченное хранение файлов\n• Удаление рекламы\n• Облачная синхронизация';

  @override
  String get later => 'Позже';

  @override
  String get upgrade => 'Обновить';

  @override
  String get adBannerText => 'Рекламная зона - Удалить с обновлением Стандарт';

  @override
  String get enterTitle => 'Пожалуйста, введите заголовок';

  @override
  String createNoteFailed(String error) {
    return 'Не удалось создать заметку: $error';
  }

  @override
  String deleteNoteFailed(String error) {
    return 'Не удалось удалить заметку: $error';
  }

  @override
  String get upgradeComingSoon =>
      'Функция обновления будет доступна в ближайшее время';
}

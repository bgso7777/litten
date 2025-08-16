// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get appName => 'Litten';

  @override
  String get home => 'Główna';

  @override
  String get listen => 'Słuchaj';

  @override
  String get write => 'Pisz';

  @override
  String get settings => 'Ustawienia';

  @override
  String get createNote => 'Utwórz Litten';

  @override
  String get newNote => 'Nowy Litten';

  @override
  String get title => 'Tytuł';

  @override
  String get description => 'Opis';

  @override
  String get optional => '(Opcjonalne)';

  @override
  String get cancel => 'Anuluj';

  @override
  String get create => 'Utwórz';

  @override
  String get delete => 'Usuń';

  @override
  String get search => 'Szukaj';

  @override
  String get searchNotes => 'Szukaj notatek...';

  @override
  String get noNotesTitle => 'Utwórz swój pierwszy Litten';

  @override
  String get noNotesSubtitle =>
      'Zarządzaj głosem, tekstem i pismem odręcznym\nw jednej zintegrowanej przestrzeni';

  @override
  String get noSearchResults => 'Brak wyników wyszukiwania';

  @override
  String noSearchResultsSubtitle(String query) {
    return 'Nie znaleziono notatek pasujących do \"$query\"';
  }

  @override
  String get clearSearch => 'Wyczyść wyszukiwanie';

  @override
  String get deleteNote => 'Usuń notatkę';

  @override
  String get deleteNoteConfirm =>
      'Czy jesteś pewien, że chcesz usunąć tę notatkę?\nWszystkie pliki zostaną usunięte razem.';

  @override
  String get noteDeleted => 'Notatka usunięta';

  @override
  String noteCreated(String title) {
    return 'Utworzono \'$title\'';
  }

  @override
  String noteSelected(String title) {
    return 'Wybrano $title';
  }

  @override
  String freeLimitReached(int limit) {
    return 'Darmowa wersja pozwala tylko na $limit notatek.';
  }

  @override
  String get upgradeToStandard => 'Przejdź na Standard';

  @override
  String get upgradeFeatures =>
      'Przejdź na Standard i otrzymaj:\n\n• Nieograniczone tworzenie notatek\n• Nieograniczone miejsce na pliki\n• Usunięcie reklam\n• Synchronizacja w chmurze';

  @override
  String get later => 'Później';

  @override
  String get upgrade => 'Przejdź';

  @override
  String get adBannerText => 'Obszar reklam - Usuń z aktualizacją Standard';

  @override
  String get enterTitle => 'Proszę wprowadzić tytuł';

  @override
  String createNoteFailed(String error) {
    return 'Nie udało się utworzyć notatki: $error';
  }

  @override
  String deleteNoteFailed(String error) {
    return 'Nie udało się usunąć notatki: $error';
  }

  @override
  String get upgradeComingSoon =>
      'Funkcja aktualizacji będzie wkrótce dostępna';
}

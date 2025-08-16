// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'Litten';

  @override
  String get home => 'Startseite';

  @override
  String get listen => 'Anhören';

  @override
  String get write => 'Schreiben';

  @override
  String get settings => 'Einstellungen';

  @override
  String get createNote => 'Litten erstellen';

  @override
  String get newNote => 'Neue Litten';

  @override
  String get title => 'Titel';

  @override
  String get description => 'Beschreibung';

  @override
  String get optional => '(Optional)';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get create => 'Erstellen';

  @override
  String get delete => 'Löschen';

  @override
  String get search => 'Suchen';

  @override
  String get searchNotes => 'Notizen suchen...';

  @override
  String get noNotesTitle => 'Erstelle deine erste Litten';

  @override
  String get noNotesSubtitle =>
      'Verwalte Sprache, Text und Handschrift\nin einem integrierten Bereich';

  @override
  String get noSearchResults => 'Keine Suchergebnisse';

  @override
  String noSearchResultsSubtitle(String query) {
    return 'Keine Notizen gefunden, die \"$query\" entsprechen';
  }

  @override
  String get clearSearch => 'Suche löschen';

  @override
  String get deleteNote => 'Notiz löschen';

  @override
  String get deleteNoteConfirm =>
      'Sind Sie sicher, dass Sie diese Notiz löschen möchten?\nAlle Dateien werden zusammen gelöscht.';

  @override
  String get noteDeleted => 'Notiz gelöscht';

  @override
  String noteCreated(String title) {
    return '\'$title\' erstellt';
  }

  @override
  String noteSelected(String title) {
    return '$title ausgewählt';
  }

  @override
  String freeLimitReached(int limit) {
    return 'Die kostenlose Version erlaubt nur $limit Notizen.';
  }

  @override
  String get upgradeToStandard => 'Auf Standard upgraden';

  @override
  String get upgradeFeatures =>
      'Auf Standard upgraden und erhalten:\n\n• Unbegrenzte Notizerstellung\n• Unbegrenzter Dateispeicher\n• Werbung entfernen\n• Cloud-Synchronisation';

  @override
  String get later => 'Später';

  @override
  String get upgrade => 'Upgraden';

  @override
  String get adBannerText => 'Werbebereich - Mit Standard-Upgrade entfernen';

  @override
  String get enterTitle => 'Bitte geben Sie einen Titel ein';

  @override
  String createNoteFailed(String error) {
    return 'Fehler beim Erstellen der Notiz: $error';
  }

  @override
  String deleteNoteFailed(String error) {
    return 'Fehler beim Löschen der Notiz: $error';
  }

  @override
  String get upgradeComingSoon => 'Upgrade-Funktion wird bald verfügbar sein';
}

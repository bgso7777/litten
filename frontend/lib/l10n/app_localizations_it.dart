// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appName => 'Litten';

  @override
  String get home => 'Home';

  @override
  String get listen => 'Ascolta';

  @override
  String get write => 'Scrivi';

  @override
  String get settings => 'Impostazioni';

  @override
  String get createNote => 'Crea Litten';

  @override
  String get newNote => 'Nuovo Litten';

  @override
  String get title => 'Titolo';

  @override
  String get description => 'Descrizione';

  @override
  String get optional => '(Opzionale)';

  @override
  String get cancel => 'Annulla';

  @override
  String get create => 'Crea';

  @override
  String get delete => 'Elimina';

  @override
  String get search => 'Cerca';

  @override
  String get searchNotes => 'Cerca note...';

  @override
  String get noNotesTitle => 'Crea il tuo primo Litten';

  @override
  String get noNotesSubtitle =>
      'Gestisci voce, testo e scrittura a mano\nin un unico spazio integrato';

  @override
  String get noSearchResults => 'Nessun risultato di ricerca';

  @override
  String noSearchResultsSubtitle(String query) {
    return 'Nessuna nota trovata corrispondente a \"$query\"';
  }

  @override
  String get clearSearch => 'Cancella ricerca';

  @override
  String get deleteNote => 'Elimina nota';

  @override
  String get deleteNoteConfirm =>
      'Sei sicuro di voler eliminare questa nota?\nTutti i file verranno eliminati insieme.';

  @override
  String get noteDeleted => 'Nota eliminata';

  @override
  String noteCreated(String title) {
    return '\'$title\' creato';
  }

  @override
  String noteSelected(String title) {
    return '$title selezionato';
  }

  @override
  String freeLimitReached(int limit) {
    return 'La versione gratuita consente solo $limit note.';
  }

  @override
  String get upgradeToStandard => 'Aggiorna a Standard';

  @override
  String get upgradeFeatures =>
      'Aggiorna a Standard e ottieni:\n\n• Creazione note illimitata\n• Archiviazione file illimitata\n• Rimozione pubblicità\n• Sincronizzazione cloud';

  @override
  String get later => 'Più tardi';

  @override
  String get upgrade => 'Aggiorna';

  @override
  String get adBannerText =>
      'Area Pubblicità - Rimuovi con aggiornamento Standard';

  @override
  String get enterTitle => 'Inserisci un titolo';

  @override
  String createNoteFailed(String error) {
    return 'Creazione nota fallita: $error';
  }

  @override
  String deleteNoteFailed(String error) {
    return 'Eliminazione nota fallita: $error';
  }

  @override
  String get upgradeComingSoon =>
      'La funzione di aggiornamento sarà presto disponibile';
}

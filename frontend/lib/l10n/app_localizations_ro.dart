// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Romanian Moldavian Moldovan (`ro`).
class AppLocalizationsRo extends AppLocalizations {
  AppLocalizationsRo([String locale = 'ro']) : super(locale);

  @override
  String get appName => 'Litten';

  @override
  String get home => 'Acasă';

  @override
  String get listen => 'Ascultă';

  @override
  String get write => 'Scrie';

  @override
  String get settings => 'Setări';

  @override
  String get createNote => 'Creează Litten';

  @override
  String get newNote => 'Litten nou';

  @override
  String get title => 'Titlu';

  @override
  String get description => 'Descriere';

  @override
  String get optional => '(Opțional)';

  @override
  String get cancel => 'Anulează';

  @override
  String get create => 'Creează';

  @override
  String get delete => 'Șterge';

  @override
  String get search => 'Caută';

  @override
  String get searchNotes => 'Caută notițe...';

  @override
  String get noNotesTitle => 'Creează primul tău Litten';

  @override
  String get noNotesSubtitle =>
      'Gestionează vocea, textul și scrisul de mână\nîntr-un singur spațiu integrat';

  @override
  String get noSearchResults => 'Niciun rezultat de căutare';

  @override
  String noSearchResultsSubtitle(String query) {
    return 'Nicio notiță găsită care să corespundă cu \"$query\"';
  }

  @override
  String get clearSearch => 'Șterge căutarea';

  @override
  String get deleteNote => 'Șterge notița';

  @override
  String get deleteNoteConfirm =>
      'Ești sigur că vrei să ștergi această notiță?\nToate fișierele vor fi șterse împreună.';

  @override
  String get noteDeleted => 'Notiță ștersă';

  @override
  String noteCreated(String title) {
    return '\'$title\' creat';
  }

  @override
  String noteSelected(String title) {
    return '$title selectat';
  }

  @override
  String freeLimitReached(int limit) {
    return 'Versiunea gratuită permite doar $limit notițe.';
  }

  @override
  String get upgradeToStandard => 'Actualizează la Standard';

  @override
  String get upgradeFeatures =>
      'Actualizează la Standard și obține:\n\n• Crearea nelimitată de notițe\n• Stocare nelimitată de fișiere\n• Eliminarea reclamelor\n• Sincronizare în cloud';

  @override
  String get later => 'Mai târziu';

  @override
  String get upgrade => 'Actualizează';

  @override
  String get adBannerText =>
      'Zona de reclamă - Elimină cu actualizarea Standard';

  @override
  String get enterTitle => 'Te rugăm să introduci un titlu';

  @override
  String createNoteFailed(String error) {
    return 'Crearea notiței a eșuat: $error';
  }

  @override
  String deleteNoteFailed(String error) {
    return 'Ștergerea notiței a eșuat: $error';
  }

  @override
  String get upgradeComingSoon =>
      'Funcția de actualizare va fi disponibilă în curând';
}

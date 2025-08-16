// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get appName => 'Litten';

  @override
  String get home => 'Home';

  @override
  String get listen => 'Luister';

  @override
  String get write => 'Schrijf';

  @override
  String get settings => 'Instellingen';

  @override
  String get createNote => 'Maak Litten';

  @override
  String get newNote => 'Nieuwe Litten';

  @override
  String get title => 'Titel';

  @override
  String get description => 'Beschrijving';

  @override
  String get optional => '(Optioneel)';

  @override
  String get cancel => 'Annuleer';

  @override
  String get create => 'Maak';

  @override
  String get delete => 'Verwijder';

  @override
  String get search => 'Zoek';

  @override
  String get searchNotes => 'Zoek notities...';

  @override
  String get noNotesTitle => 'Maak je eerste Litten';

  @override
  String get noNotesSubtitle =>
      'Beheer stem, tekst en handschrift\nin één geïntegreerde ruimte';

  @override
  String get noSearchResults => 'Geen zoekresultaten';

  @override
  String noSearchResultsSubtitle(String query) {
    return 'Geen notities gevonden die overeenkomen met \"$query\"';
  }

  @override
  String get clearSearch => 'Zoekopdracht wissen';

  @override
  String get deleteNote => 'Verwijder notitie';

  @override
  String get deleteNoteConfirm =>
      'Weet je zeker dat je deze notitie wilt verwijderen?\nAlle bestanden worden samen verwijderd.';

  @override
  String get noteDeleted => 'Notitie verwijderd';

  @override
  String noteCreated(String title) {
    return '\'$title\' gemaakt';
  }

  @override
  String noteSelected(String title) {
    return '$title geselecteerd';
  }

  @override
  String freeLimitReached(int limit) {
    return 'Gratis versie staat slechts $limit notities toe.';
  }

  @override
  String get upgradeToStandard => 'Upgrade naar Standaard';

  @override
  String get upgradeFeatures =>
      'Upgrade naar Standaard en krijg:\n\n• Onbeperkt notities maken\n• Onbeperkte bestandsopslag\n• Advertenties verwijderen\n• Cloudsynchronisatie';

  @override
  String get later => 'Later';

  @override
  String get upgrade => 'Upgrade';

  @override
  String get adBannerText =>
      'Advertentiegebied - Verwijder met Standaard upgrade';

  @override
  String get enterTitle => 'Voer een titel in';

  @override
  String createNoteFailed(String error) {
    return 'Notitie maken mislukt: $error';
  }

  @override
  String deleteNoteFailed(String error) {
    return 'Notitie verwijderen mislukt: $error';
  }

  @override
  String get upgradeComingSoon =>
      'Upgrade functie wordt binnenkort beschikbaar';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'Litten';

  @override
  String get home => 'Accueil';

  @override
  String get listen => 'Écouter';

  @override
  String get write => 'Écrire';

  @override
  String get settings => 'Paramètres';

  @override
  String get createNote => 'Créer Litten';

  @override
  String get newNote => 'Nouveau Litten';

  @override
  String get title => 'Titre';

  @override
  String get description => 'Description';

  @override
  String get optional => '(Optionnel)';

  @override
  String get cancel => 'Annuler';

  @override
  String get create => 'Créer';

  @override
  String get delete => 'Supprimer';

  @override
  String get search => 'Rechercher';

  @override
  String get searchNotes => 'Rechercher des notes...';

  @override
  String get noNotesTitle => 'Créez votre premier Litten';

  @override
  String get noNotesSubtitle =>
      'Gérez la voix, le texte et l\'écriture manuscrite\ndans un espace intégré';

  @override
  String get noSearchResults => 'Aucun résultat de recherche';

  @override
  String noSearchResultsSubtitle(String query) {
    return 'Aucune note trouvée correspondant à \"$query\"';
  }

  @override
  String get clearSearch => 'Effacer la recherche';

  @override
  String get deleteNote => 'Supprimer la Note';

  @override
  String get deleteNoteConfirm =>
      'Êtes-vous sûr de vouloir supprimer cette note ?\nTous les fichiers seront supprimés ensemble.';

  @override
  String get noteDeleted => 'Note supprimée';

  @override
  String noteCreated(String title) {
    return '\'$title\' créé';
  }

  @override
  String noteSelected(String title) {
    return '$title sélectionné';
  }

  @override
  String freeLimitReached(int limit) {
    return 'La version gratuite permet seulement $limit notes.';
  }

  @override
  String get upgradeToStandard => 'Passer à Standard';

  @override
  String get upgradeFeatures =>
      'Passez à Standard et obtenez :\n\n• Création illimitée de notes\n• Stockage illimité de fichiers\n• Suppression des publicités\n• Synchronisation cloud';

  @override
  String get later => 'Plus tard';

  @override
  String get upgrade => 'Mettre à niveau';

  @override
  String get adBannerText =>
      'Zone publicitaire - Supprimer avec la mise à niveau Standard';

  @override
  String get enterTitle => 'Veuillez saisir un titre';

  @override
  String createNoteFailed(String error) {
    return 'Échec de création de note : $error';
  }

  @override
  String deleteNoteFailed(String error) {
    return 'Échec de suppression de note : $error';
  }

  @override
  String get upgradeComingSoon =>
      'La fonction de mise à niveau sera bientôt disponible';
}

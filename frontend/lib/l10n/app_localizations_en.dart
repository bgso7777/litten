// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Litten';

  @override
  String get home => 'Home';

  @override
  String get listen => 'Listen';

  @override
  String get write => 'Write';

  @override
  String get settings => 'Settings';

  @override
  String get createNote => 'Create Litten';

  @override
  String get newNote => 'New Litten';

  @override
  String get title => 'Title';

  @override
  String get description => 'Description';

  @override
  String get optional => '(Optional)';

  @override
  String get cancel => 'Cancel';

  @override
  String get create => 'Create';

  @override
  String get delete => 'Delete';

  @override
  String get search => 'Search';

  @override
  String get searchNotes => 'Search notes...';

  @override
  String get noNotesTitle => 'Create your first Litten';

  @override
  String get noNotesSubtitle =>
      'Manage voice, text, and handwriting\nin one integrated space';

  @override
  String get noSearchResults => 'No search results';

  @override
  String noSearchResultsSubtitle(String query) {
    return 'No notes found matching \"$query\"';
  }

  @override
  String get clearSearch => 'Clear search';

  @override
  String get deleteNote => 'Delete Note';

  @override
  String get deleteNoteConfirm =>
      'Are you sure you want to delete this note?\nAll files will be deleted together.';

  @override
  String get noteDeleted => 'Note deleted';

  @override
  String noteCreated(String title) {
    return '\'$title\' created';
  }

  @override
  String noteSelected(String title) {
    return '$title selected';
  }

  @override
  String freeLimitReached(int limit) {
    return 'Free version allows up to $limit notes only.';
  }

  @override
  String get upgradeToStandard => 'Upgrade to Standard';

  @override
  String get upgradeFeatures =>
      'Upgrade to Standard and get:\n\n• Unlimited note creation\n• Unlimited file storage\n• Ad removal\n• Cloud synchronization';

  @override
  String get later => 'Later';

  @override
  String get upgrade => 'Upgrade';

  @override
  String get adBannerText => 'Ad Area - Remove with Standard upgrade';

  @override
  String get enterTitle => 'Please enter a title';

  @override
  String createNoteFailed(String error) {
    return 'Failed to create note: $error';
  }

  @override
  String deleteNoteFailed(String error) {
    return 'Failed to delete note: $error';
  }

  @override
  String get upgradeComingSoon => 'Upgrade feature will be available soon';
}

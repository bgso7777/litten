// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Marathi (`mr`).
class AppLocalizationsMr extends AppLocalizations {
  AppLocalizationsMr([String locale = 'mr']) : super(locale);

  @override
  String get appName => 'Litten';

  @override
  String get home => 'होम';

  @override
  String get listen => 'ऐका';

  @override
  String get write => 'लिहा';

  @override
  String get settings => 'सेटिंग्स';

  @override
  String get createNote => 'Litten बनवा';

  @override
  String get newNote => 'नवीन Litten';

  @override
  String get title => 'शीर्षक';

  @override
  String get description => 'वर्णन';

  @override
  String get optional => '(पर्यायी)';

  @override
  String get cancel => 'रद्द करा';

  @override
  String get create => 'बनवा';

  @override
  String get delete => 'हटवा';

  @override
  String get search => 'शोधा';

  @override
  String get searchNotes => 'नोट्स शोधा...';

  @override
  String get noNotesTitle => 'तुमचे पहिले Litten बनवा';

  @override
  String get noNotesSubtitle =>
      'आवाज, मजकूर आणि हस्तलेखन\nएका एकीकृत जागेत व्यवस्थापित करा';

  @override
  String get noSearchResults => 'शोध परिणाम नाहीत';

  @override
  String noSearchResultsSubtitle(String query) {
    return '\"$query\" शी जुळणारे कोणतेही नोट्स सापडले नाहीत';
  }

  @override
  String get clearSearch => 'शोध साफ करा';

  @override
  String get deleteNote => 'नोट हटवा';

  @override
  String get deleteNoteConfirm =>
      'तुम्हाला खात्री आहे की तुम्ही ही नोट हटवू इच्छिता?\nसर्व फाइल्स एकत्र हटवल्या जातील.';

  @override
  String get noteDeleted => 'नोट हटवली';

  @override
  String noteCreated(String title) {
    return '\'$title\' तयार केले';
  }

  @override
  String noteSelected(String title) {
    return '$title निवडले';
  }

  @override
  String freeLimitReached(int limit) {
    return 'मुफ्त आवृत्ती केवळ $limit नोट्सना परवानगी देते.';
  }

  @override
  String get upgradeToStandard => 'स्टँडर्डला अपग्रेड करा';

  @override
  String get upgradeFeatures =>
      'स्टँडर्डमध्ये अपग्रेड करा आणि मिळवा:\n\n• अमर्यादित नोट तयार करणे\n• अमर्यादित फाइल स्टोरेज\n• जाहिरात काढणे\n• क्लाउड समक्रमण';

  @override
  String get later => 'नंतर';

  @override
  String get upgrade => 'अपग्रेड';

  @override
  String get adBannerText => 'जाहिरात क्षेत्र - स्टँडर्ड अपग्रेडसह काढा';

  @override
  String get enterTitle => 'कृपया शीर्षक प्रविष्ट करा';

  @override
  String createNoteFailed(String error) {
    return 'नोट तयार करण्यात अयशस्वी: $error';
  }

  @override
  String deleteNoteFailed(String error) {
    return 'नोट हटवण्यात अयशस्वी: $error';
  }

  @override
  String get upgradeComingSoon => 'अपग्रेड वैशिष्ट्य लवकरच उपलब्ध होईल';
}

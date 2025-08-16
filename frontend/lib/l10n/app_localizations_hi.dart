// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appName => 'लिटन';

  @override
  String get home => 'मुख्य';

  @override
  String get listen => 'सुनें';

  @override
  String get write => 'लिखें';

  @override
  String get settings => 'सेटिंग्स';

  @override
  String get createNote => 'लिटन बनाएं';

  @override
  String get newNote => 'नया लिटन';

  @override
  String get title => 'शीर्षक';

  @override
  String get description => 'विवरण';

  @override
  String get optional => '(वैकल्पिक)';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get create => 'बनाएं';

  @override
  String get delete => 'हटाएं';

  @override
  String get search => 'खोजें';

  @override
  String get searchNotes => 'नोट्स खोजें...';

  @override
  String get noNotesTitle => 'अपना पहला लिटन बनाएं';

  @override
  String get noNotesSubtitle =>
      'आवाज, पाठ और हस्तलेखन को\nएक एकीकृत स्थान में प्रबंधित करें';

  @override
  String get noSearchResults => 'कोई खोज परिणाम नहीं';

  @override
  String noSearchResultsSubtitle(String query) {
    return '\"$query\" से मेल खाने वाले कोई नोट्स नहीं मिले';
  }

  @override
  String get clearSearch => 'खोज साफ़ करें';

  @override
  String get deleteNote => 'नोट हटाएं';

  @override
  String get deleteNoteConfirm =>
      'क्या आप वाकई इस नोट को हटाना चाहते हैं?\nसभी फाइलें एक साथ हटा दी जाएंगी।';

  @override
  String get noteDeleted => 'नोट हटा दिया गया';

  @override
  String noteCreated(String title) {
    return '\'$title\' बनाया गया';
  }

  @override
  String noteSelected(String title) {
    return '$title चुना गया';
  }

  @override
  String freeLimitReached(int limit) {
    return 'निःशुल्क संस्करण केवल $limit नोट्स की अनुमति देता है।';
  }

  @override
  String get upgradeToStandard => 'स्टैंडर्ड में अपग्रेड करें';

  @override
  String get upgradeFeatures =>
      'स्टैंडर्ड में अपग्रेड करें और पाएं:\n\n• असीमित नोट निर्माण\n• असीमित फ़ाइल स्टोरेज\n• विज्ञापन हटाना\n• क्लाउड सिंक्रोनाइज़ेशन';

  @override
  String get later => 'बाद में';

  @override
  String get upgrade => 'अपग्रेड';

  @override
  String get adBannerText =>
      'विज्ञापन क्षेत्र - स्टैंडर्ड अपग्रेड के साथ हटाएं';

  @override
  String get enterTitle => 'कृपया शीर्षक दर्ज करें';

  @override
  String createNoteFailed(String error) {
    return 'नोट बनाने में विफल: $error';
  }

  @override
  String deleteNoteFailed(String error) {
    return 'नोट हटाने में विफल: $error';
  }

  @override
  String get upgradeComingSoon => 'अपग्रेड सुविधा जल्द ही उपलब्ध होगी';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appName => 'লিটেন';

  @override
  String get home => 'হোম';

  @override
  String get listen => 'শুনুন';

  @override
  String get write => 'লিখুন';

  @override
  String get settings => 'সেটিংস';

  @override
  String get createNote => 'লিটেন তৈরি করুন';

  @override
  String get newNote => 'নতুন লিটেন';

  @override
  String get title => 'শিরোনাম';

  @override
  String get description => 'বিবরণ';

  @override
  String get optional => '(ঐচ্ছিক)';

  @override
  String get cancel => 'বাতিল';

  @override
  String get create => 'তৈরি করুন';

  @override
  String get delete => 'মুছুন';

  @override
  String get search => 'অনুসন্ধান';

  @override
  String get searchNotes => 'নোট অনুসন্ধান করুন...';

  @override
  String get noNotesTitle => 'আপনার প্রথম লিটেন তৈরি করুন';

  @override
  String get noNotesSubtitle =>
      'ভয়েস, টেক্সট এবং হাতের লেখা\nএকটি সমন্বিত স্থানে পরিচালনা করুন';

  @override
  String get noSearchResults => 'কোন অনুসন্ধান ফলাফল নেই';

  @override
  String noSearchResultsSubtitle(String query) {
    return '\"$query\" এর সাথে মিলে এমন কোন নোট পাওয়া যায়নি';
  }

  @override
  String get clearSearch => 'অনুসন্ধান পরিষ্কার করুন';

  @override
  String get deleteNote => 'নোট মুছুন';

  @override
  String get deleteNoteConfirm =>
      'আপনি কি নিশ্চিত যে এই নোটটি মুছে ফেলতে চান?\nসমস্ত ফাইল একসাথে মুছে ফেলা হবে।';

  @override
  String get noteDeleted => 'নোট মুছে ফেলা হয়েছে';

  @override
  String noteCreated(String title) {
    return '\'$title\' তৈরি করা হয়েছে';
  }

  @override
  String noteSelected(String title) {
    return '$title নির্বাচিত';
  }

  @override
  String freeLimitReached(int limit) {
    return 'ফ্রি সংস্করণ শুধুমাত্র $limitটি নোটের অনুমতি দেয়।';
  }

  @override
  String get upgradeToStandard => 'স্ট্যান্ডার্ডে আপগ্রেড করুন';

  @override
  String get upgradeFeatures =>
      'স্ট্যান্ডার্ডে আপগ্রেড করুন এবং পান:\n\n• সীমাহীন নোট তৈরি\n• সীমাহীন ফাইল সংরক্ষণ\n• বিজ্ঞাপন সরানো\n• ক্লাউড সিঙ্ক্রোনাইজেশন';

  @override
  String get later => 'পরে';

  @override
  String get upgrade => 'আপগ্রেড';

  @override
  String get adBannerText =>
      'বিজ্ঞাপন এলাকা - স্ট্যান্ডার্ড আপগ্রেডের সাথে সরান';

  @override
  String get enterTitle => 'অনুগ্রহ করে একটি শিরোনাম লিখুন';

  @override
  String createNoteFailed(String error) {
    return 'নোট তৈরিতে ব্যর্থ: $error';
  }

  @override
  String deleteNoteFailed(String error) {
    return 'নোট মুছতে ব্যর্থ: $error';
  }

  @override
  String get upgradeComingSoon => 'আপগ্রেড বৈশিষ্ট্য শীঘ্রই উপলব্ধ হবে';
}

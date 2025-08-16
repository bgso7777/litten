import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('ko'),
    Locale('zh'),
    // Add other supported locales here
  ];

  // App strings
  String get appName {
    switch (locale.languageCode) {
      case 'ko':
        return '리튼';
      case 'zh':
        return '记听';
      default:
        return 'Litten';
    }
  }

  String get home {
    switch (locale.languageCode) {
      case 'ko':
        return '홈';
      case 'zh':
        return '主页';
      default:
        return 'Home';
    }
  }

  String get listen {
    switch (locale.languageCode) {
      case 'ko':
        return '듣기';
      case 'zh':
        return '听取';
      default:
        return 'Listen';
    }
  }

  String get write {
    switch (locale.languageCode) {
      case 'ko':
        return '쓰기';
      case 'zh':
        return '书写';
      default:
        return 'Write';
    }
  }

  String get settings {
    switch (locale.languageCode) {
      case 'ko':
        return '설정';
      case 'zh':
        return '设置';
      default:
        return 'Settings';
    }
  }

  String get createNote {
    switch (locale.languageCode) {
      case 'ko':
        return '리튼 생성';
      case 'zh':
        return '创建记听';
      default:
        return 'Create Litten';
    }
  }

  String get newNote {
    switch (locale.languageCode) {
      case 'ko':
        return '새 리튼';
      case 'zh':
        return '新记听';
      default:
        return 'New Litten';
    }
  }

  String get title {
    switch (locale.languageCode) {
      case 'ko':
        return '제목';
      case 'zh':
        return '标题';
      default:
        return 'Title';
    }
  }

  String get description {
    switch (locale.languageCode) {
      case 'ko':
        return '설명';
      case 'zh':
        return '描述';
      default:
        return 'Description';
    }
  }

  String get cancel {
    switch (locale.languageCode) {
      case 'ko':
        return '취소';
      case 'zh':
        return '取消';
      default:
        return 'Cancel';
    }
  }

  String get create {
    switch (locale.languageCode) {
      case 'ko':
        return '생성';
      case 'zh':
        return '创建';
      default:
        return 'Create';
    }
  }

  String get delete {
    switch (locale.languageCode) {
      case 'ko':
        return '삭제';
      case 'zh':
        return '删除';
      default:
        return 'Delete';
    }
  }

  String get searchNotes {
    switch (locale.languageCode) {
      case 'ko':
        return '노트 검색...';
      case 'zh':
        return '搜索笔记...';
      default:
        return 'Search notes...';
    }
  }

  String get noNotesTitle {
    switch (locale.languageCode) {
      case 'ko':
        return '첫 번째 리튼을 만들어보세요';
      case 'zh':
        return '创建您的第一个记听';
      default:
        return 'Create your first Litten';
    }
  }

  String get noNotesSubtitle {
    switch (locale.languageCode) {
      case 'ko':
        return '음성, 텍스트, 필기를 하나의 공간에서\n통합 관리할 수 있습니다';
      case 'zh':
        return '在一个集成空间中管理\n语音、文本和手写内容';
      default:
        return 'Manage voice, text, and handwriting\nin one integrated space';
    }
  }

  String get adBannerText {
    switch (locale.languageCode) {
      case 'ko':
        return '광고 영역 - 스탠다드 업그레이드로 제거';
      case 'zh':
        return '广告区域 - 升级标准版移除';
      default:
        return 'Ad Area - Remove with Standard upgrade';
    }
  }

  String noteCreated(String title) {
    switch (locale.languageCode) {
      case 'ko':
        return '\'$title\' 생성 완료';
      case 'zh':
        return '\'$title\' 创建完成';
      default:
        return '\'$title\' created';
    }
  }

  String noteSelected(String title) {
    switch (locale.languageCode) {
      case 'ko':
        return '$title 선택됨';
      case 'zh':
        return '已选择 $title';
      default:
        return '$title selected';
    }
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return Future.value(AppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.contains(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/themes.dart';
import '../models/litten.dart';
import '../models/audio_file.dart';
import '../models/text_file.dart';
import '../services/litten_service.dart';

class AppStateProvider extends ChangeNotifier {
  final LittenService _littenService = LittenService();
  
  // 앱 상태
  Locale _locale = const Locale('en');
  AppThemeType _themeType = AppThemeType.natureGreen;
  bool _isInitialized = false;
  bool _isFirstLaunch = true;
  
  // 리튼 관리 상태
  List<Litten> _littens = [];
  Litten? _selectedLitten;
  int _selectedTabIndex = 0;

  // 구독 상태
  SubscriptionType _subscriptionType = SubscriptionType.free;

  // Getters
  Locale get locale => _locale;
  AppThemeType get themeType => _themeType;
  ThemeData get theme => ThemeManager.getThemeByType(_themeType);
  bool get isInitialized => _isInitialized;
  bool get isFirstLaunch => _isFirstLaunch;
  List<Litten> get littens => _littens;
  Litten? get selectedLitten => _selectedLitten;
  int get selectedTabIndex => _selectedTabIndex;
  SubscriptionType get subscriptionType => _subscriptionType;
  bool get isPremiumUser => _subscriptionType != SubscriptionType.free;
  bool get isStandardUser => _subscriptionType == SubscriptionType.standard;
  bool get isPremiumPlusUser => _subscriptionType == SubscriptionType.premium;

  // 사용 제한 확인
  bool get canCreateMoreLittens {
    if (_subscriptionType != SubscriptionType.free) return true;
    return _littens.length < 5; // 무료 사용자는 최대 5개
  }

  int get maxAudioFiles {
    if (_subscriptionType != SubscriptionType.free) return -1; // 무제한
    return 10; // 무료 사용자는 최대 10개
  }

  int get maxTextFiles {
    if (_subscriptionType != SubscriptionType.free) return -1; // 무제한
    return 5; // 무료 사용자는 최대 5개
  }

  int get maxHandwritingFiles {
    if (_subscriptionType != SubscriptionType.free) return -1; // 무제한
    return 5; // 무료 사용자는 최대 5개
  }

  // 앱 초기화
  Future<void> initializeApp() async {
    if (_isInitialized) return;

    await _loadSettings();
    await _createDefaultLittensWithLocalization();
    await _loadLittens();
    await _loadSelectedLitten();
    
    _isInitialized = true;
    notifyListeners();
  }

  // 설정 로드
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 첫 실행 여부 확인
    _isFirstLaunch = !prefs.containsKey('is_app_initialized');
    
    // 언어 설정 로드
    final languageCode = prefs.getString('language_code') ?? _getSystemLanguage();
    _locale = Locale(languageCode);
    
    // 테마 설정 로드
    final themeIndex = prefs.getInt('theme_type');
    if (themeIndex != null) {
      _themeType = AppThemeType.values[themeIndex];
    } else {
      // 첫 실행 시 언어에 따른 자동 테마 설정
      _themeType = ThemeManager.getThemeByLocale(languageCode);
      await _saveThemeType(_themeType);
    }

    // 구독 상태 로드
    final subscriptionIndex = prefs.getInt('subscription_type') ?? 0;
    _subscriptionType = SubscriptionType.values[subscriptionIndex];
  }

  String _getSystemLanguage() {
    // 시스템 언어 감지 로직
    final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final supportedLanguages = [
      'en', 'zh', 'hi', 'es', 'fr', 'ar', 'bn', 'ru', 'pt', 'ur',
      'id', 'de', 'ja', 'sw', 'mr', 'te', 'tr', 'ta', 'fa', 'ko',
      'uk', 'it', 'tl', 'pl', 'ps', 'ms', 'ro', 'nl', 'ha', 'th'
    ];
    
    return supportedLanguages.contains(systemLocale.languageCode) 
        ? systemLocale.languageCode 
        : 'en';
  }

  // 리튼 로드
  Future<void> _loadLittens() async {
    _littens = await _littenService.getAllLittens();
  }

  Future<void> _loadSelectedLitten() async {
    final selectedLittenId = await _littenService.getSelectedLittenId();
    if (selectedLittenId != null) {
      _selectedLitten = await _littenService.getLittenById(selectedLittenId);
    }
  }

  // 언어 변경
  Future<void> changeLanguage(String languageCode) async {
    if (_locale.languageCode == languageCode) return;
    
    _locale = Locale(languageCode);
    await _saveLanguageCode(languageCode);
    
    // 언어 변경 시 기본 리튼들을 새로운 언어로 다시 생성
    await _recreateDefaultLittensWithNewLanguage();
    
    notifyListeners();
  }

  // 새로운 언어로 기본 리튼들 재생성
  Future<void> _recreateDefaultLittensWithNewLanguage() async {
    // 기존 기본 리튼들을 삭제
    final littens = await _littenService.getAllLittens();
    final defaultTitles = ['기본리튼', '강의', '회의', 'Default Litten', 'Lecture', 'Meeting', '默认笔记本', '讲座', '会议'];
    
    for (final litten in littens) {
      if (defaultTitles.contains(litten.title)) {
        await _littenService.deleteLitten(litten.id);
      }
    }
    
    // 새로운 언어로 기본 리튼들 생성
    await _createDefaultLittensWithLocalization();
  }

  // 테마 변경
  Future<void> changeTheme(AppThemeType themeType) async {
    _themeType = themeType;
    await _saveThemeType(themeType);
    notifyListeners();
  }

  // 구독 상태 변경
  Future<void> changeSubscriptionType(SubscriptionType subscriptionType) async {
    _subscriptionType = subscriptionType;
    await _saveSubscriptionType(subscriptionType);
    notifyListeners();
  }

  // 탭 변경
  void changeTab(int index) {
    _selectedTabIndex = index;
    notifyListeners();
  }

  // 리튼 선택
  Future<void> selectLitten(Litten litten) async {
    _selectedLitten = litten;
    await _littenService.setSelectedLittenId(litten.id);
    notifyListeners();
  }

  // 리튼 생성
  Future<void> createLitten(String title) async {
    if (!canCreateMoreLittens) {
      throw Exception('무료 사용자는 최대 5개의 리튼만 생성할 수 있습니다.');
    }

    final litten = Litten(title: title);
    await _littenService.saveLitten(litten);
    await refreshLittens();
  }

  // 리튼 이름 변경
  Future<void> renameLitten(String littenId, String newTitle) async {
    await _littenService.renameLitten(littenId, newTitle);
    await refreshLittens();
    
    // 선택된 리튼이 변경된 경우 업데이트
    if (_selectedLitten?.id == littenId) {
      _selectedLitten = _selectedLitten!.copyWith(title: newTitle);
    }
  }

  // 리튼 삭제
  Future<void> deleteLitten(String littenId) async {
    await _littenService.deleteLitten(littenId);
    await refreshLittens();
    
    // 선택된 리튼이 삭제된 경우 선택 해제
    if (_selectedLitten?.id == littenId) {
      _selectedLitten = null;
      await _littenService.setSelectedLittenId(null);
    }
  }

  // 리튼 목록 새로고침
  Future<void> refreshLittens() async {
    _littens = await _littenService.getAllLittens();
    notifyListeners();
  }

  // 설정 저장
  Future<void> _saveLanguageCode(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);
  }

  Future<void> _saveThemeType(AppThemeType themeType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_type', themeType.index);
  }

  Future<void> _saveSubscriptionType(SubscriptionType subscriptionType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('subscription_type', subscriptionType.index);
  }

  // 현지화된 기본 리튼 생성
  Future<void> _createDefaultLittensWithLocalization() async {
    // 현재 언어에 따른 기본 리튼 제목과 설명 결정
    String defaultLittenTitle, lectureTitle, meetingTitle;
    String defaultLittenDescription, lectureDescription, meetingDescription;
    
    if (_locale.languageCode == 'ko') {
      defaultLittenTitle = '기본리튼';
      lectureTitle = '강의';
      meetingTitle = '회의';
      defaultLittenDescription = '리튼을 선택하지 않고 생성된 파일들이 저장되는 기본 공간입니다.';
      lectureDescription = '강의에 관련된 파일들을 저장하세요.';
      meetingDescription = '회의에 관련된 파일들을 저장하세요.';
    } else if (_locale.languageCode == 'zh') {
      defaultLittenTitle = '默认笔记本';
      lectureTitle = '讲座';
      meetingTitle = '会议';
      defaultLittenDescription = '未选择笔记本时创建的文件将存储在此默认空间中。';
      lectureDescription = '在此处存储与讲座相关的文件。';
      meetingDescription = '在此处存储与会议相关的文件。';
    } else {
      defaultLittenTitle = 'Default Litten';
      lectureTitle = 'Lecture';
      meetingTitle = 'Meeting';
      defaultLittenDescription = 'Default space for files created without selecting a litten.';
      lectureDescription = 'Store files related to lectures here.';
      meetingDescription = 'Store files related to meetings here.';
    }
    
    await _littenService.createDefaultLittensIfNeeded(
      defaultLittenTitle: defaultLittenTitle,
      lectureTitle: lectureTitle,
      meetingTitle: meetingTitle,
      defaultLittenDescription: defaultLittenDescription,
      lectureDescription: lectureDescription,
      meetingDescription: meetingDescription,
    );
  }

  // 기존 코드와의 호환성을 위한 메서드들
  void changeTabIndex(int index) {
    changeTab(index);
  }

  Future<void> updateSubscriptionType(SubscriptionType subscriptionType) async {
    await changeSubscriptionType(subscriptionType);
  }

  // 온보딩 완료 처리
  Future<void> completeOnboarding({String? selectedLanguage, AppThemeType? selectedTheme}) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (selectedLanguage != null) {
      await changeLanguage(selectedLanguage);
    }
    
    if (selectedTheme != null) {
      await changeTheme(selectedTheme);
    }
    
    // 앱 초기화 완료 표시
    await prefs.setBool('is_app_initialized', true);
    _isFirstLaunch = false;
    notifyListeners();
  }
}

enum SubscriptionType {
  free,
  standard,
  premium,
}
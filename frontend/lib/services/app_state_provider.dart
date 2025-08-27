import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/themes.dart';
import '../models/litten.dart';
import '../services/litten_service.dart';

class AppStateProvider extends ChangeNotifier {
  final LittenService _littenService = LittenService();
  
  // 앱 상태
  Locale _locale = const Locale('en');
  AppThemeType _themeType = AppThemeType.natureGreen;
  bool _isInitialized = false;
  
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
    await _loadLittens();
    await _loadSelectedLitten();
    
    _isInitialized = true;
    notifyListeners();
  }

  // 설정 로드
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
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
    _locale = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);
    notifyListeners();
  }

  // 테마 변경
  Future<void> changeTheme(AppThemeType themeType) async {
    _themeType = themeType;
    await _saveThemeType(themeType);
    notifyListeners();
  }

  Future<void> _saveThemeType(AppThemeType themeType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_type', themeType.index);
  }

  // 구독 상태 변경
  Future<void> updateSubscriptionType(SubscriptionType subscriptionType) async {
    _subscriptionType = subscriptionType;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('subscription_type', subscriptionType.index);
    notifyListeners();
  }

  // 탭 인덱스 변경
  void changeTabIndex(int index) {
    _selectedTabIndex = index;
    notifyListeners();
  }

  // 리튼 관리
  Future<void> createLitten(String title, {String? description}) async {
    if (!canCreateMoreLittens) {
      throw Exception('무료 사용자는 최대 5개의 리튼만 생성할 수 있습니다.');
    }

    final litten = Litten(title: title, description: description);
    await _littenService.saveLitten(litten);
    await _loadLittens();
    notifyListeners();
  }

  Future<void> deleteLitten(String littenId) async {
    await _littenService.deleteLitten(littenId);
    await _loadLittens();
    
    // 삭제된 리튼이 선택된 리튼이었다면 선택 해제
    if (_selectedLitten?.id == littenId) {
      _selectedLitten = null;
      await _littenService.setSelectedLittenId(null);
    }
    
    notifyListeners();
  }

  Future<void> selectLitten(Litten? litten) async {
    _selectedLitten = litten;
    await _littenService.setSelectedLittenId(litten?.id);
    notifyListeners();
  }

  Future<void> refreshLittens() async {
    await _loadLittens();
    if (_selectedLitten != null) {
      _selectedLitten = await _littenService.getLittenById(_selectedLitten!.id);
    }
    notifyListeners();
  }
}

enum SubscriptionType {
  free,
  standard,
  premium,
}
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class PreferencesService {
  static late SharedPreferences _prefs;
  
  // 키 상수
  static const String _keyLanguageCode = 'language_code';
  static const String _keyThemeName = 'theme_name';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyAutoSaveInterval = 'auto_save_interval';
  static const String _keyMaxRecordingDuration = 'max_recording_duration';
  static const String _keyFirstLaunch = 'first_launch';
  static const String _keyAppId = 'app_id';
  static const String _keySubscriptionType = 'subscription_type';
  
  // 초기화
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  // 언어 설정
  static String? getLanguageCode() => _prefs.getString(_keyLanguageCode);
  static Future<bool> setLanguageCode(String value) => 
      _prefs.setString(_keyLanguageCode, value);
  
  // 테마 설정
  static String? getThemeName() => _prefs.getString(_keyThemeName);
  static Future<bool> setThemeName(String value) => 
      _prefs.setString(_keyThemeName, value);
  
  static ThemeMode getThemeMode() {
    final modeIndex = _prefs.getInt(_keyThemeMode) ?? 0;
    return ThemeMode.values[modeIndex];
  }
  static Future<bool> setThemeMode(ThemeMode mode) => 
      _prefs.setInt(_keyThemeMode, mode.index);
  
  // 자동 저장 간격 (초)
  static int getAutoSaveInterval() => _prefs.getInt(_keyAutoSaveInterval) ?? 60;
  static Future<bool> setAutoSaveInterval(int seconds) => 
      _prefs.setInt(_keyAutoSaveInterval, seconds);
  
  // 최대 녹음 시간 (분)
  static int getMaxRecordingDuration() => 
      _prefs.getInt(_keyMaxRecordingDuration) ?? 60;
  static Future<bool> setMaxRecordingDuration(int minutes) => 
      _prefs.setInt(_keyMaxRecordingDuration, minutes);
  
  // 첫 실행 여부
  static bool isFirstLaunch() => _prefs.getBool(_keyFirstLaunch) ?? true;
  static Future<bool> setFirstLaunchCompleted() => 
      _prefs.setBool(_keyFirstLaunch, false);
  
  // 앱 고유 ID
  static String? getAppId() => _prefs.getString(_keyAppId);
  static Future<bool> setAppId(String appId) => 
      _prefs.setString(_keyAppId, appId);
  
  // 구독 타입
  static String getSubscriptionType() => 
      _prefs.getString(_keySubscriptionType) ?? 'free';
  static Future<bool> setSubscriptionType(String type) => 
      _prefs.setString(_keySubscriptionType, type);
  
  // 모든 설정 초기화
  static Future<bool> clearAll() => _prefs.clear();
  
  // 특정 키 삭제
  static Future<bool> remove(String key) => _prefs.remove(key);
  
  // 범용 Boolean 값 저장/불러오기
  static bool? getBool(String key) => _prefs.getBool(key);
  static Future<bool> setBool(String key, bool value) => _prefs.setBool(key, value);
  
  // 디버그용: 모든 저장된 값 출력
  static void debugPrintAll() {
    final keys = _prefs.getKeys();
    print('=== PreferencesService Debug ===');
    for (final key in keys) {
      final value = _prefs.get(key);
      print('$key: $value');
    }
    print('================================');
  }
}
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../config/themes.dart';
import '../models/litten.dart';
import '../models/remind_item.dart';
import '../services/litten_service.dart';
import '../services/notification_service.dart';
import '../services/background_notification_service.dart';
import '../services/app_icon_badge_service.dart';
import '../services/file_storage_service.dart';
import '../services/audio_service.dart';
import '../services/auth_service.dart';
import '../services/notification_storage_service.dart';
import '../services/sync_service.dart';

class AppStateProvider extends ChangeNotifier with WidgetsBindingObserver {
  final LittenService _littenService = LittenService();
  final NotificationService _notificationService = NotificationService();
  final AppIconBadgeService _appIconBadgeService = AppIconBadgeService();
  final AuthServiceImpl _authService = AuthServiceImpl();
  final AudioService _audioService = AudioService();

  // 로그인/플랜 전환 감지를 위한 이전 상태
  AuthStatus _previousAuthStatus = AuthStatus.unauthenticated;
  bool _previousIsPremium = false;

  // 생성자: AuthService 리스너 등록 및 앱 생명주기 관찰자 등록
  AppStateProvider() {
    // SyncService에 AuthService 주입 (동기화 완료 시 UI 갱신 콜백 포함)
    SyncService.instance.init(_authService, onSyncStatusChanged: notifyFileListChanged);

    // AuthService의 상태 변경을 감지하여 UI 업데이트
    _authService.addListener(_onAuthStateChanged);

    // 앱 생명주기 관찰자 등록
    WidgetsBinding.instance.addObserver(this);
    debugPrint('🔄 AppStateProvider: 앱 생명주기 관찰자 등록 완료');
  }

  // 앱 상태
  Locale _locale = const Locale('en');
  AppThemeType _themeType = AppThemeType.natureGreen;
  bool _isInitialized = false;
  bool _isInitializing = false; // 중복 초기화 방지
  bool _isFirstLaunch = true;
  
  // 리튼 관리 상태
  List<Litten> _littens = [];
  Litten? _selectedLitten;
  int _selectedTabIndex = 0;

  // 선택된 리튼의 파일 카운트 (WritingScreen 헤더용)
  int _actualAudioCount = 0;
  int _actualTextCount = 0;
  int _actualHandwritingCount = 0;

  // 전체 파일 카운트 (캘린더 통계 영역용 - 항상 전체 합계)
  int _totalAudioCount = 0;
  int _totalTextCount = 0;
  int _totalHandwritingCount = 0;

  // WritingScreen 내부 탭 선택 상태
  String? _targetWritingTabId; // 'audio', 'text', 'handwriting', 'browser' 중 하나

  // 선택된 날짜의 알림 목록
  List<dynamic> _selectedDateNotifications = [];
  List<dynamic> get selectedDateNotifications => _selectedDateNotifications;

  // ⭐ 리마인드 상태
  List<RemindItem> _remindItems = [];
  String? _selectedRemindFileId;

  List<RemindItem> get remindItems => _remindItems;
  String? get selectedRemindFileId => _selectedRemindFileId;

  List<RemindItem> remindItemsForFile(String fileId) =>
      _remindItems.where((i) => i.fileId == fileId).toList();

  List<RemindTarget> get remindTargets {
    final Map<String, List<RemindItem>> grouped = {};
    for (final item in _remindItems) {
      grouped.putIfAbsent(item.fileId, () => []).add(item);
    }
    return grouped.entries.map((e) {
      final first = e.value.first;
      return RemindTarget(
        fileId: first.fileId,
        fileType: first.fileType,
        fileName: first.fileName,
        items: e.value,
      );
    }).toList();
  }

  void setSelectedRemindFileId(String? fileId) {
    _selectedRemindFileId = fileId;
    notifyListeners();
  }

  void addRemindItem(RemindItem item) {
    debugPrint('[AppStateProvider] addRemindItem: ${item.title}');
    _remindItems.add(item);
    if (_selectedRemindFileId == null) _selectedRemindFileId = item.fileId;
    _saveRemindItems();
    notifyListeners();
  }

  void toggleRemindDone(String itemId) {
    final index = _remindItems.indexWhere((i) => i.id == itemId);
    if (index == -1) return;
    debugPrint('[AppStateProvider] toggleRemindDone: $itemId');
    _remindItems[index] = _remindItems[index].copyWith(isDone: !_remindItems[index].isDone);
    _saveRemindItems();
    notifyListeners();
  }

  void deleteRemindItem(String itemId) {
    debugPrint('[AppStateProvider] deleteRemindItem: $itemId');
    _remindItems.removeWhere((i) => i.id == itemId);
    _saveRemindItems();
    notifyListeners();
  }

  Future<void> _saveRemindItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_remindItems.map((i) => i.toJson()).toList());
      await prefs.setString('remind_items', json);
      debugPrint('[AppStateProvider] 리마인드 항목 저장 완료: ${_remindItems.length}개');
    } catch (e) {
      debugPrint('[AppStateProvider] 리마인드 항목 저장 실패: $e');
    }
  }

  Future<void> _loadRemindItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('remind_items');
      if (json != null && json.isNotEmpty) {
        final list = jsonDecode(json) as List;
        _remindItems = list.map((e) => RemindItem.fromJson(e as Map<String, dynamic>)).toList();
        debugPrint('[AppStateProvider] 리마인드 항목 로드 완료: ${_remindItems.length}개');
      } else {
        _remindItems = _sampleRemindItems();
        debugPrint('[AppStateProvider] 샘플 리마인드 항목 주입: ${_remindItems.length}개');
      }
    } catch (e) {
      debugPrint('[AppStateProvider] 리마인드 항목 로드 실패: $e');
    }
  }

  List<RemindItem> _sampleRemindItems() {
    final now = DateTime.now();
    const file1Id = 'sample-file-1';
    const file2Id = 'sample-file-2';
    return [
      RemindItem(fileId: file1Id, fileType: RemindFileType.audio, fileName: '항목1', littenId: 'sample', title: '세부항목1-1', createdAt: now.subtract(const Duration(minutes: 3))),
      RemindItem(fileId: file1Id, fileType: RemindFileType.audio, fileName: '항목1', littenId: 'sample', title: '세부항목1-2', content: '내용~~~~~~~~~~~~\n내용~~~~~~~~~~~~', createdAt: now.subtract(const Duration(minutes: 2))),
      RemindItem(fileId: file1Id, fileType: RemindFileType.audio, fileName: '항목1', littenId: 'sample', title: '세부항목1-3', createdAt: now.subtract(const Duration(minutes: 1))),
      RemindItem(fileId: file2Id, fileType: RemindFileType.text,  fileName: '항목2', littenId: 'sample', title: '세부항목2-1', createdAt: now.subtract(const Duration(seconds: 30))),
      RemindItem(fileId: file2Id, fileType: RemindFileType.text,  fileName: '항목2', littenId: 'sample', title: '세부항목2-2', createdAt: now),
    ];
  }

  // 선택된 날짜의 알림 설정
  void setSelectedDateNotifications(List<dynamic> notifications) {
    _selectedDateNotifications = notifications;
    notifyListeners();
  }

  // ⭐ STT 실행 상태 (텍스트 탭에서 STT 사용 중인지 여부)
  bool _isSTTActive = false;
  bool get isSTTActive => _isSTTActive;

  void setSTTActive(bool isActive) {
    _isSTTActive = isActive;
    notifyListeners();
    debugPrint('🎤 STT 상태 변경: $isActive');
  }

  // ⭐ 현재 활성 탭 위치 저장 (위젯 재생성 시에도 유지)
  String _currentWritingTabId = 'text'; // WritingScreen 내부의 현재 활성 탭 (기본값: text)
  int _currentMainTabIndex = 0; // 메인 탭 인덱스 (0: 홈, 1: 쓰기, 2: 설정)

  // ⭐ 노트탭 가시성 설정 (기본: 전체탭만 표시)
  Set<String> _noteTabVisibility = {'all'};

  // ⭐ 시작 화면 설정 (기본: note)
  String _startScreen = 'note'; // 'note' | 'calendar'

  // ⭐ 도킹 사용 여부 (기본: false) — deprecated, visibleAreas로 대체
  bool _dockingEnabled = false;

  // ⭐ 영역 보기 설정 — 보이는 쿼드런트 집합 (topLeft는 항상 포함)
  Set<String> _visibleAreas = {'topLeft'};

  // ⭐ 광고 표시 여부 (기본: false - 나중에 활성화 가능)
  bool _adsEnabled = false;

  // ⭐ WritingScreen 탭 위치 저장 (all, text, handwriting, audio, browser 각각의 위치)
  Map<String, String> _writingTabPositions = {
    'all': 'topLeft',
    'text': 'topLeft',
    'handwriting': 'topLeft',
    'audio': 'topLeft',
    'browser': 'topLeft',
  };

  // HomeScreen 하단 탭 선택 상태 (0: 파일, 1: 일정)
  int _homeBottomTabIndex = 0;

  // ⭐ 파일 목록 변경 추적 (PDF 변환 등으로 파일이 추가될 때 증가)
  int _fileListVersion = 0;
  int get fileListVersion => _fileListVersion;

  // 캘린더 상태
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDate = DateTime.now();
  bool _isDateSelected = false; // 날짜 선택 여부

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
  String? get targetWritingTabId => _targetWritingTabId;
  int get homeBottomTabIndex => _homeBottomTabIndex;
  SubscriptionType get subscriptionType => _subscriptionType;
  bool get isPremiumUser => _subscriptionType != SubscriptionType.free;
  bool get isStandardUser => _subscriptionType == SubscriptionType.standard;
  bool get isPremiumPlusUser => _subscriptionType == SubscriptionType.premium;

  // ⭐ 현재 활성 탭 위치 Getters
  String get currentWritingTabId => _currentWritingTabId;
  int get currentMainTabIndex => _currentMainTabIndex;
  Map<String, String> get writingTabPositions => _writingTabPositions;
  Set<String> get noteTabVisibility => _noteTabVisibility;
  String get startScreen => _startScreen;
  bool get dockingEnabled => _dockingEnabled;
  Set<String> get visibleAreas => _visibleAreas;
  bool get adsEnabled => _adsEnabled;

  // 알림 서비스 관련 Getters
  NotificationService get notificationService => _notificationService;
  AppIconBadgeService get appIconBadgeService => _appIconBadgeService;

  // 인증 서비스 관련 Getters
  AuthServiceImpl get authService => _authService;
  bool get isLoggedIn => _authService.authStatus == AuthStatus.authenticated;
  User? get currentUser => _authService.currentUser;

  // 오디오 서비스 관련 Getters
  AudioService get audioService => _audioService;
  bool get isRecording => _audioService.isRecording;

  // 선택 리튼 파일 카운트 Getters (WritingScreen 헤더용)
  int get actualAudioCount => _actualAudioCount;
  int get actualTextCount => _actualTextCount;
  int get actualHandwritingCount => _actualHandwritingCount;

  // 전체 파일 카운트 Getters (캘린더 통계 영역용 - 항상 전체 합계)
  int get totalAudioCount => _totalAudioCount;
  int get totalTextCount => _totalTextCount;
  int get totalHandwritingCount => _totalHandwritingCount;

  // 캘린더 관련 Getters
  DateTime get selectedDate => _selectedDate;
  DateTime get focusedDate => _focusedDate;
  bool get isDateSelected => _isDateSelected;
  
  // 선택된 날짜의 리튼들
  List<Litten> get littensForSelectedDate {
    return _littens.where((litten) {
      final littenDate = DateTime(
        litten.createdAt.year,
        litten.createdAt.month,
        litten.createdAt.day,
      );
      final selected = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      return littenDate.isAtSameMomentAs(selected);
    }).toList();
  }

  // 사용 제한 확인 (undefined 리튼 제외)
  bool get canCreateMoreLittens {
    if (_subscriptionType != SubscriptionType.free) return true;
    // undefined 리튼을 제외한 개수 계산
    final userLittensCount = _littens.where((l) => l.title != 'undefined').length;
    return userLittensCount < 5; // 무료 사용자는 최대 5개
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
    if (_isInitialized || _isInitializing) return;
    _isInitializing = true;

    await _loadSettings();
    await _loadRemindItems();
    // 기본 리튼은 온보딩 완료 후에만 생성
    await _loadLittens();

    // undefined 리튼 확인 및 생성
    await _ensureUndefinedLitten();

    // ⭐ 앱 콜드 스타트 시 선택 초기화 (이전 세션 선택 미복원)
    // background→foreground 재개 시는 _restoreSelectedLittenState()가 복원함
    _selectedLitten = null;
    await _littenService.setSelectedLittenId(null);
    final _startPrefs = await SharedPreferences.getInstance();
    await _startPrefs.remove('selected_litten_id');
    debugPrint('🔄 콜드 스타트: 선택 리튼 초기화 완료');

    // 캘린더를 오늘 날짜로 초기화
    final today = DateTime.now();
    _selectedDate = today;
    _focusedDate = today;

    // 인증 상태 확인
    await _authService.checkAuthStatus();

    // 앱 아이콘 배지 서비스 초기화
    _appIconBadgeService.initialize();

    // 알림 서비스 초기화 및 시작 (재시도 로직 포함)
    try {
      debugPrint('🔔 알림 서비스 초기화 시작');

      // 백그라운드 알림 서비스 초기화 (재시도 포함)
      final bgService = BackgroundNotificationService();
      await bgService.initialize();

      // 알림 체커 시작
      _notificationService.onNotificationFired = _onNotificationFired;
      _notificationService.startNotificationChecker();
      _notificationService.addListener(_onNotificationChanged);

      // 알림 스케줄 업데이트
      _updateNotificationSchedule();

      // 백그라운드 작업 등록
      await bgService.registerBackgroundTask();

      debugPrint('✅ 알림 서비스 초기화 완료');
    } catch (e) {
      debugPrint('❌ 알림 서비스 초기화 실패: $e');
      // 초기화 실패해도 앱은 계속 실행
      // 5초 후 재시도
      Future.delayed(const Duration(seconds: 5), () {
        _notificationService.startNotificationChecker();
        _updateNotificationSchedule();
      });
    }

    _isInitialized = true;
    _isInitializing = false;
    notifyListeners();

    // 앱 시작 동기화 (비동기 fire-and-forget)
    SyncService.instance.syncOnAppStart();
    // 미동기화 로컬 파일 일괄 업로드 (프리미엄 여부는 내부에서 판단)
    final startLittenIds = _littens.map((l) => l.id).toList();
    SyncService.instance.uploadAllLocalFiles(startLittenIds);
  }

  // 인증 상태 변경 핸들러
  void _onAuthStateChanged() {
    final newStatus = _authService.authStatus;
    final currentIsPremium = _authService.currentUser?.isPremium ?? false;

    if (_isInitialized) {
      // 로그아웃 → 로그인 전환 시 구독 플랜 동기화 + 동기화 시작
      if (_previousAuthStatus != AuthStatus.authenticated &&
          newStatus == AuthStatus.authenticated) {
        final serverPlan = _authService.currentUser?.subscriptionPlan ?? SubscriptionPlan.free;
        final serverType = _planToSubscriptionType(serverPlan);
        // 서버 플랜이 더 높을 때만 업데이트
        // (로그인 전에 로컬에서 선택한 플랜이 더 높으면 유지)
        if (_subscriptionTypeLevel(serverType) > _subscriptionTypeLevel(_subscriptionType)) {
          _subscriptionType = serverType;
          _saveSubscriptionType(_subscriptionType);
          debugPrint('[AppStateProvider] 로그인 시 서버 플랜으로 업그레이드: $_subscriptionType');
        } else {
          debugPrint('[AppStateProvider] 로그인 시 로컬 플랜 유지: $_subscriptionType (서버: $serverType)');
          // AuthService에도 로컬 플랜 동기화
          _authService.updateLocalSubscriptionPlan(_subscriptionTypeToPlan(_subscriptionType));
        }
        SyncService.instance.syncOnLogin();
        // 로그인 시 미동기화 로컬 파일 일괄 업로드
        final littenIds = _littens.map((l) => l.id).toList();
        SyncService.instance.uploadAllLocalFiles(littenIds);
      }
      // 비프리미엄 → 프리미엄 업그레이드 시 일괄 업로드
      else if (newStatus == AuthStatus.authenticated &&
          !_previousIsPremium &&
          currentIsPremium) {
        _subscriptionType = SubscriptionType.premium;
        _saveSubscriptionType(_subscriptionType);
        debugPrint('[AppStateProvider] 프리미엄 업그레이드 감지 - 로컬 파일 일괄 업로드');
        SyncService.instance.syncOnLogin();
        final littenIds = _littens.map((l) => l.id).toList();
        SyncService.instance.uploadAllLocalFiles(littenIds);
      }
    }

    _previousAuthStatus = newStatus;
    _previousIsPremium = currentIsPremium;
    debugPrint('[AppStateProvider] 인증 상태 변경: $newStatus, isPremium: $currentIsPremium');
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

    // TODO: 개발 중 — 구독 플랜 강제 프리미엄 (출시 전 제거)
    _subscriptionType = SubscriptionType.premium;
    await prefs.setString('subscription_type', _subscriptionType.name);
    debugPrint('💰 [AppStateProvider] 개발 모드 — 구독 상태 강제 프리미엄: $_subscriptionType');

    // ⭐ 쓰기 탭 위치 복원 (저장된 값이 없으면 기본값 'text' 사용)
    _currentWritingTabId = prefs.getString('current_writing_tab_id') ?? 'text';
    debugPrint('✅ [AppStateProvider] 저장된 쓰기 탭 위치 복원: $_currentWritingTabId');

    // ⭐ 각 탭의 위치 복원 (all, text, handwriting, audio, browser)
    final savedTabPositionAll = prefs.getString('tab_position_all');
    _writingTabPositions = {
      'all':         savedTabPositionAll ?? 'topLeft',
      'text':        prefs.getString('tab_position_text') ?? 'topLeft',
      'handwriting': prefs.getString('tab_position_handwriting') ?? 'topLeft',
      'audio':       prefs.getString('tab_position_audio') ?? 'topLeft',
      'browser':     prefs.getString('tab_position_browser') ?? 'topLeft',
    };
    debugPrint('✅ [AppStateProvider] 저장된 탭 위치들 복원: $_writingTabPositions');

    // ⭐ 노트탭 가시성 복원 (기본: 전체탭만)
    final savedVisibility = prefs.getStringList('note_tab_visibility');
    if (savedVisibility != null && savedVisibility.isNotEmpty) {
      _noteTabVisibility = savedVisibility.toSet();
    } else {
      _noteTabVisibility = {'all'};
    }
    debugPrint('✅ [AppStateProvider] 노트탭 가시성 복원: $_noteTabVisibility');

    // ⭐ 시작 화면 복원 (기본: note)
    _startScreen = prefs.getString('start_screen') ?? 'note';
    debugPrint('✅ [AppStateProvider] 시작 화면 복원: $_startScreen');

    _dockingEnabled = prefs.getBool('docking_enabled') ?? false;
    debugPrint('✅ [AppStateProvider] 도킹 사용 여부 복원: $_dockingEnabled');

    // 영역 보기 복원
    final savedAreas = prefs.getStringList('visible_areas');
    final isFirstLaunch = savedAreas == null && savedVisibility == null && savedTabPositionAll == null;

    if (isFirstLaunch) {
      // 최초 설치 — 디바이스 타입에 따른 기본값 적용
      final isTablet = _detectIsTablet();
      debugPrint('📱 [AppStateProvider] 최초 설치 감지 — 디바이스: ${isTablet ? "패드" : "폰"}');

      if (isTablet) {
        // 패드 기본값: 4분할 + 전체탭 활성화 + 각 영역에 탭 배치
        _visibleAreas    = {'topLeft', 'topRight', 'bottomLeft', 'bottomRight'};
        _noteTabVisibility = {'all', 'text', 'handwriting', 'audio', 'browser'};
        _writingTabPositions = {
          'all':         'topLeft',
          'handwriting': 'topRight',
          'text':        'bottomLeft',
          'audio':       'bottomRight',
          'browser':     'bottomRight',
        };
      } else {
        // 폰 기본값: 좌상단만 + 전체탭만
        _visibleAreas      = {'topLeft'};
        _noteTabVisibility = {'all'};
        _writingTabPositions = {
          'all': 'topLeft', 'text': 'topLeft',
          'handwriting': 'topLeft', 'audio': 'topLeft', 'browser': 'topLeft',
        };
      }

      // SharedPreferences에 기본값 저장
      await prefs.setStringList('visible_areas', _visibleAreas.toList());
      await prefs.setStringList('note_tab_visibility', _noteTabVisibility.toList());
      for (final entry in _writingTabPositions.entries) {
        await prefs.setString('tab_position_${entry.key}', entry.value);
      }
      debugPrint('💾 [AppStateProvider] 디바이스 기본값 저장 완료: visibleAreas=$_visibleAreas');
    } else if (savedAreas != null) {
      _visibleAreas = {'topLeft', ...savedAreas};
    } else {
      // 기존 사용자 마이그레이션 (docking_enabled → visibleAreas)
      _visibleAreas = _dockingEnabled ? {'topLeft', 'bottomLeft'} : {'topLeft'};
    }
    debugPrint('✅ [AppStateProvider] 영역 보기 복원: $_visibleAreas');

    _adsEnabled = prefs.getBool('ads_enabled') ?? false;
    debugPrint('✅ [AppStateProvider] 광고 표시 여부 복원: $_adsEnabled');
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
    // 파일 카운트 업데이트
    await updateFileCount();
  }

  // undefined 리튼 확인 및 생성
  Future<void> _ensureUndefinedLitten() async {
    // undefined 리튼이 이미 존재하는지 확인
    final undefinedExists = _littens.any((l) => l.title == 'undefined');

    if (!undefinedExists) {
      // undefined 리튼 생성
      final undefinedLitten = Litten(
        title: 'undefined',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _littenService.saveLitten(undefinedLitten);
      await _loadLittens(); // 리튼 목록 재로드

      debugPrint('✅ undefined 리튼 생성 완료');
    }
  }

  Future<void> _loadSelectedLitten() async {
    final selectedLittenId = await _littenService.getSelectedLittenId();
    if (selectedLittenId != null) {
      final litten = await _littenService.getLittenById(selectedLittenId);
      // undefined는 기본 선택으로 복원하지 않음
      if (litten != null && litten.title != 'undefined') {
        _selectedLitten = litten;
        debugPrint('✅ 선택된 리튼 복원: ${litten.title}');
      } else {
        _selectedLitten = null;
        debugPrint('ℹ️ 저장된 리튼이 undefined 또는 없음 - 선택 없음으로 시작');
      }
    }
  }

  // 언어 변경
  Future<void> changeLanguage(String languageCode) async {
    if (_locale.languageCode == languageCode) return;
    
    _locale = Locale(languageCode);
    await _saveLanguageCode(languageCode);
    
    // 온보딩 중이 아닌 경우에만 기본 리튼들 재생성
    if (!_isFirstLaunch) {
      await _recreateDefaultLittensWithNewLanguage();
    }
    
    notifyListeners();
  }

  // 새로운 언어로 기본 리튼들 재생성
  Future<void> _recreateDefaultLittensWithNewLanguage() async {
    // 기존 기본 리튼들을 삭제
    final littens = await _littenService.getAllLittens();
    final defaultTitles = [
      // Korean
      '기본리튼', '강의', '회의', '강의 (샘플)', '모임 (샘플)',
      // English
      'Default Litten', 'Lecture', 'Meeting',
      // Chinese
      '默认笔记本', '讲座', '会议',
      // Hindi
      'डिफ़ॉल्ट लिट्टेन', 'व्याख्यान', 'मीटिंग',
      // Spanish
      'Litten Predeterminado', 'Conferencia', 'Reunión',
      // French
      'Litten par Défaut', 'Conférence', 'Réunion',
      // Arabic
      'ليتن افتراضي', 'محاضرة', 'اجتماع',
      // Bengali
      'ডিফল্ট লিটেন', 'লেকচার', 'মিটিং',
      // Russian
      'Литтен по умолчанию', 'Лекция', 'Встреча',
      // Portuguese
      'Litten Padrão', 'Palestra', 'Reunião',
      // Urdu
      'ڈیفالٹ لٹن', 'لیکچر', 'میٹنگ',
      // Indonesian
      'Litten Default', 'Kuliah', 'Rapat',
      // German
      'Standard-Litten', 'Vorlesung', 'Besprechung',
      // Japanese
      'デフォルトリッテン', '講義', 'ミーティング',
      // Swahili
      'Litten Chaguo-msingi', 'Hotuba', 'Mkutano',
      // Marathi
      'डिफॉल्ट लिट्टन', 'व्याख्यान', 'सभा',
      // Telugu
      'డిఫాల్ట్ లిట్టెన్', 'ఉపన్యాసం', 'సమావేశం',
      // Turkish
      'Varsayılan Litten', 'Ders', 'Toplantı',
      // Tamil
      'இயல்புநிலை லிட்டன்', 'விரிவுரை', 'கூட்டம்',
      // Persian
      'لیتن پیش‌فرض', 'سخنرانی', 'جلسه',
      // Ukrainian
      'Літтен за замовчуванням', 'Лекція', 'Зустріч',
      // Italian
      'Litten Predefinito', 'Lezione', 'Riunione',
      // Filipino
      'Default na Litten', 'Lektura', 'Pulong',
      // Polish
      'Domyślny Litten', 'Wykład', 'Spotkanie',
      // Pashto
      'د پیل لیټن', 'لیکچر', 'غونډه',
      // Malay
      'Litten Lalai', 'Kuliah', 'Mesyuarat',
      // Romanian
      'Litten Implicit', 'Prelegere', 'Întâlnire',
      // Dutch
      'Standaard Litten', 'Lezing', 'Vergadering',
      // Hausa
      'Litten na Asali', 'Lacca', 'Taro',
      // Thai
      'ลิทเทนเริ่มต้น', 'การบรรยาย', 'การประชุม',
    ];
    
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
    // AuthService.currentUser 동기화 (SyncService._canSync 체크용)
    if (_authService.authStatus == AuthStatus.authenticated) {
      final plan = _subscriptionTypeToPlan(subscriptionType);
      await _authService.updateLocalSubscriptionPlan(plan);
    }
    notifyListeners();
  }

  SubscriptionType _planToSubscriptionType(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free: return SubscriptionType.free;
      case SubscriptionPlan.standard: return SubscriptionType.standard;
      case SubscriptionPlan.premium: return SubscriptionType.premium;
    }
  }

  SubscriptionPlan _subscriptionTypeToPlan(SubscriptionType type) {
    switch (type) {
      case SubscriptionType.free: return SubscriptionPlan.free;
      case SubscriptionType.standard: return SubscriptionPlan.standard;
      case SubscriptionType.premium: return SubscriptionPlan.premium;
    }
  }

  SubscriptionType _planNameToType(String planName) {
    switch (planName) {
      case 'standard': return SubscriptionType.standard;
      case 'premium': return SubscriptionType.premium;
      default: return SubscriptionType.free;
    }
  }

  // free=0, standard=1, premium=2 — 플랜 높낮이 비교용
  int _subscriptionTypeLevel(SubscriptionType type) {
    switch (type) {
      case SubscriptionType.standard: return 1;
      case SubscriptionType.premium: return 2;
      default: return 0;
    }
  }

  // 탭 변경
  void changeTab(int index) {
    _selectedTabIndex = index;
    notifyListeners();
  }

  // 노트탭 진입 시 클라우드 동기화 (로컬 ↔ 클라우드 최신 파일 비교 적용)
  void syncNoteTab() {
    final littenIds = _littens.map((l) => l.id).toList();
    debugPrint('[AppStateProvider] syncNoteTab - ${littenIds.length}개 리튼 동기화');
    SyncService.instance.syncOnNoteTab(littenIds);
  }

  // WritingScreen 내부 탭 설정 (파일 타입에 따라)
  void setTargetWritingTab(String? tabId) {
    _targetWritingTabId = tabId;
    notifyListeners();
  }

  // 파일 목록 변경 알림 (PDF 변환 등으로 파일이 추가/삭제될 때 호출)
  void notifyFileListChanged() {
    _fileListVersion++;
    debugPrint('📄 AppStateProvider: 파일 목록 변경 알림 - UI 강제 새로고침 (version: $_fileListVersion)');
    notifyListeners();
  }

  // 리튼 선택
  Future<void> selectLitten(Litten litten) async {
    debugPrint('🔄 리튼 선택 시도: ${litten.title} (${litten.id})');

    // 녹음 중인지 확인
    if (_audioService.isRecording) {
      debugPrint('⚠️ 녹음 중에는 리튼을 변경할 수 없습니다.');
      throw Exception('녹음 중에는 리튼을 변경할 수 없습니다. 녹음을 중지한 후 다시 시도해주세요.');
    }

    _selectedLitten = litten;

    // undefined 리튼 선택은 세션 내에서만 유지 (영구 저장 안 함)
    // → 앱 재시작 시 undefined가 기본 선택되는 것 방지
    if (litten.title != 'undefined') {
      await _littenService.setSelectedLittenId(litten.id);
      await _saveSelectedLittenState();
    } else {
      debugPrint('ℹ️ undefined 리튼 선택 - 세션 내에서만 유지 (영구 저장 생략)');
    }

    // 리튼 선택 시 파일 카운트 업데이트
    await updateFileCount();

    notifyListeners();
    debugPrint('✅ 리튼 선택 완료 및 영구 저장');
  }

  Future<void> clearSelectedLitten() async {
    debugPrint('🔄 선택된 리튼 해제');
    _selectedLitten = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selected_litten_id');
    await updateFileCount();
    notifyListeners();
    debugPrint('✅ 리튼 선택 해제 완료');
  }

  // 선택된 리튼 상태 저장
  Future<void> _saveSelectedLittenState() async {
    final prefs = await SharedPreferences.getInstance();
    if (_selectedLitten != null) {
      await prefs.setString('selected_litten_id', _selectedLitten!.id);
      debugPrint('💾 선택된 리튼 ID 저장: ${_selectedLitten!.id}');
    } else {
      await prefs.remove('selected_litten_id');
      debugPrint('💾 선택된 리튼 ID 제거');
    }
  }

  // 선택된 리튼 상태 복원
  Future<void> _restoreSelectedLittenState() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedLittenId = prefs.getString('selected_litten_id');

    if (selectedLittenId != null) {
      // 메모리에서 먼저 찾기
      final memoryLitten = _littens.firstWhere(
        (l) => l.id == selectedLittenId,
        orElse: () => Litten(
          id: '',
          title: '',
          description: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // undefined는 복원하지 않음
      if (memoryLitten.id.isNotEmpty && memoryLitten.title != 'undefined') {
        _selectedLitten = memoryLitten;
        debugPrint('🔄 메모리에서 리튼 복원: ${memoryLitten.title} (${memoryLitten.id})');
        notifyListeners();
        return;
      } else if (memoryLitten.title == 'undefined') {
        debugPrint('ℹ️ 복원 대상이 undefined 리튼 - 선택 해제 유지');
        return;
      }

      // 메모리에 없으면 스토리지에서 로드
      final litten = await _littenService.getLittenById(selectedLittenId);
      if (litten != null && litten.title != 'undefined') {
        _selectedLitten = litten;
        // 메모리 리스트도 업데이트
        final index = _littens.indexWhere((l) => l.id == litten.id);
        if (index != -1) {
          _littens[index] = litten;
        } else {
          _littens.add(litten);
        }
        debugPrint('🔄 스토리지에서 리튼 복원: ${litten.title} (${litten.id})');
        notifyListeners();
      } else {
        debugPrint('⚠️ 저장된 리튼 ID를 찾을 수 없거나 undefined: $selectedLittenId');
        _selectedLitten = null;
      }
    }
  }

  // 리튼 생성
  Future<Litten> createLitten(String title, {LittenSchedule? schedule}) async {
    debugPrint('🔄 리튼 생성 시작: $title');

    try {
      if (!canCreateMoreLittens) {
        debugPrint('❌ 리튼 생성 실패: 최대 생성 개수 초과');
        throw Exception('무료 사용자는 최대 5개의 리튼만 생성할 수 있습니다.');
      }

      // 제목 유효성 검사
      if (title.trim().isEmpty) {
        debugPrint('❌ 리튼 생성 실패: 빈 제목');
        throw Exception('리튼 제목을 입력해주세요.');
      }

      // 스케줄 유효성 검사
      if (schedule != null) {
        final startTime = schedule.startTime;
        final endTime = schedule.endTime;
        if (startTime.hour == endTime.hour && startTime.minute >= endTime.minute) {
          debugPrint('❌ 리튼 생성 실패: 잘못된 시간 설정');
          throw Exception('시작 시간이 종료 시간보다 늦을 수 없습니다.');
        }
        debugPrint('📅 일정 정보: ${schedule.date} ${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')} - ${endTime.hour}:${endTime.minute.toString().padLeft(2, '0')}');
        debugPrint('   종료일자: ${schedule.endDate}');
        debugPrint('   알림 규칙: ${schedule.notificationRules.length}개');
      }

      // 스케줄이 있으면 스케줄 날짜 사용, 없으면 선택된 날짜 사용
      final targetDate = schedule?.date ?? _selectedDate;
      final selectedDateTime = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        DateTime.now().hour,
        DateTime.now().minute,
        DateTime.now().second,
        DateTime.now().millisecond,
        DateTime.now().microsecond,
      );

      final litten = Litten(
        title: title.trim(),
        createdAt: selectedDateTime,
        updatedAt: selectedDateTime,
        schedule: schedule,
      );

      await _littenService.saveLitten(litten);
      await refreshLittens();
      _updateNotificationSchedule();

      debugPrint('✅ 리튼 생성 완료: ${litten.id} - $title');
      return litten;
    } catch (e) {
      debugPrint('❌ 리튼 생성 에러: $e');
      rethrow;
    }
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

  // 리튼 업데이트
  Future<void> updateLitten(Litten updatedLitten) async {
    debugPrint('🔄 리튼 업데이트 시작: ${updatedLitten.id} - ${updatedLitten.title}');

    try {
      await _littenService.saveLitten(updatedLitten);
      await refreshLittens();

      // 선택된 리튼이 변경된 경우 업데이트
      if (_selectedLitten?.id == updatedLitten.id) {
        _selectedLitten = updatedLitten;
      }

      // 알림 스케줄 업데이트 - 매우 중요!
      _updateNotificationSchedule();

      debugPrint('✅ 리튼 업데이트 완료: ${updatedLitten.id}');
    } catch (e) {
      debugPrint('❌ 리튼 업데이트 에러: $e');
      rethrow;
    }
  }

  // 리튼 삭제
  Future<void> deleteLitten(String littenId) async {
    debugPrint('🗑️ 리튼 삭제 시도: $littenId');

    // 녹음 중인지 확인
    if (_audioService.isRecording) {
      debugPrint('⚠️ 녹음 중에는 리튼을 삭제할 수 없습니다.');
      throw Exception('녹음 중에는 리튼을 삭제할 수 없습니다. 녹음을 중지한 후 다시 시도해주세요.');
    }

    await _littenService.deleteLitten(littenId);
    await refreshLittens();

    if (_selectedLitten?.id == littenId) {
      _selectedLitten = null;
      await _littenService.setSelectedLittenId(null);
      debugPrint('✅ 리튼 삭제 후 선택 해제');
    }
  }

  // 리튼 날짜 이동
  Future<void> moveLittenToDate(String littenId, DateTime targetDate) async {
    debugPrint('📅 리튼 날짜 이동 시도: $littenId');

    // 녹음 중인지 확인
    if (_audioService.isRecording) {
      debugPrint('⚠️ 녹음 중에는 리튼 날짜를 이동할 수 없습니다.');
      throw Exception('녹음 중에는 리튼 날짜를 이동할 수 없습니다. 녹음을 중지한 후 다시 시도해주세요.');
    }

    final litten = _littens.firstWhere((l) => l.id == littenId);
    
    // 기존 시간을 유지하면서 날짜만 변경
    final newDateTime = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      litten.createdAt.hour,
      litten.createdAt.minute,
      litten.createdAt.second,
      litten.createdAt.millisecond,
      litten.createdAt.microsecond,
    );
    
    final newLitten = Litten(
      id: litten.id,
      title: litten.title,
      description: litten.description,
      createdAt: newDateTime,
      updatedAt: DateTime.now(),
      audioFileIds: litten.audioFileIds,
      textFileIds: litten.textFileIds,
      handwritingFileIds: litten.handwritingFileIds,
    );
    
    await _littenService.saveLitten(newLitten);
    await refreshLittens();
  }

  // 리튼 목록 새로고침
  Future<void> refreshLittens() async {
    debugPrint('🔄 refreshLittens 시작');
    _littens = await _littenService.getAllLittens();

    // 선택된 리튼이 있다면 업데이트된 데이터로 다시 설정
    if (_selectedLitten != null) {
      _selectedLitten = _littens.where((l) => l.id == _selectedLitten!.id).firstOrNull;
    }

    // 파일 카운트 업데이트
    debugPrint('🔄 파일 카운트 업데이트 호출');
    await updateFileCount();

    _updateNotificationSchedule();
    notifyListeners();
    debugPrint('🔄 refreshLittens 완료');
  }

  void _updateNotificationSchedule() async {
    // Child 리튼 생성이 녹음이나 리튼 선택을 방해하지 않도록 비동기 처리
    try {
      await _notificationService.scheduleNotifications(_littens).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('⚠️ 알림 스케줄링 타임아웃');
        },
      );
    } catch (e) {
      debugPrint('❌ 알림 스케줄링 오류: $e');
    }
  }

  void _onNotificationChanged() {
    final notificationCount = _notificationService.firedNotifications.length;
    _appIconBadgeService.updateBadge(notificationCount);
  }

  /// 알림 서비스가 실행 중인지 확인하고 필요시 재시작
  void _ensureNotificationServiceRunning() {
    try {
      debugPrint('🔍 알림 서비스 상태 확인');

      // NotificationService의 타이머가 활성화되어 있는지 확인
      // 타이머가 없거나 비활성화되어 있으면 재시작
      if (!_notificationService.isRunning) {
        debugPrint('⚠️ 알림 서비스가 중지됨 - 재시작');
        _notificationService.startNotificationChecker();
        _updateNotificationSchedule();
      } else {
        // isRunning이 true여도 실제 타이머가 비활성화되었을 수 있으므로
        // NotificationService 내부에서 헬스 체크를 수행하도록 함
        debugPrint('✅ 알림 서비스 실행 중 (내부 헬스 체크 수행)');
        
        // 수동으로 헬스 체크 트리거 (타이머가 멈췄는지 확인)
        Future.delayed(const Duration(milliseconds: 100), () {
          _notificationService.manualCheckNotifications();
        });
      }
    } catch (e) {
      debugPrint('❌ 알림 서비스 상태 확인 실패: $e');
      // 오류 발생 시 안전하게 재시작
      try {
        _notificationService.startNotificationChecker();
        _updateNotificationSchedule();
      } catch (retryError) {
        debugPrint('❌ 알림 서비스 재시작도 실패: $retryError');
      }
    }
  }

  @override
  void dispose() {
    debugPrint('🔄 AppStateProvider: 리소스 정리 시작');
    WidgetsBinding.instance.removeObserver(this);
    _authService.removeListener(_onAuthStateChanged);
    _notificationService.removeListener(_onNotificationChanged);
    _notificationService.dispose();
    super.dispose();
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
    // AuthService와 동일한 string 포맷으로 저장 (key 충돌 방지)
    await prefs.setString('subscription_type', subscriptionType.name);
  }

  // 현지화된 기본 리튼 생성
  Future<void> _createDefaultLittensWithLocalization() async {
    // 현재 언어에 따른 기본 리튼 제목과 설명 결정
    String? defaultLittenTitle, lectureTitle, meetingTitle;
    String? defaultLittenDescription, lectureDescription, meetingDescription;

    switch (_locale.languageCode) {
      case 'ko':
        defaultLittenTitle = null; // 기본리튼 제거
        lectureTitle = '강의 (샘플)';
        meetingTitle = '모임 (샘플)';
        defaultLittenDescription = null;
        lectureDescription = '강의 노트로 활용해보세요.';
        meetingDescription = '스케쥴러 활용해보세요.';
        break;
      case 'zh':
        defaultLittenTitle = null; // 基本默认笔记本 제거
        lectureTitle = '讲座';
        meetingTitle = '会议';
        defaultLittenDescription = null;
        lectureDescription = '在此处存储与讲座相关的文件。';
        meetingDescription = '在此处存储与会议相关的文件。';
        break;
      case 'hi':
        defaultLittenTitle = null; // 기본리튼 제거
        lectureTitle = 'व्याख्यान';
        meetingTitle = 'मीटिंग';
        defaultLittenDescription = null;
        lectureDescription = 'व्याख्यान से संबंधित फ़ाइलें यहाँ संग्रहीत करें।';
        meetingDescription = 'मीटिंग से संबंधित फ़ाइलें यहाँ संग्रहीत करें।';
        break;
      case 'es':
        defaultLittenTitle = null; // 기본리튼 제거
        lectureTitle = 'Conferencia';
        meetingTitle = 'Reunión';
        defaultLittenDescription = null;
        lectureDescription = 'Almacena archivos relacionados con conferencias aquí.';
        meetingDescription = 'Almacena archivos relacionados con reuniones aquí.';
        break;
      case 'fr':
        defaultLittenTitle = null; // 기본리튼 제거
        lectureTitle = 'Conférence';
        meetingTitle = 'Réunion';
        defaultLittenDescription = null;
        lectureDescription = 'Stockez les fichiers liés aux conférences ici.';
        meetingDescription = 'Stockez les fichiers liés aux réunions ici.';
        break;
      case 'ar':
        defaultLittenTitle = null; // 기본리튼 제거
        lectureTitle = 'محاضرة';
        meetingTitle = 'اجتماع';
        defaultLittenDescription = null;
        lectureDescription = 'احفظ الملفات المتعلقة بالمحاضرات هنا.';
        meetingDescription = 'احفظ الملفات المتعلقة بالاجتماعات هنا.';
        break;
      case 'bn':
        defaultLittenTitle = null; // 기본리튼 제거
        lectureTitle = 'লেকচার';
        meetingTitle = 'মিটিং';
        defaultLittenDescription = null;
        lectureDescription = 'লেকচার সম্পর্কিত ফাইল এখানে সংরক্ষণ করুন।';
        meetingDescription = 'মিটিং সম্পর্কিত ফাইল এখানে সংরক্ষণ করুন।';
        break;
      case 'ru':
        defaultLittenTitle = null; // 기본리튼 제거
        lectureTitle = 'Лекция';
        meetingTitle = 'Встреча';
        defaultLittenDescription = null;
        lectureDescription = 'Сохраняйте файлы, связанные с лекциями, здесь.';
        meetingDescription = 'Сохраняйте файлы, связанные с встречами, здесь.';
        break;
      case 'pt':
        defaultLittenTitle = null; // 기본리튼 제거
        lectureTitle = 'Palestra';
        meetingTitle = 'Reunião';
        defaultLittenDescription = null;
        lectureDescription = 'Armazene arquivos relacionados a palestras aqui.';
        meetingDescription = 'Armazene arquivos relacionados a reuniões aqui.';
        break;
      case 'ur':
        defaultLittenTitle = null; // 기본리튼 제거
        lectureTitle = 'لیکچر';
        meetingTitle = 'میٹنگ';
        defaultLittenDescription = null;
        lectureDescription = 'لیکچر سے متعلق فائلیں یہاں محفوظ کریں۔';
        meetingDescription = 'میٹنگ سے متعلق فائلیں یہاں محفوظ کریں۔';
        break;
      case 'id':
        defaultLittenTitle = null; // 기본리튼 제거
        lectureTitle = 'Kuliah';
        meetingTitle = 'Rapat';
        defaultLittenDescription = null;
        lectureDescription = 'Simpan file terkait kuliah di sini.';
        meetingDescription = 'Simpan file terkait rapat di sini.';
        break;
      case 'de':
        defaultLittenTitle = null; // 기본리튼 제거
        lectureTitle = 'Vorlesung';
        meetingTitle = 'Besprechung';
        defaultLittenDescription = null;
        lectureDescription = 'Speichern Sie vorlesungsbezogene Dateien hier.';
        meetingDescription = 'Speichern Sie besprechungsbezogene Dateien hier.';
        break;
      case 'ja':
        defaultLittenTitle = null; // 기본리튼 제거
        lectureTitle = '講義';
        meetingTitle = 'ミーティング';
        defaultLittenDescription = null;
        lectureDescription = '講義関連のファイルをここに保存してください。';
        meetingDescription = 'ミーティング関連のファイルをここに保存してください。';
        break;
      case 'sw':
        defaultLittenTitle = null; // 기본리튼 제거
        lectureTitle = 'Hotuba';
        meetingTitle = 'Mkutano';
        defaultLittenDescription = null;
        lectureDescription = 'Hifadhi faili zinazohusiana na hotuba hapa.';
        meetingDescription = 'Hifadhi faili zinazohusiana na mikutano hapa.';
        break;
      case 'mr':
        defaultLittenTitle = null; // 기본리튼 제거
        lectureTitle = 'व्याख्यान';
        meetingTitle = 'सभा';
        defaultLittenDescription = null;
        lectureDescription = 'व्याख्यानाशी संबंधित फाइली येथे साठवा.';
        meetingDescription = 'सभाशी संबंधित फाइली येथे साठवा.';
        break;
      case 'te':
        defaultLittenTitle = null; // 기본리튼 제거
        lectureTitle = 'ఉపన్యాసం';
        meetingTitle = 'సమావేశం';
        defaultLittenDescription = null;
        lectureDescription = 'ఉపన్యాసాలకు సంబంధించిన ఫైల్‌లను ఇక్కడ నిల్వ చేయండి.';
        meetingDescription = 'సమావేశాలకు సంబంధించిన ఫైల్‌లను ఇక్కడ నిల్వ చేయండి.';
        break;
      case 'tr':
        defaultLittenTitle = null; // 기본리튼 제거
        lectureTitle = 'Ders';
        meetingTitle = 'Toplantı';
        defaultLittenDescription = null;
        lectureDescription = 'Dersle ilgili dosyaları burada saklayın.';
        meetingDescription = 'Toplantıyla ilgili dosyaları burada saklayın.';
        break;
      case 'ta':
        defaultLittenTitle = null; // 기본리튼 제거
        lectureTitle = 'விரிவுரை';
        meetingTitle = 'கூட்டம்';
        defaultLittenDescription = null;
        lectureDescription = 'விரிவுரை தொடர்பான கோப்புகளை இங்கே சேமிக்கவும்.';
        meetingDescription = 'கூட்டம் தொடர்பான கோப்புகளை இங்கே சேமிக்கவும்.';
        break;
      case 'fa':
        defaultLittenTitle = null; // 기본리튼 제거
        lectureTitle = 'سخنرانی';
        meetingTitle = 'جلسه';
        defaultLittenDescription = null;
        lectureDescription = 'فایل‌های مربوط به سخنرانی را اینجا ذخیره کنید.';
        meetingDescription = 'فایل‌های مربوط به جلسه را اینجا ذخیره کنید.';
        break;
      case 'uk':
        defaultLittenTitle = null; // 기본리튼 제거
        lectureTitle = 'Лекція';
        meetingTitle = 'Зустріч';
        defaultLittenDescription = null;
        lectureDescription = 'Зберігайте файли, пов\'язані з лекціями, тут.';
        meetingDescription = 'Зберігайте файли, пов\'язані зі зустрічами, тут.';
        break;
      case 'it':
        defaultLittenTitle = null; // 기본리튼 제거
        lectureTitle = 'Lezione';
        meetingTitle = 'Riunione';
        defaultLittenDescription = null;
        lectureDescription = 'Memorizza qui i file relativi alle lezioni.';
        meetingDescription = 'Memorizza qui i file relativi alle riunioni.';
        break;
      case 'tl':
        defaultLittenTitle = null; // 기본리튼 제거
        lectureTitle = 'Lektura';
        meetingTitle = 'Pulong';
        defaultLittenDescription = null;
        lectureDescription = 'Mag-imbak ng mga file na may kaugnayan sa lektura dito.';
        meetingDescription = 'Mag-imbak ng mga file na may kaugnayan sa pulong dito.';
        break;
      case 'pl':
        defaultLittenTitle = null; // 기본리튼 제거
        lectureTitle = 'Wykład';
        meetingTitle = 'Spotkanie';
        defaultLittenDescription = null;
        lectureDescription = 'Przechowuj tutaj pliki związane z wykładami.';
        meetingDescription = 'Przechowuj tutaj pliki związane ze spotkaniami.';
        break;
      case 'ps':
        defaultLittenTitle = null; // 기본리튼 제거
        lectureTitle = 'لیکچر';
        meetingTitle = 'غونډه';
        defaultLittenDescription = null;
        lectureDescription = 'د لیکچر پورې اړوند فایلونه دلته خوندي کړئ.';
        meetingDescription = 'د غونډې پورې اړوند فایلونه دلته خوندي کړئ.';
        break;
      case 'ms':
        defaultLittenTitle = null; // 기본리튼 제거
        lectureTitle = 'Kuliah';
        meetingTitle = 'Mesyuarat';
        defaultLittenDescription = null;
        lectureDescription = 'Simpan fail berkaitan kuliah di sini.';
        meetingDescription = 'Simpan fail berkaitan mesyuarat di sini.';
        break;
      case 'ro':
        defaultLittenTitle = null; // 기본리튼 제거
        lectureTitle = 'Prelegere';
        meetingTitle = 'Întâlnire';
        defaultLittenDescription = null;
        lectureDescription = 'Stocați aici fișierele legate de prelegeri.';
        meetingDescription = 'Stocați aici fișierele legate de întâlniri.';
        break;
      case 'nl':
        defaultLittenTitle = null; // 기본리튼 제거
        lectureTitle = 'Lezing';
        meetingTitle = 'Vergadering';
        defaultLittenDescription = null;
        lectureDescription = 'Sla lezinggerelateerde bestanden hier op.';
        meetingDescription = 'Sla vergaderinggerelateerde bestanden hier op.';
        break;
      case 'ha':
        defaultLittenTitle = null; // 기본리튼 제거
        lectureTitle = 'Lacca';
        meetingTitle = 'Taro';
        defaultLittenDescription = null;
        lectureDescription = 'Ajiye fayiloli masu alaka da lacca a nan.';
        meetingDescription = 'Ajiye fayiloli masu alaka da taro a nan.';
        break;
      case 'th':
        defaultLittenTitle = null; // 기본리튼 제거
        lectureTitle = 'การบรรยาย';
        meetingTitle = 'การประชุม';
        defaultLittenDescription = null;
        lectureDescription = 'เก็บไฟล์ที่เกี่ยวข้องกับการบรรยายไว้ที่นี่';
        meetingDescription = 'เก็บไฟล์ที่เกี่ยวข้องกับการประชุมไว้ที่นี่';
        break;
      default:
        defaultLittenTitle = null; // Default Litten 제거
        lectureTitle = 'Lecture';
        meetingTitle = 'Meeting';
        defaultLittenDescription = null;
        lectureDescription = 'Store files related to lectures here.';
        meetingDescription = 'Store files related to meetings here.';
        break;
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

  void setHomeBottomTabIndex(int index) {
    _homeBottomTabIndex = index;
    notifyListeners();
    debugPrint('🏠 홈 화면 하단 탭 인덱스 변경: $index');
  }

  // ⭐ 현재 활성 탭 위치 저장 메서드들
  /// WritingScreen 내부 탭 위치 저장 (text, handwriting, audio, browser)
  void setCurrentWritingTab(String tabId) async {
    if (_currentWritingTabId != tabId) {
      _currentWritingTabId = tabId;
      debugPrint('✅ [AppStateProvider] 쓰기 탭 위치 저장: $tabId');

      // ⭐ SharedPreferences에 영구 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_writing_tab_id', tabId);
      debugPrint('💾 [AppStateProvider] 쓰기 탭 위치 영구 저장 완료: $tabId');

      // notifyListeners()를 호출하지 않음 - 탭 변경만으로 UI 전체 재빌드 불필요
    }
  }

  /// 메인 탭 인덱스 저장 (0: 홈, 1: 쓰기, 2: 설정)
  void setCurrentMainTab(int index) {
    if (_currentMainTabIndex != index) {
      _currentMainTabIndex = index;
      debugPrint('✅ [AppStateProvider] 메인 탭 위치 저장: $index');
      // notifyListeners()를 호출하지 않음 - 탭 변경만으로 UI 전체 재빌드 불필요
    }
  }

  /// WritingScreen 탭의 위치 저장 (text, handwriting, audio, browser 각각의 위치)
  /// position: 'topLeft', 'topRight', 'bottomLeft', 'bottomRight', 'fullScreen'
  Future<void> setWritingTabPosition(String tabId, String position) async {
    if (_writingTabPositions[tabId] != position) {
      _writingTabPositions[tabId] = position;
      debugPrint('✅ [AppStateProvider] $tabId 탭 위치 저장: $position');

      // ⭐ SharedPreferences에 영구 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tab_position_$tabId', position);
      debugPrint('💾 [AppStateProvider] $tabId 탭 위치 영구 저장 완료: $position');

      // notifyListeners()를 호출하지 않음 - 탭 위치 변경만으로 UI 전체 재빌드 불필요
    }
  }

  /// 노트탭 가시성 저장
  Future<void> setNoteTabVisibility(Set<String> visibility) async {
    _noteTabVisibility = {'all', ...visibility}; // 전체탭은 항상 포함
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('note_tab_visibility', _noteTabVisibility.toList());
    debugPrint('💾 [AppStateProvider] 노트탭 가시성 저장: $_noteTabVisibility');
    notifyListeners();
  }

  /// 시작 화면 저장 ('note' | 'calendar')
  Future<void> setDockingEnabled(bool enabled) async {
    if (_dockingEnabled == enabled) return;
    _dockingEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('docking_enabled', enabled);
    debugPrint('💾 [AppStateProvider] 도킹 사용 여부 저장: $_dockingEnabled');
    notifyListeners();
  }

  /// 영역 보기 설정 — topLeft는 항상 포함, 숨겨진 영역의 탭은 topLeft로 이동
  Future<void> setVisibleAreas(Set<String> areas) async {
    final newAreas = {'topLeft', ...areas};
    final removedAreas = _visibleAreas.difference(newAreas);

    // 숨겨진 영역에 있던 탭을 topLeft로 이동
    if (removedAreas.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      for (final tabId in _writingTabPositions.keys.toList()) {
        if (removedAreas.contains(_writingTabPositions[tabId])) {
          _writingTabPositions[tabId] = 'topLeft';
          await prefs.setString('tab_position_$tabId', 'topLeft');
          debugPrint('[AppStateProvider] $tabId 탭을 topLeft로 이동 (영역 비활성화)');
        }
      }
    }

    _visibleAreas = newAreas;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('visible_areas', _visibleAreas.toList());
    debugPrint('💾 [AppStateProvider] 영역 보기 저장: $_visibleAreas');
    notifyListeners();
  }

  /// 디바이스가 태블릿인지 감지 (shortestSide >= 600dp 기준)
  bool _detectIsTablet() {
    try {
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      final shortestSide = view.physicalSize.shortestSide / view.devicePixelRatio;
      debugPrint('📐 [AppStateProvider] shortestSide: $shortestSide');
      return shortestSide >= 600;
    } catch (e) {
      debugPrint('⚠️ [AppStateProvider] 디바이스 타입 감지 실패: $e');
      return false;
    }
  }

  Future<void> setAdsEnabled(bool enabled) async {
    if (_adsEnabled == enabled) return;
    _adsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ads_enabled', enabled);
    debugPrint('💾 [AppStateProvider] 광고 표시 여부 저장: $_adsEnabled');
    notifyListeners();
  }

  Future<void> setStartScreen(String screen) async {
    if (_startScreen == screen) return;
    _startScreen = screen;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('start_screen', screen);
    debugPrint('💾 [AppStateProvider] 시작 화면 저장: $_startScreen');
    notifyListeners();
  }

  Future<void> updateSubscriptionType(SubscriptionType subscriptionType) async {
    await changeSubscriptionType(subscriptionType);
  }

  // 온보딩 완료 처리
  Future<void> completeOnboarding({
    String? selectedLanguage,
    AppThemeType? selectedTheme,
    SubscriptionType? selectedSubscription,
  }) async {
    debugPrint('[AppStateProvider] 🚀 completeOnboarding 시작');
    debugPrint('[AppStateProvider] 선택 언어: $selectedLanguage, 테마: $selectedTheme, 구독: $selectedSubscription');

    final prefs = await SharedPreferences.getInstance();

    if (selectedLanguage != null) {
      debugPrint('[AppStateProvider] 언어 변경 중: $selectedLanguage');
      await changeLanguage(selectedLanguage);
    }

    if (selectedTheme != null) {
      debugPrint('[AppStateProvider] 테마 변경 중: $selectedTheme');
      await changeTheme(selectedTheme);
    }

    if (selectedSubscription != null) {
      debugPrint('[AppStateProvider] 구독 타입 변경 중: $selectedSubscription');
      await changeSubscriptionType(selectedSubscription);
    }

    // 온보딩 완료 시점에 기본 리튼들 생성
    debugPrint('[AppStateProvider] 기본 리튼 생성 시작');
    await _createDefaultLittensWithLocalization();

    debugPrint('[AppStateProvider] 리튼 목록 로드 시작');
    await _loadLittens();

    debugPrint('[AppStateProvider] 선택된 리튼 로드 시작');
    await _loadSelectedLitten();

    // 앱 초기화 완료 표시
    debugPrint('[AppStateProvider] 앱 초기화 플래그 저장');
    await prefs.setBool('is_app_initialized', true);

    debugPrint('[AppStateProvider] _isFirstLaunch를 false로 설정 (이전: $_isFirstLaunch)');
    _isFirstLaunch = false;

    debugPrint('[AppStateProvider] notifyListeners 호출');
    notifyListeners();

    debugPrint('[AppStateProvider] ✅ completeOnboarding 완료 - _isFirstLaunch: $_isFirstLaunch');
  }
  
  // 캘린더 관련 메서드들
  void selectDate(DateTime date) {
    debugPrint('📅 날짜 선택: ${DateFormat('yyyy-MM-dd').format(date)}');
    // 시간 부분을 제거하고 날짜만 비교
    final newDate = DateTime(date.year, date.month, date.day);
    final currentDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    // 날짜가 다르거나, 같은 날짜라도 아직 선택되지 않은 상태면 선택 처리
    if (!currentDate.isAtSameMomentAs(newDate) || !_isDateSelected) {
      _selectedDate = newDate;
      _isDateSelected = true;
      debugPrint('✅ 날짜 선택 완료: isDateSelected = $_isDateSelected');
      notifyListeners();
    } else {
      debugPrint('⚠️ 이미 선택된 날짜입니다.');
      // 같은 날짜를 다시 클릭해도 UI 업데이트를 위해 notifyListeners 호출
      notifyListeners();
    }
  }

  void clearDateSelection() {
    _isDateSelected = false;
    notifyListeners();
  }

  /// UI 강제 업데이트 (외부에서 호출 가능)
  void forceUpdate() {
    notifyListeners();
  }

  void changeFocusedDate(DateTime date) {
    if (_focusedDate != date) {
      _focusedDate = date;
      notifyListeners();
    }
  }
  
  // 특정 날짜에 생성된 리튼들의 개수 (undefined 제외)
  int getLittenCountForDate(DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);
    return _littens.where((litten) {
      // undefined 리튼은 제외
      if (litten.title == 'undefined') return false;

      final littenDate = DateTime(
        litten.createdAt.year,
        litten.createdAt.month,
        litten.createdAt.day,
      );
      return littenDate.isAtSameMomentAs(targetDate);
    }).length;
  }

  // 특정 날짜에 알림이 있는지 확인 (리튼 생성일 + 알림 예정일)
  Future<int> getNotificationCountForDate(DateTime date) async {
    final targetDate = DateTime(date.year, date.month, date.day);

    try {
      // 1. 해당 날짜에 생성된 리튼 개수
      final littenCount = getLittenCountForDate(date);

      // 2. 저장소에서 모든 알림 로드
      final storage = NotificationStorageService();
      final allNotifications = await storage.loadNotifications();

      // 3. 해당 날짜에 예정된 알림 개수 (중복 제거를 위해 Set 사용)
      final notificationDates = allNotifications
          .where((notification) {
            final triggerDate = DateTime(
              notification.triggerTime.year,
              notification.triggerTime.month,
              notification.triggerTime.day,
            );
            return triggerDate.isAtSameMomentAs(targetDate);
          })
          .map((n) => n.littenId)
          .toSet();

      // 리튼 개수와 알림 있는 리튼 개수 중 큰 값 반환 (최대 3개)
      final totalCount = littenCount + notificationDates.length;
      return totalCount > 3 ? 3 : totalCount;
    } catch (e) {
      debugPrint('❌ 날짜별 알림 개수 확인 실패: $e');
      return getLittenCountForDate(date);
    }
  }

  // 특정 리튼에 발생한 알림이 있는지 확인하는 메서드
  bool hasNotificationForLitten(String littenId) {
    try {
      // 발생한 알림만 확인 (대기 중인 알림은 제외)
      return _notificationService.firedNotifications.any((notification) => notification.littenId == littenId);
    } catch (e) {
      debugPrint('❌ 리튼 알림 확인 실패: $e');
      return false;
    }
  }

  // 홈탭에서 알림이 있을 때 자동으로 선택하는 메서드
  void selectNotificationTargetsOnHomeTab() {
    try {
      // 대기 중인 알림과 발생한 알림을 모두 확인
      final allNotifications = <NotificationEvent>[];
      allNotifications.addAll(_notificationService.pendingNotifications);
      allNotifications.addAll(_notificationService.firedNotifications);

      debugPrint('🏠 홈탭 알림 체크: 대기 중 ${_notificationService.pendingNotifications.length}개, 발생 ${_notificationService.firedNotifications.length}개');

      if (allNotifications.isNotEmpty) {
        selectNotificationTargets(allNotifications);
        debugPrint('✅ 홈탭에서 알림 대상 자동 선택 완료');
      } else {
        debugPrint('📋 홈탭에서 확인할 알림 없음');
      }
    } catch (e) {
      debugPrint('❌ 홈탭 알림 체크 실패: $e');
    }
  }

  // 알림에 해당하는 리튼과 날짜를 선택하는 메서드 (가장 과거 알림 기준)
  void selectNotificationTargets(List<NotificationEvent> notifications) {
    if (notifications.isEmpty) return;

    try {
      // 가장 과거의 알림을 찾기 (일정 날짜 기준으로 정렬)
      final sortedNotifications = List<NotificationEvent>.from(notifications);
      sortedNotifications.sort((a, b) => a.schedule.date.compareTo(b.schedule.date));

      final oldestNotification = sortedNotifications.first;
      debugPrint('🎯 가장 과거 알림 선택: ${oldestNotification.littenTitle} - ${DateFormat('yyyy-MM-dd').format(oldestNotification.schedule.date)}');

      // 해당 리튼을 찾기
      final targetLitten = _littens.firstWhere(
        (litten) => litten.id == oldestNotification.littenId,
        orElse: () {
          debugPrint('⚠️ 알림의 리튼을 찾을 수 없음: ${oldestNotification.littenId}');
          // 빈 리튼을 반환하여 에러를 방지
          return Litten(
            id: 'not_found',
            title: '알림 리튼을 찾을 수 없음',
            createdAt: DateTime.now(),
          );
        },
      );

      // 리튼이 존재하면 선택
      if (targetLitten.id != 'not_found') {
        _selectedLitten = targetLitten;
        debugPrint('✅ 리튼 선택됨: ${targetLitten.title}');
      }

      // 가장 과거 알림의 일정 날짜로 선택된 날짜 변경
      final scheduleDate = oldestNotification.schedule.date;
      final targetDate = DateTime(
        scheduleDate.year,
        scheduleDate.month,
        scheduleDate.day,
      );

      if (_selectedDate != targetDate) {
        _selectedDate = targetDate;
        _focusedDate = targetDate;
        debugPrint('✅ 날짜 선택됨: ${DateFormat('yyyy-MM-dd').format(targetDate)}');
      }

      // 상태 변경 알림
      notifyListeners();

      // 모든 알림 정보 로그 (날짜순 정렬)
      if (notifications.length > 1) {
        debugPrint('📢 전체 알림 ${notifications.length}개 (날짜순):');
        for (int i = 0; i < sortedNotifications.length; i++) {
          final notification = sortedNotifications[i];
          final prefix = i == 0 ? '👑 [선택됨]' : '   ';
          debugPrint('$prefix ${notification.littenTitle}: ${DateFormat('yyyy-MM-dd HH:mm').format(notification.schedule.date)}');
        }
      }
    } catch (e) {
      debugPrint('❌ 알림 대상 선택 실패: $e');
    }
  }

  // 알림 발생 시 리튼을 최상위로 올리기 위해 updatedAt 업데이트
  Future<void> _onNotificationFired(String littenId) async {
    try {
      debugPrint('📌 알림 발생: 리튼을 최상위로 이동 - $littenId');

      // 해당 리튼 찾기
      final litten = _littens.firstWhere(
        (l) => l.id == littenId,
        orElse: () => Litten(id: '', title: ''),
      );

      if (litten.id.isEmpty) {
        debugPrint('⚠️ 알림 리튼을 찾을 수 없음: $littenId');
        return;
      }

      // updatedAt을 현재 시간으로 업데이트 (최상위로 올리기)
      final updatedLitten = litten.copyWith(
        notificationCount: litten.notificationCount + 1,
      );

      // 리튼 저장
      await _littenService.saveLitten(updatedLitten);

      // 리튼 목록 새로고침
      await refreshLittens();

      debugPrint('✅ 리튼 업데이트 완료: ${litten.title} (알림 횟수: ${updatedLitten.notificationCount})');
    } catch (e, stackTrace) {
      debugPrint('❌ 알림 리튼 업데이트 실패: $e');
      debugPrint('스택 트레이스: $stackTrace');
    }
  }

  // 선택된 날짜의 모든 파일들을 가져오기
  Future<List<Map<String, dynamic>>> getAllFilesForSelectedDate() async {
    debugPrint('📁 선택된 날짜의 모든 파일 로드 시작: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}');

    final allFiles = <Map<String, dynamic>>[];

    // undefined 리튼을 제외한 선택된 날짜의 리튼들
    final selectedDateLittens = littensForSelectedDate
        .where((litten) => litten.title != 'undefined')
        .toList();

    debugPrint('📋 리튼 개수: ${selectedDateLittens.length}');

    for (final litten in selectedDateLittens) {
      // 오디오 파일들
      final audioFiles = await _littenService.getAudioFilesByLittenId(litten.id);
      for (final audioFile in audioFiles) {
        allFiles.add({
          'type': 'audio',
          'file': audioFile,
          'littenTitle': litten.title,
          'littenId': litten.id,
          'createdAt': audioFile.createdAt,
        });
      }

      // 텍스트 파일들
      final textFiles = await FileStorageService.instance.loadTextFiles(litten.id);
      for (final textFile in textFiles) {
        allFiles.add({
          'type': 'text',
          'file': textFile,
          'littenTitle': litten.title,
          'littenId': litten.id,
          'createdAt': textFile.createdAt,
        });
      }

      // 필기 파일들
      final handwritingFiles = await FileStorageService.instance.loadHandwritingFiles(litten.id);
      for (final handwritingFile in handwritingFiles) {
        allFiles.add({
          'type': 'handwriting',
          'file': handwritingFile,
          'littenTitle': litten.title,
          'littenId': litten.id,
          'createdAt': handwritingFile.createdAt,
        });
      }
    }

    // 최신순으로 정렬
    allFiles.sort((a, b) => (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));

    debugPrint('✅ 총 ${allFiles.length}개 파일 로드 완료 (오디오: ${allFiles.where((f) => f['type'] == 'audio').length}, 텍스트: ${allFiles.where((f) => f['type'] == 'text').length}, 필기: ${allFiles.where((f) => f['type'] == 'handwriting').length})');

    return allFiles;
  }

  /// 모든 리튼의 모든 파일을 가져오기 (시간 순서대로 정렬)
  Future<List<Map<String, dynamic>>> getAllFiles() async {
    debugPrint('📁 전체 파일 로드 시작 (모든 리튼 포함)');

    final allFiles = <Map<String, dynamic>>[];

    // 모든 리튼들 (undefined 포함)
    final allLittens = _littens.toList();

    debugPrint('📋 전체 리튼 개수: ${allLittens.length}');

    for (final litten in allLittens) {
      debugPrint('🔍 리튼 파일 스캔 시작: ${litten.title} (${litten.id})');

      // 오디오 파일들 (파일 시스템에서 직접 로드)
      final audioFiles = await AudioService().getAudioFiles(litten);
      debugPrint('   🎵 오디오 파일: ${audioFiles.length}개');
      for (final audioFile in audioFiles) {
        debugPrint('      - ${audioFile.displayName}');
        allFiles.add({
          'type': 'audio',
          'file': audioFile,
          'littenTitle': litten.title,
          'littenId': litten.id,
          'createdAt': audioFile.createdAt,
          'updatedAt': audioFile.createdAt, // 오디오 파일은 updatedAt이 없으므로 createdAt 사용
        });
      }

      // 텍스트 파일들
      final textFiles = await FileStorageService.instance.loadTextFiles(litten.id);
      for (final textFile in textFiles) {
        allFiles.add({
          'type': 'text',
          'file': textFile,
          'littenTitle': litten.title,
          'littenId': litten.id,
          'createdAt': textFile.createdAt,
          'updatedAt': textFile.updatedAt,
        });
      }

      // 필기 파일들
      final handwritingFiles = await FileStorageService.instance.loadHandwritingFiles(litten.id);
      for (final handwritingFile in handwritingFiles) {
        allFiles.add({
          'type': 'handwriting',
          'file': handwritingFile,
          'littenTitle': litten.title,
          'littenId': litten.id,
          'createdAt': handwritingFile.createdAt,
          'updatedAt': handwritingFile.updatedAt,
        });
      }
    }

    // 수정일자 기준 내림차순 정렬 (최신순)
    allFiles.sort((a, b) => (b['updatedAt'] as DateTime).compareTo(a['updatedAt'] as DateTime));

    debugPrint('✅ 총 ${allFiles.length}개 파일 로드 완료 (오디오: ${allFiles.where((f) => f['type'] == 'audio').length}, 텍스트: ${allFiles.where((f) => f['type'] == 'text').length}, 필기: ${allFiles.where((f) => f['type'] == 'handwriting').length})');

    return allFiles;
  }

  // 선택된 리튼의 파일만 가져오기
  Future<List<Map<String, dynamic>>> getFilesForSelectedLitten() async {
    if (_selectedLitten == null) {
      debugPrint('📁 선택된 리튼이 없음');
      return [];
    }

    debugPrint('📁 선택된 리튼의 파일 로드 시작: ${_selectedLitten!.title} (${_selectedLitten!.id})');

    final allFiles = <Map<String, dynamic>>[];

    // 오디오 파일들
    final audioFiles = await AudioService().getAudioFiles(_selectedLitten!);
    debugPrint('   🎵 오디오 파일: ${audioFiles.length}개');
    for (final audioFile in audioFiles) {
      allFiles.add({
        'type': 'audio',
        'file': audioFile,
        'littenTitle': _selectedLitten!.title,
        'littenId': _selectedLitten!.id,
        'createdAt': audioFile.createdAt,
        'updatedAt': audioFile.createdAt, // 오디오 파일은 updatedAt이 없으므로 createdAt 사용
      });
    }

    // 텍스트 파일들
    final textFiles = await FileStorageService.instance.loadTextFiles(_selectedLitten!.id);
    debugPrint('   📝 텍스트 파일: ${textFiles.length}개');
    for (final textFile in textFiles) {
      allFiles.add({
        'type': 'text',
        'file': textFile,
        'littenTitle': _selectedLitten!.title,
        'littenId': _selectedLitten!.id,
        'createdAt': textFile.createdAt,
        'updatedAt': textFile.updatedAt,
      });
    }

    // 필기 파일들
    final handwritingFiles = await FileStorageService.instance.loadHandwritingFiles(_selectedLitten!.id);
    debugPrint('   ✍️ 필기 파일: ${handwritingFiles.length}개');
    for (final handwritingFile in handwritingFiles) {
      allFiles.add({
        'type': 'handwriting',
        'file': handwritingFile,
        'littenTitle': _selectedLitten!.title,
        'littenId': _selectedLitten!.id,
        'createdAt': handwritingFile.createdAt,
        'updatedAt': handwritingFile.updatedAt,
      });
    }

    // 수정일자 기준 내림차순 정렬 (최신순)
    allFiles.sort((a, b) => (b['updatedAt'] as DateTime).compareTo(a['updatedAt'] as DateTime));

    debugPrint('📁 선택된 리튼의 총 파일 개수: ${allFiles.length}개');
    return allFiles;
  }

  /// 앱 생명주기 상태 변경 시 호출
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    debugPrint('🔄 앱 생명주기 변경: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        // 앱이 포그라운드로 돌아옴
        debugPrint('▶️ 앱 포그라운드 전환 - 상태 복원 및 알림 서비스 재개');

        // 선택된 리튼과 녹음 상태 복원 (Child 리튼 생성과 독립적)
        _restoreSelectedLittenState();
        _audioService.restoreRecordingState();

        // ⭐ 알림 서비스 재개 (타이머 상태 확인 및 재시작 포함)
        _notificationService.onAppResumed();

        // 알림 서비스가 멈췄을 수 있으므로 확인 후 재시작
        // Child 리튼 생성은 타임아웃 설정으로 블로킹되지 않음
        _ensureNotificationServiceRunning();

        // 추가 안전장치: 1초 후 다시 한 번 확인
        Future.delayed(const Duration(seconds: 1), () {
          _ensureNotificationServiceRunning();
        });

        // 포그라운드 전환 시 동기화 (5분 이상 백그라운드였을 때만 실행)
        SyncService.instance.syncOnForeground();
        break;
      case AppLifecycleState.inactive:
        // 앱이 비활성 상태 (예: 전화 수신, 알림 센터 열기)
        debugPrint('⏸️ 앱 비활성 상태');
        break;
      case AppLifecycleState.paused:
        // 앱이 백그라운드로 감
        debugPrint('⏸️ 앱 백그라운드 전환 - 상태 저장 및 알림 서비스 일시정지');
        _saveSelectedLittenState();
        _audioService.saveRecordingState(
          littenId: _selectedLitten?.id,
        );
        _notificationService.onAppPaused();
        // 백그라운드 진입 시각 기록 (포그라운드 전환 시 경과 시간 계산용)
        SyncService.instance.recordBackgroundTime();
        break;
      case AppLifecycleState.detached:
        // 앱이 종료됨
        debugPrint('🛑 앱 종료');
        _saveSelectedLittenState();
        _audioService.saveRecordingState(
          littenId: _selectedLitten?.id,
        );
        break;
      case AppLifecycleState.hidden:
        // 앱이 숨겨짐 (일부 플랫폼에서 사용)
        debugPrint('👁️ 앱 숨김 상태');
        break;
    }
  }

  // 실제 파일 개수를 직접 카운트하는 메서드
  // 항상 전체 리튼을 1회 순회하여 전체 카운트와 선택 리튼 카운트를 동시에 계산
  Future<Map<String, int>> getActualFileCounts({String? littenId}) async {
    debugPrint('📊 실제 파일 카운트 시작 - littenId: $littenId');

    final fileStorageService = FileStorageService.instance;

    int totalAudio = 0, totalText = 0, totalHandwriting = 0;
    int selectedAudio = 0, selectedText = 0, selectedHandwriting = 0;

    for (final litten in _littens) {
      final audioFiles = await _audioService.getAudioFiles(litten);
      final textFiles = await fileStorageService.loadTextFiles(litten.id);
      final handwritingFiles = await fileStorageService.loadHandwritingFiles(litten.id);

      totalAudio += audioFiles.length;
      totalText += textFiles.length;
      totalHandwriting += handwritingFiles.length;

      if (littenId == null || litten.id == littenId) {
        selectedAudio += audioFiles.length;
        selectedText += textFiles.length;
        selectedHandwriting += handwritingFiles.length;
      }
    }

    // 전체 카운트 업데이트 (캘린더 통계 영역 - 항상 전체)
    _totalAudioCount = totalAudio;
    _totalTextCount = totalText;
    _totalHandwritingCount = totalHandwriting;

    // 선택 리튼 카운트 업데이트 (WritingScreen 헤더용)
    _actualAudioCount = selectedAudio;
    _actualTextCount = selectedText;
    _actualHandwritingCount = selectedHandwriting;

    debugPrint('📊 전체 파일 수 - 오디오: $totalAudio, 텍스트: $totalText, 필기: $totalHandwriting');
    if (littenId != null) {
      debugPrint('📊 선택 리튼 "$littenId" 파일 수 - 오디오: $selectedAudio, 텍스트: $selectedText, 필기: $selectedHandwriting');
    }

    notifyListeners();

    return {
      'audio': selectedAudio,
      'text': selectedText,
      'handwriting': selectedHandwriting,
    };
  }

  // 파일 카운트 업데이트 (파일 추가/삭제 시 호출)
  Future<void> updateFileCount() async {
    // undefined 또는 미선택이면 전체 카운트, 그 외는 해당 리튼 카운트
    final littenId = (_selectedLitten == null || _selectedLitten!.title == 'undefined')
        ? null
        : _selectedLitten!.id;
    await getActualFileCounts(littenId: littenId);
  }
}

enum SubscriptionType {
  free,
  standard,
  premium,
}
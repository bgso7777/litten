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
  
  // 캘린더 상태
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDate = DateTime.now();

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
  
  // 캘린더 관련 Getters
  DateTime get selectedDate => _selectedDate;
  DateTime get focusedDate => _focusedDate;
  
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
    // 기본 리튼은 온보딩 완료 후에만 생성
    await _loadLittens();
    // 앱 시작 시에는 아무 리튼도 선택하지 않음
    _selectedLitten = null;
    
    // 캘린더를 오늘 날짜로 초기화
    final today = DateTime.now();
    _selectedDate = today;
    _focusedDate = today;
    
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
      '기본리튼', '강의', '회의',
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

    // 선택된 날짜에 현재 시간을 조합하여 생성
    final selectedDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      DateTime.now().hour,
      DateTime.now().minute,
      DateTime.now().second,
      DateTime.now().millisecond,
      DateTime.now().microsecond,
    );

    final litten = Litten(
      title: title, 
      createdAt: selectedDateTime,
      updatedAt: selectedDateTime,
    );
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

  // 리튼 날짜 이동
  Future<void> moveLittenToDate(String littenId, DateTime targetDate) async {
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
    _littens = await _littenService.getAllLittens();
    
    // 선택된 리튼이 있다면 업데이트된 데이터로 다시 설정
    if (_selectedLitten != null) {
      _selectedLitten = _littens.where((l) => l.id == _selectedLitten!.id).firstOrNull;
    }
    
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
    String? defaultLittenTitle, lectureTitle, meetingTitle;
    String? defaultLittenDescription, lectureDescription, meetingDescription;

    switch (_locale.languageCode) {
      case 'ko':
        defaultLittenTitle = null; // 기본리튼 제거
        lectureTitle = '강의';
        meetingTitle = '회의';
        defaultLittenDescription = null;
        lectureDescription = '강의에 관련된 파일들을 저장하세요.';
        meetingDescription = '회의에 관련된 파일들을 저장하세요.';
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
    
    // 온보딩 완료 시점에 기본 리튼들 생성
    await _createDefaultLittensWithLocalization();
    await _loadLittens();
    await _loadSelectedLitten();
    
    // 앱 초기화 완료 표시
    await prefs.setBool('is_app_initialized', true);
    _isFirstLaunch = false;
    notifyListeners();
  }
  
  // 캘린더 관련 메서드들
  void selectDate(DateTime date) {
    if (_selectedDate != date) {
      _selectedDate = date;
      notifyListeners();
    }
  }
  
  void changeFocusedDate(DateTime date) {
    if (_focusedDate != date) {
      _focusedDate = date;
      notifyListeners();
    }
  }
  
  // 특정 날짜에 생성된 리튼들의 개수
  int getLittenCountForDate(DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);
    return _littens.where((litten) {
      final littenDate = DateTime(
        litten.createdAt.year,
        litten.createdAt.month,
        litten.createdAt.day,
      );
      return littenDate.isAtSameMomentAs(targetDate);
    }).length;
  }
}

enum SubscriptionType {
  free,
  standard,
  premium,
}
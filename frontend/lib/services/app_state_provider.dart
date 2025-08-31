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
    // 기본 리튼은 온보딩 완료 후에만 생성
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
    String defaultLittenTitle, lectureTitle, meetingTitle;
    String defaultLittenDescription, lectureDescription, meetingDescription;
    
    switch (_locale.languageCode) {
      case 'ko':
        defaultLittenTitle = '기본리튼';
        lectureTitle = '강의';
        meetingTitle = '회의';
        defaultLittenDescription = '리튼을 선택하지 않고 생성된 파일들이 저장되는 기본 공간입니다.';
        lectureDescription = '강의에 관련된 파일들을 저장하세요.';
        meetingDescription = '회의에 관련된 파일들을 저장하세요.';
        break;
      case 'zh':
        defaultLittenTitle = '默认笔记本';
        lectureTitle = '讲座';
        meetingTitle = '会议';
        defaultLittenDescription = '未选择笔记本时创建的文件将存储在此默认空间中。';
        lectureDescription = '在此处存储与讲座相关的文件。';
        meetingDescription = '在此处存储与会议相关的文件。';
        break;
      case 'hi':
        defaultLittenTitle = 'डिफ़ॉल्ट लिट्टेन';
        lectureTitle = 'व्याख्यान';
        meetingTitle = 'मीटिंग';
        defaultLittenDescription = 'लिट्टेन चुने बिना बनाई गई फ़ाइलों के लिए डिफ़ॉल्ट स्थान।';
        lectureDescription = 'व्याख्यान से संबंधित फ़ाइलें यहाँ संग्रहीत करें।';
        meetingDescription = 'मीटिंग से संबंधित फ़ाइलें यहाँ संग्रहीत करें।';
        break;
      case 'es':
        defaultLittenTitle = 'Litten Predeterminado';
        lectureTitle = 'Conferencia';
        meetingTitle = 'Reunión';
        defaultLittenDescription = 'Espacio predeterminado para archivos creados sin seleccionar un litten.';
        lectureDescription = 'Almacena archivos relacionados con conferencias aquí.';
        meetingDescription = 'Almacena archivos relacionados con reuniones aquí.';
        break;
      case 'fr':
        defaultLittenTitle = 'Litten par Défaut';
        lectureTitle = 'Conférence';
        meetingTitle = 'Réunion';
        defaultLittenDescription = 'Espace par défaut pour les fichiers créés sans sélectionner un litten.';
        lectureDescription = 'Stockez les fichiers liés aux conférences ici.';
        meetingDescription = 'Stockez les fichiers liés aux réunions ici.';
        break;
      case 'ar':
        defaultLittenTitle = 'ليتن افتراضي';
        lectureTitle = 'محاضرة';
        meetingTitle = 'اجتماع';
        defaultLittenDescription = 'مساحة افتراضية للملفات المنشأة بدون تحديد ليتن.';
        lectureDescription = 'احفظ الملفات المتعلقة بالمحاضرات هنا.';
        meetingDescription = 'احفظ الملفات المتعلقة بالاجتماعات هنا.';
        break;
      case 'bn':
        defaultLittenTitle = 'ডিফল্ট লিটেন';
        lectureTitle = 'লেকচার';
        meetingTitle = 'মিটিং';
        defaultLittenDescription = 'লিটেন নির্বাচন ছাড়াই তৈরি ফাইলের জন্য ডিফল্ট স্থান।';
        lectureDescription = 'লেকচার সম্পর্কিত ফাইল এখানে সংরক্ষণ করুন।';
        meetingDescription = 'মিটিং সম্পর্কিত ফাইল এখানে সংরক্ষণ করুন।';
        break;
      case 'ru':
        defaultLittenTitle = 'Литтен по умолчанию';
        lectureTitle = 'Лекция';
        meetingTitle = 'Встреча';
        defaultLittenDescription = 'Пространство по умолчанию для файлов, созданных без выбора литтена.';
        lectureDescription = 'Сохраняйте файлы, связанные с лекциями, здесь.';
        meetingDescription = 'Сохраняйте файлы, связанные с встречами, здесь.';
        break;
      case 'pt':
        defaultLittenTitle = 'Litten Padrão';
        lectureTitle = 'Palestra';
        meetingTitle = 'Reunião';
        defaultLittenDescription = 'Espaço padrão para arquivos criados sem selecionar um litten.';
        lectureDescription = 'Armazene arquivos relacionados a palestras aqui.';
        meetingDescription = 'Armazene arquivos relacionados a reuniões aqui.';
        break;
      case 'ur':
        defaultLittenTitle = 'ڈیفالٹ لٹن';
        lectureTitle = 'لیکچر';
        meetingTitle = 'میٹنگ';
        defaultLittenDescription = 'لٹن منتخب کیے بغیر بنائی گئی فائلوں کے لیے ڈیفالٹ جگہ۔';
        lectureDescription = 'لیکچر سے متعلق فائلیں یہاں محفوظ کریں۔';
        meetingDescription = 'میٹنگ سے متعلق فائلیں یہاں محفوظ کریں۔';
        break;
      case 'id':
        defaultLittenTitle = 'Litten Default';
        lectureTitle = 'Kuliah';
        meetingTitle = 'Rapat';
        defaultLittenDescription = 'Ruang default untuk file yang dibuat tanpa memilih litten.';
        lectureDescription = 'Simpan file terkait kuliah di sini.';
        meetingDescription = 'Simpan file terkait rapat di sini.';
        break;
      case 'de':
        defaultLittenTitle = 'Standard-Litten';
        lectureTitle = 'Vorlesung';
        meetingTitle = 'Besprechung';
        defaultLittenDescription = 'Standardbereich für Dateien, die ohne Auswahl eines Littens erstellt wurden.';
        lectureDescription = 'Speichern Sie vorlesungsbezogene Dateien hier.';
        meetingDescription = 'Speichern Sie besprechungsbezogene Dateien hier.';
        break;
      case 'ja':
        defaultLittenTitle = 'デフォルトリッテン';
        lectureTitle = '講義';
        meetingTitle = 'ミーティング';
        defaultLittenDescription = 'リッテンを選択せずに作成されたファイルのデフォルト領域。';
        lectureDescription = '講義関連のファイルをここに保存してください。';
        meetingDescription = 'ミーティング関連のファイルをここに保存してください。';
        break;
      case 'sw':
        defaultLittenTitle = 'Litten Chaguo-msingi';
        lectureTitle = 'Hotuba';
        meetingTitle = 'Mkutano';
        defaultLittenDescription = 'Nafasi chaguo-msingi ya faili zilizoundwa bila kuchagua litten.';
        lectureDescription = 'Hifadhi faili zinazohusiana na hotuba hapa.';
        meetingDescription = 'Hifadhi faili zinazohusiana na mikutano hapa.';
        break;
      case 'mr':
        defaultLittenTitle = 'डिफॉल्ट लिट्टन';
        lectureTitle = 'व्याख्यान';
        meetingTitle = 'सभा';
        defaultLittenDescription = 'लिट्टन निवडल्याशिवाय तयार केलेल्या फाइलींसाठी डिफॉल्ट जागा.';
        lectureDescription = 'व्याख्यानाशी संबंधित फाइली येथे साठवा.';
        meetingDescription = 'सभाशी संबंधित फाइली येथे साठवा.';
        break;
      case 'te':
        defaultLittenTitle = 'డిఫాల్ట్ లిట్టెన్';
        lectureTitle = 'ఉపన్యాసం';
        meetingTitle = 'సమావేశం';
        defaultLittenDescription = 'లిట్టెన్ ఎంచుకోకుండా సృష్టించబడిన ఫైల్‌ల కోసం డిఫాల్ట్ స్థలం.';
        lectureDescription = 'ఉపన్యాసాలకు సంబంధించిన ఫైల్‌లను ఇక్కడ నిల్వ చేయండి.';
        meetingDescription = 'సమావేశాలకు సంబంధించిన ఫైల్‌లను ఇక్కడ నిల్వ చేయండి.';
        break;
      case 'tr':
        defaultLittenTitle = 'Varsayılan Litten';
        lectureTitle = 'Ders';
        meetingTitle = 'Toplantı';
        defaultLittenDescription = 'Litten seçilmeden oluşturulan dosyalar için varsayılan alan.';
        lectureDescription = 'Dersle ilgili dosyaları burada saklayın.';
        meetingDescription = 'Toplantıyla ilgili dosyaları burada saklayın.';
        break;
      case 'ta':
        defaultLittenTitle = 'இயல்புநிலை லிட்டன்';
        lectureTitle = 'விரிவுரை';
        meetingTitle = 'கூட்டம்';
        defaultLittenDescription = 'லிட்டன் தேர்ந்தெடுக்காமல் உருவாக்கப்பட்ட கோப்புகளுக்கான இயல்புநிலை இடம்.';
        lectureDescription = 'விரிவுரை தொடர்பான கோப்புகளை இங்கே சேமிக்கவும்.';
        meetingDescription = 'கூட்டம் தொடர்பான கோப்புகளை இங்கே சேமிக்கவும்.';
        break;
      case 'fa':
        defaultLittenTitle = 'لیتن پیش‌فرض';
        lectureTitle = 'سخنرانی';
        meetingTitle = 'جلسه';
        defaultLittenDescription = 'فضای پیش‌فرض برای فایل‌های ایجاد شده بدون انتخاب لیتن.';
        lectureDescription = 'فایل‌های مربوط به سخنرانی را اینجا ذخیره کنید.';
        meetingDescription = 'فایل‌های مربوط به جلسه را اینجا ذخیره کنید.';
        break;
      case 'uk':
        defaultLittenTitle = 'Літтен за замовчуванням';
        lectureTitle = 'Лекція';
        meetingTitle = 'Зустріч';
        defaultLittenDescription = 'Простір за замовчуванням для файлів, створених без вибору літтена.';
        lectureDescription = 'Зберігайте файли, пов\'язані з лекціями, тут.';
        meetingDescription = 'Зберігайте файли, пов\'язані зі зустрічами, тут.';
        break;
      case 'it':
        defaultLittenTitle = 'Litten Predefinito';
        lectureTitle = 'Lezione';
        meetingTitle = 'Riunione';
        defaultLittenDescription = 'Spazio predefinito per i file creati senza selezionare un litten.';
        lectureDescription = 'Memorizza qui i file relativi alle lezioni.';
        meetingDescription = 'Memorizza qui i file relativi alle riunioni.';
        break;
      case 'tl':
        defaultLittenTitle = 'Default na Litten';
        lectureTitle = 'Lektura';
        meetingTitle = 'Pulong';
        defaultLittenDescription = 'Default na lugar para sa mga file na ginawa nang walang pagpili ng litten.';
        lectureDescription = 'Mag-imbak ng mga file na may kaugnayan sa lektura dito.';
        meetingDescription = 'Mag-imbak ng mga file na may kaugnayan sa pulong dito.';
        break;
      case 'pl':
        defaultLittenTitle = 'Domyślny Litten';
        lectureTitle = 'Wykład';
        meetingTitle = 'Spotkanie';
        defaultLittenDescription = 'Domyślne miejsce dla plików utworzonych bez wyboru littena.';
        lectureDescription = 'Przechowuj tutaj pliki związane z wykładami.';
        meetingDescription = 'Przechowuj tutaj pliki związane ze spotkaniami.';
        break;
      case 'ps':
        defaultLittenTitle = 'د پیل لیټن';
        lectureTitle = 'لیکچر';
        meetingTitle = 'غونډه';
        defaultLittenDescription = 'د هغه فایلونو لپاره چې د لیټن د ټاکلو پرته رامینځته شوي.';
        lectureDescription = 'د لیکچر پورې اړوند فایلونه دلته خوندي کړئ.';
        meetingDescription = 'د غونډې پورې اړوند فایلونه دلته خوندي کړئ.';
        break;
      case 'ms':
        defaultLittenTitle = 'Litten Lalai';
        lectureTitle = 'Kuliah';
        meetingTitle = 'Mesyuarat';
        defaultLittenDescription = 'Ruang lalai untuk fail yang dibuat tanpa memilih litten.';
        lectureDescription = 'Simpan fail berkaitan kuliah di sini.';
        meetingDescription = 'Simpan fail berkaitan mesyuarat di sini.';
        break;
      case 'ro':
        defaultLittenTitle = 'Litten Implicit';
        lectureTitle = 'Prelegere';
        meetingTitle = 'Întâlnire';
        defaultLittenDescription = 'Spațiul implicit pentru fișierele create fără selectarea unui litten.';
        lectureDescription = 'Stocați aici fișierele legate de prelegeri.';
        meetingDescription = 'Stocați aici fișierele legate de întâlniri.';
        break;
      case 'nl':
        defaultLittenTitle = 'Standaard Litten';
        lectureTitle = 'Lezing';
        meetingTitle = 'Vergadering';
        defaultLittenDescription = 'Standaardruimte voor bestanden die zijn gemaakt zonder een litten te selecteren.';
        lectureDescription = 'Sla lezinggerelateerde bestanden hier op.';
        meetingDescription = 'Sla vergaderinggerelateerde bestanden hier op.';
        break;
      case 'ha':
        defaultLittenTitle = 'Litten na Asali';
        lectureTitle = 'Lacca';
        meetingTitle = 'Taro';
        defaultLittenDescription = 'Wurin asali na fayiloli da aka kirkira ba tare da zabar litten ba.';
        lectureDescription = 'Ajiye fayiloli masu alaka da lacca a nan.';
        meetingDescription = 'Ajiye fayiloli masu alaka da taro a nan.';
        break;
      case 'th':
        defaultLittenTitle = 'ลิทเทนเริ่มต้น';
        lectureTitle = 'การบรรยาย';
        meetingTitle = 'การประชุม';
        defaultLittenDescription = 'พื้นที่เริ่มต้นสำหรับไฟล์ที่สร้างโดยไม่ได้เลือกลิทเทน';
        lectureDescription = 'เก็บไฟล์ที่เกี่ยวข้องกับการบรรยายไว้ที่นี่';
        meetingDescription = 'เก็บไฟล์ที่เกี่ยวข้องกับการประชุมไว้ที่นี่';
        break;
      default:
        defaultLittenTitle = 'Default Litten';
        lectureTitle = 'Lecture';
        meetingTitle = 'Meeting';
        defaultLittenDescription = 'Default space for files created without selecting a litten.';
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
}

enum SubscriptionType {
  free,
  standard,
  premium,
}
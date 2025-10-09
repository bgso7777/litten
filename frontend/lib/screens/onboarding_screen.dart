import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state_provider.dart';
import '../config/themes.dart';
import '../l10n/app_localizations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  String? _selectedLanguage;
  AppThemeType? _selectedTheme;

  // 지원하는 언어 목록 (시스템 언어로 표시)
  final List<LanguageOption> _languages = [
    LanguageOption('en', 'English', '🇺🇸'),
    LanguageOption('ko', '한국어', '🇰🇷'),
    LanguageOption('zh', '中文', '🇨🇳'),
    LanguageOption('hi', 'हिन्दी', '🇮🇳'),
    LanguageOption('es', 'Español', '🇪🇸'),
    LanguageOption('fr', 'Français', '🇫🇷'),
    LanguageOption('ar', 'العربية', '🇸🇦'),
    LanguageOption('bn', 'বাংলা', '🇧🇩'),
    LanguageOption('ru', 'Русский', '🇷🇺'),
    LanguageOption('pt', 'Português', '🇧🇷'),
    LanguageOption('ur', 'اردو', '🇵🇰'),
    LanguageOption('id', 'Bahasa Indonesia', '🇮🇩'),
    LanguageOption('de', 'Deutsch', '🇩🇪'),
    LanguageOption('ja', '日本語', '🇯🇵'),
    LanguageOption('sw', 'Kiswahili', '🇰🇪'),
    LanguageOption('mr', 'मराठी', '🇮🇳'),
    LanguageOption('te', 'తెలుగు', '🇮🇳'),
    LanguageOption('tr', 'Türkçe', '🇹🇷'),
    LanguageOption('ta', 'தமிழ்', '🇮🇳'),
    LanguageOption('fa', 'فارسی', '🇮🇷'),
    LanguageOption('uk', 'Українська', '🇺🇦'),
    LanguageOption('it', 'Italiano', '🇮🇹'),
    LanguageOption('tl', 'Filipino', '🇵🇭'),
    LanguageOption('pl', 'Polski', '🇵🇱'),
    LanguageOption('ps', 'پښتو', '🇦🇫'),
    LanguageOption('ms', 'Bahasa Melayu', '🇲🇾'),
    LanguageOption('ro', 'Română', '🇷🇴'),
    LanguageOption('nl', 'Nederlands', '🇳🇱'),
    LanguageOption('ha', 'Hausa', '🇳🇬'),
    LanguageOption('th', 'ไทย', '🇹🇭'),
  ];

  // 테마 옵션
  List<ThemeOption> _getThemeOptions(AppLocalizations? l10n) {
    return [
      ThemeOption(AppThemeType.classicBlue, 'Classic Blue', l10n?.classicBlue ?? '클래식 블루', Color(0xFF4A90E2)),
      ThemeOption(AppThemeType.darkMode, 'Dark Mode', l10n?.darkMode ?? '다크 모드', Color(0xFF64B5F6)),
      ThemeOption(AppThemeType.natureGreen, 'Nature Green', l10n?.natureGreen ?? '네이처 그린', Color(0xFF4CAF50)),
      ThemeOption(AppThemeType.sunsetOrange, 'Sunset Orange', l10n?.sunsetOrange ?? '선셋 오렌지', Color(0xFFFF9800)),
      ThemeOption(AppThemeType.monochromeGrey, 'Monochrome Grey', l10n?.monochromeGrey ?? '모노크롬 그레이', Color(0xFF757575)),
    ];
  }

  SubscriptionType? _selectedSubscription;

  @override
  void initState() {
    super.initState();

    // 시스템 언어를 기본 선택으로 설정
    final appState = context.read<AppStateProvider>();
    _selectedLanguage = appState.locale.languageCode;
    _selectedTheme = ThemeManager.getThemeByLocale(_selectedLanguage!);
    _selectedSubscription = SubscriptionType.free; // 기본값: 무료
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 상단 진행 표시
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  for (int i = 0; i < 4; i++)
                    Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
                        decoration: BoxDecoration(
                          color: i <= _currentPage
                              ? Theme.of(context).primaryColor
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 페이지 뷰
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildWelcomePage(),
                  _buildLanguagePage(),
                  _buildThemePage(),
                  _buildSubscriptionPage(),
                ],
              ),
            ),
            // 하단 버튼
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousPage,
                        child: Text(AppLocalizations.of(context)?.previous ?? '이전'),
                      ),
                    ),
                  if (_currentPage > 0)
                    const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _currentPage == 3 ? _completeOnboarding : _nextPage,
                      child: Text(_currentPage == 3
                          ? (AppLocalizations.of(context)?.getStarted ?? '시작하기')
                          : (AppLocalizations.of(context)?.next ?? '다음')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 앱 로고/아이콘
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(
              Icons.note_alt_outlined,
              size: 60,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 32),
          
          // 앱 이름
          Text(
            'Litten',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          
          // 설명
          Text(
            l10n?.welcomeDescription ?? 'Smart note app that integrates\nlisten, write, and draw',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 48),
          
          // 기능 소개
          _buildFeatureItem(
            icon: Icons.mic,
            title: l10n?.listen ?? 'Listen',
            description: l10n?.listenDescription ?? 'Voice recording and playback',
            color: AppColors.recordingColor,
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(
            icon: Icons.edit_note,
            title: l10n?.write ?? 'Write',
            description: l10n?.writeDescription ?? 'Text creation and editing',
            color: AppColors.writingColor,
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(
            icon: Icons.draw,
            title: l10n?.draw ?? 'Draw',
            description: l10n?.drawDescription ?? 'Handwriting on images',
            color: AppColors.handwritingColor,
          ),
        ],
      ),
    );
  }

  Widget _buildLanguagePage() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            l10n?.selectLanguage ?? '언어를 선택하세요',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.selectLanguageDescription ?? '앱에서 사용할 언어를 선택해주세요',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: ListView.separated(
              itemCount: _languages.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                // 선택된 언어를 맨 위로 정렬
                final sortedLanguages = List<LanguageOption>.from(_languages);
                sortedLanguages.sort((a, b) {
                  if (a.code == _selectedLanguage) return -1;
                  if (b.code == _selectedLanguage) return 1;
                  return 0;
                });
                final language = sortedLanguages[index];
                final isSelected = _selectedLanguage == language.code;
                
                return ListTile(
                  leading: Text(
                    language.flag,
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(
                    language.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected 
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).primaryColor,
                        )
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected 
                          ? Theme.of(context).primaryColor 
                          : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  onTap: () async {
                    // 언어 변경 먼저 적용
                    final appState = context.read<AppStateProvider>();
                    await appState.changeLanguage(language.code);
                    
                    // 상태 업데이트 및 위젯 재빌드
                    setState(() {
                      _selectedLanguage = language.code;
                      // 언어 변경 시 추천 테마도 업데이트
                      _selectedTheme = ThemeManager.getThemeByLocale(language.code);
                    });
                    
                    // 언어 선택 후 첫 화면(Welcome 페이지)으로 돌아가기
                    _pageController.animateToPage(
                      0, // Welcome 페이지
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemePage() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            l10n?.selectTheme ?? '테마를 선택하세요',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.themeRecommendationMessage ?? '선택하신 언어에 맞는 추천 테마가 자동으로 선택되었습니다',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: ListView.separated(
              itemCount: _getThemeOptions(l10n).length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final themes = _getThemeOptions(l10n);
                final theme = themes[index];
                final isSelected = _selectedTheme == theme.type;
                final isRecommended = _selectedTheme == theme.type && 
                    ThemeManager.getThemeByLocale(_selectedLanguage!) == theme.type;
                
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.color,
                      borderRadius: BorderRadius.circular(20),
                      border: isSelected 
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                      boxShadow: isSelected 
                          ? [BoxShadow(
                              color: theme.color.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )]
                          : null,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        theme.koreanName, // 이미 l10n으로 처리된 이름
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            l10n?.recommended ?? '추천',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(theme.englishName),
                  trailing: isSelected 
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).primaryColor,
                        )
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected 
                          ? Theme.of(context).primaryColor 
                          : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  onTap: () => setState(() => _selectedTheme = theme.type),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionPage() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            l10n?.selectSubscriptionPlan ?? '구독 플랜을 선택하세요',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.subscriptionDescription ?? '원하시는 플랜을 선택해주세요',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: ListView(
              children: [
                _buildSubscriptionOption(
                  type: SubscriptionType.free,
                  title: l10n?.freeVersion ?? 'Free',
                  price: l10n?.freeWithAds ?? 'Free (with ads)',
                  features: [
                    '${l10n?.maxLittens ?? 'Litten'}: ${l10n?.maxLittensLimit ?? 'Max 5'}',
                    '${l10n?.maxRecordingFiles ?? 'Recording files'}: ${l10n?.maxRecordingFilesLimit ?? 'Max 10'}',
                    '${l10n?.maxTextFiles ?? 'Text files'}: ${l10n?.maxTextFilesLimit ?? 'Max 5'}',
                    '${l10n?.maxHandwritingFiles ?? 'Handwriting files'}: ${l10n?.maxHandwritingFilesLimit ?? 'Max 5'}',
                  ],
                  color: Colors.grey,
                ),
                const SizedBox(height: 12),
                _buildSubscriptionOption(
                  type: SubscriptionType.standard,
                  title: l10n?.standardVersion ?? 'Standard',
                  price: l10n?.standardMonthly ?? 'Standard (\$4.99/month)',
                  features: [
                    l10n?.removeAds ?? 'Remove ads',
                    l10n?.unlimitedLittens ?? 'Unlimited littens',
                    l10n?.unlimitedFiles ?? 'Unlimited files',
                  ],
                  color: AppColors.recordingColor,
                ),
                const SizedBox(height: 12),
                _buildSubscriptionOption(
                  type: SubscriptionType.premium,
                  title: l10n?.premiumVersion ?? 'Premium',
                  price: l10n?.premiumMonthly ?? 'Premium (\$9.99/month)',
                  features: [
                    l10n?.allStandardFeatures ?? 'All Standard features',
                    l10n?.cloudSync ?? 'Cloud sync',
                    l10n?.multiDeviceSupport ?? 'Multi-device support',
                  ],
                  color: AppColors.handwritingColor,
                  comingSoon: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionOption({
    required SubscriptionType type,
    required String title,
    required String price,
    required List<String> features,
    required Color color,
    bool comingSoon = false,
  }) {
    final l10n = AppLocalizations.of(context);
    final isSelected = _selectedSubscription == type;

    return GestureDetector(
      onTap: () => setState(() => _selectedSubscription = type),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : Colors.black,
                    ),
                  ),
                ),
                if (comingSoon)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n?.comingSoon ?? 'Coming Soon',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                if (isSelected && !comingSoon)
                  Icon(Icons.check_circle, color: color),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            ...features.map((feature) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.check,
                    size: 16,
                    color: isSelected ? color : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _completeOnboarding() {
    final appState = context.read<AppStateProvider>();
    appState.completeOnboarding(
      selectedLanguage: _selectedLanguage,
      selectedTheme: _selectedTheme,
      selectedSubscription: _selectedSubscription,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class LanguageOption {
  final String code;
  final String name;
  final String flag;
  
  LanguageOption(this.code, this.name, this.flag);
}

class ThemeOption {
  final AppThemeType type;
  final String englishName;
  final String koreanName;
  final Color color;
  
  ThemeOption(this.type, this.englishName, this.koreanName, this.color);
}
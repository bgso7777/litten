import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state_provider.dart';
import '../config/themes.dart';

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
  final List<ThemeOption> _themes = [
    ThemeOption(AppThemeType.classicBlue, 'Classic Blue', '클래식 블루', Color(0xFF4A90E2)),
    ThemeOption(AppThemeType.darkMode, 'Dark Mode', '다크 모드', Color(0xFF64B5F6)),
    ThemeOption(AppThemeType.natureGreen, 'Nature Green', '네이처 그린', Color(0xFF4CAF50)),
    ThemeOption(AppThemeType.sunsetOrange, 'Sunset Orange', '선셋 오렌지', Color(0xFFFF9800)),
    ThemeOption(AppThemeType.monochromeGrey, 'Monochrome Grey', '모노크롬 그레이', Color(0xFF757575)),
  ];

  @override
  void initState() {
    super.initState();
    
    // 시스템 언어를 기본 선택으로 설정
    final appState = context.read<AppStateProvider>();
    _selectedLanguage = appState.locale.languageCode;
    _selectedTheme = ThemeManager.getThemeByLocale(_selectedLanguage!);
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
                  for (int i = 0; i < 3; i++)
                    Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
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
                        child: const Text('이전'),
                      ),
                    ),
                  if (_currentPage > 0)
                    const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _currentPage == 2 ? _completeOnboarding : _nextPage,
                      child: Text(_currentPage == 2 ? '시작하기' : '다음'),
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
            '듣기, 쓰기, 필기를 통합한\n스마트 노트 앱',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 48),
          
          // 기능 소개
          _buildFeatureItem(
            icon: Icons.mic,
            title: '듣기',
            description: '음성 녹음 및 재생',
            color: AppColors.recordingColor,
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(
            icon: Icons.edit_note,
            title: '쓰기',
            description: '텍스트 작성 및 편집',
            color: AppColors.writingColor,
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(
            icon: Icons.draw,
            title: '필기',
            description: '이미지 위에 필기',
            color: AppColors.handwritingColor,
          ),
        ],
      ),
    );
  }

  Widget _buildLanguagePage() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            '언어를 선택하세요',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '앱에서 사용할 언어를 선택해주세요',
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
                final language = _languages[index];
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
                  onTap: () => setState(() {
                    _selectedLanguage = language.code;
                    // 언어 변경 시 추천 테마도 업데이트
                    _selectedTheme = ThemeManager.getThemeByLocale(language.code);
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemePage() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            '테마를 선택하세요',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '선택하신 언어에 맞는 추천 테마가 자동으로 선택되었습니다',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: ListView.separated(
              itemCount: _themes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final theme = _themes[index];
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
                        theme.koreanName,
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
                            '추천',
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
    if (_currentPage < 2) {
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
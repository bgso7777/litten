import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../services/preferences_service.dart';
import 'main_tab_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
          },
          children: [
            _buildWelcomePage(),
            _buildLanguageSelectionPage(),
            _buildThemeSelectionPage(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.headphones,
              size: 60,
              color: Color(0xFF2196F3),
            ),
          ),
          const SizedBox(height: 40),
          const Text(
            '리튼 (Litten)',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '듣기 + 쓰기 통합 노트 앱',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 60),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                _buildFeatureItem(
                  Icons.mic,
                  '음성 녹음 & 재생',
                  '강의나 회의 내용을 녹음하고 언제든 다시 들어보세요',
                ),
                const SizedBox(height: 20),
                _buildFeatureItem(
                  Icons.edit,
                  '실시간 메모 작성',
                  '듣기 중에 중요한 내용을 텍스트나 필기로 기록하세요',
                ),
                const SizedBox(height: 20),
                _buildFeatureItem(
                  Icons.sync,
                  '음성-텍스트 동기화',
                  '작성한 메모와 음성의 위치가 자동으로 연결됩니다',
                ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: () {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Theme.of(context).primaryColor,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: const Text(
                '시작하기',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
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
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSelectionPage() {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const Expanded(
                    child: Text(
                      '언어 선택',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                '리튼을 사용할 언어를 선택해주세요.\n30개 언어를 지원합니다.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 30),
              
              // 언어별 그룹으로 나누어 표시
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLanguageGroup(
                        '주요 언어',
                        [
                          {'code': 'ko', 'name': '한국어', 'englishName': 'Korean'},
                          {'code': 'en', 'name': 'English', 'englishName': 'English'},
                          {'code': 'zh', 'name': '中文', 'englishName': 'Chinese'},
                          {'code': 'ja', 'name': '日本語', 'englishName': 'Japanese'},
                          {'code': 'es', 'name': 'Español', 'englishName': 'Spanish'},
                          {'code': 'fr', 'name': 'Français', 'englishName': 'French'},
                        ],
                        localeProvider,
                      ),
                      const SizedBox(height: 20),
                      _buildLanguageGroup(
                        '아시아 언어',
                        [
                          {'code': 'hi', 'name': 'हिन्दी', 'englishName': 'Hindi'},
                          {'code': 'bn', 'name': 'বাংলা', 'englishName': 'Bengali'},
                          {'code': 'ur', 'name': 'اردو', 'englishName': 'Urdu'},
                          {'code': 'id', 'name': 'Bahasa Indonesia', 'englishName': 'Indonesian'},
                          {'code': 'ms', 'name': 'Bahasa Melayu', 'englishName': 'Malay'},
                          {'code': 'th', 'name': 'ไทย', 'englishName': 'Thai'},
                          {'code': 'te', 'name': 'తెలుగు', 'englishName': 'Telugu'},
                          {'code': 'ta', 'name': 'தமிழ்', 'englishName': 'Tamil'},
                          {'code': 'mr', 'name': 'मराठी', 'englishName': 'Marathi'},
                          {'code': 'tl', 'name': 'Filipino', 'englishName': 'Filipino'},
                        ],
                        localeProvider,
                      ),
                      const SizedBox(height: 20),
                      _buildLanguageGroup(
                        '유럽 언어',
                        [
                          {'code': 'de', 'name': 'Deutsch', 'englishName': 'German'},
                          {'code': 'ru', 'name': 'Русский', 'englishName': 'Russian'},
                          {'code': 'pt', 'name': 'Português', 'englishName': 'Portuguese'},
                          {'code': 'it', 'name': 'Italiano', 'englishName': 'Italian'},
                          {'code': 'pl', 'name': 'Polski', 'englishName': 'Polish'},
                          {'code': 'uk', 'name': 'Українська', 'englishName': 'Ukrainian'},
                          {'code': 'tr', 'name': 'Türkçe', 'englishName': 'Turkish'},
                          {'code': 'nl', 'name': 'Nederlands', 'englishName': 'Dutch'},
                          {'code': 'ro', 'name': 'Română', 'englishName': 'Romanian'},
                        ],
                        localeProvider,
                      ),
                      const SizedBox(height: 20),
                      _buildLanguageGroup(
                        '중동 & 아프리카 언어',
                        [
                          {'code': 'ar', 'name': 'العربية', 'englishName': 'Arabic'},
                          {'code': 'fa', 'name': 'فارسی', 'englishName': 'Persian'},
                          {'code': 'ps', 'name': 'پښتو', 'englishName': 'Pashto'},
                          {'code': 'sw', 'name': 'Kiswahili', 'englishName': 'Swahili'},
                          {'code': 'ha', 'name': 'Hausa', 'englishName': 'Hausa'},
                        ],
                        localeProvider,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    '다음',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageGroup(String groupTitle, List<Map<String, String>> languages, LocaleProvider localeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          groupTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        ...languages.map((lang) => _buildLanguageItem(
          lang['code']!,
          lang['name']!,
          lang['englishName']!,
          localeProvider,
        )),
      ],
    );
  }

  Widget _buildLanguageItem(String code, String name, String englishName, LocaleProvider localeProvider) {
    final isSelected = localeProvider.locale.languageCode == code;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          localeProvider.setLocale(Locale(code));
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? Theme.of(context).primaryColor : null,
                      ),
                    ),
                    if (name != englishName) ...[
                      const SizedBox(height: 4),
                      Text(
                        englishName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSelectionPage() {
    return Consumer2<ThemeProvider, LocaleProvider>(
      builder: (context, themeProvider, localeProvider, child) {
        final currentLanguage = localeProvider.locale.languageCode;
        final recommendedTheme = themeProvider.getRecommendedThemeForLanguage(currentLanguage);
        
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const Expanded(
                    child: Text(
                      '테마 선택',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                '앱의 색상 테마를 선택해주세요.\n현재 언어(${localeProvider.getLanguageDisplayName(currentLanguage)})에 따라 "${themeProvider.getThemeDisplayName(recommendedTheme)}" 테마가 추천됩니다.',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 30),
              
              Expanded(
                child: ListView(
                  children: [
                    _buildThemeItem('classic_blue', 'Classic Blue', '클래식한 파란색 테마 (아시아권 추천)', const Color(0xFF2196F3), themeProvider, recommendedTheme),
                    const SizedBox(height: 16),
                    _buildThemeItem('dark_mode', 'Dark Mode', '어두운 테마 (유럽권 추천)', const Color(0xFF212121), themeProvider, recommendedTheme),
                    const SizedBox(height: 16),
                    _buildThemeItem('nature_green', 'Nature Green', '자연친화적 녹색 테마 (아메리카권 추천)', const Color(0xFF4CAF50), themeProvider, recommendedTheme),
                    const SizedBox(height: 16),
                    _buildThemeItem('sunset_orange', 'Sunset Orange', '따뜻한 주황색 테마 (중동/아프리카권 추천)', const Color(0xFFFF9800), themeProvider, recommendedTheme),
                    const SizedBox(height: 16),
                    _buildThemeItem('monochrome_grey', 'Monochrome Grey', '모노크롬 회색 테마 (기타 지역 추천)', const Color(0xFF757575), themeProvider, recommendedTheme),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _completeOnboarding();
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    '앱 시작하기',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeItem(String themeId, String title, String description, Color color, ThemeProvider themeProvider, String recommendedTheme) {
    final isSelected = themeProvider.currentThemeName == themeId;
    final isRecommended = themeId == recommendedTheme;
    
    return InkWell(
      onTap: () {
        themeProvider.setTheme(themeId);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? color : (isRecommended ? color.withOpacity(0.6) : Colors.grey.withOpacity(0.3)),
            width: isSelected ? 2 : (isRecommended ? 2 : 1),
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? color.withOpacity(0.1) : (isRecommended ? color.withOpacity(0.05) : null),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: isRecommended && !isSelected
                  ? const Icon(
                      Icons.star,
                      color: Colors.white,
                      size: 20,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected || isRecommended ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? color : (isRecommended ? color.withOpacity(0.8) : null),
                        ),
                      ),
                      if (isRecommended && !isSelected) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '추천',
                            style: TextStyle(
                              fontSize: 12,
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
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
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: color,
                size: 24,
              )
            else if (isRecommended)
              Icon(
                Icons.star_border,
                color: color,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  void _completeOnboarding() async {
    // onboarding 완료 및 첫 실행 완료 표시 저장
    await PreferencesService.setBool('onboarding_completed', true);
    await PreferencesService.setFirstLaunchCompleted();
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainTabScreen()),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
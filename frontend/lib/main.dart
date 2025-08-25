import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'frameworks/providers/theme_provider.dart';
import 'frameworks/providers/locale_provider.dart';
import 'frameworks/screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 세로 방향 고정
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  AppConfig.logInfo('main - 리튼 앱 시작');
  
  runApp(const LittenApp());
}

class LittenApp extends StatelessWidget {
  const LittenApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    AppConfig.logDebug('LittenApp.build - 앱 빌드 시작');
    
    return MultiProvider(
      providers: [
        // Theme Provider
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        
        // Locale Provider
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: Consumer2<ThemeProvider, LocaleProvider>(
        builder: (context, themeProvider, localeProvider, child) {
          AppConfig.logDebug('LittenApp.build - Consumer2 빌드: 테마=\${themeProvider.currentTheme}, 언어=\${localeProvider.languageCode}');
          
          return MaterialApp(
            title: 'Litten',
            
            // 테마 설정
            theme: themeProvider.themeData,
            
            // 다국어 설정
            locale: localeProvider.locale,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: LocaleProvider.supportedLocales,
            
            // RTL 지원
            localeResolutionCallback: (locale, supportedLocales) {
              // 현재 로케일이 RTL인지 확인하여 텍스트 방향 설정
              if (locale != null && LocaleProvider.rtlLanguages.contains(locale.languageCode)) {
                return Locale(locale.languageCode);
              }
              
              // 지원하는 로케일 찾기
              for (final supportedLocale in supportedLocales) {
                if (supportedLocale.languageCode == locale?.languageCode) {
                  return supportedLocale;
                }
              }
              
              // 기본 로케일 반환
              return supportedLocales.first;
            },
            
            // 디버그 배너 제거
            debugShowCheckedModeBanner: false,
            
            // 홈 화면
            home: const AppHomeWrapper(),
            
            // 라우트 설정
            routes: {
              '/home': (context) => const SimpleHomeScreen(),
              '/onboarding': (context) => const OnboardingScreen(),
            },
            
            // 글로벌 텍스트 방향 설정
            builder: (context, child) {
              final isRTL = localeProvider.isRTL;
              return Directionality(
                textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                child: child ?? Container(),
              );
            },
          );
        },
      ),
    );
  }
}

class AppHomeWrapper extends StatefulWidget {
  const AppHomeWrapper({Key? key}) : super(key: key);

  @override
  State<AppHomeWrapper> createState() => _AppHomeWrapperState();
}

class _AppHomeWrapperState extends State<AppHomeWrapper> {
  bool? _isOnboardingCompleted;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    AppConfig.logDebug('AppHomeWrapper._checkOnboardingStatus - 온보딩 상태 확인');
    
    final prefs = await SharedPreferences.getInstance();
    final isCompleted = prefs.getBool('onboarding_completed') ?? false;
    
    AppConfig.logInfo('AppHomeWrapper._checkOnboardingStatus - 온보딩 완료 여부: $isCompleted');
    
    setState(() {
      _isOnboardingCompleted = isCompleted;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isOnboardingCompleted == null) {
      // 로딩 중
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_isOnboardingCompleted!) {
      // 온보딩 완료됨 - 메인 화면
      return const SimpleHomeScreen();
    } else {
      // 온보딩 필요 - 온보딩 화면
      return const OnboardingScreen();
    }
  }
}

class SimpleHomeScreen extends StatelessWidget {
  const SimpleHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('리튼 (Litten)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // 설정 화면으로 이동 (온보딩 다시 실행 옵션 포함)
              _showSettingsDialog(context);
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.headset_mic,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            const Text(
              '듣기와 쓰기를 하나로',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              '리튼 앱 MVP 버전이 성공적으로 실행되었습니다!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                // 향후 리튼 생성 기능 추가
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('리튼 생성 기능이 곧 추가될 예정입니다!')),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('리튼 생성'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildFeatureCard(
                  icon: Icons.mic,
                  title: '음성 녹음',
                  subtitle: '고품질 녹음',
                ),
                _buildFeatureCard(
                  icon: Icons.edit,
                  title: '텍스트 쓰기',
                  subtitle: '리치 에디터',
                ),
                _buildFeatureCard(
                  icon: Icons.draw,
                  title: '필기/스케치',
                  subtitle: '자유로운 그리기',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: Colors.blue),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('설정'),
          content: const Text('온보딩을 다시 실행하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                
                // 온보딩 완료 상태 초기화
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('onboarding_completed', false);
                
                // 온보딩 화면으로 이동
                Navigator.of(context).pushReplacementNamed('/onboarding');
              },
              child: const Text('온보딩 다시 실행'),
            ),
          ],
        );
      },
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/note_provider.dart';
import 'services/audio_service.dart';
import 'services/drawing_service.dart';
import 'services/subscription_service.dart';
import 'screens/main_tab_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/preferences_service.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 로컬 저장소 초기화
  await PreferencesService.init();
  
  runApp(const LittenApp());
}

class LittenApp extends StatelessWidget {
  const LittenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProxyProvider<LocaleProvider, ThemeProvider>(
          create: (_) => ThemeProvider(),
          update: (context, localeProvider, themeProvider) {
            // 언어가 변경될 때 테마도 자동으로 업데이트
            if (themeProvider != null) {
              themeProvider.updateThemeForLanguage(localeProvider.locale.languageCode);
            }
            return themeProvider ?? ThemeProvider();
          },
        ),
        ChangeNotifierProvider(create: (_) => NoteProvider()),
        ChangeNotifierProvider(create: (_) => AudioService()),
        ChangeNotifierProvider(create: (_) => DrawingService()),
        ChangeNotifierProvider(create: (_) => SubscriptionService()),
      ],
      child: Consumer2<LocaleProvider, ThemeProvider>(
        builder: (context, localeProvider, themeProvider, child) {
          return MaterialApp(
            title: 'Litten',
            debugShowCheckedModeBanner: false,
            
            // 테마 설정
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            
            // 국제화 설정
            locale: localeProvider.locale,
            supportedLocales: AppConfig.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            
            // 네비게이션
            home: const AppInitializer(),
          );
        },
      ),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  void _checkOnboardingStatus() async {
    // onboarding 완료 여부 확인
    final bool onboardingCompleted = PreferencesService.getBool('onboarding_completed') ?? false;
    
    // 웹 환경에서 디버깅을 위해 온보딩을 항상 표시 (개발 모드)
    // 배포 시에는 이 라인을 제거하세요
    final bool forceOnboarding = false;
    
    // 짧은 지연 후 해당 화면으로 이동
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => (onboardingCompleted && !forceOnboarding)
              ? const MainTabScreen() 
              : const OnboardingScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.headphones,
              size: 80,
              color: Colors.white,
            ),
            SizedBox(height: 20),
            Text(
              '리튼 (Litten)',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '듣기 + 쓰기 통합 노트 앱',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: 40),
            CircularProgressIndicator(
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
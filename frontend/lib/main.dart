import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'config/app_localizations_temp.dart';

import 'services/app_state_provider.dart';
import 'screens/main_tab_screen.dart';
import 'screens/onboarding_screen.dart';
import 'config/themes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppStateProvider(),
      child: const LittenApp(),
    ),
  );
}

class LittenApp extends StatelessWidget {
  const LittenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return MaterialApp(
          title: 'Litten',
          theme: appState.theme,
          locale: appState.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'), // English
            Locale('ko'), // Korean
            Locale('zh'), // Chinese
            Locale('hi'), // Hindi
            Locale('es'), // Spanish
            Locale('fr'), // French
            Locale('ar'), // Arabic
            Locale('bn'), // Bengali
            Locale('ru'), // Russian
            Locale('pt'), // Portuguese
            Locale('ur'), // Urdu
            Locale('id'), // Indonesian
            Locale('de'), // German
            Locale('ja'), // Japanese
            Locale('sw'), // Swahili
            Locale('mr'), // Marathi
            Locale('te'), // Telugu
            Locale('tr'), // Turkish
            Locale('ta'), // Tamil
            Locale('fa'), // Persian
            Locale('uk'), // Ukrainian
            Locale('it'), // Italian
            Locale('tl'), // Tagalog
            Locale('pl'), // Polish
            Locale('ps'), // Pashto
            Locale('ms'), // Malay
            Locale('ro'), // Romanian
            Locale('nl'), // Dutch
            Locale('ha'), // Hausa
            Locale('th'), // Thai
          ],
          home: FutureBuilder(
            future: appState.isInitialized 
                ? Future.value() 
                : appState.initializeApp(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              // 첫 실행 시 온보딩 화면 표시
              if (appState.isFirstLaunch) {
                return const OnboardingScreen();
              }
              
              return const MainTabScreen();
            },
          ),
          builder: (context, child) {
            // RTL 언어 지원
            final languageCode = appState.locale.languageCode;
            final textDirection = RTLHelper.getTextDirection(languageCode);
            
            return Directionality(
              textDirection: textDirection,
              child: child!,
            );
          },
        );
      },
    );
  }
}
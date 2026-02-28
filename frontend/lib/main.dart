import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';

import 'services/app_state_provider.dart';
import 'services/background_notification_service.dart';
import 'screens/main_tab_screen.dart';
import 'screens/onboarding_screen.dart';
import 'config/themes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 백그라운드 알림 서비스 초기화
  await BackgroundNotificationService().initialize();

  runApp(
    ChangeNotifierProvider(
      create: (context) => AppStateProvider(),
      child: const LittenApp(),
    ),
  );
}

class LittenApp extends StatefulWidget {
  const LittenApp({super.key});

  @override
  State<LittenApp> createState() => _LittenAppState();
}

class _LittenAppState extends State<LittenApp> {
  // ⭐ MainTabScreen 상태 유지를 위한 GlobalKey
  final GlobalKey _mainTabScreenKey = GlobalKey();
  Widget? _cachedHome;
  bool _wasFirstLaunch = true; // 이전 isFirstLaunch 상태 추적

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        // ⭐ isFirstLaunch 상태가 변경되었는지 확인
        final isFirstLaunchChanged = _wasFirstLaunch != appState.isFirstLaunch;
        if (isFirstLaunchChanged) {
          _wasFirstLaunch = appState.isFirstLaunch;
          _cachedHome = null; // 캐시 초기화하여 새 화면으로 전환
        }

        // ⭐ home 위젯을 캐시하여 재사용 (theme/locale 변경 시에도 MainTabScreen 상태 유지)
        if (_cachedHome == null) {
          if (appState.isFirstLaunch) {
            _cachedHome = const OnboardingScreen();
          } else if (appState.isInitialized) {
            _cachedHome = MainTabScreen(key: _mainTabScreenKey);
          }
        }

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
          supportedLocales: AppLocalizations.supportedLocales,
          home: appState.isInitialized
              ? _cachedHome
              : FutureBuilder(
                  future: appState.initializeApp(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    // 초기화 완료 후 캐시된 home으로 전환
                    return _cachedHome ?? const SizedBox();
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
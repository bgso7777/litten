import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_localizations_temp.dart';

import '../services/app_state_provider.dart';
import '../widgets/common/ad_banner.dart';
import 'home_screen.dart';
import 'recording_screen.dart';
import 'writing_screen.dart';
import 'settings_screen.dart';
import '../config/themes.dart';

class MainTabScreen extends StatelessWidget {
  const MainTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        final l10n = AppLocalizations.of(context);
        
        return Scaffold(
          appBar: AppBar(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 8),
                const Icon(Icons.headphones, size: 24),
                AppSpacing.horizontalSpaceXS,
                const Icon(Icons.mic, size: 16),
                AppSpacing.horizontalSpaceXS,
                const Icon(Icons.edit, size: 16),
              ],
            ),
            leadingWidth: 80,
            title: appState.selectedLitten != null
                ? Text(
                    appState.selectedLitten!.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : Text(
                    l10n?.emptyLittenTitle ?? '리튼을 생성하거나 선택하세요',
                    style: const TextStyle(fontSize: 14),
                  ),
            actions: appState.selectedLitten != null
                ? [
                    // 듣기 파일 배지
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.recordingColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.mic, size: 12, color: Colors.white),
                          AppSpacing.horizontalSpaceXS,
                          Text(
                            '${appState.selectedLitten!.audioCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.horizontalSpaceXS,
                    // 쓰기 파일 배지
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.writingColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit, size: 12, color: Colors.white),
                          AppSpacing.horizontalSpaceXS,
                          Text(
                            '${appState.selectedLitten!.textCount + appState.selectedLitten!.handwritingCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.horizontalSpaceM,
                  ]
                : null,
          ),
          body: Column(
            children: [
              if (!appState.isPremiumUser) const AdBanner(),
              Expanded(
                child: IndexedStack(
                  index: appState.selectedTabIndex,
                  children: const [
                    HomeScreen(),
                    RecordingScreen(),
                    WritingScreen(),
                    SettingsScreen(),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: appState.selectedTabIndex,
            onTap: appState.changeTabIndex,
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home),
                label: l10n?.homeTitle ?? '홈',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.mic),
                label: l10n?.recordingTitle ?? '듣기',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.edit),
                label: l10n?.writingTitle ?? '쓰기',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.settings),
                label: l10n?.settingsTitle ?? '설정',
              ),
            ],
          ),
        );
      },
    );
  }
}
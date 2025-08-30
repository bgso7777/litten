import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';

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
                const Icon(Icons.hearing, size: 24),
                AppSpacing.horizontalSpaceXS,
                const Icon(Icons.mic, size: 16),
                AppSpacing.horizontalSpaceXS,
                const Icon(Icons.draw, size: 16),
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
            actions: _buildFileCountBadges(appState),
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
                icon: const Icon(Icons.hearing),
                label: l10n?.recordingTitle ?? '듣기',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.draw),
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

  List<Widget>? _buildFileCountBadges(AppStateProvider appState) {
    int audioCount = 0;
    int textCount = 0;
    int handwritingCount = 0;

    if (appState.selectedLitten != null) {
      // 선택된 리튼의 파일 수 표시
      audioCount = appState.selectedLitten!.audioCount;
      textCount = appState.selectedLitten!.textCount;
      handwritingCount = appState.selectedLitten!.handwritingCount;
    } else {
      // 전체 리튼의 파일 수 합계 표시
      for (final litten in appState.littens) {
        audioCount += litten.audioCount;
        textCount += litten.textCount;
        handwritingCount += litten.handwritingCount;
      }
    }

    // 파일이 하나도 없으면 배지를 표시하지 않음
    if (audioCount == 0 && textCount == 0 && handwritingCount == 0) {
      return null;
    }

    final badges = <Widget>[];

    // 녹음 파일 배지
    if (audioCount > 0) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.recordingColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hearing, size: 12, color: Colors.white),
              AppSpacing.horizontalSpaceXS,
              Text(
                audioCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 텍스트 파일 배지
    if (textCount > 0) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.writingColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.keyboard, size: 12, color: Colors.white),
              AppSpacing.horizontalSpaceXS,
              Text(
                textCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 필기 파일 배지
    if (handwritingCount > 0) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.writingColor.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.draw, size: 12, color: Colors.white),
              AppSpacing.horizontalSpaceXS,
              Text(
                handwritingCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 배지들 사이에 균일한 간격 추가
    final spacedBadges = <Widget>[];
    for (int i = 0; i < badges.length; i++) {
      spacedBadges.add(badges[i]);
      if (i < badges.length - 1) {
        spacedBadges.add(AppSpacing.horizontalSpaceXS);
      }
    }
    
    // 마지막에 여백 추가
    if (spacedBadges.isNotEmpty) {
      spacedBadges.add(AppSpacing.horizontalSpaceM);
    }

    return spacedBadges.isEmpty ? null : spacedBadges;
  }
}
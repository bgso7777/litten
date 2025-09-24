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
import '../utils/responsive_utils.dart';

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
            actions: _buildFileCountBadges(appState, context),
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
            onTap: (index) {
              if (index == 0) {
                // 홈탭 클릭 시 알림 확인 처리
                _clearHomeNotifications(appState);
              }
              appState.changeTabIndex(index);
            },
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(
                icon: _buildHomeIconWithBadge(appState),
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

  List<Widget>? _buildFileCountBadges(AppStateProvider appState, BuildContext context) {
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

    final badges = <Widget>[];

    // 전체 리튼 수 배지 (가장 앞에 추가)
    final littenCount = appState.littens.length;
    badges.add(
      Container(
        padding: ResponsiveUtils.getBadgePadding(context),
        decoration: BoxDecoration(
          color: littenCount > 0 
              ? Theme.of(context).primaryColor
              : Theme.of(context).primaryColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(ResponsiveUtils.getBadgeBorderRadius(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder, 
                size: ResponsiveUtils.getBadgeIconSize(context), 
                color: littenCount > 0 ? Colors.white : Colors.white70),
            AppSpacing.horizontalSpaceXS,
            Text(
              littenCount.toString(),
              style: TextStyle(
                color: littenCount > 0 ? Colors.white : Colors.white70,
                fontSize: ResponsiveUtils.getBadgeFontSize(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );

    // 녹음 파일 배지 (0개일 때도 표시)
    badges.add(
      Container(
        padding: ResponsiveUtils.getBadgePadding(context),
        decoration: BoxDecoration(
          color: audioCount > 0 ? AppColors.recordingColor : AppColors.recordingColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(ResponsiveUtils.getBadgeBorderRadius(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hearing, 
                size: ResponsiveUtils.getBadgeIconSize(context), 
                color: audioCount > 0 ? Colors.white : Colors.white70),
            AppSpacing.horizontalSpaceXS,
            Text(
              audioCount.toString(),
              style: TextStyle(
                color: audioCount > 0 ? Colors.white : Colors.white70,
                fontSize: ResponsiveUtils.getBadgeFontSize(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );

    // 텍스트 파일 배지 (0개일 때도 표시)
    badges.add(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 4.9, vertical: 1.6),
        decoration: BoxDecoration(
          color: textCount > 0 ? AppColors.writingColor : AppColors.writingColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(ResponsiveUtils.getBadgeBorderRadius(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.keyboard, 
                size: ResponsiveUtils.getBadgeIconSize(context), 
                color: textCount > 0 ? Colors.white : Colors.white70),
            AppSpacing.horizontalSpaceXS,
            Text(
              textCount.toString(),
              style: TextStyle(
                color: textCount > 0 ? Colors.white : Colors.white70,
                fontSize: ResponsiveUtils.getBadgeFontSize(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );

    // 필기 파일 배지 (0개일 때도 표시)
    badges.add(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 4.9, vertical: 1.6),
        decoration: BoxDecoration(
          color: handwritingCount > 0 
              ? AppColors.writingColor.withValues(alpha: 0.8)
              : AppColors.writingColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(ResponsiveUtils.getBadgeBorderRadius(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.draw, 
                size: ResponsiveUtils.getBadgeIconSize(context), 
                color: handwritingCount > 0 ? Colors.white : Colors.white70),
            AppSpacing.horizontalSpaceXS,
            Text(
              handwritingCount.toString(),
              style: TextStyle(
                color: handwritingCount > 0 ? Colors.white : Colors.white70,
                fontSize: ResponsiveUtils.getBadgeFontSize(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );


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

    return spacedBadges;
  }

  Widget _buildHomeIconWithBadge(AppStateProvider appState) {
    return AnimatedBuilder(
      animation: appState.notificationService,
      builder: (context, child) {
        final notificationCount = appState.notificationService.firedNotifications.length;

        if (notificationCount == 0) {
          return const Icon(Icons.home);
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.home),
            Positioned(
              right: -8,
              top: -8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  notificationCount > 99 ? '99+' : notificationCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _clearHomeNotifications(AppStateProvider appState) {
    // 홈탭을 클릭했을 때 발생한 알림들을 모두 지움
    final firedNotifications = List.from(appState.notificationService.firedNotifications);
    for (final notification in firedNotifications) {
      appState.notificationService.dismissNotification(notification);
    }
  }
}
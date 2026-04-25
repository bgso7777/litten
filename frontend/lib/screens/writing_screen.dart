import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state_provider.dart';
import '../widgets/draggable_tab_layout.dart';
import '../l10n/app_localizations.dart';
import '../config/themes.dart';
import '../utils/responsive_utils.dart';
import '../widgets/common/litten_unified_list_view.dart';

// 실제 기능 탭들을 import
import '../widgets/recording_tab.dart';
import '../widgets/text_tab.dart';
import '../widgets/handwriting_tab.dart';
import '../widgets/browser_tab.dart';

class WritingScreen extends StatefulWidget {
  const WritingScreen({super.key});

  @override
  State<WritingScreen> createState() => _WritingScreenState();
}

class _WritingScreenState extends State<WritingScreen> {
  late List<TabItem> _tabs;
  final GlobalKey _tabLayoutKey = GlobalKey();
  int _recordingTabRefreshCount = 0; // 녹음 탭 새로고침 카운터
  bool _listVisible = false; // 일정/파일 리스트 패널 표시 여부
  String? _filterType; // 필터 타입: 'text', 'handwriting', 'audio', null=전체

  // ⭐ TextTab 상태 유지를 위한 GlobalKey
  final GlobalKey<State<StatefulWidget>> _textTabKey = GlobalKey();
  final GlobalKey<State<StatefulWidget>> _handwritingTabKey = GlobalKey();
  final GlobalKey<State<StatefulWidget>> _browserTabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // 탭 초기화는 build()에서 AppStateProvider의 저장된 위치를 사용하여 수행
  }

  void _initializeTabs(Map<String, String> savedPositions) {
    // 저장된 위치를 TabPosition enum으로 변환하는 헬퍼 함수
    TabPosition parsePosition(String positionStr) {
      switch (positionStr) {
        case 'topLeft':
          return TabPosition.topLeft;
        case 'topRight':
          return TabPosition.topRight;
        case 'bottomLeft':
          return TabPosition.bottomLeft;
        case 'bottomRight':
          return TabPosition.bottomRight;
        case 'fullScreen':
          return TabPosition.fullScreen;
        default:
          return TabPosition.topLeft;
      }
    }

    // ⭐ AppStateProvider에서 저장된 위치로 탭 초기화
    // ⭐ GlobalKey를 사용하여 위젯 상태 유지 (특히 TextTab의 편집 상태)
    final l10n = AppLocalizations.of(context);
    _tabs = [
      TabItem(
        id: 'text',
        title: l10n?.textTab ?? '텍스트',
        icon: Icons.keyboard,
        content: TextTab(key: _textTabKey),
        position: parsePosition(savedPositions['text'] ?? 'topLeft'),
      ),
      TabItem(
        id: 'handwriting',
        title: l10n?.handwritingTab ?? '필기',
        icon: Icons.draw,
        content: HandwritingTab(key: _handwritingTabKey),
        position: parsePosition(savedPositions['handwriting'] ?? 'topLeft'),
      ),
      TabItem(
        id: 'audio',
        title: l10n?.audioTab ?? '녹음',
        icon: Icons.mic,
        content: RecordingTab(key: ValueKey(_recordingTabRefreshCount)),
        position: parsePosition(savedPositions['audio'] ?? 'topLeft'),
      ),
      TabItem(
        id: 'browser',
        title: l10n?.browserTab ?? '검색',
        icon: Icons.public,
        content: BrowserTab(key: _browserTabKey),
        position: parsePosition(savedPositions['browser'] ?? 'topLeft'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        // ⭐ 저장된 탭 위치로 초기화
        _initializeTabs(appState.writingTabPositions);

        // TabPosition enum을 문자열로 변환하는 헬퍼 함수
        String positionToString(TabPosition position) {
          switch (position) {
            case TabPosition.topLeft:
              return 'topLeft';
            case TabPosition.topRight:
              return 'topRight';
            case TabPosition.bottomLeft:
              return 'bottomLeft';
            case TabPosition.bottomRight:
              return 'bottomRight';
            case TabPosition.fullScreen:
              return 'fullScreen';
          }
        }

        // DraggableTabLayout을 매번 생성하되, initialActiveTabId를 전달
        final draggableTabLayout = DraggableTabLayout(
          key: ValueKey(appState.targetWritingTabId), // targetWritingTabId가 바뀌면 위젯 재생성
          tabs: _tabs,
          initialActiveTabId: appState.currentWritingTabId, // ⭐ AppStateProvider에 저장된 현재 탭 사용
          onTabPositionChanged: (tabId, newPosition) {
            setState(() {
              for (final tab in _tabs) {
                if (tab.id == tabId) {
                  tab.position = newPosition;
                  break;
                }
              }
            });

            // ⭐ 탭 위치가 변경될 때마다 AppStateProvider에 저장
            final positionStr = positionToString(newPosition);
            debugPrint('[WritingScreen] 탭 위치 변경됨: $tabId -> $positionStr');
            appState.setWritingTabPosition(tabId, positionStr);
          },
          onTabChanged: (tabId) {
            // ⭐ 탭이 변경될 때마다 AppStateProvider에 저장
            debugPrint('[WritingScreen] 탭 변경됨: $tabId');
            appState.setCurrentWritingTab(tabId);

            // ⭐ 녹음 탭이 선택되었을 때 위젯 재생성하여 파일 목록 새로고침
            if (tabId == 'audio') {
              setState(() {
                _recordingTabRefreshCount++;
                debugPrint('[WritingScreen] 녹음 탭 새로고침 트리거: $_recordingTabRefreshCount');
              });
            }
          },
        );
        // 리튼이 선택되지 않았을 때
        final body = appState.selectedLitten == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.create_new_folder,
                      size: 64,
                      color: Theme.of(context).disabledColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '먼저 리튼을 선택하거나 생성하세요',
                      style: TextStyle(
                        fontSize: 18,
                        color: Theme.of(context).disabledColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '홈 탭에서 리튼을 관리할 수 있습니다',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).disabledColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              )
            : draggableTabLayout;

        return LayoutBuilder(
          builder: (context, constraints) {
            final totalHeight = constraints.maxHeight;
            final halfHeight = totalHeight / 2;
            const headerHeight = 45.0;
            final listPanelHeight = halfHeight - headerHeight;

            return Stack(
              children: [
                // 메인 콘텐츠 (DraggableTabLayout / 빈 화면)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  top: _listVisible ? halfHeight : headerHeight,
                  left: 0, right: 0, bottom: 0,
                  child: body,
                ),
                // 일정/파일 리스트 패널 (아래로 스와이프 시 나타남)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  top: headerHeight,
                  left: 0, right: 0,
                  height: _listVisible ? listPanelHeight : 0,
                  child: ClipRect(
                    child: _listVisible
                        ? NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              // 리스트 맨 위에서 위로 오버스크롤 → 패널 닫기
                              if (notification is OverscrollNotification && notification.overscroll < -5) {
                                setState(() { _listVisible = false; _filterType = null; });
                                return true;
                              }
                              if (notification is ScrollUpdateNotification && notification.metrics.pixels < 0) {
                                setState(() { _listVisible = false; _filterType = null; });
                                return true;
                              }
                              return false;
                            },
                            child: LittenUnifiedListView(
                              padding: const EdgeInsets.only(left: 8, right: 8, top: 0, bottom: 8),
                              filterType: _filterType,
                              littenId: (_filterType != null && appState.selectedLitten?.title != 'undefined')
                                  ? appState.selectedLitten?.id
                                  : null,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                // 통계 헤더 (항상 최상단)
                Positioned(
                  top: 0, left: 0, right: 0, height: headerHeight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() {
                      _listVisible = !_listVisible;
                      if (!_listVisible) _filterType = null;
                    }),
                    onVerticalDragEnd: (details) {
                      final velocity = details.primaryVelocity ?? 0;
                      if (velocity > 150 && !_listVisible) {
                        setState(() => _listVisible = true);
                      } else if (velocity < -150 && _listVisible) {
                        setState(() { _listVisible = false; _filterType = null; });
                      }
                    },
                    child: _buildStatsHeader(context, appState),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatsHeader(BuildContext context, AppStateProvider appState) {
    final l10n = AppLocalizations.of(context);
    final littenCount = appState.littens.where((l) => l.title != 'undefined').length;
    final hasNotifications = appState.notificationService.firedNotifications.isNotEmpty;
    final displayCount = hasNotifications ? littenCount - 1 : littenCount;

    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).primaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          // 리튼 수 배지 — 패널 열린 상태에서 탭이 헤더 토글로 전파되지 않도록 차단
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_listVisible) {
                // 패널이 열려있으면 필터 해제만 (패널 유지)
                setState(() => _filterType = null);
              } else {
                // 패널이 닫혀있으면 열기
                setState(() => _listVisible = true);
              }
            },
            child: Container(
              padding: ResponsiveUtils.getBadgePadding(context),
              decoration: BoxDecoration(
                color: littenCount > 0
                    ? (hasNotifications ? Colors.orange : Theme.of(context).primaryColor)
                    : Theme.of(context).primaryColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(ResponsiveUtils.getBadgeBorderRadius(context)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_available,
                      size: ResponsiveUtils.getBadgeIconSize(context) * 1.331,
                      color: littenCount > 0 ? Colors.white : Colors.white70),
                  AppSpacing.horizontalSpaceXS,
                  Text(
                    displayCount.toString(),
                    style: TextStyle(
                      color: littenCount > 0 ? Colors.white : Colors.white70,
                      fontSize: ResponsiveUtils.getBadgeFontSize(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 선택된 리튼 이름
          Expanded(
            child: appState.selectedLitten != null && appState.selectedLitten!.title != 'undefined'
                ? Text(
                    appState.selectedLitten!.title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          // 파일 수 배지들
          _buildFileCountBadges(context, appState),
        ],
      ),
    );
  }

  Widget _buildFileCountBadges(BuildContext context, AppStateProvider appState) {
    final audioCount = appState.actualAudioCount;
    final textCount = appState.actualTextCount;
    final handwritingCount = appState.actualHandwritingCount;

    Widget badge(int count, IconData icon, String type) {
      final isActive = _filterType == type && _listVisible;
      return GestureDetector(
        onTap: () {
          setState(() {
            if (_filterType == type) {
              // 같은 배지 재탭 → 필터 해제, 패널은 유지
              _filterType = null;
            } else {
              _filterType = type;
              _listVisible = true;
            }
          });
        },
        child: Container(
          padding: ResponsiveUtils.getBadgePadding(context),
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).primaryColor
                : count > 0
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).primaryColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(ResponsiveUtils.getBadgeBorderRadius(context)),
            border: isActive ? Border.all(color: Colors.white, width: 2) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: ResponsiveUtils.getBadgeIconSize(context) * 1.331,
                  color: Colors.white),
              AppSpacing.horizontalSpaceXS,
              Text(
                count.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: ResponsiveUtils.getBadgeFontSize(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        badge(textCount, Icons.keyboard, 'text'),
        const SizedBox(width: 5.1),
        badge(handwritingCount, Icons.draw, 'handwriting'),
        const SizedBox(width: 5.1),
        badge(audioCount, Icons.mic, 'audio'),
        AppSpacing.horizontalSpaceM,
      ],
    );
  }
}
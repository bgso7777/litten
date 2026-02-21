import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state_provider.dart';
import '../widgets/draggable_tab_layout.dart';

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
    _tabs = [
      TabItem(
        id: 'text',
        title: '텍스트',
        icon: Icons.keyboard,
        content: TextTab(),
        position: parsePosition(savedPositions['text'] ?? 'topLeft'),
      ),
      TabItem(
        id: 'handwriting',
        title: '필기',
        icon: Icons.draw,
        content: HandwritingTab(),
        position: parsePosition(savedPositions['handwriting'] ?? 'topLeft'),
      ),
      TabItem(
        id: 'audio',
        title: '녹음',
        icon: Icons.mic,
        content: RecordingTab(key: ValueKey(_recordingTabRefreshCount)),
        position: parsePosition(savedPositions['audio'] ?? 'topLeft'),
      ),
      TabItem(
        id: 'browser',
        title: '검색',
        icon: Icons.public,
        content: const BrowserTab(),
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
        if (appState.selectedLitten == null) {
          return Center(
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
          );
        }

        // 드래그 가능한 탭 레이아웃 반환
        return draggableTabLayout;
      },
    );
  }
}
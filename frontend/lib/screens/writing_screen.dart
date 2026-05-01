import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:provider/provider.dart';
import '../services/app_state_provider.dart';
import '../widgets/draggable_tab_layout.dart';
import '../l10n/app_localizations.dart';
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
  bool _listVisible = false;
  AppStateProvider? _appState;
  final ScrollController _listScrollController = ScrollController();

  // ⭐ TextTab 상태 유지를 위한 GlobalKey
  final GlobalKey<State<StatefulWidget>> _textTabKey = GlobalKey();
  final GlobalKey<State<StatefulWidget>> _handwritingTabKey = GlobalKey();
  final GlobalKey<State<StatefulWidget>> _browserTabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _listScrollController.addListener(_onListScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _appState = Provider.of<AppStateProvider>(context, listen: false);
      _appState!.addListener(_onAppStateChanged);
      _onAppStateChanged(); // 초기 상태 확인
    });
  }

  void _onListScroll() {
    if (!mounted || !_listScrollController.hasClients) return;
    final pos = _listScrollController.position;
    // 최상단에서 위 방향으로 드래그 시 리스트 접기
    if (pos.pixels <= 0 && pos.userScrollDirection == ScrollDirection.reverse && _listVisible) {
      setState(() => _listVisible = false);
    }
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    // 노트탭(index 1)이 활성이고 선택된 일정이 없으면 리스트 펼치기
    if (appState.selectedTabIndex == 1 && appState.selectedLitten == null && !_listVisible) {
      setState(() => _listVisible = true);
    }
  }

  @override
  void dispose() {
    _listScrollController.dispose();
    _appState?.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _initializeTabs(Map<String, String> savedPositions, {int textCount = 0, int handwritingCount = 0, int audioCount = 0}) {
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
        title: textCount.toString(),
        icon: Icons.keyboard,
        content: TextTab(key: _textTabKey),
        position: parsePosition(savedPositions['text'] ?? 'topLeft'),
      ),
      TabItem(
        id: 'handwriting',
        title: handwritingCount.toString(),
        icon: Icons.draw,
        content: HandwritingTab(key: _handwritingTabKey),
        position: parsePosition(savedPositions['handwriting'] ?? 'topLeft'),
      ),
      TabItem(
        id: 'audio',
        title: audioCount.toString(),
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
        // ⭐ 저장된 탭 위치로 초기화 (선택된 리튼의 파일 카운트를 탭 제목으로 표시)
        _initializeTabs(
          appState.writingTabPositions,
          textCount: appState.actualTextCount,
          handwritingCount: appState.actualHandwritingCount,
          audioCount: appState.actualAudioCount,
        );

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
                      Icons.event_note,
                      size: 64,
                      color: Theme.of(context).disabledColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '먼저 일정을 선택하세요.',
                      style: TextStyle(
                        fontSize: 18,
                        color: Theme.of(context).disabledColor,
                      ),
                    ),
                  ],
                ),
              )
            : draggableTabLayout;

        return LayoutBuilder(
          builder: (context, constraints) {
            const statsHeight = 45.0;
            final panelHeight = _listVisible
                ? constraints.maxHeight / 2
                : statsHeight;

            return Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: panelHeight,
                  child: LittenUnifiedListView(
                    scrollController: _listScrollController,
                    padding: const EdgeInsets.only(left: 8, right: 8, top: 0, bottom: 8),
                    listVisible: _listVisible,
                    onListToggle: () => setState(() => _listVisible = !_listVisible),
                    ignoreSelectedDate: true,
                  ),
                ),
                Expanded(child: body),
              ],
            );
          },
        );
      },
    );
  }

}
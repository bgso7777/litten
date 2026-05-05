import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state_provider.dart';
import '../widgets/draggable_tab_layout.dart';
import '../l10n/app_localizations.dart';
// 실제 기능 탭들을 import
import '../widgets/recording_tab.dart';
import '../widgets/text_tab.dart';
import '../widgets/handwriting_tab.dart';
import '../widgets/browser_tab.dart';
import '../widgets/all_files_tab.dart';
import '../widgets/common/summary_reminder_chip.dart';
import '../widgets/remind_panel.dart';

enum _PanelState { closed, half, full }

class WritingScreen extends StatefulWidget {
  const WritingScreen({super.key});

  @override
  State<WritingScreen> createState() => _WritingScreenState();
}

class _WritingScreenState extends State<WritingScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;
  late List<TabItem> _tabs;
  int _recordingTabRefreshCount = 0;
  AppStateProvider? _appState;

  // ⭐ 리마인드 패널 — 연속 높이 + 스냅 애니메이션
  _PanelState _panelState = _PanelState.closed;
  double _panelHeight = 0;
  double _totalHeight = 0;
  late AnimationController _panelController;
  late Tween<double> _panelTween;
  late Animation<double> _panelAnim;
  static const double _kTabBarMinHeight = 46.0;

  double get _halfHeight => _totalHeight * 0.5;
  double get _fullHeight => _totalHeight - _kTabBarMinHeight;

  // 실시간 높이 기반 panelLevel (칩 화살표용)
  int get _panelLevel {
    if (_totalHeight == 0 || _panelHeight < _halfHeight * 0.3) return 0;
    if (_panelHeight < (_halfHeight + _fullHeight) * 0.5) return 1;
    return 2;
  }

  // ⭐ TextTab 상태 유지를 위한 GlobalKey
  final GlobalKey<State<StatefulWidget>> _textTabKey = GlobalKey();
  final GlobalKey<State<StatefulWidget>> _handwritingTabKey = GlobalKey();
  final GlobalKey<State<StatefulWidget>> _browserTabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _panelController = AnimationController(vsync: this);
    _panelTween = Tween<double>(begin: 0, end: 0);
    _panelAnim = _panelTween.animate(
      CurvedAnimation(parent: _panelController, curve: Curves.easeOutCubic),
    );
    _panelAnim.addListener(_onPanelAnimTick);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _appState = Provider.of<AppStateProvider>(context, listen: false);
      _appState!.addListener(_onAppStateChanged);
      _onAppStateChanged();
    });
  }

  void _onPanelAnimTick() {
    if (mounted) setState(() => _panelHeight = _panelAnim.value);
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    final appState = Provider.of<AppStateProvider>(context, listen: false);

    // ⭐ 노트탭에서 일정이 선택되지 않았으면 undefined 자동 선택
    if (appState.selectedTabIndex == 0 && appState.selectedLitten == null) {
      _autoSelectUndefined(appState);
    }
  }

  Future<void> _autoSelectUndefined(AppStateProvider appState) async {
    final undefinedLitten = appState.littens
        .where((l) => l.title == 'undefined')
        .firstOrNull;
    if (undefinedLitten != null) {
      try {
        await appState.selectLitten(undefinedLitten);
        debugPrint('✅ [WritingScreen] undefined 리튼 자동 선택 완료');
      } catch (e) {
        debugPrint('❌ [WritingScreen] undefined 자동 선택 실패: $e');
      }
    }
  }

  @override
  void dispose() {
    _panelAnim.removeListener(_onPanelAnimTick);
    _panelController.dispose();
    _appState?.removeListener(_onAppStateChanged);
    super.dispose();
  }

  // 목표 높이로 스냅 애니메이션
  void _snapTo(double target, _PanelState newState) {
    if (_totalHeight == 0) return;
    _panelTween.begin = _panelHeight;
    _panelTween.end = target.clamp(0.0, _fullHeight);
    setState(() => _panelState = newState);
    _panelController
      ..duration = const Duration(milliseconds: 380)
      ..forward(from: 0);
    debugPrint('[WritingScreen] 스냅: ${_panelHeight.toStringAsFixed(0)} → ${target.toStringAsFixed(0)} (${newState.name})');
  }

  // 드래그 중 실시간 높이 갱신
  void _onDragUpdate(double dy) {
    if (_panelState == _PanelState.closed) return;
    _panelController.stop();
    setState(() {
      _panelHeight = (_panelHeight - dy).clamp(0.0, _fullHeight);
    });
  }

  // 드래그 종료 → 가장 가까운 스냅 포인트로
  void _onDragEnd(double velocityY) {
    if (_totalHeight == 0) return;
    final half = _halfHeight;
    final full = _fullHeight;
    double target;
    _PanelState newState;

    if (velocityY < -600) {
      // 위로 빠르게 → 다음 단계
      if (_panelHeight < half) { target = half; newState = _PanelState.half; }
      else { target = full; newState = _PanelState.full; }
    } else if (velocityY > 600) {
      // 아래로 빠르게 → 이전 단계
      if (_panelHeight > half) { target = half; newState = _PanelState.half; }
      else { target = 0; newState = _PanelState.closed; }
    } else {
      // 가장 가까운 스냅 포인트
      if (_panelHeight < half * 0.4) { target = 0; newState = _PanelState.closed; }
      else if (_panelHeight < (half + full) * 0.5) { target = half; newState = _PanelState.half; }
      else { target = full; newState = _PanelState.full; }
    }
    _snapTo(target, newState);
  }

  void _expandPanel() {
    if (_totalHeight == 0) return;
    if (_panelState == _PanelState.closed) { _snapTo(_halfHeight, _PanelState.half); }
    else if (_panelState == _PanelState.half) { _snapTo(_fullHeight, _PanelState.full); }
  }

  void _shrinkPanel() {
    if (_panelState == _PanelState.full) { _snapTo(_halfHeight, _PanelState.half); }
    else if (_panelState == _PanelState.half) { _snapTo(0, _PanelState.closed); }
  }

  void _togglePanel() {
    if (_panelState == _PanelState.closed) { _snapTo(_halfHeight, _PanelState.half); }
    else { _snapTo(0, _PanelState.closed); }
  }

  void _initializeTabs(Map<String, String> savedPositions, {int textCount = 0, int handwritingCount = 0, int audioCount = 0, String? littenTitle, Set<String> noteTabVisibility = const {'all'}}) {
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

    final l10n = AppLocalizations.of(context);
    _tabs = [
      TabItem(
        id: 'all',
        title: '',
        icon: Icons.apps,
        customTabWidget: AllFilesTabButton(
          textCount: textCount,
          handwritingCount: handwritingCount,
          audioCount: audioCount,
          littenTitle: littenTitle,
        ),
        content: const AllFilesTab(),
        position: parsePosition(savedPositions['all'] ?? 'topLeft'),
      ),
      TabItem(
        id: 'text',
        title: textCount.toString(),
        icon: Icons.keyboard,
        content: TextTab(key: _textTabKey),
        position: parsePosition(savedPositions['text'] ?? 'topLeft'),
        isVisible: noteTabVisibility.contains('text'),
      ),
      TabItem(
        id: 'handwriting',
        title: handwritingCount.toString(),
        icon: Icons.draw,
        content: HandwritingTab(key: _handwritingTabKey),
        position: parsePosition(savedPositions['handwriting'] ?? 'topLeft'),
        isVisible: noteTabVisibility.contains('handwriting'),
      ),
      TabItem(
        id: 'audio',
        title: audioCount.toString(),
        icon: Icons.mic,
        content: RecordingTab(key: ValueKey(_recordingTabRefreshCount)),
        position: parsePosition(savedPositions['audio'] ?? 'topLeft'),
        isVisible: noteTabVisibility.contains('audio'),
      ),
      TabItem(
        id: 'browser',
        title: l10n?.browserTab ?? '검색',
        icon: Icons.public,
        content: BrowserTab(key: _browserTabKey),
        position: parsePosition(savedPositions['browser'] ?? 'topLeft'),
        isVisible: noteTabVisibility.contains('browser'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 필수
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        _initializeTabs(
          appState.writingTabPositions,
          textCount: appState.actualTextCount,
          handwritingCount: appState.actualHandwritingCount,
          audioCount: appState.actualAudioCount,
          littenTitle: appState.selectedLitten?.title,
          noteTabVisibility: appState.noteTabVisibility,
        );

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

        final draggableTabLayout = DraggableTabLayout(
          key: ValueKey(appState.targetWritingTabId),
          tabs: _tabs,
          initialActiveTabId: appState.currentWritingTabId,
          visibleAreas: appState.visibleAreas,
          onTabPositionChanged: (tabId, newPosition) {
            setState(() {
              for (final tab in _tabs) {
                if (tab.id == tabId) {
                  tab.position = newPosition;
                  break;
                }
              }
            });
            final positionStr = positionToString(newPosition);
            debugPrint('[WritingScreen] 탭 위치 변경됨: $tabId -> $positionStr');
            appState.setWritingTabPosition(tabId, positionStr);
          },
          onTabChanged: (tabId) {
            debugPrint('[WritingScreen] 탭 변경됨: $tabId');
            appState.setCurrentWritingTab(tabId);
            if (tabId == 'audio') {
              setState(() {
                _recordingTabRefreshCount++;
                debugPrint('[WritingScreen] 녹음 탭 새로고침 트리거: $_recordingTabRefreshCount');
              });
            }
          },
        );

        return Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // totalHeight 캐시 (처음 또는 변경 시)
                  if (_totalHeight != constraints.maxHeight) {
                    _totalHeight = constraints.maxHeight;
                  }
                  final tabH = (_totalHeight - _panelHeight).clamp(0.0, _totalHeight);

                  return Column(
                    children: [
                      SizedBox(height: tabH, child: draggableTabLayout),
                      SizedBox(
                        height: _panelHeight,
                        child: _panelHeight > 0
                            ? RemindPanel(
                                onClose: _shrinkPanel,
                                onDragUpdate: _onDragUpdate,
                                onDragEnd: _onDragEnd,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  );
                },
              ),
            ),
            // ⭐ 요약 리마인드 칩
            SummaryReminderChip(
              onTap: _togglePanel,
              onScrollUp: _expandPanel,
              panelLevel: _panelLevel,
            ),
          ],
        );
      },
    );
  }
}

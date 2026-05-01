import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state_provider.dart';
import '../widgets/draggable_tab_layout.dart';
import '../l10n/app_localizations.dart';
import '../utils/timezone_utils.dart';
// 실제 기능 탭들을 import
import '../widgets/recording_tab.dart';
import '../widgets/text_tab.dart';
import '../widgets/handwriting_tab.dart';
import '../widgets/browser_tab.dart';
import '../widgets/all_files_tab.dart';

class WritingScreen extends StatefulWidget {
  const WritingScreen({super.key});

  @override
  State<WritingScreen> createState() => _WritingScreenState();
}

class _WritingScreenState extends State<WritingScreen> {
  late List<TabItem> _tabs;
  int _recordingTabRefreshCount = 0;
  bool _isAutoSelecting = false;
  AppStateProvider? _appState;

  // ⭐ TextTab 상태 유지를 위한 GlobalKey
  final GlobalKey<State<StatefulWidget>> _textTabKey = GlobalKey();
  final GlobalKey<State<StatefulWidget>> _handwritingTabKey = GlobalKey();
  final GlobalKey<State<StatefulWidget>> _browserTabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _appState = Provider.of<AppStateProvider>(context, listen: false);
      _appState!.addListener(_onAppStateChanged);
      _onAppStateChanged();
    });
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    if (appState.selectedTabIndex == 1 && appState.selectedLitten == null) {
      _autoSelectLittenForNoteTab(appState);
    }
  }

  Future<void> _autoSelectLittenForNoteTab(AppStateProvider appState) async {
    if (_isAutoSelecting || !mounted) return;
    _isAutoSelecting = true;
    try {
      final now = nowForLanguage(appState.locale.languageCode);
      final today = DateTime(now.year, now.month, now.day);
      final currentMinutes = now.hour * 60 + now.minute;

      // 1순위: 오늘 날짜의 현재 시간 범위 내 일정 선택
      for (final litten in appState.littens) {
        final schedule = litten.schedule;
        if (schedule == null) continue;
        final d = schedule.date;
        if (d.year != today.year || d.month != today.month || d.day != today.day) continue;
        final startMin = schedule.startTime.hour * 60 + schedule.startTime.minute;
        final endMin = schedule.endTime.hour * 60 + schedule.endTime.minute;
        if (currentMinutes >= startMin && currentMinutes <= endMin) {
          debugPrint('⏰ [WritingScreen] 현재 시간 내 일정 자동 선택: ${litten.title}');
          await appState.selectLitten(litten);
          return;
        }
      }

      debugPrint('⏰ [WritingScreen] 현재 시간 내 일정 없음 - undefined 자동 선택');
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
    } finally {
      _isAutoSelecting = false;
    }
  }

  @override
  void dispose() {
    _appState?.removeListener(_onAppStateChanged);
    super.dispose();
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

        return draggableTabLayout;
      },
    );
  }
}

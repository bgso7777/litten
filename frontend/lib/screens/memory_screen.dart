import 'package:flutter/material.dart';
import '../widgets/draggable_tab_layout.dart';
import '../widgets/remind_panel.dart';

/// 리마인드 영역 — 노트의 필기/녹음탭과 동일한 탭 레이아웃(DraggableTabLayout)으로 구성.
/// 현재는 '리마인드' 탭 하나만 있고, 향후 개인화로 탭을 추가/재배치할 수 있다.
///
/// ⭐ 개인화 확장 지점:
///   [_tabs] 리스트에 TabItem을 추가하면 리마인드 영역에 탭이 늘어난다.
class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  late final List<TabItem> _tabs;

  @override
  void initState() {
    super.initState();
    // ⭐ 개인화 확장 지점: 여기에 TabItem을 추가하면 탭이 늘어난다.
    _tabs = [
      TabItem(
        id: 'remind',
        title: '리마인드',
        icon: Icons.lightbulb_outline,
        // 탭 버튼이 제목 역할을 하므로 자체 헤더는 숨김(깜빡이는 유지)
        content: const RemindPanel(isFullScreen: true, showHeader: false),
        position: TabPosition.topLeft,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🧠 [MemoryScreen] build - 탭 ${_tabs.length}개');
    return DraggableTabLayout(
      tabs: _tabs,
      initialActiveTabId: 'remind',
      visibleAreas: const {'topLeft'},
      onTabPositionChanged: (tabId, newPosition) {
        setState(() {
          for (final t in _tabs) {
            if (t.id == tabId) {
              t.position = newPosition;
              break;
            }
          }
        });
        debugPrint('[MemoryScreen] 탭 위치 변경: $tabId -> $newPosition');
      },
      onTabChanged: (tabId) {
        debugPrint('[MemoryScreen] 탭 변경: $tabId');
      },
    );
  }
}

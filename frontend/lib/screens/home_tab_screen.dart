import 'package:flutter/material.dart';
import '../widgets/draggable_tab_layout.dart';
import 'home_dashboard_screen.dart';

/// 홈 영역 — 노트의 필기/녹음탭과 동일한 탭 레이아웃(DraggableTabLayout)으로 구성.
/// 현재는 '홈' 탭 하나만 있고, 향후 개인화로 탭을 추가/재배치할 수 있다.
///
/// ⭐ 개인화 확장 지점:
///   [_tabs] 리스트에 TabItem을 추가하면 홈에 탭이 늘어난다.
///   (노트 화면이 전체/메모/필기/녹음 등 여러 탭을 갖는 것과 동일한 방식)
class HomeTabScreen extends StatefulWidget {
  const HomeTabScreen({super.key, this.dashboardKey});

  /// 우측 하단 FAB(MainTabScreen)에서 홈 대시보드의 '새 채팅'을 띄우기 위한 키.
  final GlobalKey<HomeDashboardScreenState>? dashboardKey;

  @override
  State<HomeTabScreen> createState() => _HomeTabScreenState();
}

class _HomeTabScreenState extends State<HomeTabScreen> {
  late final List<TabItem> _tabs;

  @override
  void initState() {
    super.initState();
    // ⭐ 개인화 확장 지점: 여기에 TabItem을 추가하면 탭이 늘어난다.
    _tabs = [
      TabItem(
        id: 'home',
        title: '홈',
        icon: Icons.home_outlined,
        // 제목란: 공유 아이콘 + 받은(↓)·한(↑) 카운트
        customTabWidget: const ShareTabTitle(),
        content: HomeDashboardScreen(key: widget.dashboardKey),
        position: TabPosition.topLeft,
        // 단일 탭이라 드래그가 무의미 — 제목란 우측 드래그 핸들(점 6개) 숨김
        isDraggable: false,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🏠 [HomeTabScreen] build - 탭 ${_tabs.length}개');
    return DraggableTabLayout(
      tabs: _tabs,
      initialActiveTabId: 'home',
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
        debugPrint('[HomeTabScreen] 탭 위치 변경: $tabId -> $newPosition');
      },
      onTabChanged: (tabId) {
        debugPrint('[HomeTabScreen] 탭 변경: $tabId');
      },
    );
  }
}

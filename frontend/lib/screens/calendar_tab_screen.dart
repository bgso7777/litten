import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/app_state_provider.dart';
import '../widgets/draggable_tab_layout.dart';
import 'home_screen.dart';

/// 캘린더 영역 — 노트의 필기/녹음탭과 동일한 탭 레이아웃(DraggableTabLayout)으로 구성.
/// 현재는 '캘린더' 탭 하나만 있고, 향후 개인화로 탭을 추가/재배치할 수 있다.
///
/// ⭐ 개인화 확장 지점:
///   [_tabs] 리스트에 TabItem을 추가하면 캘린더 영역에 탭이 늘어난다.
///
/// HomeScreen의 GlobalKey는 상위(MainTabScreen)에서 주입받아, 기존의
/// 일정 추가 FAB·스크롤 제어(showCreateLittenDialog/scrollToTop 등)가 그대로 동작한다.
class CalendarTabScreen extends StatefulWidget {
  final GlobalKey<HomeScreenState> homeScreenKey;

  const CalendarTabScreen({super.key, required this.homeScreenKey});

  @override
  State<CalendarTabScreen> createState() => _CalendarTabScreenState();
}

class _CalendarTabScreenState extends State<CalendarTabScreen> {
  late final List<TabItem> _tabs;

  @override
  void initState() {
    super.initState();
    // ⭐ 개인화 확장 지점: 여기에 TabItem을 추가하면 탭이 늘어난다.
    _tabs = [
      TabItem(
        id: 'calendar',
        title: '캘린더',
        icon: Icons.event_available,
        // 제목란: 월 네비게이션(이전 ‹ · 2026년 6월 · 다음 ›). 캘린더 내부 헤더를 여기로 이동.
        customTabWidget: Consumer<AppStateProvider>(
          builder: (context, appState, _) {
            final color = Theme.of(context).primaryColor;
            return Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    final previousMonth = DateTime(
                      appState.focusedDate.year,
                      appState.focusedDate.month - 1,
                    );
                    appState.changeFocusedDate(previousMonth);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.chevron_left, size: 22, color: color),
                  ),
                ),
                const SizedBox(width: 40),
                Text(
                  DateFormat.yMMMM(appState.locale.languageCode)
                      .format(appState.focusedDate),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 40),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    final nextMonth = DateTime(
                      appState.focusedDate.year,
                      appState.focusedDate.month + 1,
                    );
                    appState.changeFocusedDate(nextMonth);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.chevron_right, size: 22, color: color),
                  ),
                ),
              ],
            );
          },
        ),
        content: HomeScreen(key: widget.homeScreenKey),
        position: TabPosition.topLeft,
        // 단일 탭이라 드래그가 무의미 — 제목란 우측 드래그 핸들(점 6개) 숨김
        isDraggable: false,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('📅 [CalendarTabScreen] build - 탭 ${_tabs.length}개');
    return DraggableTabLayout(
      tabs: _tabs,
      initialActiveTabId: 'calendar',
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
        debugPrint('[CalendarTabScreen] 탭 위치 변경: $tabId -> $newPosition');
      },
      onTabChanged: (tabId) {
        debugPrint('[CalendarTabScreen] 탭 변경: $tabId');
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state_provider.dart';
import '../widgets/draggable_tab_layout.dart';
import '../widgets/common/tab_count_title.dart';
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
        // 제목란: 신규(미완료) · 확인(완료) / 전체 카운트
        customTabWidget: Consumer<AppStateProvider>(
          builder: (context, appState, _) {
            final items = appState.remindItems;
            final newCount = items.where((i) => !i.isDone).length;
            final doneCount = items.where((i) => i.isDone).length;
            final totalCount = items.length;
            return TabCountTitle([
              [
                TabCount(Icons.fiber_new, newCount),
                TabCount(Icons.check_circle, doneCount),
              ],
              [
                TabCount(Icons.lightbulb_outline, totalCount),
              ],
            ]);
          },
        ),
        // 탭 버튼이 제목 역할을 하므로 자체 헤더는 숨김(깜빡이는 유지)
        // 상(2/3)=미완료 · 하(1/3)=완료로 분할
        content: const _SplitRemindView(),
        position: TabPosition.topLeft,
        // 단일 탭이라 드래그가 무의미 — 제목란 우측 드래그 핸들(점 6개) 숨김
        isDraggable: false,
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

/// 리마인드 탭 본문 — 상(2/3) 미완료 · 하(1/3) 완료로 분할.
/// 미완료는 기억을 유도(깜빡이)하고, 완료는 아래에서 모아 본다.
class _SplitRemindView extends StatelessWidget {
  const _SplitRemindView();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Consumer<AppStateProvider>(
      builder: (context, appState, _) {
        final items = appState.remindItems;
        final pendingCount = items.where((i) => !i.isDone).length;
        final doneCount = items.where((i) => i.isDone).length;

        return Column(
          children: [
            // 상단 2/3 — 미완료
            Expanded(
              flex: 2,
              child: _RemindSection(
                icon: Icons.fiber_new,
                label: '미완료',
                count: pendingCount,
                color: color,
                child: const RemindPanel(
                  isFullScreen: true,
                  showHeader: false,
                  doneFilter: RemindDoneFilter.pending,
                ),
              ),
            ),
            // 상하 구분
            Container(height: 1, color: color.withValues(alpha: 0.2)),
            // 하단 1/3 — 완료
            Expanded(
              flex: 1,
              child: _RemindSection(
                icon: Icons.check_circle,
                label: '완료',
                count: doneCount,
                color: color,
                child: const RemindPanel(
                  isFullScreen: true,
                  showHeader: false,
                  doneFilter: RemindDoneFilter.done,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 분할 섹션 — 작은 라벨 헤더(아이콘+이름+카운트) + 리마인드 목록.
class _RemindSection extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final Widget child;

  const _RemindSection({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 섹션 라벨
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          color: color.withValues(alpha: 0.06),
          child: Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

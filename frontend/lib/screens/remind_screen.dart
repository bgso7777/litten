import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/summary_entry.dart';
import '../services/app_state_provider.dart';
import '../widgets/draggable_tab_layout.dart';
import '../widgets/common/tab_count_title.dart';
import '../widgets/quiz_panel.dart';

/// 리마인드 영역(하단 4번째 탭) — 생성된 요약·퀴즈를 모아 재기억/인사이트를 돕는 메뉴.
/// 노트의 필기/녹음탭과 동일한 탭 레이아웃(DraggableTabLayout)으로 구성한다.
/// 현재는 통합 탭 하나만 있고, 향후 개인화로 탭을 추가/재배치할 수 있다.
///
/// ⭐ 개인화 확장 지점:
///   [_tabs] 리스트에 TabItem을 추가하면 리마인드 영역에 탭이 늘어난다.
class RemindScreen extends StatefulWidget {
  const RemindScreen({super.key});

  @override
  State<RemindScreen> createState() => _RemindScreenState();
}

class _RemindScreenState extends State<RemindScreen> {
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
        // 제목란: 요약(저장된 요약) 카운트 + 퀴즈(개별 항목) 카운트
        customTabWidget: Consumer<AppStateProvider>(
          builder: (context, appState, _) {
            final summaryCount = appState.summaries.length;   // 요약(SummaryEntry) 개수
            final quizCount = appState.quizItems.length;       // 퀴즈 항목 개수
            return TabCountTitle([
              [
                TabCount(Icons.auto_awesome, summaryCount),     // 요약
                TabCount(Icons.lightbulb_outline, quizCount),   // 퀴즈
              ],
            ]);
          },
        ),
        // 탭 버튼이 제목 역할을 하므로 자체 헤더는 숨김(깜빡이는 유지)
        // 요약 · 미완료 · 완료 3분할 본문
        content: const _SplitRemindView(),
        position: TabPosition.topLeft,
        // 단일 탭이라 드래그가 무의미 — 제목란 우측 드래그 핸들(점 6개) 숨김
        isDraggable: false,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🧠 [RemindScreen] build - 탭 ${_tabs.length}개');
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
        debugPrint('[RemindScreen] 탭 위치 변경: $tabId -> $newPosition');
      },
      onTabChanged: (tabId) {
        debugPrint('[RemindScreen] 탭 변경: $tabId');
      },
    );
  }
}

/// 리마인드 탭 본문 — 요약(상) · 미완료(중) · 완료(하) 3분할.
/// 미완료는 기억을 유도(깜빡이)하고, 완료는 아래에서 모아 본다.
class _SplitRemindView extends StatelessWidget {
  const _SplitRemindView();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Consumer<AppStateProvider>(
      builder: (context, appState, _) {
        final items = appState.quizItems;
        final pendingCount = items.where((i) => !i.isDone).length;
        final doneCount = items.where((i) => i.isDone).length;
        final summaries = appState.summaries;

        return Column(
          children: [
            // 최상단 (3/8) — 요약
            Expanded(
              flex: 3,
              child: _RemindSection(
                icon: Icons.auto_awesome,
                label: '요약',
                count: summaries.length,
                color: color,
                child: _SummaryList(summaries: summaries, color: color),
              ),
            ),
            Container(height: 1, color: color.withValues(alpha: 0.2)),
            // 중간 (3/8) — 미완료
            Expanded(
              flex: 3,
              child: _RemindSection(
                icon: Icons.fiber_new,
                label: '미완료',
                count: pendingCount,
                color: color,
                child: const QuizPanel(
                  isFullScreen: true,
                  showHeader: false,
                  doneFilter: QuizDoneFilter.pending,
                ),
              ),
            ),
            Container(height: 1, color: color.withValues(alpha: 0.2)),
            // 하단 (2/8) — 완료
            Expanded(
              flex: 2,
              child: _RemindSection(
                icon: Icons.check_circle,
                label: '완료',
                count: doneCount,
                color: color,
                child: const QuizPanel(
                  isFullScreen: true,
                  showHeader: false,
                  doneFilter: QuizDoneFilter.done,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 분할 섹션 — 작은 라벨 헤더(아이콘+이름+카운트) + 항목 목록(요약/미완료/완료 공용).
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

/// 요약 목록 — 저장된 요약(SummaryEntry)을 최신순으로 표시.
/// 항목 탭 시 전체 요약 보기 다이얼로그(공유/삭제 포함).
class _SummaryList extends StatelessWidget {
  final List<SummaryEntry> summaries;
  final Color color;

  const _SummaryList({required this.summaries, required this.color});

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');

  static String _dateLabel(DateTime d) =>
      '${(d.year % 100)}.${_twoDigits(d.month)}.${_twoDigits(d.day)} '
      '${_twoDigits(d.hour)}:${_twoDigits(d.minute)}';

  static String _snippet(String text) {
    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.isNotEmpty) return t;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) {
      return Center(
        child: Text(
          '요약이 없습니다.\n파일을 요약하면 여기에 모입니다.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: summaries.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: color.withValues(alpha: 0.1)),
      itemBuilder: (context, index) {
        final s = summaries[index];
        return InkWell(
          onTap: () => _showSummaryViewDialog(context, s, color),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.title.isEmpty ? '제목 없음' : s.title,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_dateLabel(s.createdAt)} · ${_snippet(s.summaryText)}',
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right, size: 18, color: color.withValues(alpha: 0.5)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSummaryViewDialog(
      BuildContext context, SummaryEntry s, Color color) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.auto_awesome, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s.title.isEmpty ? '요약' : s.title,
              style: const TextStyle(fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Container(
              width: double.maxFinite,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: SelectableText.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '📅 ${_dateLabel(s.createdAt)}\n\n',
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                    TextSpan(
                      text: s.summaryText,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black87, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          // 삭제
          TextButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final appState =
                  Provider.of<AppStateProvider>(context, listen: false);
              await appState.deleteSummary(s.id);
            },
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            label: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
          // 공유
          TextButton.icon(
            onPressed: () => Share.share(s.toShareText()),
            icon: Icon(Icons.share, size: 18, color: color),
            label: Text('공유', style: TextStyle(color: color)),
          ),
          // 닫기
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }
}

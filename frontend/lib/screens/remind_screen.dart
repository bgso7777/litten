import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/summary_entry.dart';
import '../models/quiz_item.dart';
import '../services/app_state_provider.dart';
import '../widgets/draggable_tab_layout.dart';
import '../widgets/common/tab_count_title.dart';
import '../widgets/common/quiz_bulb_icon.dart';

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
                TabCount(Icons.lightbulb_outline, quizCount,    // 퀴즈 — 전구+q
                    iconWidget: const QuizBulbIcon()),
              ],
            ]);
          },
        ),
        // 탭 버튼이 제목 역할을 하므로 자체 헤더는 숨김(깜빡이는 유지)
        // 요약·퀴즈를 일자순으로 통합한 본문
        content: const _RemindBodyView(),
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

/// 리마인드 탭 본문 — 요약(SummaryEntry)과 퀴즈(QuizItem)를 생성일시 기준으로
/// 하나의 목록에 뒤섞어 일자순(내림차순)으로 보여준다.
/// 날짜가 바뀌면 헤더(오늘/어제/날짜)를 끼우고, 하단의 필터 칩으로
/// 요약 · 퀴즈(미완료) · 퀴즈(완료) 표시 여부를 토글한다.
class _RemindBodyView extends StatefulWidget {
  const _RemindBodyView();

  @override
  State<_RemindBodyView> createState() => _RemindBodyViewState();
}

class _RemindBodyViewState extends State<_RemindBodyView> {
  bool _showSummary = true; // 요약
  bool _showQuizNew = true; // 퀴즈 미완료
  bool _showQuizEnd = true; // 퀴즈 완료

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _dateTimeLabel(DateTime d) =>
      '${d.year % 100}.${_two(d.month)}.${_two(d.day)} '
      '${_two(d.hour)}:${_two(d.minute)}';

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Consumer<AppStateProvider>(
      builder: (context, appState, _) {
        final summaries = appState.summaries;
        // 퀴즈는 개별 문항이 아니라 파일/영상 단위(QuizTarget)로 묶어 "제목" 하나로 표시
        final quizGroups = appState.quizTargets;

        // 요약 + 퀴즈 그룹을 생성일시 기준 통합(필터 적용) → 내림차순 정렬
        final items = <({DateTime at, SummaryEntry? summary, QuizTarget? quizGroup})>[];
        if (_showSummary) {
          for (final s in summaries) {
            items.add((at: s.createdAt, summary: s, quizGroup: null));
          }
        }
        for (final g in quizGroups) {
          if (g.items.isEmpty) continue;
          // 그룹에 미완료가 하나라도 있으면 'new', 모두 완료면 'end'로 분류
          final hasPending = g.pendingCount > 0;
          if ((_showQuizNew && hasPending) || (_showQuizEnd && !hasPending)) {
            items.add((at: g.items.first.createdAt, summary: null, quizGroup: g));
          }
        }
        items.sort((a, b) => b.at.compareTo(a.at));

        return Column(
          children: [
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        '표시할 항목이 없습니다.\n파일을 요약하거나 퀴즈를 만들면 여기에 모입니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final entry = items[index];
                        final at = entry.at;
                        final currentDate = DateTime(at.year, at.month, at.day);
                        final prevAt = index == 0 ? null : items[index - 1].at;
                        final showHeader = prevAt == null ||
                            DateTime(prevAt.year, prevAt.month, prevAt.day) != currentDate;

                        final row = entry.summary != null
                            ? _summaryRow(entry.summary!, color)
                            : _quizGroupRow(entry.quizGroup!, color, appState);

                        if (showHeader) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [_dateHeader(currentDate, color), row],
                          );
                        }
                        return row;
                      },
                    ),
            ),
            _buildFilterChips(color),
          ],
        );
      },
    );
  }

  /// 날짜 구분 헤더 (오늘/어제/날짜)
  Widget _dateHeader(DateTime d, Color color) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    final String label = diff == 0
        ? '오늘'
        : diff == 1
            ? '어제'
            : '${d.year}.${_two(d.month)}.${_two(d.day)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: color.withValues(alpha: 0.2))),
        ],
      ),
    );
  }

  /// 요약 항목 행 — 별 아이콘 + 제목 + 일시. 탭 시 요약 보기 다이얼로그.
  Widget _summaryRow(SummaryEntry s, Color color) {
    return InkWell(
      onTap: () => _showSummaryViewDialog(context, s, color),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, size: 16, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                s.title.isEmpty ? '제목 없음' : s.title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _dateTimeLabel(s.createdAt),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  /// 퀴즈 그룹 행 — 전구+q + 파일/영상 제목 + (완료/전체) 배지 + 일시.
  /// 한 파일/영상에서 만든 여러 문항을 "제목" 하나로 묶어 보여준다.
  /// 탭하면 그룹의 퀴즈 문항(문제→답)을 펼쳐 보는 다이얼로그를 연다.
  Widget _quizGroupRow(QuizTarget g, Color color, AppStateProvider appState) {
    final total = g.items.length;
    final done = total - g.pendingCount;
    final allDone = g.pendingCount == 0;
    return InkWell(
      onTap: () => _showQuizGroupDialog(context, g, color),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            QuizBulbIcon(size: 16, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                g.fileName.isEmpty ? '제목 없음' : g.fileName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  // 모두 완료된 그룹은 취소선 + 흐리게
                  decoration: allDone ? TextDecoration.lineThrough : null,
                  color: allDone ? Colors.grey : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            // 완료/전체 문항 수 배지
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                '$done/$total',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold, color: color),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _dateTimeLabel(g.items.first.createdAt),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  /// 하단 필터 칩 — 좌우로 긴 타원 3개(요약 / 퀴즈 new / 퀴즈 end).
  Widget _buildFilterChips(Color color) {
    return Container(
      // + 칩 바(_CreateChipBar)와 동일: 바 배경 alpha 0.08 + 상단 경계선, 세로 패딩 7
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border(top: BorderSide(color: color.withValues(alpha: 0.15))),
      ),
      child: Row(
        children: [
          Expanded(
            child: _filterChip(
              label: '요약',
              iconBuilder: (c) => Icon(Icons.auto_awesome, size: 16, color: c),
              active: _showSummary,
              color: color,
              onTap: () => setState(() => _showSummary = !_showSummary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _filterChip(
              label: '퀴즈 new',
              iconBuilder: (c) => QuizBulbIcon(size: 16, color: c),
              active: _showQuizNew,
              color: color,
              onTap: () => setState(() => _showQuizNew = !_showQuizNew),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _filterChip(
              label: '퀴즈 end',
              iconBuilder: (c) => Icon(Icons.check_circle, size: 16, color: c),
              active: _showQuizEnd,
              color: color,
              onTap: () => setState(() => _showQuizEnd = !_showQuizEnd),
            ),
          ),
        ],
      ),
    );
  }

  /// 노트(+)의 칩(`_CreateChipBar._chip`)과 동일한 3단 컬러·높이:
  ///   바탕 base alpha 0.15 / 테두리 base alpha 0.2 / 아이콘·글씨 base.
  /// 필터 ON은 primaryColor, OFF는 회색(base)으로 구분한다.
  Widget _filterChip({
    required String label,
    required Widget Function(Color) iconBuilder,
    required bool active,
    required Color color,
    required VoidCallback onTap,
  }) {
    final Color base = active ? color : Colors.grey;

    return Material(
      color: base.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          // + 칩과 동일한 높이(세로 패딩 3)
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: base.withValues(alpha: 0.2), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              iconBuilder(base),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: base,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 퀴즈 그룹 보기 다이얼로그 — 그룹의 문항을 "문제 → (탭) 답" 형태로 펼쳐 본다.
  /// 각 문항 우측 체크로 완료/미완료 토글.
  void _showQuizGroupDialog(BuildContext context, QuizTarget g, Color color) {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final Set<String> opened = {}; // 답이 펼쳐진 문항 id

    // QuizTarget과 동일한 그룹 키(summaryGroupId ?? 'file:fileId')로 문항을 추출한다.
    // (fileId만으로 필터하면 같은 파일의 다른 회차 퀴즈까지 섞여 배지와 불일치)
    final String gKey = g.summaryGroupId ?? 'file:${g.fileId}';
    List<QuizItem> groupItems() {
      final list = appState.quizItems
          .where((i) => (i.summaryGroupId ?? 'file:${i.fileId}') == gKey)
          .toList();
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final items = groupItems();
          return AlertDialog(
            title: Row(children: [
              QuizBulbIcon(size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  g.fileName.isEmpty ? '퀴즈' : g.fileName,
                  style: const TextStyle(fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            content: SizedBox(
              width: double.maxFinite,
              child: items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('문항이 없습니다.'),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int i = 0; i < items.length; i++)
                            _quizDialogItem(
                              no: i + 1,
                              q: items[i],
                              color: color,
                              isOpen: opened.contains(items[i].id),
                              onToggleOpen: () => setLocal(() {
                                if (opened.contains(items[i].id)) {
                                  opened.remove(items[i].id);
                                } else {
                                  opened.add(items[i].id);
                                }
                              }),
                              onToggleDone: () {
                                appState.toggleQuizDone(items[i].id);
                                setLocal(() {});
                              },
                            ),
                        ],
                      ),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('닫기'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 퀴즈 그룹 다이얼로그의 문항 1개 — 문제(제목) + 펼치면 답(내용) + 완료 체크.
  Widget _quizDialogItem({
    required int no,
    required QuizItem q,
    required Color color,
    required bool isOpen,
    required VoidCallback onToggleOpen,
    required VoidCallback onToggleDone,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 문제 행 (탭 → 답 펼치기)
          InkWell(
            onTap: onToggleOpen,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$no.',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      q.title.isEmpty ? '(문제 없음)' : q.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration: q.isDone ? TextDecoration.lineThrough : null,
                        color: q.isDone ? Colors.grey : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // 완료 토글
                  GestureDetector(
                    onTap: onToggleDone,
                    child: Icon(
                      q.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 20,
                      color: q.isDone ? color : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(isOpen ? Icons.expand_less : Icons.expand_more,
                      size: 18, color: Colors.grey),
                ],
              ),
            ),
          ),
          // 답 (펼침)
          if (isOpen)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Text(
                q.content.isEmpty ? '(답 없음)' : q.content,
                style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }

  /// 요약 보기 다이얼로그 (공유/삭제 포함).
  void _showSummaryViewDialog(BuildContext context, SummaryEntry s, Color color) {
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
                      text: '📅 ${_dateTimeLabel(s.createdAt)}\n\n',
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

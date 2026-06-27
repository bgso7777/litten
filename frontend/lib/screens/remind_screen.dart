import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/audio_file.dart' show SyncStatus;
import '../models/summary_entry.dart';
import '../models/quiz_item.dart';
import '../services/app_state_provider.dart';
import '../services/sync_service.dart';
import '../widgets/draggable_tab_layout.dart';
import '../widgets/common/tab_count_title.dart';
import '../widgets/common/quiz_bulb_icon.dart';

/// 리마인드 영역(하단 4번째 탭) — 생성된 요약·퀴즈를 모아 재기억/인사이트를 돕는 메뉴.
/// 노트의 필기/녹음탭과 동일한 탭 레이아웃(DraggableTabLayout)으로 구성한다.
/// 현재는 통합 탭 하나만 있고, 향후 개인화로 탭을 추가/재배치할 수 있다.
///
/// ⭐ 개인화 확장 지점:
///   [_tabs] 리스트에 TabItem을 추가하면 리마인드 영역에 탭이 늘어난다.
/// 리마인드 표시 필터 — 제목란(요약/퀴즈 토글)과 본문·하단 칩이 공유한다.
/// 단일 출처(single source of truth)로 두어 제목 탭과 하단 칩이 항상 동기화된다.
///
/// 본문은 상단(확인 안 함)/하단(확인함) 2분할이며:
///  - [showSummary]/[showQuiz]: 요약·퀴즈 종류별 표시 여부(상·하단 공통)
///  - [confirmedOpen]: 하단(확인함) 영역을 펼칠지. 펼치면 상단 50% / 하단 50%.
class _RemindFilter extends ChangeNotifier {
  bool showSummary = true;    // 요약 표시
  bool showQuiz = true;       // 퀴즈 표시
  bool confirmedOpen = false; // 하단(확인함) 영역 펼침 — '퀴즈 end'로 토글

  void toggleSummary() {
    showSummary = !showSummary;
    notifyListeners();
  }

  void toggleQuiz() {
    showQuiz = !showQuiz;
    notifyListeners();
  }

  /// 하단(확인함) 영역 펼침/닫힘 토글.
  void toggleConfirmed() {
    confirmedOpen = !confirmedOpen;
    notifyListeners();
  }
}

class RemindScreen extends StatefulWidget {
  const RemindScreen({super.key});

  @override
  State<RemindScreen> createState() => _RemindScreenState();
}

class _RemindScreenState extends State<RemindScreen> {
  late final List<TabItem> _tabs;
  final _RemindFilter _filter = _RemindFilter();

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // ⭐ 개인화 확장 지점: 여기에 TabItem을 추가하면 탭이 늘어난다.
    _tabs = [
      TabItem(
        id: 'remind',
        title: '리마인드',
        icon: Icons.lightbulb_outline,
        // 제목란: 요약(저장된 요약) 카운트 + 퀴즈(그룹 단위) 카운트.
        // 각 요소를 탭하면 본문 표시를 토글한다(_filter 공유 → 하단 칩과 동기화).
        customTabWidget: AnimatedBuilder(
          animation: _filter,
          builder: (context, child) => Consumer<AppStateProvider>(
            builder: (context, appState, _) {
              // 제목 카운트는 '확인 안 한 것'만 (상단 영역과 일치): 확인 완료 제외.
              final summaryCount =
                  appState.summaries.where((s) => !s.isDone).length;
              // 퀴즈는 그룹(QuizTarget) 단위 — 미완료(pending) 있는 그룹만 카운트.
              final quizCount = appState.quizTargets
                  .where((g) => g.items.isNotEmpty && g.pendingCount > 0)
                  .length;
              return TabCountTitle([
                [
                  TabCount(Icons.auto_awesome, summaryCount,     // 요약 — 탭 토글
                      active: _filter.showSummary, onTap: _filter.toggleSummary),
                  TabCount(Icons.lightbulb_outline, quizCount,   // 퀴즈 — 전구+q, 탭 토글
                      iconWidget: const QuizBulbIcon(),
                      active: _filter.showQuiz, onTap: _filter.toggleQuiz),
                ],
              ]);
            },
          ),
        ),
        // 탭 버튼이 제목 역할을 하므로 자체 헤더는 숨김(깜빡이는 유지)
        // 요약·퀴즈를 일자순으로 통합한 본문
        content: _RemindBodyView(filter: _filter),
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
  const _RemindBodyView({required this.filter});

  final _RemindFilter filter;

  @override
  State<_RemindBodyView> createState() => _RemindBodyViewState();
}

class _RemindBodyViewState extends State<_RemindBodyView>
    with SingleTickerProviderStateMixin {
  _RemindFilter get _filter => widget.filter;
  late final AnimationController _paneAnim; // 하단(확인) 영역 슬라이드용

  @override
  void initState() {
    super.initState();
    _paneAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: _filter.confirmedOpen ? 1.0 : 0.0,
    );
    _filter.addListener(_onFilterChanged);
  }

  @override
  void dispose() {
    _filter.removeListener(_onFilterChanged);
    _paneAnim.dispose();
    super.dispose();
  }

  // 제목 탭/하단 바가 필터를 바꾸면 본문을 다시 그린다.
  void _onFilterChanged() {
    // 하단(확인) 영역은 아래에서 위로 슬라이드하며 열리고/닫힌다.
    if (_filter.confirmedOpen) {
      _paneAnim.forward();
    } else {
      _paneAnim.reverse();
    }
    if (mounted) setState(() {});
  }

  /// 당겨서 새로고침 — 서버 동기화(요약·퀴즈 포함)를 돌리고 디스크에서 리마인드를 다시 읽는다.
  Future<void> _onRefresh(AppStateProvider appState) async {
    debugPrint('[RemindScreen] pull-to-refresh - 동기화 + 리로드');
    try {
      final littenIds = appState.littens.map((l) => l.id).toList();
      await SyncService.instance.syncOnNoteTab(littenIds);
    } catch (e) {
      debugPrint('[RemindScreen] 새로고침 동기화 오류: $e');
    }
    await appState.reloadRemindsFromDisk();
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _dateTimeLabel(DateTime d) =>
      '${d.year % 100}.${_two(d.month)}.${_two(d.day)} '
      '${_two(d.hour)}:${_two(d.minute)}';

  /// 일시 바로 앞에 붙는 동기화 상태 아이콘 (파일 목록과 동일 컨벤션).
  /// 프리미엄이 아니거나 미동기화(none)면 표시하지 않는다(빈 공간도 없음).
  Widget _syncIcon(SyncStatus status) {
    final isPremium =
        Provider.of<AppStateProvider>(context, listen: false).isPremiumPlusUser;
    if (!isPremium || status == SyncStatus.none) return const SizedBox.shrink();
    final primaryColor = Theme.of(context).primaryColor;
    Widget icon;
    switch (status) {
      case SyncStatus.synced:
        icon = Icon(Icons.cloud_done, size: 14, color: primaryColor);
        break;
      case SyncStatus.pending:
        icon = Icon(Icons.cloud_upload_outlined, size: 14, color: Colors.orange.shade400);
        break;
      case SyncStatus.syncing:
        icon = const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5));
        break;
      case SyncStatus.error:
        icon = const Icon(Icons.cloud_off, size: 14, color: Colors.red);
        break;
      case SyncStatus.none:
        return const SizedBox.shrink();
    }
    return Padding(padding: const EdgeInsets.only(right: 6), child: icon);
  }

  /// 일시 앞(동기화 아이콘 다음)에 붙는 공유 아이콘 — 탭 시 해당 항목을 공유.
  /// 행 전체 탭(보기 다이얼로그)과 겹치지 않도록 자체 InkWell로 탭을 가로챈다.
  /// 공유 전이므로 기본은 비활성(회색)으로 표시한다.
  Widget _shareButton(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Icon(Icons.share, size: 14, color: Colors.grey.shade400),
      ),
    );
  }

  /// 퀴즈 그룹 공유용 평문 (제목 + 각 문항 번호·문제·답)
  String _quizShareText(QuizTarget g) {
    final sorted = [...g.items]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final buf = StringBuffer()
      ..writeln('[퀴즈] ${g.fileName.isEmpty ? '제목 없음' : g.fileName}');
    for (int i = 0; i < sorted.length; i++) {
      final q = sorted[i];
      buf.writeln('');
      buf.writeln('${i + 1}. ${q.title}');
      if (q.content.trim().isNotEmpty) buf.writeln('   ${q.content.trim()}');
    }
    return buf.toString().trim();
  }

  /// 퀴즈 그룹의 종합 동기화 상태 — 모두 synced면 synced, 일부 미완이면 그 상태.
  SyncStatus _groupSyncStatus(QuizTarget g) {
    if (g.items.isEmpty) return SyncStatus.none;
    if (g.items.every((i) => i.syncStatus == SyncStatus.synced)) return SyncStatus.synced;
    if (g.items.any((i) => i.syncStatus == SyncStatus.error)) return SyncStatus.error;
    if (g.items.any((i) =>
        i.syncStatus == SyncStatus.pending || i.syncStatus == SyncStatus.syncing)) {
      return SyncStatus.pending;
    }
    return SyncStatus.none;
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Consumer<AppStateProvider>(
      builder: (context, appState, _) {
        final summaries = appState.summaries;
        // 퀴즈는 개별 문항이 아니라 파일/영상 단위(QuizTarget)로 묶어 "제목" 하나로 표시
        final quizGroups = appState.quizTargets;

        // 상단(확인 안 함) / 하단(확인함)으로 분리:
        //  - 요약: isDone==false → 상단, true → 하단
        //  - 퀴즈 그룹: 미완료(pending) 있으면 상단, 모두 완료면 하단
        // 제목의 요약/퀴즈 토글(showSummary/showQuiz)은 '상단 영역만' 반영한다.
        // (하단=확인 영역은 토글과 무관하게 항상 확인 완료 항목을 보여준다.)
        final topItems = <({DateTime at, SummaryEntry? summary, QuizTarget? quizGroup})>[];
        final bottomItems = <({DateTime at, SummaryEntry? summary, QuizTarget? quizGroup})>[];
        for (final s in summaries) {
          if (s.isDone) {
            bottomItems.add((at: s.createdAt, summary: s, quizGroup: null));
          } else if (_filter.showSummary) {
            topItems.add((at: s.createdAt, summary: s, quizGroup: null));
          }
        }
        for (final g in quizGroups) {
          if (g.items.isEmpty) continue;
          if (g.pendingCount == 0) {
            bottomItems.add((at: g.items.first.createdAt, summary: null, quizGroup: g));
          } else if (_filter.showQuiz) {
            topItems.add((at: g.items.first.createdAt, summary: null, quizGroup: g));
          }
        }
        topItems.sort((a, b) => b.at.compareTo(a.at));
        bottomItems.sort((a, b) => b.at.compareTo(a.at));

        return Column(
          children: [
            // 상단(확인 안 함)은 항상, 하단(확인함)은 아래에서 슬라이드로 올라온다.
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final halfH = constraints.maxHeight * 0.5;
                  return AnimatedBuilder(
                    animation: _paneAnim,
                    builder: (context, _) {
                      final t = Curves.easeOut.transform(_paneAnim.value);
                      final bottomH = halfH * t;
                      return Column(
                        children: [
                          // 상단: 남은 공간을 채움(하단이 올라온 만큼 줄어듦).
                          // 우측 하단에 '+' 플로팅 버튼(상단 영역 전용 — 메모 추가).
                          Expanded(
                            child: Stack(
                              children: [
                                _paneList(topItems, color, appState,
                                    emptyText:
                                        '확인하지 않은 항목이 없습니다.\n파일을 요약하거나 퀴즈를 만들면 여기에 모입니다.'),
                                Positioned(
                                  right: 14,
                                  bottom: 14,
                                  child: _buildAddButton(color, appState),
                                ),
                              ],
                            ),
                          ),
                          // 하단: 높이를 0→50%로 키우며, 고정 높이 내용물을 클립해 올라오는 효과
                          SizedBox(
                            height: bottomH,
                            child: bottomH < 1
                                ? const SizedBox.shrink()
                                : ClipRect(
                                    child: OverflowBox(
                                      minHeight: 0,
                                      maxHeight: halfH,
                                      alignment: Alignment.topCenter,
                                      child: SizedBox(
                                        height: halfH,
                                        child: Column(
                                          children: [
                                            _confirmedHeader(color),
                                            Expanded(
                                              child: _paneList(bottomItems, color, appState,
                                                  emptyText: '확인한 항목이 없습니다.'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            _buildConfirmedBar(color, appState),
          ],
        );
      },
    );
  }

  /// 한 영역(상단/하단)의 목록 — 당겨서 새로고침 + 날짜 헤더 포함.
  Widget _paneList(
    List<({DateTime at, SummaryEntry? summary, QuizTarget? quizGroup})> items,
    Color color,
    AppStateProvider appState, {
    required String emptyText,
  }) {
    return RefreshIndicator(
      onRefresh: () => _onRefresh(appState),
      child: items.isEmpty
          ? ListView(
              // 비어 있어도 당겨서 새로고침이 되도록 스크롤 가능하게.
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(
                      emptyText,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
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
    );
  }

  /// 하단(확인함) 영역 구분 헤더.
  Widget _confirmedHeader(Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border(
          top: BorderSide(color: color.withValues(alpha: 0.25)),
          bottom: BorderSide(color: color.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 14, color: color),
          const SizedBox(width: 6),
          Text('확인',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
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

  /// 요약 항목 행 — 별 아이콘 + 제목 + '...'(삭제) 메뉴. 탭 시 요약 보기 다이얼로그.
  /// (상·하단 공통으로 우측은 일시 대신 '...' 메뉴)
  Widget _summaryRow(SummaryEntry s, Color color) {
    return InkWell(
      onTap: () => _showSummaryViewDialog(context, s, color),
      child: Padding(
        // 전체탭 파일 항목과 비슷한 높이/간격이 되도록 세로 여백을 넓힌다.
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
            _syncIcon(s.syncStatus),
            _shareButton(() => Share.share(s.toShareText())),
            _deleteMenu(() =>
                Provider.of<AppStateProvider>(context, listen: false)
                    .deleteSummary(s.id)),
          ],
        ),
      ),
    );
  }

  /// 확인 영역 우측의 '...' 메뉴 — 삭제만 제공.
  Widget _deleteMenu(VoidCallback onDelete) {
    return SizedBox(
      width: 28,
      height: 28,
      child: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade600),
        padding: EdgeInsets.zero,
        tooltip: '',
        onSelected: (v) {
          if (v == 'delete') onDelete();
        },
        itemBuilder: (ctx) => [
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: const [
                Icon(Icons.delete_outline, size: 18, color: Colors.red),
                SizedBox(width: 8),
                Text('삭제', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 퀴즈 그룹 행 — 전구+q + 파일/영상 제목 + (완료/전체) 배지 + 일시.
  /// 한 파일/영상에서 만든 여러 문항을 "제목" 하나로 묶어 보여준다.
  /// 탭하면 그룹의 퀴즈 문항(문제→답)을 펼쳐 보는 다이얼로그를 연다.
  Widget _quizGroupRow(QuizTarget g, Color color, AppStateProvider appState) {
    final total = g.items.length;
    final done = total - g.pendingCount;
    return InkWell(
      onTap: () => _showQuizGroupDialog(context, g, color),
      child: Padding(
        // 전체탭 파일 항목과 비슷한 높이/간격이 되도록 세로 여백을 넓힌다.
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Row(
          children: [
            QuizBulbIcon(size: 16, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                g.fileName.isEmpty ? '제목 없음' : g.fileName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  // 완료 그룹도 취소선·흐림 없이 진한 기본 색으로 표시(확인 영역으로 이미 구분됨)
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
            _syncIcon(_groupSyncStatus(g)),
            _shareButton(() => Share.share(_quizShareText(g))),
            _deleteMenu(() => appState.deleteQuizGroup(
                summaryGroupId: g.summaryGroupId, fileId: g.fileId)),
          ],
        ),
      ),
    );
  }

  /// 하단 바 — 상단에 그래버 라인(위로 펼침/스크롤 암시) + 가운데 확인 완료(요약/퀴즈) 카운트.
  /// 카운트는 항상 선택색(primary)으로 표시하고, **바 영역 전체**를 탭하면 확인 영역을
  /// 펼침/닫힘 토글한다(아이콘 부분만이 아니라 빈 곳을 눌러도 인식되도록).
  /// (제목란은 '확인 안 한' 카운트, 이 바는 '확인 완료' 카운트로 대칭을 이룬다.)
  Widget _buildConfirmedBar(Color color, AppStateProvider appState) {
    final doneSummary = appState.summaries.where((s) => s.isDone).length;
    final doneQuiz = appState.quizTargets
        .where((g) => g.items.isNotEmpty && g.pendingCount == 0)
        .length;

    return Material(
      color: color.withValues(alpha: 0.08), // 바 배경(InkWell 잉크가 보이도록 Material로)
      child: InkWell(
        onTap: _filter.toggleConfirmed, // 바 전체가 토글 영역
        child: Container(
          width: double.infinity, // 전체 폭(가운데 정렬, 좌우 잘림 방지)
          // 생성 칩 바(_CreateChipBar)와 동일한 세로 패딩(7)으로 높이를 맞춘다.
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: color.withValues(alpha: 0.15))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 상단 그래버 라인 — 위(상단 영역)로 펼침/스크롤할 수 있음을 암시
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 4),
              // 확인 완료 카운트 — 항상 선택색.
              Row(
                mainAxisSize: MainAxisSize.min,
                // 전체탭 제목과 동일: 아이콘 17 + 작은 카운트(≈0.8×13)를 아이콘 하단에 맞춤
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(Icons.auto_awesome, size: 17, color: color), // 요약
                  const SizedBox(width: 2),
                  Text('$doneSummary',
                      style: TextStyle(
                          fontSize: 10.5, fontWeight: FontWeight.w600, color: color)),
                  const SizedBox(width: 16),
                  QuizBulbIcon(size: 17, color: color), // 퀴즈
                  const SizedBox(width: 2),
                  Text('$doneQuiz',
                      style: TextStyle(
                          fontSize: 10.5, fontWeight: FontWeight.w600, color: color)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 상단 영역 전용 '+' 플로팅 버튼 — 메모 추가 팝업을 띄운다.
  /// (추가한 메모는 '확인 안 함' 항목이라 상단 영역으로 들어간다.)
  Widget _buildAddButton(Color color, AppStateProvider appState) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _showAddMemoDialog(context, color, appState),
        child: const Padding(
          padding: EdgeInsets.all(11),
          child: Icon(Icons.add, size: 22, color: Colors.white),
        ),
      ),
    );
  }

  /// 메모 추가 팝업 — 제목·내용을 입력하고 '요약' 또는 '퀴즈'로 저장한다.
  void _showAddMemoDialog(
      BuildContext context, Color color, AppStateProvider appState) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    bool isEmpty() =>
        titleController.text.trim().isEmpty &&
        contentController.text.trim().isEmpty;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('메모 추가', style: TextStyle(fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                    labelText: '제목', isDense: true, border: OutlineInputBorder()),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(
                    labelText: '내용',
                    isDense: true,
                    alignLabelWithHint: true,
                    border: OutlineInputBorder()),
                minLines: 3,
                maxLines: 6,
              ),
              const SizedBox(height: 6),
              Text('저장할 형식을 선택하세요.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          // 요약으로 저장
          TextButton.icon(
            onPressed: () async {
              if (isEmpty()) {
                Navigator.of(ctx).pop();
                return;
              }
              final title = titleController.text.trim();
              final content = contentController.text.trim();
              Navigator.of(ctx).pop();
              await appState.addManualSummary(title: title, content: content);
            },
            icon: Icon(Icons.auto_awesome, size: 18, color: color),
            label: Text('요약', style: TextStyle(color: color)),
          ),
          // 퀴즈로 저장
          TextButton.icon(
            onPressed: () {
              if (isEmpty()) {
                Navigator.of(ctx).pop();
                return;
              }
              final title = titleController.text.trim();
              final content = contentController.text.trim();
              Navigator.of(ctx).pop();
              appState.addManualQuiz(title: title, content: content);
            },
            icon: QuizBulbIcon(size: 18, color: color),
            label: Text('퀴즈', style: TextStyle(color: color)),
          ),
        ],
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
          // 그룹 전체가 완료면 '확인 취소', 아니면 '확인' (요약 팝업과 동일 토글)
          final allDone = items.isNotEmpty && items.every((i) => i.isDone);
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
              // 확인(완료) 토글 — 그룹 전체를 완료/미완료 처리 → 상단(확인 안 함) ↔ 하단(확인) 이동
              TextButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  appState.setQuizGroupDone(
                      summaryGroupId: g.summaryGroupId,
                      fileId: g.fileId,
                      done: !allDone);
                },
                icon: Icon(allDone ? Icons.remove_done : Icons.check_circle,
                    size: 18, color: color),
                label: Text(allDone ? '확인 취소' : '확인',
                    style: TextStyle(color: color)),
              ),
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
          // 확인(완료) 토글 — 누르면 상단(확인 안 함) ↔ 하단(확인함) 이동
          TextButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final appState =
                  Provider.of<AppStateProvider>(context, listen: false);
              await appState.toggleSummaryDone(s.id);
            },
            icon: Icon(s.isDone ? Icons.remove_done : Icons.check_circle,
                size: 18, color: color),
            label: Text(s.isDone ? '확인 취소' : '확인',
                style: TextStyle(color: color)),
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

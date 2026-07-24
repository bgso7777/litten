import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/audio_file.dart' show SyncStatus;
import '../models/summary_entry.dart';
import '../models/quiz_item.dart';
import '../services/app_state_provider.dart';
import '../services/sync_service.dart';
import '../widgets/draggable_tab_layout.dart';
import '../widgets/common/tab_count_title.dart';
import '../widgets/common/tab_title_search.dart';
import '../widgets/common/quiz_bulb_icon.dart';
import '../widgets/share_compose_dialog.dart';

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
  bool showSummary = true;    // 요약 표시(상단=확인 안 함 목록)
  bool showQuiz = true;       // 퀴즈 표시(상단=확인 안 함 목록)
  bool confirmedOpen = false; // 하단(확인함) 영역 펼침
  // 하단(확인함) 영역 종류 필터: null=전체, 'summary'=완료 요약만, 'quiz'=완료 퀴즈만.
  String? confirmedKind;

  void toggleSummary() {
    showSummary = !showSummary;
    notifyListeners();
  }

  void toggleQuiz() {
    showQuiz = !showQuiz;
    notifyListeners();
  }

  /// 제목 요약 아이콘 탭 — 배타 선택: 요약만 활성(퀴즈 비활성). 이미 요약만이면 전체 복원.
  void selectOnlySummary() {
    if (showSummary && !showQuiz) {
      showSummary = true;
      showQuiz = true; // 재탭 → 전체
    } else {
      showSummary = true;
      showQuiz = false; // 요약만
    }
    notifyListeners();
  }

  /// 제목 퀴즈 아이콘 탭 — 배타 선택: 퀴즈만 활성(요약 비활성). 이미 퀴즈만이면 전체 복원.
  void selectOnlyQuiz() {
    if (showQuiz && !showSummary) {
      showSummary = true;
      showQuiz = true; // 재탭 → 전체
    } else {
      showSummary = false;
      showQuiz = true; // 퀴즈만
    }
    notifyListeners();
  }

  /// 제목 아이콘 바깥 영역 탭 — 전체 선택(요약+퀴즈 모두 활성).
  void selectAll() {
    if (showSummary && showQuiz) return;
    showSummary = true;
    showQuiz = true;
    notifyListeners();
  }

  /// 하단 바 요약 아이콘 탭 — 확인함 영역을 열고 '완료된 요약'만 표시.
  /// 이미 그 상태면 닫는다(토글).
  void showConfirmedSummary() {
    if (confirmedOpen && confirmedKind == 'summary') {
      confirmedOpen = false;
    } else {
      confirmedOpen = true;
      confirmedKind = 'summary';
    }
    notifyListeners();
  }

  /// 하단 바 퀴즈 아이콘 탭 — 확인함 영역을 열고 '완료된 퀴즈'만 표시.
  void showConfirmedQuiz() {
    if (confirmedOpen && confirmedKind == 'quiz') {
      confirmedOpen = false;
    } else {
      confirmedOpen = true;
      confirmedKind = 'quiz';
    }
    notifyListeners();
  }

  /// 하단(확인함) 영역 펼침/닫힘 토글(빈 영역 탭). 열 때는 종류 필터 전체로.
  void toggleConfirmed() {
    confirmedOpen = !confirmedOpen;
    if (confirmedOpen) confirmedKind = null;
    notifyListeners();
  }

  /// 확인함 영역 닫기 — 헤더 밴드를 아래로 드래그할 때 사용.
  void closeConfirmed() {
    if (!confirmedOpen) return;
    confirmedOpen = false;
    notifyListeners();
  }
}

class RemindScreen extends StatefulWidget {
  const RemindScreen({super.key});

  @override
  State<RemindScreen> createState() => RemindScreenState();
}

class RemindScreenState extends State<RemindScreen> {
  late final List<TabItem> _tabs;
  final _RemindFilter _filter = _RemindFilter();
  // 우측 하단 FAB(MainTabScreen)에서 본문의 '메모 추가'를 띄우기 위해 본문 상태에 접근하는 키
  final GlobalKey<_RemindBodyViewState> _bodyKey =
      GlobalKey<_RemindBodyViewState>();

  /// 우측 하단 FAB(+)에서 호출 — 메모 추가 다이얼로그를 띄운다.
  void showAddMemo() => _bodyKey.currentState?.showAddMemo();

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
              final primary = Theme.of(context).primaryColor;
              // 상단 토글: 누르면 이 자리(상단)에 검색창이 뜬다. 하단 토글과 독립이며 검색어는 공유.
              final isSearch = appState.remindTitleMode == 'search';
              final toggle = GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    appState.setRemindTitleMode(isSearch ? 'stats' : 'search'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Icon(isSearch ? Icons.bar_chart : Icons.search,
                      size: 18, color: primary),
                ),
              );
              final Widget titleBody = isSearch
                  ? TabTitleSearchField(
                      initialValue: appState.remindSearchQuery,
                      onChanged: appState.setRemindSearchQuery,
                    )
                  : TabCountTitle([
                      [
                        TabCount(Icons.auto_awesome, summaryCount,     // 요약 — 탭하면 요약만
                            active: _filter.showSummary,
                            onTap: _filter.selectOnlySummary),
                        TabCount(Icons.lightbulb_outline, quizCount,   // 퀴즈 — 전구+q, 탭하면 퀴즈만
                            iconWidget: const QuizBulbIcon(),
                            active: _filter.showQuiz,
                            onTap: _filter.selectOnlyQuiz),
                      ],
                    ], countColor: Colors.black);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: titleBody),
                  const SizedBox(width: 8),
                  toggle,
                ],
              );
            },
          ),
        ),
        // 제목 아이콘 바깥 영역 탭 → 전체(요약+퀴즈) 선택.
        onCustomBackgroundTap: _filter.selectAll,
        // 탭 버튼이 제목 역할을 하므로 자체 헤더는 숨김(깜빡이는 유지)
        // 요약·퀴즈를 일자순으로 통합한 본문
        content: _RemindBodyView(key: _bodyKey, filter: _filter),
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
  const _RemindBodyView({super.key, required this.filter});

  final _RemindFilter filter;

  @override
  State<_RemindBodyView> createState() => _RemindBodyViewState();
}

class _RemindBodyViewState extends State<_RemindBodyView>
    with SingleTickerProviderStateMixin {
  _RemindFilter get _filter => widget.filter;
  late final AnimationController _paneAnim; // 하단(확인) 영역 슬라이드용
  // 확인함(하단) 목록을 최상단에서 아래로 당긴 누적량 — 임계치 넘으면 창을 닫는다.
  double _confirmedPullDown = 0;

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
    // 확인함이 열리거나 닫힐 때마다 오버스크롤 누적값을 초기화한다.
    // (초기화하지 않으면 직전 제스처의 잔류 누적으로 다음에 열자마자 조금만 당겨도 닫혀버림)
    _confirmedPullDown = 0;
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
        icon = Icon(Icons.sync, size: 14, color: primaryColor);
        break;
      case SyncStatus.pending:
        icon = Icon(Icons.sync, size: 14, color: Colors.orange.shade400);
        break;
      case SyncStatus.syncing:
        icon = const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5));
        break;
      case SyncStatus.error:
        icon = const Icon(Icons.sync_disabled, size: 14, color: Colors.red);
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

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 요약 공유 — 전체탭과 동일한 '사용자에게 공유 / 외부 앱' 선택 시트.
  void _shareSummary(SummaryEntry s) {
    final appState = context.read<AppStateProvider>();
    _openRemindShareSheet(
      title: s.title.isEmpty ? '요약' : s.title,
      // 사용자 공유는 메모 파일이 필요 — 아직 메모로 저장 안 했으면 자동 저장 후 공유.
      onUser: () => _shareRemindToUser(
          littenId: s.littenId, kind: 'summary', refId: s.id,
          ensureMemo: () => appState.saveSummaryAsMemo(s)),
      onExternal: () => Share.share(s.toShareText()),
    );
  }

  /// 퀴즈 그룹 공유 — 전체탭과 동일한 선택 시트.
  void _shareQuizGroup(QuizTarget g) {
    final appState = context.read<AppStateProvider>();
    final refId = g.summaryGroupId ?? 'file:${g.fileId}';
    final littenId = g.items.isNotEmpty ? g.items.first.littenId : '';
    _openRemindShareSheet(
      title: g.fileName.isEmpty ? '퀴즈' : g.fileName,
      onUser: () => _shareRemindToUser(
          littenId: littenId, kind: 'quiz', refId: refId,
          ensureMemo: () => appState.saveQuizGroupAsMemo(g)),
      onExternal: () => Share.share(_quizShareText(g)),
    );
  }

  /// '사용자에게 공유 / 외부 앱' 선택 시트 (전체탭 _openShareSheet와 동일 스타일).
  void _openRemindShareSheet({
    required String title,
    required VoidCallback onUser,
    required VoidCallback onExternal,
  }) {
    final color = Theme.of(context).primaryColor;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(children: [
                Icon(Icons.share, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
            ListTile(
              leading: Icon(Icons.send, color: color),
              title: const Text('사용자에게 공유'),
              subtitle: const Text('리튼 사용자/그룹에게 보내기'),
              onTap: () { Navigator.pop(ctx); onUser(); },
            ),
            ListTile(
              leading: Icon(Icons.ios_share, color: color),
              title: const Text('외부 앱으로 공유'),
              subtitle: const Text('카카오톡·메일 등 다른 앱'),
              onTap: () { Navigator.pop(ctx); onExternal(); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 요약/퀴즈에 연결된 메모 파일을 리튼 사용자/그룹에게 공유
  /// (전체탭 _shareFileToUser와 동일 흐름 — dual-write로 생성된 .html을 업로드).
  Future<void> _shareRemindToUser({
    required String littenId,
    required String kind,
    required String refId,
    Future<void> Function()? ensureMemo,
  }) async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    if (!appState.isLoggedIn) {
      _snack('로그인 후 사용자 공유가 가능합니다.');
      return;
    }
    if (!appState.isPremiumPlusUser) {
      _snack('공유 보내기는 프리미엄 플랜에서 가능합니다.');
      return;
    }
    var memo = await appState.findRemindMemoFile(
        littenId: littenId, kind: kind, refId: refId);
    // 아직 메모로 저장 안 했으면 자동 저장 후 다시 조회(공유는 메모 파일이 필요).
    if (memo == null && ensureMemo != null) {
      await ensureMemo();
      memo = await appState.findRemindMemoFile(
          littenId: littenId, kind: kind, refId: refId);
    }
    if (memo == null) {
      _snack('공유할 메모를 만들지 못했습니다.');
      return;
    }
    if (!mounted) return;
    final appDir = await getApplicationDocumentsDirectory();
    final path = '${appDir.path}/littens/${memo.littenId}/text/${memo.id}.html';
    await appState.reloadShareGroups();
    if (!mounted) return;
    final result = await showShareComposeDialog(context,
        fileLabel: '${memo.displayTitle}.html');
    if (result == null || !mounted) return;
    final res = await appState.shareFile(
      filePath: path,
      fileType: 'text',
      fileName: '${memo.displayTitle}.html',
      contentType: 'text/html',
      littenTitle: appState.selectedLitten?.title,
      targetType: result.targetType,
      recipientKey: result.recipientKey,
      groupId: result.groupId,
      message: result.message,
    );
    if (!mounted) return;
    final ok = res['success'] == true;
    if (ok) await appState.markFileShared(memo.id);
    if (!mounted) return;
    _snack(ok
        ? '공유했습니다 (${res['recipientCount'] ?? 1}명)'
        : (res['message']?.toString() ?? '공유에 실패했습니다.'));
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
        // 상단 목록: 제목의 요약/퀴즈 토글(showSummary/showQuiz) 반영.
        // 하단 목록: 항상 '완료된 것만', 하단 바의 종류 필터(confirmedKind) 반영.
        final topItems = <({DateTime at, SummaryEntry? summary, QuizTarget? quizGroup})>[];
        final bottomItems = <({DateTime at, SummaryEntry? summary, QuizTarget? quizGroup})>[];
        final ck = _filter.confirmedKind; // null=전체 | 'summary' | 'quiz'
        // 상단(확인 안 함) = 제목란 토글 검색어로, 하단(확인함 패널) = 패널 상단 바 검색어로 각각 필터.
        final topQ = appState.remindSearchActive
            ? appState.remindSearchQuery.trim().toLowerCase()
            : '';
        final paneQ = appState.remindPaneSearchOn
            ? appState.remindPaneSearchQuery.trim().toLowerCase()
            : '';
        for (final s in summaries) {
          final t = s.title.toLowerCase();
          if (s.isDone) {
            if (paneQ.isNotEmpty && !t.contains(paneQ)) continue;
            if (ck == null || ck == 'summary') {
              bottomItems.add((at: s.createdAt, summary: s, quizGroup: null));
            }
          } else if (_filter.showSummary) {
            if (topQ.isNotEmpty && !t.contains(topQ)) continue;
            topItems.add((at: s.createdAt, summary: s, quizGroup: null));
          }
        }
        for (final g in quizGroups) {
          if (g.items.isEmpty) continue;
          final t = g.fileName.toLowerCase();
          if (g.pendingCount == 0) {
            if (paneQ.isNotEmpty && !t.contains(paneQ)) continue;
            if (ck == null || ck == 'quiz') {
              bottomItems.add((at: g.items.first.createdAt, summary: null, quizGroup: g));
            }
          } else if (_filter.showQuiz) {
            if (topQ.isNotEmpty && !t.contains(topQ)) continue;
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
                          // 메모 추가 '+'는 하단 칩 바(_buildConfirmedBar) 우측으로 이동.
                          Expanded(
                            child: _paneList(topItems, color, appState,
                                emptyText:
                                    '확인하지 않은 항목이 없습니다.\n파일을 요약하거나 퀴즈를 만들면 여기에 모입니다.'),
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
                                            _confirmedHeader(color, appState),
                                            Expanded(
                                              child: _paneList(bottomItems, color, appState,
                                                  emptyText: '확인한 항목이 없습니다.',
                                                  // 최상단에서 아래로 더 당기면 확인함 창 닫기.
                                                  onPullDownAtTop:
                                                      _filter.closeConfirmed),
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
    VoidCallback? onPullDownAtTop,
  }) {
    final Widget list = items.isEmpty
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
                    ? _summaryRow(entry.summary!, color, appState)
                    : _quizGroupRow(entry.quizGroup!, color, appState);

                if (showHeader) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [_dateHeader(currentDate, color), row],
                  );
                }
                return row;
              },
            );

    // 확인함(하단) 영역: 최상단에서 아래로 더 당기면 창을 닫는다(당겨서 새로고침 대신).
    if (onPullDownAtTop != null) {
      return NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is OverscrollNotification &&
              n.overscroll < 0 &&
              n.metrics.pixels <= n.metrics.minScrollExtent) {
            // 위쪽 오버스크롤 누적 — 임계치(56px)를 넘으면 닫는다.
            // (짧은 목록은 드래그 중 Scroll Start/End가 반복되므로 그때는 리셋하지 않고,
            //  실제 콘텐츠를 스크롤해 최상단을 벗어났을 때만 누적을 초기화한다.)
            _confirmedPullDown += -n.overscroll;
            if (_confirmedPullDown > 56) {
              _confirmedPullDown = 0;
              onPullDownAtTop();
            }
          } else if (n is ScrollUpdateNotification &&
              n.metrics.pixels > n.metrics.minScrollExtent) {
            _confirmedPullDown = 0;
          }
          return false;
        },
        child: list,
      );
    }

    // 상단(확인 안 함) 영역: 당겨서 새로고침.
    return RefreshIndicator(
      onRefresh: () => _onRefresh(appState),
      child: list,
    );
  }

  /// 하단(확인함) 영역 구분 헤더. 밴드를 아래로 드래그하면 확인함 영역을 닫는다.
  Widget _confirmedHeader(Color color, AppStateProvider appState) {
    final searchOn = appState.remindPaneSearchOn;
    final doneSummary = appState.summaries.where((s) => s.isDone).length;
    final doneQuiz = appState.quizTargets
        .where((g) => g.items.isNotEmpty && g.pendingCount == 0)
        .length;
    // 확인함 종류 필터에 따른 활성(전체=null이면 둘 다 활성).
    bool act(String k) =>
        _filter.confirmedKind == null || _filter.confirmedKind == k;
    // 하단 칩과 동일한 '아이콘+카운트' 요소(탭하면 해당 종류만 확인함으로 필터).
    Widget kindCount(String k, Widget icon, int n, VoidCallback onTap) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            icon,
            const SizedBox(width: 2),
            Transform.translate(
              offset: const Offset(0, 2),
              child: Text('$n',
                  style: TextStyle(
                      fontSize: 10.4,
                      fontWeight: FontWeight.normal,
                      color: act(k) ? Colors.black : Colors.grey.shade400)),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // 헤더(아이콘 제외 배경/‘확인’ 영역)를 탭하면 확인함 영역 닫기.
      // 아이콘(카운트·검색 토글)은 각자 GestureDetector가 opaque로 이벤트를 흡수하므로 닫히지 않는다.
      onTap: _filter.closeConfirmed,
      // 아래로 스와이프(내림) → 확인함 영역 닫기.
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 0) _filter.closeConfirmed();
      },
      child: Container(
        width: double.infinity,
        // 바 상하 높이를 하단 칩 위젯과 동일하게(= 세로패딩9 + 콘텐츠28 = 46).
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          border: Border(
            top: BorderSide(color: color.withValues(alpha: 0.25)),
            bottom: BorderSide(color: color.withValues(alpha: 0.1)),
          ),
        ),
        child: SizedBox(
          height: 31.0, // 검색창 +10% 높이에 맞춤(기존 28)
          child: searchOn
              // 검색 모드: 리마인드 제목의 검색과 동일한 크기(고정 180×28)로, 가운데 정렬.
              ? Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TabTitleSearchField(
                        initialValue: appState.remindPaneSearchQuery,
                        onChanged: (v) => context
                            .read<AppStateProvider>()
                            .setRemindPaneSearchQuery(v),
                      ),
                      const SizedBox(width: 8),
                      _paneToggle(color, searchOn),
                    ],
                  ),
                )
              // 통계 모드: '✓ 확인'은 좌측 정렬, '요약/퀴즈 카운트 + 검색 토글'은 가운데 정렬.
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    // 좌측: ✓ 확인
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 14, color: color),
                          const SizedBox(width: 6),
                          Text('확인',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: color)),
                        ],
                      ),
                    ),
                    // 가운데: 요약/퀴즈 카운트 + 검색 토글
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        kindCount(
                            'summary',
                            Icon(Icons.auto_awesome,
                                size: 17,
                                color: act('summary')
                                    ? color
                                    : Colors.grey.shade400),
                            doneSummary,
                            _filter.showConfirmedSummary),
                        const SizedBox(width: 8),
                        kindCount(
                            'quiz',
                            QuizBulbIcon(
                                size: 17,
                                color:
                                    act('quiz') ? color : Colors.grey.shade400),
                            doneQuiz,
                            _filter.showConfirmedQuiz),
                        const SizedBox(width: 8),
                        _paneToggle(color, searchOn),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// 확인함 헤더 우측 통계↔검색 토글 아이콘.
  Widget _paneToggle(Color color, bool searchOn) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () =>
          context.read<AppStateProvider>().setRemindPaneSearchOn(!searchOn),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Icon(searchOn ? Icons.bar_chart : Icons.search,
            size: 18, color: color),
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
  Widget _summaryRow(SummaryEntry s, Color color, AppStateProvider appState) {
    final savedAsMemo = appState.isRemindSavedAsMemo('summary', s.id);
    return InkWell(
      onTap: () => _showSummaryViewDialog(context, s, color),
      child: Padding(
        // 전체탭 파일 항목과 비슷한 높이/간격이 되도록 세로 여백을 넓힌다.
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                s.title.isEmpty ? '제목 없음' : s.title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _syncIcon(s.syncStatus),
            _shareButton(() => _shareSummary(s)),
            _itemMenu(
              color: color,
              savedAsMemo: savedAsMemo,
              onToggleMemo: () => _toggleSummaryMemo(s, appState),
              onDelete: () => appState.deleteSummary(s.id),
            ),
          ],
        ),
      ),
    );
  }

  /// 항목 우측 '...' 메뉴 — '메모로 저장'(토글) + 삭제.
  /// 메모로 저장하면 전체 파일 리스트에 노출된다(다시 누르면 제거).
  Widget _itemMenu({
    required Color color,
    required bool savedAsMemo,
    required VoidCallback onToggleMemo,
    required VoidCallback onDelete,
  }) {
    return SizedBox(
      width: 28,
      height: 28,
      child: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade600),
        padding: EdgeInsets.zero,
        tooltip: '',
        onSelected: (v) {
          if (v == 'memo') {
            onToggleMemo();
          } else if (v == 'delete') {
            onDelete();
          }
        },
        itemBuilder: (ctx) => [
          PopupMenuItem<String>(
            value: 'memo',
            child: Row(
              children: [
                Icon(savedAsMemo ? Icons.bookmark_remove : Icons.note_add_outlined,
                    size: 18,
                    color: savedAsMemo ? color : Colors.grey.shade700),
                const SizedBox(width: 8),
                Text(savedAsMemo ? '메모에서 제거' : '메모로 저장'),
              ],
            ),
          ),
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

  /// 요약을 전체탭 메모로 저장/제거 토글.
  Future<void> _toggleSummaryMemo(SummaryEntry s, AppStateProvider appState) async {
    if (appState.isRemindSavedAsMemo('summary', s.id)) {
      await appState.removeRemindMemo(
          littenId: s.littenId, kind: 'summary', refId: s.id);
      _snack('전체 파일에서 메모를 제거했습니다.');
    } else {
      await appState.saveSummaryAsMemo(s);
      _snack('전체 파일에 메모로 저장했습니다.');
    }
  }

  /// 퀴즈 그룹을 전체탭 메모로 저장/제거 토글.
  Future<void> _toggleQuizMemo(QuizTarget g, AppStateProvider appState) async {
    final refId = g.summaryGroupId ?? 'file:${g.fileId}';
    final littenId = g.items.isNotEmpty ? g.items.first.littenId : '';
    if (appState.isRemindSavedAsMemo('quiz', refId)) {
      await appState.removeRemindMemo(
          littenId: littenId, kind: 'quiz', refId: refId);
      _snack('전체 파일에서 메모를 제거했습니다.');
    } else {
      await appState.saveQuizGroupAsMemo(g);
      _snack('전체 파일에 메모로 저장했습니다.');
    }
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
            QuizBulbIcon(size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                g.fileName.isEmpty ? '제목 없음' : g.fileName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
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
            _shareButton(() => _shareQuizGroup(g)),
            _itemMenu(
              color: color,
              savedAsMemo: appState.isRemindSavedAsMemo(
                  'quiz', g.summaryGroupId ?? 'file:${g.fileId}'),
              onToggleMemo: () => _toggleQuizMemo(g, appState),
              onDelete: () => appState.deleteQuizGroup(
                  summaryGroupId: g.summaryGroupId, fileId: g.fileId),
            ),
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
          // 생성 칩 바(_CreateChipBar)와 동일한 세로 패딩(9)으로 높이를 맞춘다. (전체 높이 약 10% 상향)
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: color.withValues(alpha: 0.15))),
          ),
          // 가운데: 확인 완료 카운트(아이콘+숫자). 검색은 확인함 패널 상단 바로 이동(패널 내부만 검색).
          // 노트(_CreateChipBar)·캘린더·홈 칩 바와 동일한 콘텐츠 높이(28.0)로 바 높이를 일치시킨다.
          child: SizedBox(
            height: 28.0,
            // 확인함 패널 상단(_confirmedHeader)과 동일하게: 좌측 '✓ 확인' + 가운데 카운트.
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 좌측: ✓ 확인 (확인함 패널 상단과 동일한 위치·스타일).
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 14, color: color),
                      const SizedBox(width: 6),
                      Text('확인',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: color)),
                    ],
                  ),
                ),
                // 가운데: 확인 완료 카운트(요약/퀴즈 아이콘+숫자).
                Row(
                mainAxisSize: MainAxisSize.min,
                // 채팅 하단 칩과 동일하게 하단정렬 + 카운트 2px 하향.
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 요약: 아이콘 탭 → 확인함 영역 열고 '완료된 요약'만(재탭 시 닫힘). 비활성이면 흐리게.
                  Builder(builder: (context) {
                    // 확인함이 열려 '전체(kind=null)'면 요약·퀴즈 모두 활성, '요약'만 선택하면 요약만 활성.
                    // 닫혀 있으면(미터치) 회색(비활성).
                    final sel = _filter.confirmedOpen &&
                        (_filter.confirmedKind == null ||
                            _filter.confirmedKind == 'summary');
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _filter.showConfirmedSummary,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // 상단 탭제목(TabCountTitle)과 동일한 아이콘 17 / 카운트 10.4.
                          Icon(Icons.auto_awesome,
                              size: 17,
                              color: sel ? color : Colors.grey.shade400),
                          const SizedBox(width: 2),
                          Transform.translate(
                            offset: const Offset(0, 2),
                            child: Text('$doneSummary',
                                style: TextStyle(
                                    fontSize: 10.4,
                                    fontWeight: FontWeight.normal,
                                    color: sel ? Colors.black : Colors.grey.shade400)),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(width: 8), // 전체탭 탭제목 아이콘카운트와 동일한 항목 간격(8).
                  // 퀴즈: 아이콘 탭 → 확인함 영역 열고 '완료된 퀴즈'만(재탭 시 닫힘).
                  Builder(builder: (context) {
                    // 확인함이 열려 '전체(kind=null)'면 요약·퀴즈 모두 활성, '퀴즈'만 선택하면 퀴즈만 활성.
                    // 닫혀 있으면(미터치) 회색(비활성).
                    final sel = _filter.confirmedOpen &&
                        (_filter.confirmedKind == null ||
                            _filter.confirmedKind == 'quiz');
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _filter.showConfirmedQuiz,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          QuizBulbIcon(
                              size: 17,
                              color: sel ? color : Colors.grey.shade400),
                          const SizedBox(width: 2),
                          Transform.translate(
                            offset: const Offset(0, 2),
                            child: Text('$doneQuiz',
                                style: TextStyle(
                                    fontSize: 10.4,
                                    fontWeight: FontWeight.normal,
                                    color: sel ? Colors.black : Colors.grey.shade400)),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 우측 하단 FAB(+)에서 호출 — 메모 추가 다이얼로그를 띄운다.
  void showAddMemo() {
    final color = Theme.of(context).primaryColor;
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    _showAddMemoDialog(context, color, appState);
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

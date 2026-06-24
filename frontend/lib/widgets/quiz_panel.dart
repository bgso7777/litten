import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/remind_item.dart';
import '../services/app_state_provider.dart';
import '../l10n/app_localizations.dart';

/// 리마인드 패널의 완료 상태 필터.
/// - all: 전체(기본) · pending: 미완료만 · done: 완료만
enum RemindDoneFilter { all, pending, done }

/// 노트영역 하단 — 요약 리마인드 아코디언 패널 (3단계 높이)
///
/// 항목1 (파일)                          3개  ▶
///   세부항목1-1 (리마인드 제목)               ▶
///     내용~~~~~
///   세부항목1-2                              ▶
/// 항목2 (파일)                          2개  ▶
class RemindPanel extends StatefulWidget {
  final VoidCallback? onClose;
  final void Function(double dy)? onDragUpdate;
  final void Function(double velocity)? onDragEnd;

  /// 전체화면 모드: 드래그 핸들 제거 + 미완료 항목 깜빡이
  final bool isFullScreen;

  /// 전체화면 모드에서 자체 '리마인드' 헤더 표시 여부.
  /// (상단 탭바/탭 레이아웃 안에 넣을 때는 false로 두어 헤더 중복을 피한다)
  final bool showHeader;

  /// 완료 상태 필터 — 미완료/완료를 상하로 나눠 보여줄 때 사용.
  final RemindDoneFilter doneFilter;

  const RemindPanel({
    super.key,
    this.onClose,
    this.onDragUpdate,
    this.onDragEnd,
    this.isFullScreen = false,
    this.showHeader = false,
    this.doneFilter = RemindDoneFilter.all,
  });

  @override
  State<RemindPanel> createState() => _RemindPanelState();
}

class _RemindPanelState extends State<RemindPanel>
    with SingleTickerProviderStateMixin {
  final Set<String> _openTargets = {};
  final Set<String> _openItems = {};
  final ScrollController _scrollController = ScrollController();

  // 리스트 드래그 추적
  bool _isResizing = false;
  VelocityTracker? _velocityTracker;

  // ⭐ 기억 탭: 미완료 항목 기억 유도용 깜빡이 애니메이션
  late final AnimationController _blinkController;
  late final Animation<double> _blinkAnim;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _blinkAnim = Tween<double>(begin: 1.0, end: 0.25)
        .animate(CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut));
    if (widget.isFullScreen) {
      _blinkController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleTarget(String fileId) {
    debugPrint('[RemindPanel] 파일 토글: $fileId');
    setState(() {
      if (_openTargets.contains(fileId)) {
        _openTargets.remove(fileId);
      } else {
        _openTargets.add(fileId);
      }
    });
  }

  void _toggleItem(String itemId) {
    debugPrint('[RemindPanel] 항목 토글: $itemId');
    setState(() {
      if (_openItems.contains(itemId)) {
        _openItems.remove(itemId);
      } else {
        _openItems.add(itemId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, _) {
        final targets =
            _applyDoneFilter(_sortedTargets(appState.remindTargets));

        return Container(
          margin: const EdgeInsets.fromLTRB(0, 4, 0, 8),
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          child: Column(
            children: [
              if (!widget.isFullScreen)
                _buildDragHandle()
              else if (widget.showHeader)
                _buildHeader(appState),
              Expanded(
                child: targets.isEmpty
                    ? _buildEmpty()
                    : _buildList(context, targets, appState),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 기억 탭 헤더 ──────────────────────────────────────────────────────────

  Widget _buildHeader(AppStateProvider appState) {
    final primaryColor = Theme.of(context).primaryColor;
    final l10n = AppLocalizations.of(context);
    final pendingCount = appState.remindItems.where((i) => !i.isDone).length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(color: primaryColor.withValues(alpha: 0.15), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, size: 20, color: primaryColor),
          const SizedBox(width: 8),
          Text(
            '리마인드',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor),
          ),
          const SizedBox(width: 10),
          if (pendingCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                l10n?.reminderCount(pendingCount) ?? '$pendingCount개',
                style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  // ── 드래그 핸들 ───────────────────────────────────────────────────────────

  Widget _buildDragHandle() {
    final primaryColor = Theme.of(context).primaryColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (d) => widget.onDragUpdate?.call(d.delta.dy),
      onVerticalDragEnd: (d) => widget.onDragEnd?.call(d.velocity.pixelsPerSecond.dy),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.1),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
          ),
        ),
        child: Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  // ── 아코디언 리스트 ────────────────────────────────────────────────────────

  Widget _buildList(BuildContext context, List<RemindTarget> targets, AppStateProvider appState) {
    // SelectionArea: 자식 위젯의 모든 Text를 선택/복사 가능하게 함
    // (GestureDetector의 onTap과 충돌하지 않음 — long-press로 선택 시작)
    final children = <Widget>[];
    DateTime? lastDate;
    for (final target in targets) {
      // ⭐ 그룹의 첫 항목 createdAt 기준 일자 헤더
      final groupCreatedAt = target.items.isNotEmpty
          ? target.items.first.createdAt
          : DateTime.now();
      final currentDate = DateTime(groupCreatedAt.year, groupCreatedAt.month, groupCreatedAt.day);
      if (lastDate == null || lastDate != currentDate) {
        children.add(_buildDateHeader(currentDate));
        lastDate = currentDate;
      }

      children.add(_buildTargetRow(context, target));
      if (_openTargets.contains(target.summaryGroupId ?? 'file:${target.fileId}')) {
        for (final item in _sortedItems(target.items)) {
          children.add(_buildItemRow(context, item, appState));
          if (_openItems.contains(item.id)) {
            children.add(_buildContentRow(context, item, appState));
          }
        }
      }
    }
    children.add(const SizedBox(height: 8));

    final scrollContent = SelectionArea(
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(children: children),
      ),
    );

    return Listener(
      onPointerDown: (e) {
        _isResizing = false;
        _velocityTracker = VelocityTracker.withKind(e.kind);
      },
      onPointerMove: (e) {
        _velocityTracker?.addPosition(e.timeStamp, e.position);
        if (!_scrollController.hasClients) return;
        final pos = _scrollController.position;
        final dy = e.delta.dy;

        if (!_isResizing) {
          final atBottom = pos.pixels >= pos.maxScrollExtent - 0.5;
          final atTop = pos.pixels <= pos.minScrollExtent + 0.5;
          // 위로 스와이프(dy<0) + 하단끝, 또는 아래로 스와이프(dy>0) + 상단끝
          if ((dy < -1 && atBottom) || (dy > 1 && atTop)) {
            _isResizing = true;
          }
        }
        if (_isResizing) {
          widget.onDragUpdate?.call(dy);
        }
      },
      onPointerUp: (e) {
        if (_isResizing) {
          final vel = _velocityTracker?.getVelocity().pixelsPerSecond.dy ?? 0;
          debugPrint('[RemindPanel] 드래그 종료 velocity=$vel');
          widget.onDragEnd?.call(vel);
          _isResizing = false;
        }
        _velocityTracker = null;
      },
      onPointerCancel: (_) {
        _isResizing = false;
        _velocityTracker = null;
      },
      child: scrollContent,
    );
  }

  // ── Level 1: 파일 행 ──────────────────────────────────────────────────────

  Widget _buildTargetRow(BuildContext context, RemindTarget target) {
    // 요약 그룹별 고유 키 (groupId 우선, 없으면 fileId)
    final groupKey = target.summaryGroupId ?? 'file:${target.fileId}';
    final isOpen = _openTargets.contains(groupKey);
    final pending = target.items.where((i) => !i.isDone).length;
    final total = target.items.length;
    final primaryColor = Theme.of(context).primaryColor;

    final contentType = target.contentType;
    final levelLabel = target.summaryLevel != null
        ? _kLevelLabels[target.summaryLevel!] ?? 'Lv.${target.summaryLevel}'
        : null;

    return GestureDetector(
      onTap: () => _toggleTarget(groupKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: primaryColor.withValues(alpha: 0.2), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline, size: 16, color: primaryColor),
            const SizedBox(width: 10),
            // 제목만
            Expanded(
              child: Text(
                target.fileName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.normal,
                  color: Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 요약 보기 아이콘 (요약 수준 칩 앞) — 24x24 영역
            if (target.summaryText != null && target.summaryText!.isNotEmpty) ...[
              SizedBox(
                width: 24,
                height: 24,
                child: GestureDetector(
                  onTap: () => _showSummaryDialog(context, target),
                  child: Icon(Icons.auto_awesome, size: 16, color: primaryColor),
                ),
              ),
            ],
            // 요약 수준 칩
            if (levelLabel != null) ...[
              const SizedBox(width: 6),
              _buildSmallChip(levelLabel, primaryColor),
            ],
            // 콘텐츠 유형 칩
            if (contentType != null && contentType.isNotEmpty) ...[
              const SizedBox(width: 4),
              _buildSmallChip(contentType, primaryColor),
            ],
            const SizedBox(width: 6),
            // 완료/전체 카운트 (예: "4/4개")
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: pending > 0 ? primaryColor : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$pending/$total',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 4),
            // 펼침 화살표 (24x24 영역, 16px 아이콘)
            SizedBox(
              width: 24,
              height: 24,
              child: Icon(
                isOpen ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                size: 16,
                color: primaryColor.withValues(alpha: 0.8),
              ),
            ),
            // ⋮ 메뉴 (수정 / 삭제) — 파일리스트와 동일 사이즈
            SizedBox(
              width: 24,
              height: 24,
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                iconSize: 16,
                icon: Icon(Icons.more_vert, size: 16, color: primaryColor.withValues(alpha: 0.7)),
                tooltip: '그룹 메뉴',
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditGroupDialog(context, target);
                  } else if (value == 'delete') {
                    _confirmDeleteGroup(context, target);
                  }
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('이름 수정'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('그룹 삭제', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditGroupDialog(BuildContext context, RemindTarget target) {
    final controller = TextEditingController(text: target.fileName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('그룹 이름 수정'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '그룹 이름',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              final appState = Provider.of<AppStateProvider>(context, listen: false);
              for (final item in target.items) {
                final updated = RemindItem(
                  id: item.id,
                  fileId: item.fileId,
                  fileType: item.fileType,
                  fileName: newName,
                  littenId: item.littenId,
                  title: item.title,
                  remindAt: item.remindAt,
                  content: item.content,
                  isDone: item.isDone,
                  createdAt: item.createdAt,
                  summaryGroupId: item.summaryGroupId,
                  summaryLevel: item.summaryLevel,
                  contentType: item.contentType,
                  summaryText: item.summaryText,
                );
                appState.updateRemindItem(updated);
              }
              Navigator.pop(ctx);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGroup(BuildContext context, RemindTarget target) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('리마인드 그룹 삭제'),
        content: Text('"${target.fileName}"의 리마인드 ${target.items.length}개를 모두 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final appState = Provider.of<AppStateProvider>(context, listen: false);
              appState.deleteRemindGroup(
                summaryGroupId: target.summaryGroupId,
                fileId: target.fileId,
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  static const Map<int, String> _kLevelLabels = {
    1: '한줄',
    2: '간단',
    3: '일반',
    4: '상세',
    5: '전체',
  };

  // 요약 내용 팝업 표시 (리마인드 섹션은 제외하고 본문만)
  void _showSummaryDialog(BuildContext context, RemindTarget target) {
    final color = Theme.of(context).primaryColor;
    final levelLabel = target.summaryLevel != null
        ? _kLevelLabels[target.summaryLevel!] ?? 'Lv.${target.summaryLevel}'
        : '';
    final contentType = target.contentType ?? '';
    final firstCreated = target.items.isNotEmpty ? target.items.first.createdAt : null;
    final dateLabel = firstCreated != null
        ? '${firstCreated.year}.${firstCreated.month.toString().padLeft(2, '0')}.${firstCreated.day.toString().padLeft(2, '0')} '
            '${firstCreated.hour.toString().padLeft(2, '0')}:${firstCreated.minute.toString().padLeft(2, '0')}'
        : '';

    // ⭐ 리마인드 섹션 제거 (본문 요약만 표시)
    final fullText = target.summaryText ?? '';
    const reminderMarker = '─── 📌 리마인드 ───';
    final reminderIdx = fullText.indexOf(reminderMarker);
    final summaryOnly = reminderIdx != -1
        ? fullText.substring(0, reminderIdx).trim()
        : fullText;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.auto_awesome, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              target.fileName,
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
                      text: '📅 $dateLabel',
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                    if (levelLabel.isNotEmpty || contentType.isNotEmpty)
                      TextSpan(
                        text: '   [$levelLabel${levelLabel.isNotEmpty && contentType.isNotEmpty ? '/' : ''}$contentType]\n\n',
                        style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      )
                    else
                      const TextSpan(text: '\n\n'),
                    TextSpan(
                      text: summaryOnly,
                      style: const TextStyle(fontSize: 12, height: 1.5, color: Colors.black),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  // ── Level 2: 리마인드 항목 행 ─────────────────────────────────────────────

  Widget _buildItemRow(BuildContext context, RemindItem item, AppStateProvider appState) {
    final isOpen = _openItems.contains(item.id);
    final primaryColor = Theme.of(context).primaryColor;

    return GestureDetector(
      onTap: () {
        if (item.content.isNotEmpty || item.remindAt != null) {
          _toggleItem(item.id);
        }
      },
      child: Container(
        padding: const EdgeInsets.only(left: 36, right: 14, top: 9, bottom: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: primaryColor.withValues(alpha: 0.1), width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 체크 아이콘 — 탭 시 완료 토글
            GestureDetector(
              onTap: () {
                debugPrint('[RemindPanel] 체크 토글: ${item.id}');
                appState.toggleRemindDone(item.id);
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: (widget.isFullScreen && !item.isDone)
                    // ⭐ 기억 유도: 미완료 항목 체크 아이콘 깜빡이
                    ? FadeTransition(
                        opacity: _blinkAnim,
                        child: Icon(
                          Icons.radio_button_unchecked,
                          size: 20,
                          color: primaryColor,
                        ),
                      )
                    : Icon(
                        item.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 20,
                        color: item.isDone ? Colors.grey.shade400 : primaryColor,
                      ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: item.isDone ? Colors.grey.shade400 : Colors.black,
                      decoration: item.isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (item.remindAt != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 11, color: Colors.grey.shade600),
                        const SizedBox(width: 3),
                        Text(
                          DateFormat('M/d HH:mm').format(item.remindAt!),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (item.content.isNotEmpty || item.remindAt != null)
              SizedBox(
                width: 24,
                height: 24,
                child: Icon(
                  isOpen ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                  size: 16,
                  color: primaryColor.withValues(alpha: 0.6),
                ),
              ),
            // ⋮ 메뉴 (항목 수정/삭제) — 폭 축소
            SizedBox(
              width: 24,
              height: 24,
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                iconSize: 16,
                icon: Icon(Icons.more_vert, size: 16, color: primaryColor.withValues(alpha: 0.6)),
                tooltip: '항목 메뉴',
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditItemDialog(context, item, appState);
                  } else if (value == 'delete') {
                    _confirmDeleteItem(context, item, appState);
                  }
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('수정'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('삭제', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteItem(BuildContext context, RemindItem item, AppStateProvider appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('리마인드 항목 삭제'),
        content: Text('"${item.title}"을(를) 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              appState.deleteRemindItem(item.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _showEditItemDialog(BuildContext context, RemindItem item, AppStateProvider appState) {
    final titleController = TextEditingController(text: item.title);
    final contentController = TextEditingController(text: item.content);
    DateTime? remindAt = item.remindAt;
    final color = Theme.of(context).primaryColor;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('리마인드 수정'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: '제목',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '내용',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                // 알림 시간
                Row(
                  children: [
                    Icon(Icons.schedule, size: 18, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        remindAt != null
                            ? '${remindAt!.year}-${remindAt!.month.toString().padLeft(2, '0')}-${remindAt!.day.toString().padLeft(2, '0')} ${remindAt!.hour.toString().padLeft(2, '0')}:${remindAt!.minute.toString().padLeft(2, '0')}'
                            : '알림 시간 없음',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                          context: ctx,
                          initialDate: remindAt ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate == null) return;
                        if (!ctx.mounted) return;
                        final pickedTime = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(remindAt ?? DateTime.now()),
                        );
                        if (pickedTime == null) return;
                        setStateDialog(() {
                          remindAt = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      },
                      child: const Text('변경'),
                    ),
                    if (remindAt != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setStateDialog(() => remindAt = null),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                final updated = item.copyWith(
                  title: titleController.text.trim(),
                  content: contentController.text.trim(),
                  remindAt: remindAt,
                  clearRemindAt: remindAt == null,
                );
                appState.updateRemindItem(updated);
                Navigator.pop(ctx);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Level 3: 내용 행 ──────────────────────────────────────────────────────

  Widget _buildContentRow(BuildContext context, RemindItem item, AppStateProvider appState) {
    // Level 2 padding(36) + 체크아이콘(20) + 우측 padding(10) = 66 (체크 아이콘 안쪽으로 들여쓰기)
    return Container(
      padding: const EdgeInsets.only(left: 66, right: 14, top: 6, bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.content.isNotEmpty)
            Text(
              item.content,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                height: 1.6,
              ),
            ),
          if (item.remindAt != null) ...[
            if (item.content.isNotEmpty) const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 13, color: Colors.grey.shade700),
                  const SizedBox(width: 5),
                  Text(
                    DateFormat('yyyy년 M월 d일 HH:mm').format(item.remindAt!),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 일자 헤더 ─────────────────────────────────────────────────────────────

  Widget _buildDateHeader(DateTime date) {
    final primaryColor = Theme.of(context).primaryColor;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    String label;
    if (date == today) {
      label = '오늘';
    } else if (date == yesterday) {
      label = '어제';
    } else {
      label = DateFormat('yyyy년 M월 d일 (E)', 'ko').format(date);
    }

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: primaryColor.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }

  // ── 빈 상태 ───────────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    final primaryColor = Theme.of(context).primaryColor;
    final l10n = AppLocalizations.of(context);

    // 필터별 빈 상태 메시지/아이콘
    final IconData icon;
    final String message;
    switch (widget.doneFilter) {
      case RemindDoneFilter.pending:
        icon = Icons.check_circle_outline;
        message = '미완료 리마인드가 없습니다';
        break;
      case RemindDoneFilter.done:
        icon = Icons.history;
        message = '완료한 리마인드가 없습니다';
        break;
      case RemindDoneFilter.all:
        icon = Icons.folder_open_outlined;
        message = l10n?.noRemindItems ?? '요약에서 리마인드를\n추출하면 여기 표시됩니다';
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: primaryColor.withValues(alpha: 0.4)),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(fontSize: 13, color: primaryColor.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── 정렬 헬퍼 ─────────────────────────────────────────────────────────────

  /// 완료 상태 필터 적용 — 그룹(타깃) 내 항목을 필터에 맞게 추려내고,
  /// 남은 항목이 없는 그룹은 제외한다. (미완료/완료 분할 표시용)
  List<RemindTarget> _applyDoneFilter(List<RemindTarget> targets) {
    if (widget.doneFilter == RemindDoneFilter.all) return targets;
    final wantDone = widget.doneFilter == RemindDoneFilter.done;
    final result = <RemindTarget>[];
    for (final t in targets) {
      final items = t.items.where((i) => i.isDone == wantDone).toList();
      if (items.isEmpty) continue;
      result.add(RemindTarget(
        fileId: t.fileId,
        fileType: t.fileType,
        fileName: t.fileName,
        items: items,
        summaryGroupId: t.summaryGroupId,
        summaryLevel: t.summaryLevel,
        contentType: t.contentType,
        summaryText: t.summaryText,
      ));
    }
    return result;
  }

  List<RemindTarget> _sortedTargets(List<RemindTarget> targets) {
    final list = List<RemindTarget>.from(targets);
    list.sort((a, b) {
      final aLatest = a.items.map((i) => i.createdAt).reduce((x, y) => x.isAfter(y) ? x : y);
      final bLatest = b.items.map((i) => i.createdAt).reduce((x, y) => x.isAfter(y) ? x : y);
      return bLatest.compareTo(aLatest);
    });
    return list;
  }

  List<RemindItem> _sortedItems(List<RemindItem> items) {
    final list = List<RemindItem>.from(items);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }
}

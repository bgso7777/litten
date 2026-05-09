import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/remind_item.dart';
import '../services/app_state_provider.dart';

/// 노트영역 하단 — 요약 리마인드 아코디언 패널 (3단계 높이)
///
/// 항목1 (파일)                          3개  ▶
///   세부항목1-1 (리마인드 제목)               ▶
///     내용~~~~~
///   세부항목1-2                              ▶
/// 항목2 (파일)                          2개  ▶
class RemindPanel extends StatefulWidget {
  final VoidCallback onClose;
  final void Function(double dy)? onDragUpdate;
  final void Function(double velocity)? onDragEnd;

  const RemindPanel({
    super.key,
    required this.onClose,
    this.onDragUpdate,
    this.onDragEnd,
  });

  @override
  State<RemindPanel> createState() => _RemindPanelState();
}

class _RemindPanelState extends State<RemindPanel> {
  final Set<String> _openTargets = {};
  final Set<String> _openItems = {};
  final ScrollController _scrollController = ScrollController();

  // 리스트 드래그 추적
  bool _isResizing = false;
  VelocityTracker? _velocityTracker;

  @override
  void dispose() {
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
        final targets = _sortedTargets(appState.remindTargets);

        return Container(
          margin: const EdgeInsets.fromLTRB(0, 4, 0, 8),
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          child: Column(
            children: [
              _buildDragHandle(),
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
    final scrollContent = SelectionArea(
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            for (final target in targets) ...[
              _buildTargetRow(context, target),
              if (_openTargets.contains(target.summaryGroupId ?? 'file:${target.fileId}'))
                for (final item in _sortedItems(target.items)) ...[
                  _buildItemRow(context, item, appState),
                  if (_openItems.contains(item.id))
                    _buildContentRow(context, item, appState),
                ],
            ],
            const SizedBox(height: 8),
          ],
        ),
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
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 요약 보기 아이콘 (요약 수준 칩 앞)
            if (target.summaryText != null && target.summaryText!.isNotEmpty) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _showSummaryDialog(context, target),
                child: Icon(Icons.auto_awesome, size: 16, color: primaryColor),
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
            const SizedBox(width: 8),
            Icon(
              isOpen ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
              size: 20,
              color: primaryColor.withValues(alpha: 0.8),
            ),
          ],
        ),
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
                child: Icon(
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
              Icon(
                isOpen ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                size: 16,
                color: primaryColor.withValues(alpha: 0.6),
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

  // ── 빈 상태 ───────────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    final primaryColor = Theme.of(context).primaryColor;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_outlined, size: 36, color: primaryColor.withValues(alpha: 0.4)),
            const SizedBox(height: 10),
            Text(
              '요약에서 리마인드를\n추출하면 여기 표시됩니다',
              style: TextStyle(fontSize: 13, color: primaryColor.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── 정렬 헬퍼 ─────────────────────────────────────────────────────────────

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

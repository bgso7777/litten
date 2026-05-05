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
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
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
          ),
        );
      },
    );
  }

  // ── 드래그 핸들 ───────────────────────────────────────────────────────────

  Widget _buildDragHandle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (d) => widget.onDragUpdate?.call(d.delta.dy),
      onVerticalDragEnd: (d) => widget.onDragEnd?.call(d.velocity.pixelsPerSecond.dy),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
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
              color: Colors.blue.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  // ── 아코디언 리스트 ────────────────────────────────────────────────────────

  Widget _buildList(BuildContext context, List<RemindTarget> targets, AppStateProvider appState) {
    final scrollContent = SingleChildScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          for (final target in targets) ...[
            _buildTargetRow(context, target),
            if (_openTargets.contains(target.fileId))
              for (final item in _sortedItems(target.items)) ...[
                _buildItemRow(context, item, appState),
                if (_openItems.contains(item.id))
                  _buildContentRow(context, item, appState),
              ],
          ],
          const SizedBox(height: 8),
        ],
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
    final isOpen = _openTargets.contains(target.fileId);
    final pending = target.items.where((i) => !i.isDone).length;
    final total = target.items.length;

    return GestureDetector(
      onTap: () => _toggleTarget(target.fileId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isOpen ? Colors.blue.shade50 : Colors.white,
          border: Border(
            top: BorderSide(color: Colors.blue.shade200, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, size: 16, color: Colors.blue.shade500),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                target.fileName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 완료/전체 카운트
            Text(
              '$pending/$total',
              style: TextStyle(fontSize: 12, color: Colors.blue.shade500),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: pending > 0 ? Colors.blue.shade600 : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${target.items.length}개',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isOpen ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
              size: 20,
              color: Colors.blue.shade400,
            ),
          ],
        ),
      ),
    );
  }

  // ── Level 2: 리마인드 항목 행 ─────────────────────────────────────────────

  Widget _buildItemRow(BuildContext context, RemindItem item, AppStateProvider appState) {
    final isOpen = _openItems.contains(item.id);

    return GestureDetector(
      onTap: () {
        if (item.content.isNotEmpty || item.remindAt != null) {
          _toggleItem(item.id);
        }
      },
      child: Container(
        padding: const EdgeInsets.only(left: 36, right: 14, top: 9, bottom: 9),
        decoration: BoxDecoration(
          color: item.isDone ? Colors.grey.shade50 : Colors.white,
          border: Border(
            top: BorderSide(color: Colors.blue.shade100, width: 0.5),
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
                  color: item.isDone ? Colors.grey.shade400 : Colors.blue.shade600,
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
                      color: item.isDone ? Colors.grey.shade400 : Colors.blue.shade900,
                      decoration: item.isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (item.remindAt != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 11, color: Colors.blue.shade400),
                        const SizedBox(width: 3),
                        Text(
                          DateFormat('M/d HH:mm').format(item.remindAt!),
                          style: TextStyle(fontSize: 11, color: Colors.blue.shade400),
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
                color: Colors.blue.shade300,
              ),
          ],
        ),
      ),
    );
  }

  // ── Level 3: 내용 행 ──────────────────────────────────────────────────────

  Widget _buildContentRow(BuildContext context, RemindItem item, AppStateProvider appState) {
    return Container(
      padding: const EdgeInsets.only(left: 66, right: 14, top: 6, bottom: 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withValues(alpha: 0.6),
        border: Border(
          top: BorderSide(color: Colors.blue.shade100, width: 0.5),
          left: BorderSide(color: Colors.blue.shade300, width: 2.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.content.isNotEmpty)
            Text(
              item.content,
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue.shade900.withValues(alpha: 0.8),
                height: 1.6,
              ),
            ),
          if (item.remindAt != null) ...[
            if (item.content.isNotEmpty) const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 13, color: Colors.blue.shade700),
                  const SizedBox(width: 5),
                  Text(
                    DateFormat('yyyy년 M월 d일 HH:mm').format(item.remindAt!),
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade800, fontWeight: FontWeight.w500),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_outlined, size: 36, color: Colors.blue.shade200),
            const SizedBox(height: 10),
            Text(
              '요약에서 리마인드를\n추출하면 여기 표시됩니다',
              style: TextStyle(fontSize: 13, color: Colors.blue.shade300),
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

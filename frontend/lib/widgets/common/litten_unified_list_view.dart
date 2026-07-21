import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../utils/timezone_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/themes.dart';
import '../../l10n/app_localizations.dart';
import '../../models/audio_file.dart';
import '../../models/handwriting_file.dart';
import '../../models/litten.dart';
import '../../models/text_file.dart';
import '../../screens/home_dashboard_screen.dart' show showEditRoomScheduleDialog;
import '../../services/app_state_provider.dart';
import '../../services/notification_storage_service.dart';
import '../../utils/schedule_utils.dart' as schedule_utils;
import '../../widgets/common/empty_state.dart';
import '../../widgets/dialogs/edit_litten_dialog.dart';

class LittenUnifiedListView extends StatefulWidget {
  final ScrollController? scrollController;
  final EdgeInsets? padding;
  final String? filterType; // 'text', 'handwriting', 'audio' — null이면 전체 표시
  final String? littenId;   // 설정 시 해당 일정의 파일만 표시
  final bool? listVisible;  // 외부에서 리스트 표시 여부를 제어할 때 사용
  final VoidCallback? onListToggle; // 외부 토글 콜백
  final VoidCallback? onListExpand; // 리스트가 숨김→보임으로 전환될 때 콜백
  final bool ignoreSelectedDate; // true면 캘린더 날짜 선택을 무시하고 전체 일정 표시

  const LittenUnifiedListView({super.key, this.scrollController, this.padding, this.filterType, this.littenId, this.listVisible, this.onListToggle, this.onListExpand, this.ignoreSelectedDate = false});

  @override
  State<LittenUnifiedListView> createState() => _LittenUnifiedListViewState();
}

class _LittenUnifiedListViewState extends State<LittenUnifiedListView> {
  Set<String> _collapsedLittenIds = {};
  int _currentTabIndex = 0;
  bool _littenListVisible = true;

  Future<List<Map<String, dynamic>>>? _filesFuture;
  String? _filesFutureKey;

  void _refreshFilesFutureIfNeeded(AppStateProvider appState, String key) {
    if (_filesFutureKey != key) {
      _filesFutureKey = key;
      _filesFuture = appState.getAllFiles();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCollapsedLittenIds();
  }

  Future<void> _loadCollapsedLittenIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final collapsedIds = prefs.getStringList('collapsed_litten_ids');
      if (!mounted) return;
      if (collapsedIds == null) {
        final appState = Provider.of<AppStateProvider>(context, listen: false);
        final allLittenIds = appState.littens.map((l) => l.id).toSet();
        setState(() { _collapsedLittenIds = allLittenIds; });
        await prefs.setStringList('collapsed_litten_ids', _collapsedLittenIds.toList());
      } else {
        setState(() { _collapsedLittenIds = collapsedIds.toSet(); });
      }
    } catch (e) {
      debugPrint('❌ 숨겨진 리튼 ID 로드 실패: $e');
    }
  }

  Future<void> _toggleLittenCollapse(String littenId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        if (_collapsedLittenIds.contains(littenId)) {
          _collapsedLittenIds.remove(littenId);
        } else {
          _collapsedLittenIds.add(littenId);
        }
      });
      await prefs.setStringList('collapsed_litten_ids', _collapsedLittenIds.toList());
    } catch (e) {
      debugPrint('❌ 리튼 숨김 토글 실패: $e');
    }
  }

  void _showEditLittenDialog(String littenId) {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final currentLitten = appState.littens.firstWhere((l) => l.id == littenId);
    showDialog(
      context: context,
      builder: (context) => EditLittenDialog(
        litten: currentLitten,
        onScheduleIndexChanged: (index) { _currentTabIndex = index; },
      ),
    );
  }

  void _showDeleteDialog(String littenId, String title) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일정 삭제'),
        content: Text('\'$title\' 일정을 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없으며, 관련된 모든 파일이 함께 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.cancel ?? '취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final appState = Provider.of<AppStateProvider>(context, listen: false);
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              try {
                await appState.deleteLitten(littenId);
                if (mounted) {
                  navigator.pop();
                }
              } catch (e) {
                if (mounted) {
                  navigator.pop();
                  scaffoldMessenger.showSnackBar(SnackBar(
                    content: Text(e.toString().replaceAll('Exception: ', '')),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 3),
                  ));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
            child: Text(l10n?.delete ?? '삭제', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        final l10n = AppLocalizations.of(context);
        final effectivePadding = widget.padding ??
            EdgeInsets.only(
              left: AppSpacing.paddingM.left,
              right: AppSpacing.paddingM.right,
              top: 0,
              bottom: AppSpacing.paddingM.left + 80,
            );

        final sliver = widget.filterType != null
            ? _buildFilteredSliverContent(context, appState, widget.filterType!, littenId: widget.littenId)
            : _buildSliverContent(context, appState, l10n, appState.selectedDateNotifications, littenId: widget.littenId);

        return CustomScrollView(
          key: widget.key != null ? null : PageStorageKey<String>('litten_unified_list_${widget.filterType ?? 'all'}_${widget.littenId ?? 'all'}'),
          controller: widget.scrollController,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverPadding(
              padding: effectivePadding,
              sliver: sliver,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatsSection(BuildContext context, AppStateProvider appState) {
    final littenCount = appState.littens.where((l) => l.title != 'undefined').length;
    final audioCount = appState.totalAudioCount;
    final textCount = appState.totalTextCount;
    final handwritingCount = appState.totalHandwritingCount;
    final themeColor = Theme.of(context).primaryColor;
    final hPad = widget.padding?.left ?? AppSpacing.paddingM.left;
    final effectiveVisible = widget.listVisible ?? _littenListVisible;

    void handleToggle() {
      if (widget.onListToggle != null) {
        widget.onListToggle!();
      } else {
        final wasHidden = !_littenListVisible;
        setState(() => _littenListVisible = !_littenListVisible);
        if (wasHidden) widget.onListExpand?.call(); // 숨김 → 보임 전환 시 콜백
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: handleToggle,
      child: Container(
        height: 45,
        decoration: BoxDecoration(
          color: themeColor.withValues(alpha: 0.1),
          border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
        ),
        child: Row(
          children: [
            SizedBox(width: 16 + hPad),
            Icon(Icons.event_available, size: 20, color: themeColor),
            const SizedBox(width: 4),
            Text('$littenCount', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: themeColor)),
            const SizedBox(width: 8),
            const Spacer(),
            _buildFileCountBadge(Icons.notes, textCount, themeColor),
            const SizedBox(width: 4),
            _buildFileCountBadge(Icons.draw, handwritingCount, themeColor),
            const SizedBox(width: 4),
            _buildFileCountBadge(Icons.mic, audioCount, themeColor),
            const SizedBox(width: 4),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'toggle') handleToggle();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(children: [
                      Icon(effectiveVisible ? Icons.visibility_off : Icons.visibility, size: 18),
                      const SizedBox(width: 8),
                      Text(effectiveVisible ? '감추기' : '보이기'),
                    ]),
                  ),
                ],
                child: Icon(Icons.more_vert, color: Colors.grey.shade600, size: 20),
              ),
            ),
            SizedBox(width: 16 + hPad),
          ],
        ),
      ),
    );
  }

  Widget _buildFilteredSliverContent(BuildContext context, AppStateProvider appState, String filterType, {String? littenId}) {
    final IconData headerIcon;
    final String headerTitle;
    switch (filterType) {
      case 'text':
        headerIcon = Icons.notes;
        headerTitle = '텍스트 파일';
        break;
      case 'handwriting':
        headerIcon = Icons.draw;
        headerTitle = '필기 파일';
        break;
      case 'audio':
        headerIcon = Icons.mic;
        headerTitle = '녹음 파일';
        break;
      default:
        headerIcon = Icons.folder;
        headerTitle = '파일';
    }

    final filterKey = 'filter-$filterType-${appState.littens.length}-${littenId ?? ''}-${appState.totalTextCount}-${appState.totalHandwritingCount}-${appState.totalAudioCount}';
    _refreshFilesFutureIfNeeded(appState, filterKey);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _filesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final allFiles = snapshot.data ?? [];

        // 타입 필터 + 선택된 일정 필터
        final filteredFiles = allFiles
            .where((f) => f['type'] == filterType && (littenId == null || f['littenId'] == littenId))
            .toList();

        filteredFiles.sort((a, b) {
          final fileA = a['file'];
          final fileB = b['file'];
          DateTime timeA;
          DateTime timeB;
          if (fileA is AudioFile) timeA = a['createdAt'] as DateTime;
          else if (fileA is TextFile) timeA = fileA.updatedAt;
          else if (fileA is HandwritingFile) timeA = fileA.updatedAt;
          else timeA = DateTime.now();
          if (fileB is AudioFile) timeB = b['createdAt'] as DateTime;
          else if (fileB is TextFile) timeB = fileB.updatedAt;
          else if (fileB is HandwritingFile) timeB = fileB.updatedAt;
          else timeB = DateTime.now();
          return timeB.compareTo(timeA);
        });

        if (filteredFiles.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: headerIcon,
              title: '$headerTitle이 없습니다',
              description: '파일을 추가해보세요',
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index == 0) {
                // 헤더
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(headerIcon, size: 16, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        '$headerTitle (${filteredFiles.length}개)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return _buildFileItem(context, appState, filteredFiles[index - 1]);
            },
            childCount: filteredFiles.length + 1, // +1 for header
          ),
        );
      },
    );
  }

  Widget _buildSliverContent(
    BuildContext context,
    AppStateProvider appState,
    AppLocalizations? l10n,
    List<dynamic> selectedDateNotifications, {
    String? littenId,
  }) {
    final bool hasSelectedDate = !widget.ignoreSelectedDate && appState.isDateSelected;
    final int notificationCount = (littenId != null || widget.ignoreSelectedDate) ? 0 : selectedDateNotifications.length;

    final contentKey = '$hasSelectedDate-$notificationCount-${appState.littens.length}-${littenId ?? ''}-${appState.totalTextCount}-${appState.totalHandwritingCount}-${appState.totalAudioCount}';
    _refreshFilesFutureIfNeeded(appState, contentKey);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _filesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final allFiles = snapshot.data ?? [];

        List<Litten> displayLittens;
        if (littenId != null) {
          // 선택된 일정만 표시
          displayLittens = appState.littens.where((l) => l.id == littenId).toList();
        } else if (hasSelectedDate) {
          displayLittens = appState.littensForSelectedDate.toList();
        } else {
          displayLittens = appState.littens.toList();
        }

        final List<Map<String, dynamic>> littenGroups = [];
        for (final litten in displayLittens) {
          final isUndefined = litten.title == 'undefined';
          final currentLittenId = litten.id;
          List<Map<String, dynamic>> littenFiles = [];

          // undefined 일정은 전체 파일, 그 외는 해당 리튼 파일만
          final targetFiles = isUndefined ? allFiles : allFiles.where((f) => f['littenId'] == currentLittenId).toList();

          for (final fileData in targetFiles) {
            final file = fileData['file'];
            final createdAt = fileData['createdAt'] as DateTime;
            DateTime updatedAt;
            if (file is AudioFile) {
              updatedAt = createdAt;
            } else if (file is TextFile) {
              updatedAt = file.updatedAt;
            } else if (file is HandwritingFile) {
              updatedAt = file.updatedAt;
            } else {
              updatedAt = DateTime.now();
            }
            littenFiles.add({'fileData': fileData, 'updatedAt': updatedAt, 'createdAt': createdAt});
          }

          // undefined는 생성 순서(최신순), 그 외는 수정 순서
          littenFiles.sort((a, b) {
            if (isUndefined) {
              return (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime);
            }
            int updatedCompare = (b['updatedAt'] as DateTime).compareTo(a['updatedAt'] as DateTime);
            if (updatedCompare != 0) return updatedCompare;
            return (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime);
          });

          final hasSchedule = litten.schedule != null;
          final hasActiveNotifications = hasSchedule && litten.schedule!.notificationRules.any((r) => r.isEnabled);

          final now = nowForLanguage(appState.locale.languageCode);

          // 일정 원본 시작 DateTime
          DateTime? scheduleDateTime;
          if (hasSchedule) {
            scheduleDateTime = DateTime(
              litten.schedule!.date.year,
              litten.schedule!.date.month,
              litten.schedule!.date.day,
              litten.schedule!.startTime.hour,
              litten.schedule!.startTime.minute,
            );
          }

          // 다음 발생 시각(주간 반복 반영). 더 이상 발생하지 않으면 null
          final nextOccurrence =
              hasSchedule ? _nextScheduleOccurrence(litten.schedule!, now) : null;

          // 상단(1): 앞으로 발생할 일정(반복 포함) → 다음 발생 시각 빠른 순
          // 중단(2): 더 이상 발생하지 않는 지난 일정 → 최신 상위
          // 하단(3): 일정 없음 → 생성시간 최신 상위
          int sortPriority;
          DateTime sortTime;

          if (nextOccurrence != null) {
            sortPriority = 1;
            sortTime = nextOccurrence;
          } else if (scheduleDateTime != null) {
            sortPriority = 2;
            sortTime = scheduleDateTime;
          } else {
            sortPriority = 3;
            sortTime = litten.createdAt;
          }

          littenGroups.add({
            'type': 'litten-group',
            'litten': litten,
            'files': littenFiles,
            'sortPriority': sortPriority,
            'sortTime': sortTime,
            'hasNotifications': hasActiveNotifications,
          });
        }

        // 셀(공유) 일정도 같은 정렬 규칙에 태운다.
        // 리튼과 함께 '다음 발생 시각' 순으로 섞이도록 정렬 직전에 합류시킨다.
        // (미분류 리튼은 아래에서 맨 위로 고정되므로 셀 일정은 자연히 그 아래에 온다)
        final listVisibleNow = widget.listVisible ?? _littenListVisible;
        final nowForRoom = nowForLanguage(appState.locale.languageCode);
        if (listVisibleNow && littenId == null) {
          for (final rs in _roomScheduleRows(appState, hasSelectedDate)) {
            final d = DateTime.tryParse(rs['date']?.toString() ?? '');
            if (d == null) continue;
            final st = (rs['startTime']?.toString() ?? '00:00').split(':');
            // 반복 일정은 다음 발생 시각으로 정렬·표시한다(알약과 같은 규칙).
            final sc = schedule_utils.roomScheduleToLittenSchedule(rs);
            final next = sc != null
                ? schedule_utils.nextScheduleOccurrence(sc, nowForRoom)
                : null;
            final when = next ??
                DateTime(
                    d.year,
                    d.month,
                    d.day,
                    int.tryParse(st.isNotEmpty ? st[0] : '0') ?? 0,
                    int.tryParse(st.length > 1 ? st[1] : '0') ?? 0);
            littenGroups.add({
              'type': 'room-schedule',
              'room': rs,
              'when': when,
              // 아직 안 지난 일정은 리튼의 예정 일정과 같은 1순위로 시간순 배치
              'sortPriority': when.isAfter(nowForRoom) ? 1 : 2,
              'sortTime': when,
            });
          }
        }

        // 우선순위 오름차순, 상단(1)은 빠른 시간 상위(오름차순), 중단·하단은 최신 상위(내림차순)
        littenGroups.sort((a, b) {
          int priorityCompare = (a['sortPriority'] as int).compareTo(b['sortPriority'] as int);
          if (priorityCompare != 0) return priorityCompare;
          if ((a['sortPriority'] as int) == 1) {
            return (a['sortTime'] as DateTime).compareTo(b['sortTime'] as DateTime);
          }
          return (b['sortTime'] as DateTime).compareTo(a['sortTime'] as DateTime);
        });

        // undefined 일정을 항상 최상위로
        final undefinedIdx = littenGroups.indexWhere((g) =>
            g['type'] != 'room-schedule' &&
            (g['litten'] as Litten).title == 'undefined');
        if (undefinedIdx > 0) {
          final undefinedGroup = littenGroups.removeAt(undefinedIdx);
          littenGroups.insert(0, undefinedGroup);
        }

        if (littenGroups.isEmpty && notificationCount == 0) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.event_note,
              title: '일정과 파일이 없습니다',
              description: '일정을 생성하거나 파일을 추가해보세요',
            ),
          );
        }

        final showNotificationSection = notificationCount > 0 && appState.isDateSelected;
        final isListVisible = widget.listVisible ?? _littenListVisible;
        final effectiveLittenGroups = isListVisible ? littenGroups : <Map<String, dynamic>>[];

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (showNotificationSection && index == 0) {
                return _buildNotificationSection(appState, selectedDateNotifications);
              }
              final itemIndex = showNotificationSection ? index - 1 : index;
              if (itemIndex < 0 || itemIndex >= effectiveLittenGroups.length) {
                return const SizedBox.shrink();
              }
              final group = effectiveLittenGroups[itemIndex];

              // 셀(공유) 일정 행 — 리튼과 같은 목록에 시간순으로 섞여 있다.
              if (group['type'] == 'room-schedule') {
                return _buildRoomScheduleTile(
                    context,
                    group['room'] as Map<String, dynamic>,
                    group['when'] as DateTime);
              }

              return _buildLittenGroup(
                context,
                appState,
                group['litten'] as Litten,
                group['files'] as List<Map<String, dynamic>>,
                group['hasNotifications'] as bool,
              );
            },
            childCount: (showNotificationSection ? 1 : 0) + effectiveLittenGroups.length,
          ),
        );
      },
    );
  }

  /// 목록에 끼워 넣을 셀 일정 행.
  /// 날짜 선택 상태면 그 날짜에 걸린 일정만, 아니면 아직 지나지 않은 일정을 시간순으로.
  List<Map<String, dynamic>> _roomScheduleRows(
      AppStateProvider appState, bool hasSelectedDate) {
    final rows = <Map<String, dynamic>>[];
    final now = DateTime.now();
    final sel = appState.selectedDate;
    final target = DateTime(sel.year, sel.month, sel.day);

    for (final rs in appState.roomSchedules) {
      // 내가 공유한 내 일정은 리튼 행이 이미 있으므로 중복 제외
      if (schedule_utils.roomScheduleDuplicatesMine(rs, appState.littens)) continue;
      final start = DateTime.tryParse(rs['date']?.toString() ?? '');
      if (start == null) continue;
      final startDay = DateTime(start.year, start.month, start.day);
      final endStr = rs['endDate']?.toString();
      final end = (endStr != null && endStr.isNotEmpty) ? DateTime.tryParse(endStr) : null;
      final endDay = end != null ? DateTime(end.year, end.month, end.day) : startDay;

      if (hasSelectedDate) {
        if (target.isBefore(startDay) || target.isAfter(endDay)) continue;
      } else {
        if (endDay.isBefore(DateTime(now.year, now.month, now.day))) continue;
      }
      rows.add(rs);
    }
    rows.sort((a, b) => '${a['date']}${a['startTime']}'
        .compareTo('${b['date']}${b['startTime']}'));
    return rows;
  }

  /// 일정의 다음 발생 시각(주간 반복 반영). 공용 유틸에 위임.
  /// (칩 바[home_screen]와 동일 규칙 유지를 위해 schedule_utils 한 곳에서 관리)
  DateTime? _nextScheduleOccurrence(LittenSchedule s, DateTime now) =>
      schedule_utils.nextScheduleOccurrence(s, now);

  /// 일정 시작 시각까지 남은 기간/시간 라벨. 공용 유틸에 위임.
  String? _remainingLabel(DateTime start, DateTime now) =>
      schedule_utils.remainingLabel(start, now);

  /// 셀 공유 일정 타일 — 개인 일정과 구분되도록 육각형 아이콘과 셀 이름을 함께 보여준다.
  /// 리튼에 연결되지 않으므로 탭해도 리튼을 선택하지 않는다.
  Widget _buildRoomScheduleTile(
      BuildContext context, Map<String, dynamic> rs, DateTime startDateTime) {
    final isPast = startDateTime.isBefore(DateTime.now());
    final fg = isPast ? Colors.grey.shade600 : Colors.black87;
    final sub = isPast ? Colors.grey.shade500 : Colors.grey.shade700;
    // 일정을 만들 때 고른 색 — 멤버 전원이 같은 색으로 본다.
    final scheduleColor =
        AppColors.scheduleColor((rs['colorIndex'] as num?)?.toInt());

    final start = DateFormat('HH:mm').format(startDateTime);
    final end = (rs['endTime']?.toString() ?? '');
    final timeRange = end.isEmpty ? start : '$start - ${end.substring(0, end.length >= 5 ? 5 : end.length)}';
    final roomName = rs['roomName']?.toString() ?? '';
    final creator = rs['creatorName']?.toString() ?? '';
    final notes = rs['notes']?.toString() ?? '';

    return ListTile(
      // 탭하면 수정 창(캘린더 일정 등록 창과 같은 SchedulePicker)이 열린다.
      // 권한(작성자/방장)은 서버가 검증하고, 저장하면 멤버 전원에게 반영된다.
      onTap: () => showEditRoomScheduleDialog(context, roomSchedule: rs),
      leading: Icon(Icons.hexagon, color: scheduleColor, size: 24),
      title: Text(rs['title']?.toString() ?? '',
          style: TextStyle(fontWeight: FontWeight.w600, color: fg)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            roomName.isEmpty ? timeRange : '$roomName · $timeRange',
            style: TextStyle(fontSize: 12, color: sub),
          ),
          if (notes.isNotEmpty)
            Text(notes,
                style: TextStyle(fontSize: 12, color: sub),
                maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
      trailing: creator.isEmpty
          ? null
          : Text(creator,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      dense: true,
    );
  }

  Widget _buildNotificationSection(AppStateProvider appState, List<dynamic> selectedDateNotifications) {
    final selectedDate = appState.selectedDate;
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month, color: Theme.of(context).primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${DateFormat('M월 d일 (E)', 'ko').format(selectedDate)} 일정',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blue.shade700, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    '${selectedDateNotifications.length}개',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: selectedDateNotifications.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.blue.shade100),
            itemBuilder: (context, index) {
              final item = selectedDateNotifications[index];
              // 셀(스터디룸) 공유 일정 — 리튼에 종속되지 않아 별도 타일로 그린다.
              if (item['roomSchedule'] != null) {
                return _buildRoomScheduleTile(
                    context,
                    Map<String, dynamic>.from(item['roomSchedule'] as Map),
                    item['startDateTime'] as DateTime);
              }
              final litten = item['litten'] as Litten;
              final schedule = item['schedule'] as LittenSchedule;
              final startDateTime = item['startDateTime'] as DateTime;
              final isPast = startDateTime.isBefore(DateTime.now());
              final timeRange = '${DateFormat('HH:mm').format(startDateTime)} - '
                  '${schedule.endTime.hour.toString().padLeft(2, '0')}:${schedule.endTime.minute.toString().padLeft(2, '0')}';

              final isSelected = appState.selectedLitten?.id == litten.id;

              final itemFg = isSelected ? Colors.white : (isPast ? Colors.grey.shade600 : Colors.black87);
              final itemSub = isSelected ? Colors.white70 : (isPast ? Colors.grey.shade500 : Colors.grey.shade700);
              return Container(
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).primaryColor : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.event_available,
                    color: isSelected ? Colors.white : Theme.of(context).primaryColor,
                    size: 24,
                  ),
                title: Text(litten.title, style: TextStyle(fontWeight: FontWeight.w600, color: itemFg)),
                subtitle: Builder(builder: (context) {
                  // 제목과 일시 사이에 남은 기간/시간 표시 (캘린더 힌트 칩과 동일 규칙). 지난 일정은 미표시.
                  final remainLabel = isPast ? null : _remainingLabel(startDateTime, DateTime.now());
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (remainLabel != null)
                        Text(
                          remainLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Theme.of(context).primaryColor,
                          ),
                        ),
                      Text(timeRange, style: TextStyle(fontSize: 12, color: itemSub)),
                      if (schedule.notes != null && schedule.notes!.isNotEmpty)
                        Text(schedule.notes!, style: TextStyle(fontSize: 11, color: itemSub), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  );
                }),
                  trailing: Icon(Icons.arrow_forward_ios, size: 14, color: isSelected ? Colors.white54 : Colors.blue.shade300),
                  // 탭하면 이 일정의 수정 창을 연다(셀 일정 타일과 동일 동선).
                  onTap: () {
                    if (appState.isSTTActive) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('음성 인식 중에는 일정을 수정할 수 없습니다. 먼저 음성 인식을 중지해주세요.'), backgroundColor: Colors.orange, duration: Duration(seconds: 2)));
                      return;
                    }
                    _showEditLittenDialog(litten.id);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLittenGroup(BuildContext context, AppStateProvider appState, Litten litten, List<Map<String, dynamic>> files, bool hasNotifications) {
    final themeColor = Theme.of(context).primaryColor;
    final isCollapsed = _collapsedLittenIds.contains(litten.id);
    final isUndefinedLitten = litten.title == 'undefined';
    // undefined 일정은 전체 합계, 그 외는 해당 리튼 파일 수
    final audioCount = isUndefinedLitten ? appState.totalAudioCount : files.where((f) => (f['fileData'] as Map)['type'] == 'audio').length;
    final textCount = isUndefinedLitten ? appState.totalTextCount : files.where((f) => (f['fileData'] as Map)['type'] == 'text').length;
    final handwritingCount = isUndefinedLitten ? appState.totalHandwritingCount : files.where((f) => (f['fileData'] as Map)['type'] == 'handwriting').length;
    final hasSchedule = litten.schedule != null;
    final hasEnabledNotification = hasSchedule && litten.schedule!.notificationRules.any((r) => r.isEnabled);

    // 다음 발생 시각까지 남은 기간/시간 라벨 (반복 일정 반영). undefined/일정없음/지난 일정은 미표시.
    String? remainLabel;
    if (!isUndefinedLitten && hasSchedule) {
      final now = nowForLanguage(appState.locale.languageCode);
      final nextOcc = _nextScheduleOccurrence(litten.schedule!, now);
      if (nextOcc != null) remainLabel = _remainingLabel(nextOcc, now);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () async {
            try {
              final storage = NotificationStorageService();
              final allNotifications = await storage.loadNotifications();
              final littenNotifications = allNotifications.where((n) => n.littenId == litten.id && !n.isAcknowledged).toList();
              if (littenNotifications.isNotEmpty) {
                final updated = allNotifications.map((n) => (n.littenId == litten.id && !n.isAcknowledged) ? n.markAsAcknowledged() : n).toList();
                await storage.saveNotifications(updated);
                for (final notification in littenNotifications) {
                  final fired = appState.notificationService.firedNotifications
                      .where((f) => f.littenId == notification.littenId && f.triggerTime.isAtSameMomentAs(notification.triggerTime))
                      .firstOrNull;
                  if (fired != null) await appState.notificationService.dismissNotification(fired);
                }
                if (mounted) setState(() {});
              } else if (litten.schedule != null && litten.schedule!.notificationRules.any((r) => r.isEnabled)) {
                // 저장된 알림 없지만 활성 규칙 있음 → 수동 해제로 표시
                final prefs = await SharedPreferences.getInstance();
                final dismissed = prefs.getStringList('badge_dismissed_litten_ids')?.toSet() ?? {};
                dismissed.add(litten.id);
                await prefs.setStringList('badge_dismissed_litten_ids', dismissed.toList());
                appState.notificationService.notifyBadgeChange();
              }
            } catch (e) {
              debugPrint('❌ 리튼 알림 확인 처리 실패: $e');
            }
            try {
              if (appState.isSTTActive) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('음성 인식 중에는 리튼을 변경할 수 없습니다.'), backgroundColor: Colors.orange, duration: Duration(seconds: 2)));
                return;
              }
              // 캘린더: 선택을 undefined로 고정 (다른 일정으로 바뀌지 않게)
              final undefinedTarget = appState.littens.where((l) => l.title == 'undefined').firstOrNull ?? litten;
              await appState.selectLitten(undefinedTarget);
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.orange, duration: const Duration(seconds: 3)));
            }
          },
          onLongPress: isUndefinedLitten ? null : () => _showEditLittenDialog(litten.id),
          child: Builder(builder: (context) {
            // 캘린더: undefined 일정을 항상 선택 상태로 강조, 다른 리튼은 강조하지 않음
            final isSelected = isUndefinedLitten;
            // undefined 선택 시 통계바 스타일(연한 배경 + 일반 색상), 일반 선택은 primary 배경 + 흰색
            final isUndefinedSelected = isUndefinedLitten && isSelected;
            final bgColor = isSelected
                ? (isUndefinedLitten ? themeColor.withValues(alpha: 0.1) : themeColor)
                : Colors.grey.shade50;
            final fgColor = isUndefinedSelected ? themeColor : (isSelected ? Colors.white : themeColor);
            final badgeColor = fgColor;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          isUndefinedLitten
                              ? Icons.event_available
                              : (hasEnabledNotification ? Icons.event_available : Icons.calendar_today),
                          color: fgColor,
                          size: 20,
                        ),
                        if (isUndefinedLitten) ...[
                          const SizedBox(width: 4),
                          Text(
                            '${appState.littens.where((l) => l.title != 'undefined').length}',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fgColor),
                          ),
                        ],
                        const SizedBox(width: 8),
                        // 남은 기간/시간은 행 우측 고정 위치로 이동(아래 참고). 여기는 제목만 표시.
                        Expanded(
                          child: Text(
                            isUndefinedLitten ? '' : litten.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: isSelected && !isUndefinedLitten ? Colors.white : (isUndefinedLitten ? Colors.grey.shade600 : null),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // undefined: 파일 카운트 미표시(전체 일정 카운트만). 그 외: 카운트>0인 파일 유형만 표시
                  if (!isUndefinedLitten) ...[
                    if (textCount > 0) ...[
                      _buildFileCountBadge(Icons.notes, textCount, badgeColor),
                      const SizedBox(width: 4),
                    ],
                    if (handwritingCount > 0) ...[
                      _buildFileCountBadge(Icons.draw, handwritingCount, badgeColor),
                      const SizedBox(width: 4),
                    ],
                    if (audioCount > 0) ...[
                      _buildFileCountBadge(Icons.mic, audioCount, badgeColor),
                      const SizedBox(width: 4),
                    ],
                  ],
                  // 남은 기간/시간: 행 우측 고정 위치(고정 너비 + 우측 정렬).
                  // 파일 뱃지 개수와 무관하게 메뉴 버튼 바로 왼쪽에 일정하게 표시된다.
                  if (remainLabel != null) ...[
                    SizedBox(
                      width: 70,
                      child: Text(
                        remainLabel,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') _showEditLittenDialog(litten.id);
                      else if (value == 'delete') _showDeleteDialog(litten.id, litten.title);
                      else if (value == 'toggle_collapse') _toggleLittenCollapse(litten.id);
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'toggle_collapse',
                        child: Row(children: [Icon(isCollapsed ? Icons.visibility : Icons.visibility_off, size: 18), const SizedBox(width: 8), Text(isCollapsed ? '보이기' : '숨기기')]),
                      ),
                      if (!isUndefinedLitten) ...[
                        const PopupMenuItem(value: 'edit', child: Text('수정')),
                        const PopupMenuItem(value: 'delete', child: Text('삭제')),
                      ],
                    ],
                    child: Icon(Icons.more_vert, color: isSelected && !isUndefinedLitten ? Colors.white70 : Colors.grey.shade600, size: 20),
                  ),
                ],
              ),
            );
          }),
        ),
        if (!isCollapsed)
          ...files.map((fileInfo) => _buildFileItem(context, appState, fileInfo['fileData'] as Map<String, dynamic>)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildFileCountBadge(IconData icon, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildFileItem(BuildContext context, AppStateProvider appState, Map<String, dynamic> fileData) {
    final fileType = fileData['type'] as String;
    final createdAt = fileData['createdAt'] as DateTime;
    final themeColor = Theme.of(context).primaryColor;

    IconData icon;
    String title;
    DateTime displayTime;

    if (fileType == 'audio') {
      final audioFile = fileData['file'] as AudioFile;
      icon = Icons.mic;
      title = audioFile.displayName;
      displayTime = createdAt;
    } else if (fileType == 'text') {
      final textFile = fileData['file'] as TextFile;
      icon = Icons.notes;
      title = textFile.displayTitle;
      displayTime = textFile.updatedAt;
    } else {
      final handwritingFile = fileData['file'] as HandwritingFile;
      icon = handwritingFile.type == HandwritingType.pdfConvert ? Icons.picture_as_pdf : Icons.draw;
      title = handwritingFile.displayTitle;
      displayTime = handwritingFile.updatedAt;
    }

    final littenId = fileData['littenId'] as String;
    final litten = appState.littens.firstWhere((l) => l.id == littenId,
        orElse: () => appState.littens.first);
    final littenTitle = litten.title == 'undefined' ? '' : litten.title;

    return InkWell(
      onTap: () async {
        try {
          if (appState.isSTTActive) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('음성 인식 중에는 리튼을 변경할 수 없습니다. 먼저 음성 인식을 중지해주세요.'), backgroundColor: Colors.orange, duration: Duration(seconds: 2)));
            return;
          }
          await appState.selectLitten(litten);
          final targetTab = fileType == 'audio' ? 'audio' : fileType == 'text' ? 'text' : 'handwriting';
          appState.setCurrentWritingTab(targetTab);
          appState.setTargetWritingTab(targetTab);
          await Future.delayed(const Duration(milliseconds: 100));
          appState.changeTab(1);
        } catch (e) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.orange, duration: const Duration(seconds: 3)));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.5))),
        child: Row(
          children: [
            // 일정명
            SizedBox(
              width: 80,
              child: Text(
                littenTitle,
                style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            // 파일명
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            // 생성일시
            Text(
              DateFormat('MM/dd HH:mm').format(createdAt),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

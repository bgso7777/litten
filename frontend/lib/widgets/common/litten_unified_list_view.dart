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
import '../../services/app_state_provider.dart';
import '../../services/notification_storage_service.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/dialogs/edit_litten_dialog.dart';

class LittenUnifiedListView extends StatefulWidget {
  final ScrollController? scrollController;
  final EdgeInsets? padding;
  final String? filterType; // 'text', 'handwriting', 'audio' — null이면 전체 표시
  final String? littenId;   // 설정 시 해당 일정의 파일만 표시
  final bool? listVisible;  // 외부에서 리스트 표시 여부를 제어할 때 사용
  final VoidCallback? onListToggle; // 외부 토글 콜백
  final bool ignoreSelectedDate; // true면 캘린더 날짜 선택을 무시하고 전체 일정 표시

  const LittenUnifiedListView({super.key, this.scrollController, this.padding, this.filterType, this.littenId, this.listVisible, this.onListToggle, this.ignoreSelectedDate = false});

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
                  scaffoldMessenger.showSnackBar(SnackBar(content: Text('$title 일정이 삭제되었습니다.')));
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

        final showStats = widget.filterType == null && widget.littenId == null;

        return CustomScrollView(
          key: widget.key != null ? null : PageStorageKey<String>('litten_unified_list_${widget.filterType ?? 'all'}_${widget.littenId ?? 'all'}'),
          controller: widget.scrollController,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            if (showStats)
              SliverToBoxAdapter(child: _buildStatsSection(context, appState)),
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
    final hPad = widget.padding?.left ?? 0;
    final effectiveVisible = widget.listVisible ?? _littenListVisible;

    void handleToggle() {
      if (widget.onListToggle != null) {
        widget.onListToggle!();
      } else {
        setState(() => _littenListVisible = !_littenListVisible);
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
            Expanded(
              child: appState.selectedLitten != null && appState.selectedLitten!.title != 'undefined'
                  ? Text(
                      appState.selectedLitten!.title,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: themeColor),
                      overflow: TextOverflow.ellipsis,
                    )
                  : const SizedBox.shrink(),
            ),
            _buildFileCountBadge(Icons.keyboard, textCount, themeColor),
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
        headerIcon = Icons.keyboard;
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

    final filterKey = 'filter-$filterType-${appState.littens.length}-${littenId ?? ''}';
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

    final contentKey = '$hasSelectedDate-$notificationCount-${appState.littens.length}-${littenId ?? ''}';
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

          for (final fileData in allFiles) {
            if (fileData['littenId'] == currentLittenId) {
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
          }

          littenFiles.sort((a, b) {
            int updatedCompare = (b['updatedAt'] as DateTime).compareTo(a['updatedAt'] as DateTime);
            if (updatedCompare != 0) return updatedCompare;
            return (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime);
          });

          final hasSchedule = litten.schedule != null;
          final hasActiveNotifications = hasSchedule && litten.schedule!.notificationRules.any((r) => r.isEnabled);

          // 일정 시작 DateTime 계산
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

          final now = nowForLanguage(appState.locale.languageCode);
          final isUpcoming = scheduleDateTime != null && scheduleDateTime.isAfter(now);
          final isPast = scheduleDateTime != null && !scheduleDateTime.isAfter(now);

          // 상단(1): 시작 안 한 일정 (알림 유무 무관) → 빠른 시간 상위
          // 중단(2): 시작시간이 지난 일정 → 최신 상위
          // 하단(3): 일정 없음 → 생성시간 최신 상위
          int sortPriority;
          DateTime sortTime;

          if (isUpcoming) {
            sortPriority = 1;
            sortTime = scheduleDateTime!;
          } else if (isPast) {
            sortPriority = 2;
            sortTime = scheduleDateTime!;
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

        // 우선순위 오름차순, 상단(1)은 빠른 시간 상위(오름차순), 중단·하단은 최신 상위(내림차순)
        littenGroups.sort((a, b) {
          int priorityCompare = (a['sortPriority'] as int).compareTo(b['sortPriority'] as int);
          if (priorityCompare != 0) return priorityCompare;
          if ((a['sortPriority'] as int) == 1) {
            return (a['sortTime'] as DateTime).compareTo(b['sortTime'] as DateTime);
          }
          return (b['sortTime'] as DateTime).compareTo(a['sortTime'] as DateTime);
        });

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
              if (itemIndex < 0 || itemIndex >= effectiveLittenGroups.length) return const SizedBox.shrink();
              final group = effectiveLittenGroups[itemIndex];
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
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(timeRange, style: TextStyle(fontSize: 12, color: itemSub)),
                    if (schedule.notes != null && schedule.notes!.isNotEmpty)
                      Text(schedule.notes!, style: TextStyle(fontSize: 11, color: itemSub), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
                  trailing: Icon(Icons.arrow_forward_ios, size: 14, color: isSelected ? Colors.white54 : Colors.blue.shade300),
                  onTap: () async {
                    try {
                      if (appState.isSTTActive) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('음성 인식 중에는 리튼을 변경할 수 없습니다. 먼저 음성 인식을 중지해주세요.'), backgroundColor: Colors.orange, duration: Duration(seconds: 2)));
                        return;
                      }
                      await appState.selectLitten(litten);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.orange));
                    }
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
    final audioCount = files.where((f) => (f['fileData'] as Map)['type'] == 'audio').length;
    final textCount = files.where((f) => (f['fileData'] as Map)['type'] == 'text').length;
    final handwritingCount = files.where((f) => (f['fileData'] as Map)['type'] == 'handwriting').length;
    final hasSchedule = litten.schedule != null;
    final hasEnabledNotification = hasSchedule && litten.schedule!.notificationRules.any((r) => r.isEnabled);

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
              }
            } catch (e) {
              debugPrint('❌ 리튼 알림 확인 처리 실패: $e');
            }
            try {
              if (appState.isSTTActive) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('음성 인식 중에는 리튼을 변경할 수 없습니다.'), backgroundColor: Colors.orange, duration: Duration(seconds: 2)));
                return;
              }
              await appState.selectLitten(litten);
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.orange, duration: const Duration(seconds: 3)));
            }
          },
          onLongPress: () => _showEditLittenDialog(litten.id),
          child: Builder(builder: (context) {
            final isSelected = appState.selectedLitten?.id == litten.id;
            final fgColor = isSelected ? Colors.white : themeColor;
            final badgeColor = isSelected ? Colors.white : themeColor;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? themeColor : Colors.grey.shade50,
                border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          litten.title == 'undefined'
                              ? Icons.folder_open
                              : (hasEnabledNotification ? Icons.event_available : Icons.calendar_today),
                          color: fgColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            litten.title == 'undefined' ? '' : litten.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: isSelected ? Colors.white : (litten.title == 'undefined' ? Colors.grey.shade600 : null),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildFileCountBadge(Icons.keyboard, textCount, badgeColor),
                  const SizedBox(width: 4),
                  _buildFileCountBadge(Icons.draw, handwritingCount, badgeColor),
                  const SizedBox(width: 4),
                  _buildFileCountBadge(Icons.mic, audioCount, badgeColor),
                  const SizedBox(width: 4),
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
                      if (litten.title != 'undefined') ...[
                        const PopupMenuItem(value: 'edit', child: Text('수정')),
                        const PopupMenuItem(value: 'delete', child: Text('삭제')),
                      ],
                    ],
                    child: Icon(Icons.more_vert, color: isSelected ? Colors.white70 : Colors.grey.shade600, size: 20),
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
      icon = Icons.keyboard;
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';

import '../services/app_state_provider.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/home/litten_item.dart';
import '../config/themes.dart';
import '../utils/responsive_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _titleController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _titleController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // 화면 로드 후 최신 리튼으로 스크롤
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showCreateLittenDialog() {
    final l10n = AppLocalizations.of(context);
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    
    if (!appState.canCreateMoreLittens) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.freeUserLimitMessage ?? '무료 사용자는 최대 5개의 리튼만 생성할 수 있습니다. 업그레이드하여 무제한으로 생성하세요!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    _titleController.clear();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.createLitten ?? '리튼 생성'),
        content: TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: l10n?.title ?? '제목',
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.cancel ?? '취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = _titleController.text.trim();
              if (title.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n?.pleaseEnterTitle ?? '제목을 입력해주세요.')),
                );
                return;
              }
              
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              
              try {
                await appState.createLitten(title);
                if (mounted) {
                  navigator.pop();
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('$title 리튼이 생성되었습니다.')),
                  );
                  // 새로 생성된 리튼(최신)으로 스크롤
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });
                }
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('${l10n?.error ?? '오류'}: $e')),
                  );
                }
              }
            },
            child: Text(l10n?.create ?? '생성'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return Scaffold(
          appBar: null,
          body: Column(
            children: [
              // 상단 50% - 캘린더
              Expanded(
                flex: 1,
                child: _buildCalendarSection(appState, l10n),
              ),
              // 하단 50% - 리튼 리스트
              Expanded(
                flex: 1,
                child: _buildLittenListSection(appState, l10n),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _showCreateLittenDialog,
            tooltip: l10n?.createLitten ?? '리튼 생성',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _showRenameLittenDialog(String littenId, String currentTitle) {
    final l10n = AppLocalizations.of(context);
    final TextEditingController renameController = TextEditingController(text: currentTitle);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.renameLitten ?? '리튼 이름 변경'),
        content: TextField(
          controller: renameController,
          decoration: InputDecoration(
            labelText: l10n?.newName ?? '새 이름',
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (_) => _performRename(littenId, renameController.text.trim(), renameController, context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.cancel ?? '취소'),
          ),
          ElevatedButton(
            onPressed: () => _performRename(littenId, renameController.text.trim(), renameController, context),
            child: Text(l10n?.change ?? '변경'),
          ),
        ],
      ),
    ).then((_) {
      renameController.dispose();
    });
  }

  void _performRename(String littenId, String newTitle, TextEditingController controller, BuildContext dialogContext) async {
    final l10n = AppLocalizations.of(context);
    if (newTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.pleaseEnterTitle ?? '제목을 입력해주세요.')),
      );
      return;
    }
    
    if (newTitle == controller.text) {
      Navigator.of(dialogContext).pop();
      return;
    }
    
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final navigator = Navigator.of(dialogContext);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      await appState.renameLitten(littenId, newTitle);
      navigator.pop();
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('리튼 이름이 \'$newTitle\'로 변경되었습니다.')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('${l10n?.error ?? '오류'}: $e')),
      );
    }
  }

  // 캘린더 섹션 빌드
  Widget _buildCalendarSection(AppStateProvider appState, AppLocalizations? l10n) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.paddingM.left,
        right: AppSpacing.paddingM.left,
        top: 0,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
      ),
      child: Column(
        children: [
          // 월 네비게이션 헤더
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  final previousMonth = DateTime(
                    appState.focusedDate.year,
                    appState.focusedDate.month - 1,
                  );
                  appState.changeFocusedDate(previousMonth);
                },
                icon: const Icon(Icons.chevron_left),
                tooltip: '이전 달',
              ),
              Text(
                DateFormat.yMMMM(appState.locale.languageCode).format(appState.focusedDate),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: () {
                  final nextMonth = DateTime(
                    appState.focusedDate.year,
                    appState.focusedDate.month + 1,
                  );
                  appState.changeFocusedDate(nextMonth);
                },
                icon: const Icon(Icons.chevron_right),
                tooltip: '다음 달',
              ),
            ],
          ),
          // 캘린더
          Expanded(
            child: TableCalendar<dynamic>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: appState.focusedDate,
              daysOfWeekHeight: ResponsiveUtils.getCalendarDaysOfWeekHeight(context),
              rowHeight: ResponsiveUtils.getCalendarRowHeight(context),
              selectedDayPredicate: (day) {
                return isSameDay(appState.selectedDate, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                appState.selectDate(selectedDay);
                appState.changeFocusedDate(focusedDay);
              },
              onPageChanged: (focusedDay) {
                appState.changeFocusedDate(focusedDay);
              },
              calendarFormat: CalendarFormat.month,
              availableCalendarFormats: const {
                CalendarFormat.month: 'Month',
              },
              headerVisible: false, // 커스텀 헤더를 사용하므로 기본 헤더 숨김
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: TextStyle(color: Colors.red[400]),
                holidayTextStyle: TextStyle(color: Colors.red[400]),
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 3,
              ),
              eventLoader: (day) {
                // 해당 날짜에 생성된 리튼이 있으면 마커 표시
                final count = appState.getLittenCountForDate(day);
                return List.generate(count > 3 ? 3 : count, (index) => 'litten');
              },
              locale: appState.locale.languageCode,
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  return DragTarget<String>(
                    onAcceptWithDetails: (details) async {
                      // 리튼을 해당 날짜로 이동
                      await appState.moveLittenToDate(details.data, day);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('리튼이 ${DateFormat('M월 d일').format(day)}로 이동되었습니다.'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    onWillAcceptWithDetails: (details) => true,
                    builder: (context, candidateData, rejectedData) {
                      final isHovered = candidateData.isNotEmpty;
                      return Container(
                        decoration: BoxDecoration(
                          color: isHovered 
                              ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
                              : null,
                          shape: BoxShape.circle,
                          border: isHovered 
                              ? Border.all(
                                  color: Theme.of(context).primaryColor, 
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: const TextStyle().copyWith(
                              color: isHovered 
                                  ? Theme.of(context).primaryColor
                                  : null,
                              fontWeight: isHovered ? FontWeight.bold : null,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                selectedBuilder: (context, day, focusedDay) {
                  return DragTarget<String>(
                    onAcceptWithDetails: (details) async {
                      await appState.moveLittenToDate(details.data, day);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('리튼이 ${DateFormat('M월 d일').format(day)}로 이동되었습니다.'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    onWillAcceptWithDetails: (details) => true,
                    builder: (context, candidateData, rejectedData) {
                      final isHovered = candidateData.isNotEmpty;
                      return Container(
                        decoration: BoxDecoration(
                          color: isHovered 
                              ? Theme.of(context).primaryColor.withValues(alpha: 0.8)
                              : Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                          border: isHovered 
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: const TextStyle().copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                todayBuilder: (context, day, focusedDay) {
                  return DragTarget<String>(
                    onAcceptWithDetails: (details) async {
                      await appState.moveLittenToDate(details.data, day);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('리튼이 ${DateFormat('M월 d일').format(day)}로 이동되었습니다.'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    onWillAcceptWithDetails: (details) => true,
                    builder: (context, candidateData, rejectedData) {
                      final isHovered = candidateData.isNotEmpty;
                      return Container(
                        decoration: BoxDecoration(
                          color: isHovered 
                              ? Theme.of(context).primaryColor.withValues(alpha: 0.8)
                              : Theme.of(context).primaryColor.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                          border: isHovered 
                              ? Border.all(color: Theme.of(context).primaryColor, width: 2)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: const TextStyle().copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 리튼 리스트 섹션 빌드
  Widget _buildLittenListSection(AppStateProvider appState, AppLocalizations? l10n) {
    final selectedDateLittens = appState.littensForSelectedDate;
    
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.paddingM.left,
        right: AppSpacing.paddingM.left,
        bottom: AppSpacing.paddingM.left,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 리튼 리스트
          Expanded(
            child: selectedDateLittens.isEmpty
                ? EmptyState(
                    icon: Icons.calendar_today,
                    title: '선택한 날짜에 생성된 리튼이 없습니다',
                    description: '이 날짜에 첫 번째 리튼을 생성해보세요',
                    actionText: l10n?.createLitten ?? '리튼 생성',
                    onAction: _showCreateLittenDialog,
                  )
                : Scrollbar(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        await appState.refreshLittens();
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        itemCount: selectedDateLittens.length,
                        itemBuilder: (context, index) {
                          final litten = selectedDateLittens[index];
                          return LittenItem(
                            litten: litten,
                            isSelected: appState.selectedLitten?.id == litten.id,
                            onTap: () => appState.selectLitten(litten),
                            onDelete: () => _showDeleteDialog(litten.id, litten.title),
                            onLongPress: () => _showRenameLittenDialog(litten.id, litten.title),
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(String littenId, String title) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.deleteLitten ?? '리튼 삭제'),
        content: Text(l10n?.confirmDeleteLitten != null 
            ? l10n!.confirmDeleteLitten(title)
            : '\'$title\' 리튼을 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없으며, 관련된 모든 파일이 함께 삭제됩니다.'),
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
              
              await appState.deleteLitten(littenId);
              
              if (mounted) {
                navigator.pop();
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('$title 리튼이 삭제되었습니다.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n?.delete ?? '삭제', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
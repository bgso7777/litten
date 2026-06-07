import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/litten.dart';
import '../services/app_state_provider.dart';

/// 홈 탭 — 대시보드.
/// 최근/최신 일정, 미완료 리마인드 갯수, 공유한 것/공유 받은 것(이번엔 UI 자리만).
class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  // 5탭 인덱스: 홈0 · 캘린더1 · +2 · 기억3 · 설정4
  static const int _calendarTabIndex = 1;
  static const int _memoryTabIndex = 3;

  @override
  Widget build(BuildContext context) {
    debugPrint('🏠 [HomeDashboardScreen] build');
    return Consumer<AppStateProvider>(
      builder: (context, appState, _) {
        final pendingRemind =
            appState.remindItems.where((i) => !i.isDone).length;
        final upcoming = _upcomingLittens(appState.littens);

        // 탭(DraggableTabLayout)의 content로 사용 — Scaffold/AppBar 없음
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 상단: 리마인드 + 최근 일정 ──
            // 내용 크기만큼만 차지(비-flex)하여, 남는 세로 공간은 전부 아래 공유 영역(Expanded)이
            // 가져가도록 한다. (Flexible+Expanded로 flex를 나누면 상단 빈 공간이 하단에 남아
            //  공유 카드가 메인메뉴까지 닿지 않는 문제가 있었음)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 미완료 리마인드 카드 ──
                  _SectionTitle(icon: Icons.lightbulb_outline, title: '리마인드'),
                  const SizedBox(height: 8),
                  _RemindSummaryCard(
                    pendingCount: pendingRemind,
                    onTap: () => appState.changeTabIndex(_memoryTabIndex),
                  ),
                  const SizedBox(height: 24),

                  // ── 최근/최신 일정 ──
                  _SectionTitle(icon: Icons.event_note, title: '최근 일정'),
                  const SizedBox(height: 8),
                  if (upcoming.isEmpty)
                    _EmptyHint(text: '예정된 일정이 없습니다')
                  else
                    ...upcoming.map(
                      (l) => _ScheduleTile(
                        litten: l,
                        onTap: () {
                          appState.selectLitten(l);
                          appState.changeTabIndex(_calendarTabIndex);
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── 공유 (메인메뉴 위까지 확장) ──
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _SectionTitle(icon: Icons.share, title: '공유'),
            ),
            const SizedBox(height: 8),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _ShareTabs(
                  // 공유 기능은 준비 중 — 카운트 0으로 자리만 표시
                  sharedOutCount: 0,
                  sharedInCount: 0,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 다가오는 일정 우선(오늘 이후), 없으면 최신순. 시스템 기본('undefined') 제외. 상위 5개.
  List<Litten> _upcomingLittens(List<Litten> littens) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scheduled = littens
        .where((l) => l.title != 'undefined' && l.schedule != null)
        .toList();

    final upcoming = scheduled.where((l) {
      final d = l.schedule!.endDate ?? l.schedule!.date;
      return !d.isBefore(today);
    }).toList()
      ..sort((a, b) => a.schedule!.date.compareTo(b.schedule!.date));

    if (upcoming.isNotEmpty) return upcoming.take(5).toList();

    // 다가오는 일정이 없으면 최신 수정순
    scheduled.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return scheduled.take(5).toList();
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(title,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _RemindSummaryCard extends StatelessWidget {
  final int pendingCount;
  final VoidCallback onTap;
  const _RemindSummaryCard({required this.pendingCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.notifications_active_outlined, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  pendingCount > 0
                      ? '미완료 리마인드 $pendingCount개'
                      : '미완료 리마인드가 없습니다',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              Icon(Icons.chevron_right, color: color.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  final Litten litten;
  final VoidCallback onTap;
  const _ScheduleTile({required this.litten, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    final dateStr = DateFormat('M/d').format(litten.schedule!.date);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withValues(alpha: 0.15)),
      ),
      child: ListTile(
        leading: Icon(Icons.event, color: color),
        title: Text(litten.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(dateStr),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(text,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      ),
    );
  }
}

/// 공유 섹션 — "공유한 것 / 공유 받은 것" 두 탭으로 분리한 카드.
/// 각 탭 제목은 아이콘 + 카운트 (홈 탭 제목란 패턴과 일관).
class _ShareTabs extends StatelessWidget {
  final int sharedOutCount;
  final int sharedInCount;
  const _ShareTabs({required this.sharedOutCount, required this.sharedInCount});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return DefaultTabController(
      length: 2,
      child: Card(
        elevation: 0,
        color: color.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          // 카드 외곽 테두리
          side: BorderSide(color: color.withValues(alpha: 0.35)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            TabBar(
              labelColor: color,
              unselectedLabelColor: Colors.grey.shade500,
              indicatorSize: TabBarIndicatorSize.tab,
              // 선택된 탭을 테두리 박스(토글)로 강조해 두 탭을 시각적으로 구분
              indicatorPadding: const EdgeInsets.all(4),
              indicator: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color, width: 1.4),
              ),
              // 탭바와 본문 사이 구분선
              dividerColor: color.withValues(alpha: 0.25),
              tabs: [
                Tab(
                  child: _ShareTabLabel(
                      icon: Icons.download_outlined,
                      label: '공유 받은 것',
                      count: sharedInCount),
                ),
                Tab(
                  child: _ShareTabLabel(
                      icon: Icons.upload_outlined,
                      label: '공유한 것',
                      count: sharedOutCount),
                ),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _SharePanel(label: '공유 받은 것'),
                  _SharePanel(label: '공유한 것'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 공유 탭 제목: 아이콘 + 라벨 + 카운트
class _ShareTabLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  const _ShareTabLabel(
      {required this.icon, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    // 폭이 좁은 기기에서 넘치지 않도록 자동 축소
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Text('$count', style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

/// 공유 탭 내용 (현재 준비 중)
class _SharePanel extends StatelessWidget {
  final String label;
  const _SharePanel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text('준비 중',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}

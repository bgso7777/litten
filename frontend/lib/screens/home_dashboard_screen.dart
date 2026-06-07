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
        return ListView(
            padding: const EdgeInsets.all(16),
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
              const SizedBox(height: 24),

              // ── 공유 (이번엔 UI 자리만) ──
              _SectionTitle(icon: Icons.share, title: '공유'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _SharePlaceholderCard(
                      icon: Icons.upload_outlined,
                      label: '공유한 것',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SharePlaceholderCard(
                      icon: Icons.download_outlined,
                      label: '공유 받은 것',
                    ),
                  ),
                ],
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

class _SharePlaceholderCard extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SharePlaceholderCard({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.grey.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, color: Colors.grey.shade500),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text('준비 중',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }
}

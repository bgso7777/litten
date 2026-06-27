import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/litten.dart';
import '../services/app_state_provider.dart';

/// 홈 탭 — 대시보드.
/// 최근/최신 일정, 미완료 퀴즈 갯수, 공유한 것/공유 받은 것(이번엔 UI 자리만).
class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  // 5탭 인덱스: 홈0 · 캘린더1 · +2 · 리마인드3 · 설정4
  static const int _calendarTabIndex = 1;
  static const int _remindTabIndex = 3;

  @override
  Widget build(BuildContext context) {
    debugPrint('🏠 [HomeDashboardScreen] build');
    // 공유 아이콘은 탭 제목란으로 이동. body에는 공유 본문(전체/공유받은것/공유한것)만 표시.
    // 탭(DraggableTabLayout)의 content로 사용 — Scaffold/AppBar 없음
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: _ShareSection(),
          ),
        ),
      ],
    );
  }

  /// 앞으로 도래할 일정을 "다음 발생 시각(반복 포함)" 가까운 순으로 정렬해 상위 2개.
  /// 주간 반복(매주 특정 요일) 일정은 다음 발생 요일을 계산해 사용한다.
  /// 시스템 기본('undefined') 제외. 도래할 일정이 없으면 빈 목록.
  List<({Litten litten, DateTime when})> _upcomingSchedules(
      List<Litten> littens) {
    final now = DateTime.now();
    final result = <({Litten litten, DateTime when})>[];
    for (final l in littens) {
      if (l.title == 'undefined' || l.schedule == null) continue;
      final when = _nextOccurrence(l.schedule!, now);
      // 시작 시각이 이미 지난(진행 중 포함) 일정은 제외 — 아직 도래하지 않은 일정만 표시
      if (when != null && when.isAfter(now)) result.add((litten: l, when: when));
    }
    result.sort((a, b) => a.when.compareTo(b.when));
    return result.take(2).toList();
  }

  /// 일정의 "다음 발생 시각"을 계산한다.
  /// - 매주 반복(요일 지정) 일정: 오늘부터 7일 내에서 지정 요일 중 아직 끝나지 않은 가장 가까운 발생
  /// - 비반복 일정: 기준 날짜의 종료 시각이 아직 지나지 않았으면 그 시작 시각, 지났으면 null
  static DateTime? _nextOccurrence(LittenSchedule s, DateTime now) {
    final weekdays = <int>{}; // 1=월 … 7=일 (DateTime.weekday와 동일)
    for (final r in s.notificationRules) {
      if (r.isEnabled &&
          r.frequency == NotificationFrequency.weekly &&
          r.weekdays != null) {
        weekdays.addAll(r.weekdays!);
      }
    }
    final start = s.startTime;
    final end = s.endTime;

    if (weekdays.isNotEmpty) {
      final base = DateTime(now.year, now.month, now.day);
      for (int i = 0; i <= 7; i++) {
        final day = base.add(Duration(days: i));
        if (!weekdays.contains(day.weekday)) continue;
        final endDt =
            DateTime(day.year, day.month, day.day, end.hour, end.minute);
        if (endDt.isAfter(now)) {
          return DateTime(
              day.year, day.month, day.day, start.hour, start.minute);
        }
      }
      return null;
    }

    // 비반복: 기준 날짜(종료일 우선)의 종료 시각이 지나지 않았으면 시작 시각
    final d = s.endDate ?? s.date;
    final endDt = DateTime(d.year, d.month, d.day, end.hour, end.minute);
    if (endDt.isAfter(now)) {
      return DateTime(
          s.date.year, s.date.month, s.date.day, start.hour, start.minute);
    }
    return null;
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

class _QuizSummaryCard extends StatelessWidget {
  final int pendingCount;
  final VoidCallback onTap;
  const _QuizSummaryCard({required this.pendingCount, required this.onTap});

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
          // 카드 높이 약 20% 축소 (세로 패딩 16 → 10)
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.notifications_active_outlined, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  pendingCount > 0
                      ? '미완료 퀴즈 $pendingCount개'
                      : '미완료 퀴즈가 없습니다',
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
  final DateTime when; // 다음 발생 시각(반복 포함)
  final VoidCallback onTap;
  const _ScheduleTile(
      {required this.litten, required this.when, required this.onTap});

  /// 일정 시작 시각까지 남은 기간/시간 라벨 (캘린더 힌트 칩과 동일 규칙).
  /// - 24시간 이내: 분/시간(+분), 1분 미만은 초
  /// - 24시간 이상: 일 단위
  /// 이미 지난 일정은 null.
  String? _remainingLabel(DateTime start, DateTime now) {
    final diff = start.difference(now);
    if (diff.isNegative) return null;
    final secs = diff.inSeconds;
    const oneDayInSec = 86400;
    if (secs < oneDayInSec) {
      final minutes = secs ~/ 60;
      if (minutes == 0) return '${secs % 60}초 후';
      if (minutes < 60) return '$minutes분 후';
      final hours = minutes ~/ 60;
      final remaining = minutes % 60;
      return remaining > 0 ? '$hours시간 $remaining분 후' : '$hours시간 후';
    }
    final days = secs ~/ oneDayInSec;
    return '$days일 후';
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    // 다음 발생 날짜 + 시작 시각 표시 (예: 6/14 09:05)
    final dateStr = DateFormat('M/d HH:mm').format(when);
    // 제목과 일시 사이에 표시할 남은 기간/시간
    final remainLabel = _remainingLabel(when, DateTime.now());
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withValues(alpha: 0.15)),
      ),
      child: ListTile(
        dense: true,
        // 타일 높이 약 10% 축소
        visualDensity: const VisualDensity(vertical: -1),
        leading: Icon(Icons.event, color: color),
        // 제목 + 날짜를 한 줄로 표시
        title: Row(
          children: [
            Expanded(
              child: Text(litten.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            // 제목과 일시 사이: 남은 기간/시간 (지난 일정은 미표시)
            if (remainLabel != null) ...[
              const SizedBox(width: 8),
              Text(remainLabel,
                  style: TextStyle(
                      fontSize: 12, color: color, fontWeight: FontWeight.bold)),
            ],
            const SizedBox(width: 8),
            Text(dateStr,
                style: TextStyle(
                    fontSize: 13, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
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

IconData _shareFileTypeIcon(String? t) {
  switch (t) {
    case 'text':
      return Icons.notes;
    case 'audio':
      return Icons.mic;
    case 'handwriting':
      return Icons.draw;
    default:
      return Icons.attach_file;
  }
}

String _shareWhen(dynamic v) {
  final s = v?.toString() ?? '';
  return s.length >= 16 ? s.substring(0, 16) : s;
}

/// 공유 섹션 — 받은 공유 / 보낸 공유 두 탭. 서버에서 실데이터 로드.
class _ShareSection extends StatefulWidget {
  const _ShareSection();

  @override
  State<_ShareSection> createState() => _ShareSectionState();
}

class _ShareSectionState extends State<_ShareSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppStateProvider>().loadShares();
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    final appState = context.watch<AppStateProvider>();

    if (!appState.isLoggedIn) {
      return Center(
        child: Text('로그인하면 공유를 주고받을 수 있습니다.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
      );
    }

    final received = appState.sharesReceived;
    final sent = appState.sharesSent;

    return DefaultTabController(
      length: 2,
      child: Card(
        elevation: 0,
        color: color.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.35)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            TabBar(
              labelColor: color,
              unselectedLabelColor: Colors.grey.shade500,
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(4),
              indicator: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color, width: 1.4),
              ),
              dividerColor: color.withValues(alpha: 0.25),
              tabs: [
                Tab(child: _tabLabel(Icons.download_outlined, '공유 받은 것', received.length)),
                Tab(child: _tabLabel(Icons.upload_outlined, '공유한 것', sent.length)),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _receivedList(context, appState, received, color),
                  _sentList(context, appState, sent, color),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabLabel(IconData icon, String label, int count) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 6),
        Text('$count', style: const TextStyle(fontSize: 14)),
      ]),
    );
  }

  Widget _receivedList(BuildContext context, AppStateProvider appState,
      List<Map<String, dynamic>> items, Color color) {
    return RefreshIndicator(
      onRefresh: () => appState.loadShares(),
      child: items.isEmpty
          ? ListView(children: [
              const SizedBox(height: 60),
              Center(child: Text('받은 공유가 없습니다.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
            ])
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: items.length,
              itemBuilder: (ctx, i) => _ReceivedCard(share: items[i], color: color),
            ),
    );
  }

  Widget _sentList(BuildContext context, AppStateProvider appState,
      List<Map<String, dynamic>> items, Color color) {
    return RefreshIndicator(
      onRefresh: () => appState.loadShares(),
      child: items.isEmpty
          ? ListView(children: [
              const SizedBox(height: 60),
              Center(child: Text('보낸 공유가 없습니다.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
            ])
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: items.length,
              itemBuilder: (ctx, i) => _SentCard(share: items[i], color: color),
            ),
    );
  }
}

/// 받은 공유 카드 — 보낸이·파일·메시지 + 수락/거절(대기 시).
class _ReceivedCard extends StatelessWidget {
  final Map<String, dynamic> share;
  final Color color;
  const _ReceivedCard({required this.share, required this.color});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final status = share['status']?.toString() ?? 'pending';
    final fileName = share['fileName']?.toString() ?? '';
    final sender = share['senderName']?.toString() ?? '';
    final message = share['message']?.toString();
    final group = share['groupName']?.toString();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(_shareFileTypeIcon(share['fileType']?.toString()), size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(fileName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Text(_shareWhen(share['sharedAt']),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ]),
            const SizedBox(height: 4),
            Text('보낸이: $sender${group != null && group.isNotEmpty ? ' · 그룹 $group' : ''}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            if (message != null && message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('"$message"',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
              ),
            const SizedBox(height: 6),
            if (status == 'pending')
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: () async {
                    final ok = await appState.rejectReceivedShare(share);
                    if (context.mounted && !ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('거절 실패')));
                    }
                  },
                  child: const Text('거절', style: TextStyle(color: Colors.red)),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: () async {
                    final ok = await appState.acceptReceivedShare(share);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ok ? '수락하여 저장했습니다.' : '수락 처리 실패')));
                    }
                  },
                  style: FilledButton.styleFrom(
                      backgroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 16)),
                  child: const Text('수락'),
                ),
              ])
            else
              Align(
                alignment: Alignment.centerRight,
                child: Text(status == 'accepted' ? '수락됨 (저장 완료)' : '거절됨',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: status == 'accepted' ? color : Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }
}

/// 보낸 공유 카드 — 대상(개인/그룹)·파일·상태 요약 + 취소.
class _SentCard extends StatelessWidget {
  final Map<String, dynamic> share;
  final Color color;
  const _SentCard({required this.share, required this.color});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final fileName = share['fileName']?.toString() ?? '';
    final isGroup = share['targetType']?.toString() == 'group';
    final group = share['groupName']?.toString() ?? '';
    final message = share['message']?.toString();
    final pending = (share['pendingCount'] as num?)?.toInt() ?? 0;
    final accepted = (share['acceptedCount'] as num?)?.toInt() ?? 0;
    final rejected = (share['rejectedCount'] as num?)?.toInt() ?? 0;
    final shareId = (share['shareId'] as num?)?.toInt();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(_shareFileTypeIcon(share['fileType']?.toString()), size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(fileName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Text(_shareWhen(share['sharedAt']),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Icon(isGroup ? Icons.group : Icons.person, size: 13, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Expanded(
                child: Text(isGroup ? '그룹: $group' : '개인',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ]),
            if (message != null && message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('"$message"',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
              ),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: Wrap(spacing: 8, children: [
                  _statusChip('대기 $pending', Colors.orange),
                  _statusChip('수락 $accepted', color),
                  _statusChip('거절 $rejected', Colors.grey),
                ]),
              ),
              TextButton.icon(
                onPressed: shareId == null
                    ? null
                    : () async {
                        final ok = await appState.cancelSentShare(shareId);
                        if (context.mounted && !ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('취소 실패')));
                        }
                      },
                icon: const Icon(Icons.undo, size: 16, color: Colors.red),
                label: const Text('취소', style: TextStyle(color: Colors.red)),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c)),
    );
  }
}

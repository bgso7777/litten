import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/litten.dart';
import '../services/app_state_provider.dart';
import '../widgets/share_compose_dialog.dart';
import '../widgets/common/tab_count_title.dart';

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
        Expanded(child: _ShareSection()),
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
    case 'stt_text':
    case 'stt_audio':
      return Icons.record_voice_over; // 녹음 메모(STT)
    case 'handwriting':
      return Icons.draw;
    default:
      return Icons.attach_file;
  }
}

/// 표시용 파일명 — 확장자 제거. (확장자처럼 보이는 경우만: 마지막 '.' 뒤가 공백 없는 1~5자)
String _stripShareExt(String name) {
  final d = name.lastIndexOf('.');
  if (d <= 0) return name;
  final ext = name.substring(d + 1);
  if (ext.isEmpty || ext.length > 5 || ext.contains(' ')) return name;
  return name.substring(0, d);
}

String _shareWhen(dynamic v) {
  final s = v?.toString() ?? '';
  return s.length >= 16 ? s.substring(0, 16) : s;
}

/// 홈 탭 제목 — 공유 아이콘 + 받은(↓)·한(↑) 카운트. (전체탭 제목 카운트 스타일)
class ShareTabTitle extends StatelessWidget {
  const ShareTabTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, app, _) {
        final inN = app.sharesReceived.length;
        final outN = app.sharesSent.length;
        final filter = app.shareFilter;
        // 리마인드 제목탭과 동일한 스타일: 선택된 필터는 밝게, 비선택은 흐리게(active=false).
        // 'all'이면 둘 다 밝게(중립), 한쪽 선택 시 다른 쪽만 흐려진다. 같은 항목 재탭 → 전체로 토글.
        return TabCountTitle([
          [
            TabCount(Icons.download, inN,
                active: filter != 'sent',
                onTap: () => app.setShareFilter('received')),
            TabCount(Icons.upload, outN,
                active: filter != 'received',
                onTap: () => app.setShareFilter('sent')),
          ],
        ]);
      },
    );
  }
}

/// 공유 섹션 — 받은 것 + 한 것을 합쳐 일자순으로 보여준다(전체탭 파일리스트 컨셉).
class _ShareSection extends StatefulWidget {
  const _ShareSection();

  @override
  State<_ShareSection> createState() => _ShareSectionState();
}

class _ShareSectionState extends State<_ShareSection> {
  // 접힌 그룹 이름 집합 (기본 펼침 → 여기 없으면 펼침 상태)
  final Set<String> _collapsedGroups = {};
  // 비밀번호를 한 번 맞춰 잠금 해제된 그룹 이름 (다음부터 안 물어봄 — 영구 저장)
  final Set<String> _unlockedGroups = {};
  static const String _unlockedGroupsKey = 'unlocked_groups';

  @override
  void initState() {
    super.initState();
    _loadUnlockedGroups();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppStateProvider>().loadShares();
    });
  }

  Future<void> _loadUnlockedGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_unlockedGroupsKey) ?? [];
    if (mounted) setState(() => _unlockedGroups.addAll(saved));
  }

  Future<void> _persistUnlockedGroups() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_unlockedGroupsKey, _unlockedGroups.toList());
  }

  /// 그룹 비밀번호 입력 다이얼로그 — 맞으면 잠금 해제(영구 기억) 후 펼침.
  Future<void> _promptGroupPassword(String name, String password) async {
    final ctrl = TextEditingController();
    final color = Theme.of(context).primaryColor;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('"$name" 잠금', style: const TextStyle(fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(
              labelText: '비밀번호', isDense: true, border: OutlineInputBorder()),
          onSubmitted: (v) => Navigator.pop(ctx, v == password),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
              style: TextButton.styleFrom(foregroundColor: color),
              onPressed: () => Navigator.pop(ctx, ctrl.text == password),
              child: const Text('확인')),
        ],
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      setState(() {
        _unlockedGroups.add(name);
        _collapsedGroups.remove(name); // 펼침
      });
      _persistUnlockedGroups();
    } else if (ok == false) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')));
    }
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static DateTime _parseAt(dynamic v) {
    final s = (v?.toString() ?? '').replaceFirst(' ', 'T');
    return DateTime.tryParse(s) ?? DateTime(2000);
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

    // 제목의 받음/보냄 카운트 탭 필터: 'all' | 'received' | 'sent'
    final filter = appState.shareFilter;

    // 받은 것 + 한 것 통합 (필터 반영)
    final all = <_ShareItem>[];
    if (filter != 'sent') {
      for (final r in appState.sharesReceived) {
        all.add(_ShareItem(
            received: true, data: r, at: _parseAt(r['sharedAt']),
            group: (r['groupName']?.toString() ?? '').trim()));
      }
    }
    if (filter != 'received') {
      for (final s in appState.sharesSent) {
        all.add(_ShareItem(
            received: false, data: s, at: _parseAt(s['sharedAt']),
            group: (s['groupName']?.toString() ?? '').trim()));
      }
    }

    // 그룹(그룹명 보유) / 개인(1:1) 분리
    final Map<String, List<_ShareItem>> grouped = {};
    final List<_ShareItem> personal = [];
    for (final it in all) {
      if (it.group.isEmpty) {
        personal.add(it);
      } else {
        grouped.putIfAbsent(it.group, () => []).add(it);
      }
    }
    // 내가 만든 그룹은 공유 파일이 없어도 빈 컨테이너로 표시 (받음만 필터일 땐 제외)
    if (filter != 'received') {
      for (final g in appState.shareGroups) {
        final name = (g['name']?.toString() ?? '').trim();
        if (name.isNotEmpty) grouped.putIfAbsent(name, () => []);
      }
    }
    // 각 그룹 내부: 최신순(새 공유가 위로)
    for (final v in grouped.values) {
      v.sort((a, b) => b.at.compareTo(a.at));
    }
    // 그룹 정렬: 최신 활동 desc, 빈 그룹은 뒤(이름순)
    final groupNames = grouped.keys.toList()
      ..sort((a, b) {
        final la = grouped[a]!.isEmpty ? null : grouped[a]!.first.at;
        final lb = grouped[b]!.isEmpty ? null : grouped[b]!.first.at;
        if (la == null && lb == null) return a.compareTo(b);
        if (la == null) return 1;
        if (lb == null) return -1;
        return lb.compareTo(la);
      });
    // 개인: 최신순
    personal.sort((a, b) => b.at.compareTo(a.at));

    // 내가 만든 그룹(소유) 맵: 이름 → 그룹데이터(groupId/hasPassword/password 등)
    final ownedByName = <String, Map<String, dynamic>>{
      for (final g in appState.shareGroups)
        if ((g['name']?.toString() ?? '').trim().isNotEmpty)
          (g['name']?.toString() ?? '').trim(): g,
    };

    final isEmpty = groupNames.isEmpty && personal.isEmpty;

    return RefreshIndicator(
      onRefresh: () => appState.loadShares(),
      child: isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                Center(
                    child: Text('주고받은 공유가 없습니다.\n파일 카드의 공유 → 사용자에게 공유로 보낼 수 있어요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              children: _buildTimeline(groupNames, grouped, personal, color, ownedByName),
            ),
    );
  }

  /// 그룹 컨테이너 — 헤더(폴더+이름+개수+펼침아이콘) + 내부 공유 카드(최신순).
  /// [owned] 가 null이 아니면 "내가 만든 그룹" — 중간 톤 배경 + 멤버추가 아이콘 + (비밀번호 시) 잠금.
  Widget _buildGroup(String name, List<_ShareItem> items, Color color, Map<String, dynamic>? owned) {
    final isOwned = owned != null;
    final hasPassword = owned?['hasPassword'] == true;
    final password = owned?['password']?.toString();
    final groupId = (owned?['groupId'] as num?)?.toInt();
    final locked = hasPassword && !_unlockedGroups.contains(name);
    final collapsed = _collapsedGroups.contains(name) || locked;

    // 내가 만든 그룹은 중간 톤 배경으로 구분 (받은 그룹은 옅게)
    final headerBg = color.withValues(alpha: isOwned ? 0.20 : 0.08);
    final bodyBg = color.withValues(alpha: isOwned ? 0.10 : 0.04);

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: isOwned ? 0.45 : 0.25)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              // 비밀번호 그룹은 잠금 해제 전까지 펼치기 전 비번 확인
              if (locked && password != null && password.isNotEmpty) {
                _promptGroupPassword(name, password);
                return;
              }
              setState(() {
                if (_collapsedGroups.contains(name)) {
                  _collapsedGroups.remove(name);
                } else {
                  _collapsedGroups.add(name);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: headerBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: Row(children: [
                Icon(isOwned ? Icons.folder_shared : Icons.folder, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (locked)
                  Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Icon(Icons.lock, size: 15, color: color),
                  ),
                // 내가 만든 그룹 — 멤버 추가/관리 (사람 아이콘)
                if (isOwned && groupId != null)
                  InkWell(
                    onTap: () async {
                      await showGroupMembersDialog(context, groupId, name);
                      if (mounted) {
                        context.read<AppStateProvider>().reloadShareGroups();
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.group_add, size: 18, color: color),
                    ),
                  ),
                const SizedBox(width: 4),
                Text('${items.length}개',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                const SizedBox(width: 4),
                Icon(collapsed ? Icons.expand_more : Icons.expand_less,
                    size: 20, color: color),
              ]),
            ),
          ),
          if (!collapsed)
            Container(
              width: double.infinity,
              // 펼친 파일들이 이 그룹 소속임을 나타내는 배경
              decoration: BoxDecoration(
                color: bodyBg,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('아직 이 그룹으로 공유된 파일이 없습니다.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    )
                  : Column(
                      children: items
                          .map((it) => it.received
                              ? _ReceivedCard(share: it.data, color: color)
                              : _SentCard(share: it.data, color: color))
                          .toList(),
                    ),
            ),
        ],
      ),
    );
  }

  /// 그룹 컨테이너 + 개인 카드를 하나의 날짜순 타임라인으로 구성.
  /// - 활동 있는 그룹: 가장 최근 공유 시각 기준으로 날짜 섹션(오늘/어제/날짜)에 배치
  /// - 개인(1:1) 공유: 각 항목 시각 기준 배치
  /// - 빈 그룹(내가 만들기만 한): 활동이 없으므로 맨 아래 '내 그룹'에 모아 표시
  List<Widget> _buildTimeline(
      List<String> groupNames,
      Map<String, List<_ShareItem>> grouped,
      List<_ShareItem> personal,
      Color color,
      Map<String, Map<String, dynamic>> ownedByName) {
    // 날짜 배치 대상(활동 있는 그룹 + 개인) — 시각 내림차순
    final dated = <({DateTime at, Widget child})>[];
    for (final name in groupNames) {
      final its = grouped[name]!;
      if (its.isEmpty) continue; // 빈 그룹은 아래에서 따로
      dated.add((at: its.first.at, child: _buildGroup(name, its, color, ownedByName[name])));
    }
    for (final it in personal) {
      dated.add((
        at: it.at,
        child: it.received
            ? _ReceivedCard(share: it.data, color: color)
            : _SentCard(share: it.data, color: color),
      ));
    }
    dated.sort((a, b) => b.at.compareTo(a.at));

    final widgets = <Widget>[];
    DateTime? prevDay;
    for (final e in dated) {
      final cur = DateTime(e.at.year, e.at.month, e.at.day);
      if (prevDay == null || prevDay != cur) {
        widgets.add(_dateHeader(cur, color));
        prevDay = cur;
      }
      widgets.add(e.child);
    }

    // 빈 그룹(활동 없음, 내가 만들기만 한)은 맨 아래 '내 그룹'에 모아 표시
    final emptyGroups = groupNames.where((n) => grouped[n]!.isEmpty).toList();
    if (emptyGroups.isNotEmpty) {
      widgets.add(_sectionHeader('내 그룹', color));
      for (final n in emptyGroups) {
        widgets.add(_buildGroup(n, grouped[n]!, color, ownedByName[n]));
      }
    }
    return widgets;
  }

  /// 섹션 헤더 (날짜 헤더와 동일 스타일)
  Widget _sectionHeader(String label, Color color) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        child: Row(children: [
          Text(label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: color.withValues(alpha: 0.2))),
        ]),
      );

  Widget _dateHeader(DateTime d, Color color) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    final label = diff == 0
        ? '오늘'
        : diff == 1
            ? '어제'
            : '${d.year}.${_two(d.month)}.${_two(d.day)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Row(children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: color.withValues(alpha: 0.2))),
      ]),
    );
  }
}

/// 공유 항목(받은/보낸 공통) — 그룹 묶음/정렬용 래퍼.
class _ShareItem {
  final bool received;
  final Map<String, dynamic> data;
  final DateTime at;
  final String group; // 그룹명 (없으면 빈 문자열 → 개인 공유)
  _ShareItem({
    required this.received,
    required this.data,
    required this.at,
    required this.group,
  });
}

/// 방향 배지 (받음 ↓ / 보냄 ↑)
Widget _dirChip(bool received, Color color) {
  final c = received ? color : Colors.grey.shade600;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(received ? Icons.download : Icons.upload, size: 11, color: c),
      const SizedBox(width: 2),
      Text(received ? '받음' : '보냄',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c)),
    ]),
  );
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
    final fileName = _stripShareExt(share['fileName']?.toString() ?? '');
    // 보낸이: 닉네임(이메일). 닉네임이 없거나 이메일과 같으면 이메일만.
    final senderEmail = share['senderMemberId']?.toString() ?? '';
    final senderName = share['senderName']?.toString() ?? '';
    final sender = (senderName.isNotEmpty && senderName != senderEmail && senderEmail.isNotEmpty)
        ? '$senderName($senderEmail)'
        : (senderEmail.isNotEmpty ? senderEmail : senderName);
    final message = share['message']?.toString();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _dirChip(true, color),
              const SizedBox(width: 6),
              Icon(_shareFileTypeIcon(share['fileType']?.toString()), size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(fileName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Text(_shareWhen(share['sharedAt']),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ]),
            const SizedBox(height: 4),
            Text('보낸이: $sender',
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
                    final r = await appState.acceptReceivedShare(share);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(r.ok ? '수락하여 저장했습니다.' : (r.message ?? '수락 처리 실패'))));
                    }
                  },
                  style: FilledButton.styleFrom(
                      backgroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 16)),
                  child: const Text('수락'),
                ),
              ])
            else if (status == 'rejected')
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                const Text('거절됨',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {
                    final id = (share['deliveryId'] as num?)?.toInt();
                    if (id != null) appState.dismissReceivedShare(id);
                  },
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  label: const Text('삭제', style: TextStyle(color: Colors.red)),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
              ])
            else
              Align(
                alignment: Alignment.centerRight,
                child: Text('수락됨 (저장 완료)',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: color)),
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
    final fileName = _stripShareExt(share['fileName']?.toString() ?? '');
    final isGroup = share['targetType']?.toString() == 'group';
    final group = share['groupName']?.toString() ?? '';
    final message = share['message']?.toString();
    final pending = (share['pendingCount'] as num?)?.toInt() ?? 0;
    final accepted = (share['acceptedCount'] as num?)?.toInt() ?? 0;
    final rejected = (share['rejectedCount'] as num?)?.toInt() ?? 0;
    final shareId = (share['shareId'] as num?)?.toInt();
    final recipients = (share['recipients'] as List?) ?? const [];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _dirChip(false, color),
              const SizedBox(width: 6),
              Icon(_shareFileTypeIcon(share['fileType']?.toString()), size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(fileName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
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
                child: isGroup
                    ? Text('그룹: $group',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        maxLines: 1, overflow: TextOverflow.ellipsis)
                    // 개인(1:1) — 수신자를 닉네임(이메일)로 표시 (없으면 이메일만)
                    : Builder(builder: (context) {
                        final email = recipients.isNotEmpty
                            ? ((recipients.first as Map)['memberId']?.toString() ?? '')
                            : '';
                        if (email.isEmpty) {
                          return Text('개인',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600));
                        }
                        return FutureBuilder<List<String>>(
                          future: _resolveRecipientNames(appState, [email]),
                          builder: (c, snap) {
                            final label = (snap.hasData && snap.data!.isNotEmpty)
                                ? snap.data!.first
                                : email;
                            return Text(label,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                maxLines: 1, overflow: TextOverflow.ellipsis);
                          },
                        );
                      }),
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
                  _statusChip('대기 $pending', Colors.orange,
                      onTap: () => _showRecipientsDialog(
                          context, appState, recipients, 'pending', '대기', Colors.orange)),
                  _statusChip('수락 $accepted', color,
                      onTap: () => _showRecipientsDialog(
                          context, appState, recipients, 'accepted', '수락', color)),
                  _statusChip('거절 $rejected', Colors.grey,
                      onTap: () => _showRecipientsDialog(
                          context, appState, recipients, 'rejected', '거절', Colors.grey)),
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

  Widget _statusChip(String text, Color c, {VoidCallback? onTap}) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c)),
    );
    if (onTap == null) return chip;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: chip,
    );
  }

  /// 상태별 수신자 목록을 "닉네임(이메일)" 형식으로 보여주는 다이얼로그.
  /// 닉네임은 서버 조회(lookup)로 가져오고, 없으면 이메일만 표시한다.
  Future<void> _showRecipientsDialog(BuildContext context, AppStateProvider appState,
      List<dynamic> recipients, String statusKey, String label, Color c) async {
    final ids = recipients
        .whereType<Map>()
        .where((r) => r['status']?.toString() == statusKey)
        .map((r) => r['memberId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label ${ids.length}명', style: const TextStyle(fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: ids.isEmpty
              ? const Text('해당하는 사람이 없습니다.', style: TextStyle(fontSize: 13))
              : FutureBuilder<List<String>>(
                  future: _resolveRecipientNames(appState, ids),
                  builder: (c2, snap) {
                    if (!snap.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final line in snap.data!)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(children: [
                              Icon(Icons.person, size: 14, color: c),
                              const SizedBox(width: 6),
                              Expanded(
                                  child: Text(line,
                                      style: const TextStyle(fontSize: 13))),
                            ]),
                          ),
                      ],
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
        ],
      ),
    );
  }

  /// 각 memberId(이메일)의 닉네임을 조회해 "닉네임(이메일)" 문자열로 변환.
  /// 닉네임이 없거나 이메일과 같으면 이메일만 반환.
  Future<List<String>> _resolveRecipientNames(
      AppStateProvider appState, List<String> ids) async {
    final out = <String>[];
    for (final id in ids) {
      String? name;
      try {
        final r = await appState.lookupShareRecipient(id);
        if (r != null && r['found'] == true) name = r['name']?.toString();
      } catch (_) {}
      out.add((name != null && name.isNotEmpty && name != id) ? '$name($id)' : id);
    }
    return out;
  }
}

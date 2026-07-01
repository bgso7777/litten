import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/litten.dart';
import '../services/app_state_provider.dart';
import '../services/file_storage_service.dart';
import '../services/shared_snapshot_service.dart';
import '../widgets/share_compose_dialog.dart';
import '../widgets/shared_snapshot_viewer.dart';
import '../widgets/common/tab_count_title.dart';

/// 홈 탭 — 대시보드.
/// 최근/최신 일정, 미완료 퀴즈 갯수, 공유한 것/공유 받은 것(이번엔 UI 자리만).
class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  // 5탭 인덱스: 홈0 · 캘린더1 · +2 · 리마인드3 · 설정4
  static const int _calendarTabIndex = 1;
  static const int _remindTabIndex = 3;

  @override
  State<HomeDashboardScreen> createState() => HomeDashboardScreenState();
}

class HomeDashboardScreenState extends State<HomeDashboardScreen> {
  // 우측 하단 FAB(MainTabScreen)에서 공유 섹션의 '새 채팅'을 띄우기 위해 상태에 접근하는 키
  final GlobalKey<_ShareSectionState> _shareKey = GlobalKey<_ShareSectionState>();

  /// 우측 하단 FAB(+)에서 호출 — 새 채팅(1:1/그룹) 다이얼로그를 띄운다.
  void startNewChat() => _shareKey.currentState?.startNewChat();

  @override
  Widget build(BuildContext context) {
    debugPrint('🏠 [HomeDashboardScreen] build');
    // 대화방 열림 여부(provider 공유) — 대화방 안에서는 하단 칩 바를 숨겨
    // 메시지 입력창이 하단 메뉴 바로 위까지 내려오게 한다.
    final chatOpen = context.watch<AppStateProvider>().homeChatOpen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _ShareSection(key: _shareKey)),
        if (!chatOpen) const _HomeChipBar(),
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

/// 홈 탭 하단 칩 바 — 다른 탭(캘린더/+/리마인드)의 칩 바와 동일한 배경/높이.
/// 새 채팅 + 동그라미는 우측 하단 FAB(MainTabScreen)로 빠졌고, 이 바는 높이만 유지한다.
class _HomeChipBar extends StatelessWidget {
  const _HomeChipBar();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border(top: BorderSide(color: color.withValues(alpha: 0.15))),
      ),
      // 노트(_CreateChipBar)·캘린더 칩 바와 동일한 세로 패딩(9) + 칩(알약) 콘텐츠 높이(28.0)로
      // 바 전체 높이를 그 둘(123px ≒ 46.9dp)과 정확히 일치시킨다(= 9*2 + 28.0).
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: const SizedBox(height: 28.0),
    );
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
        final chatN = app.homeConversationCount;
        final inN = app.sharesReceived.length;
        final outN = app.sharesSent.length;
        // 표시 모드 전환(라디오식): 채팅(기본 선택) | 공유받음 | 공유한.
        // 선택된 것만 밝게(active) 보이고, 받음/보냄은 선택 시 공유 파일을 일자순 리스트로 보여준다.
        final mode = app.homeChatView;
        return TabCountTitle([
          [
            TabCount(Icons.chat_bubble_outline, chatN,
                active: mode == 'chat',
                onTap: () => app.setHomeChatView('chat')),
            TabCount(Icons.download, inN,
                active: mode == 'received',
                onTap: () => app.setHomeChatView('received')),
            TabCount(Icons.upload, outN,
                active: mode == 'sent',
                onTap: () => app.setHomeChatView('sent')),
          ],
        ]);
      },
    );
  }
}

/// 공유 섹션 — 받은 것 + 한 것을 합쳐 일자순으로 보여준다(전체탭 파일리스트 컨셉).
/// 대화방 열림/닫힘은 AppStateProvider.homeChatOpen 으로 공유한다(칩 바·FAB 토글용).
class _ShareSection extends StatefulWidget {
  const _ShareSection({super.key});

  @override
  State<_ShareSection> createState() => _ShareSectionState();
}

class _ShareSectionState extends State<_ShareSection> {
  // 현재 열린 대화방 key (null이면 대화 목록 화면). 'g:그룹명' 또는 'u:이메일'
  String? _openConvKey;
  // 비밀번호를 한 번 맞춰 잠금 해제된 그룹 이름 (다음부터 안 물어봄 — 영구 저장)
  final Set<String> _unlockedGroups = {};
  static const String _unlockedGroupsKey = 'unlocked_groups';
  // 대화방 하단 메시지 입력
  final TextEditingController _msgCtrl = TextEditingController();
  // 대화방 메시지 리스트 스크롤 — 진입/전송 시 맨 아래(최신)로 이동
  final ScrollController _chatScrollCtrl = ScrollController();
  bool _scrollChatToBottom = false;
  // 대화별 마지막 읽은 시각 (미읽음 메시지 뱃지용 — 영구 저장)
  final Map<String, DateTime> _convLastRead = {};
  static const String _convReadKey = 'conv_last_read';
  // 방나가기(로컬 숨김)한 대화 key → 숨긴 시각. 이후 새 항목(lastAt>숨긴시각)이 오면 다시 보인다.
  final Map<String, DateTime> _convHiddenAt = {};
  static const String _convHiddenKey = 'conv_hidden_at';

  @override
  void dispose() {
    _msgCtrl.dispose();
    _chatScrollCtrl.dispose();
    super.dispose();
  }

  /// 대화방 메시지 리스트를 맨 아래(최신)로 이동. 렌더 후 실제 최대 스크롤 위치로.
  void _jumpChatToBottom() {
    if (!_chatScrollCtrl.hasClients) return;
    _chatScrollCtrl.jumpTo(_chatScrollCtrl.position.maxScrollExtent);
  }

  Future<void> _loadConvRead() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_convReadKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      m.forEach((k, v) {
        final dt = DateTime.tryParse(v.toString());
        if (dt != null) _convLastRead[k] = dt;
      });
      if (mounted) setState(() {});
    } catch (_) {}
  }

  /// 대화방 진입 — 읽음 처리(미읽음 뱃지 제거) 후 연다.
  /// [readUpTo]는 "여기까지 읽음" 기준 시각 — 그 대화의 최신 항목 시각을 넘겨 시계 차이와 무관하게
  /// 현재 항목이 모두 읽음 처리되도록 한다(없으면 기기 현재 시각).
  void _openConv(String key, [DateTime? readUpTo]) {
    final now = DateTime.now();
    var t = readUpTo ?? now;
    if (t.isBefore(now)) t = now; // 최소 현재 시각 보장
    _convLastRead[key] = t;
    SharedPreferences.getInstance().then((p) => p.setString(
        _convReadKey,
        jsonEncode(_convLastRead.map((k, v) => MapEntry(k, v.toIso8601String())))));
    _scrollChatToBottom = true; // 진입 시 최신(맨 아래)이 보이도록
    setState(() => _openConvKey = key);
    // 대화방 진입 → 하단 칩 바 + 새 채팅 FAB 숨김(provider 공유 상태)
    context.read<AppStateProvider>().setHomeChatOpen(true);
  }

  @override
  void initState() {
    super.initState();
    _loadUnlockedGroups();
    _loadConvRead();
    _loadConvHidden();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppStateProvider>();
      app.loadShares();
      app.loadSelfChats();
    });
  }

  Future<void> _loadConvHidden() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_convHiddenKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      m.forEach((k, v) {
        final dt = DateTime.tryParse(v.toString());
        if (dt != null) _convHiddenAt[k] = dt;
      });
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _persistConvHidden() {
    SharedPreferences.getInstance().then((p) => p.setString(
        _convHiddenKey,
        jsonEncode(_convHiddenAt.map((k, v) => MapEntry(k, v.toIso8601String())))));
  }

  /// 방나가기 — 나와의 대화는 삭제, 그 외는 로컬에서 숨김(새 활동이 오면 다시 보임).
  Future<void> _leaveConv(_Conv c) async {
    final appState = context.read<AppStateProvider>();
    final isSelf = c.isSelf;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isSelf ? '대화 삭제' : '방 나가기', style: const TextStyle(fontSize: 16)),
        content: Text(isSelf
            ? '"${c.label}"을(를) 삭제할까요? 이 안의 내용도 함께 삭제됩니다.'
            : '"${c.label}" 대화를 목록에서 숨길까요? 새 메시지·공유가 오면 다시 표시됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isSelf ? '삭제' : '나가기')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (isSelf) {
      await appState.deleteSelfChat(c.key.substring(5));
    } else {
      _convHiddenAt[c.key] = DateTime.now();
      _persistConvHidden();
      setState(() {});
    }
  }

  bool _isHidden(_Conv c) {
    final h = _convHiddenAt[c.key];
    return h != null && !c.lastAt.isAfter(h);
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

  /// 그룹 비밀번호 입력 다이얼로그 — 맞으면 잠금 해제(영구 기억) 후 해당 대화방 진입.
  Future<void> _promptGroupPassword(String name, String password, String convKey,
      [DateTime? readUpTo]) async {
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
      _unlockedGroups.add(name);
      _persistUnlockedGroups();
      _openConv(convKey, readUpTo); // 잠금 해제 후 대화방 진입(읽음 처리 포함)
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '로그인하면 내가 만든 녹음·필기·요약을\n친구·동료와 자유롭게 주고받을 수 있어요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.5),
          ),
        ),
      );
    }

    final mode = appState.homeChatView; // 'chat' | 'received' | 'sent'

    // 채팅 모드: 받은 것 + 한 것 + 메시지를 모두 대화방으로 묶는다(제목 토글과 무관하게 전체 표시).
    final all = <_ShareItem>[];
    for (final r in appState.sharesReceived) {
      all.add(_ShareItem(
          received: true, data: r, at: _parseAt(r['sharedAt']),
          group: (r['groupName']?.toString() ?? '').trim()));
    }
    for (final s in appState.sharesSent) {
      all.add(_ShareItem(
          received: false, data: s, at: _parseAt(s['sharedAt']),
          group: (s['groupName']?.toString() ?? '').trim()));
    }
    // 채팅 메시지도 대화 항목으로 포함 (공유와 동일 키잉: 받은=보낸이, 보낸=수신자, 그룹=그룹명)
    for (final m in appState.messagesReceived) {
      all.add(_ShareItem(
          received: true, data: m, at: _parseAt(m['sentAt']),
          group: (m['groupName']?.toString() ?? '').trim(), isMessage: true));
    }
    for (final m in appState.messagesSent) {
      all.add(_ShareItem(
          received: false, data: m, at: _parseAt(m['sentAt']),
          group: (m['groupName']?.toString() ?? '').trim(), isMessage: true));
    }

    // ── 채팅방 형태: 상대(개인/그룹)별 대화로 묶는다 ──
    // 개인(1:1)은 상대 이메일, 그룹은 그룹명 기준. 받은 건 좌측 / 보낸 건 우측 말풍선.
    final ownedByName = <String, Map<String, dynamic>>{
      for (final g in appState.shareGroups)
        if ((g['name']?.toString() ?? '').trim().isNotEmpty)
          (g['name']?.toString() ?? '').trim(): g,
    };

    final convs = <String, _Conv>{};
    for (final it in all) {
      final group = it.group;
      String key;
      String label;
      bool isGroup = false;
      String? email;
      if (group.isNotEmpty) {
        key = 'g:$group';
        label = group;
        isGroup = true;
      } else {
        if (it.received) {
          email = it.data['senderMemberId']?.toString() ?? '';
        } else {
          final recips = (it.data['recipients'] as List?) ?? const [];
          email = recips.isNotEmpty
              ? ((recips.first as Map)['memberId']?.toString() ?? '')
              : '';
        }
        key = 'u:$email';
        label = email;
      }
      final conv = convs.putIfAbsent(
          key,
          () => _Conv(
              key: key, isGroup: isGroup, email: email, label: label,
              groupId: (ownedByName[group]?['groupId'] as num?)?.toInt()));
      conv.items.add(it);
      // 개인 대화 라벨: 닉네임이 있으면 '닉네임(이메일)', 없으면 이메일만.
      // 닉네임은 받은 항목의 senderName에서 확보(이메일과 다를 때만 닉네임으로 인정).
      if (!isGroup && it.received) {
        final sn = it.data['senderName']?.toString() ?? '';
        final em = email ?? '';
        if (sn.isNotEmpty && sn != em) conv.label = '$sn($em)';
      }
      // 수신 그룹(남의 그룹)의 비밀번호/그룹id — 수신자 잠금 검증 및 멤버 발신용
      if (isGroup && it.received) {
        final gpw = it.data['groupPassword']?.toString();
        if (gpw != null && gpw.isNotEmpty) conv.recvGroupPassword = gpw;
        final gid = (it.data['groupId'] as num?)?.toInt();
        if (gid != null) conv.recvGroupId = gid;
      }
    }
    // 내가 만든 그룹은 공유가 없어도 대화방으로 노출.
    for (final g in appState.shareGroups) {
      final name = (g['name']?.toString() ?? '').trim();
      if (name.isEmpty) continue;
      convs.putIfAbsent('g:$name',
          () => _Conv(key: 'g:$name', isGroup: true, label: name,
              groupId: (g['groupId'] as num?)?.toInt()));
    }
    // 나와의 대화(로컬 셀프 채팅방) — 공유/서버와 무관하게 목록에 노출. key 'self:{id}'.
    final myEmail0 = appState.currentUser?.id ?? '';
    for (final sc in appState.selfChats) {
      final id = sc['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final key = 'self:$id';
      final conv = convs.putIfAbsent(
          key,
          () => _Conv(
              key: key, isGroup: false, email: myEmail0,
              label: sc['name']?.toString() ?? '나와의 대화', isSelf: true));
      for (final m in appState.selfChatMessages(id)) {
        conv.items.add(_ShareItem(
            received: false, data: m, at: _parseAt(m['sentAt']),
            group: '', isMessage: true));
      }
    }

    // 열린 대화방 — 없으면(새 채팅 등) key로 임시 대화 생성
    _Conv? open;
    if (_openConvKey != null) {
      open = convs[_openConvKey];
      if (open == null) {
        final k = _openConvKey!;
        if (k.startsWith('g:')) {
          final name = k.substring(2);
          open = _Conv(key: k, isGroup: true, label: name,
              groupId: (ownedByName[name]?['groupId'] as num?)?.toInt());
        } else if (k.startsWith('u:')) {
          final email = k.substring(2);
          open = _Conv(key: k, isGroup: false, email: email, label: email);
        }
      }
    }
    if (open != null) {
      return _buildChatRoom(open, ownedByName, color, appState);
    }

    // 공유받음/공유한 모드 — 해당 공유 파일을 일자순 리스트로 보여준다(대화방 아님).
    if (mode == 'received' || mode == 'sent') {
      return _buildSharedFileList(mode, appState, color);
    }

    final convList = convs.values.where((c) => !_isHidden(c)).toList()
      ..sort((a, b) => b.lastAt.compareTo(a.lastAt));
    // 아이콘 사람 수 산정 시 '나와의 채팅'(상대가 나 자신) 판별용 내 이메일(memberId).
    final myEmail = appState.currentUser?.id ?? '';

    // 새 채팅 진입점은 하단 칩 바의 + 버튼으로 일원화(기존 우측 하단 FAB 제거).
    return RefreshIndicator(
      onRefresh: () => appState.loadShares(),
      child: convList.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                Center(
                    child: Text('아직 대화가 없습니다.\n아래 + 버튼으로 새 채팅을 시작하거나 파일을 공유해 보세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              itemCount: convList.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: color.withValues(alpha: 0.08)),
              itemBuilder: (_, i) => _convRow(convList[i], ownedByName, color, myEmail),
            ),
    );
  }

  /// 공유받음/공유한 모드 — 파일 공유 건을 공유 일자순(최신→과거)으로 나열. 탭하면 스냅샷 미리보기.
  Widget _buildSharedFileList(String mode, AppStateProvider appState, Color color) {
    final received = mode == 'received';
    final raw = received ? appState.sharesReceived : appState.sharesSent;
    final items = [...raw]
      ..sort((a, b) => _parseAt(b['sharedAt']).compareTo(_parseAt(a['sharedAt'])));
    return RefreshIndicator(
      onRefresh: () => appState.loadShares(),
      child: items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                Center(
                    child: Text(received ? '받은 공유 파일이 없습니다.' : '공유한 파일이 없습니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: color.withValues(alpha: 0.08)),
              itemBuilder: (_, i) {
                final s = items[i];
                final it = _ShareItem(
                    received: received, data: s, at: _parseAt(s['sharedAt']),
                    group: (s['groupName']?.toString() ?? '').trim());
                final fname = _stripShareExt(s['fileName']?.toString() ?? '');
                // 상대 표시: 받은 것=보낸이, 보낸 것=그룹명/수신자
                String peer;
                if (received) {
                  peer = s['senderName']?.toString().isNotEmpty == true
                      ? s['senderName'].toString()
                      : (s['senderMemberId']?.toString() ?? '');
                } else {
                  final g = (s['groupName']?.toString() ?? '').trim();
                  if (g.isNotEmpty) {
                    peer = g;
                  } else {
                    final recips = (s['recipients'] as List?) ?? const [];
                    peer = recips.isNotEmpty
                        ? ((recips.first as Map)['memberId']?.toString() ?? '')
                        : '';
                  }
                }
                return ListTile(
                  leading: Icon(_shareFileTypeIcon(s['fileType']?.toString()), color: color),
                  title: Text(fname, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text('${received ? '보낸이' : '받는이'}: $peer',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  trailing: Text(_shareWhen(s['sharedAt']),
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                  onTap: () => _openSharedSnapshot(it),
                );
              },
            ),
    );
  }

  /// + 버튼 진입점 — '나와의 대화'(즉시 생성) 또는 '새 채팅'(다른 사람/그룹) 선택.
  void startNewChat() => _newChatMenu();

  /// + 선택 시트: 나와의 대화(로컬 셀프 채팅, 여러 개 가능) / 새 채팅(1:1·그룹).
  Future<void> _newChatMenu() async {
    final appState = context.read<AppStateProvider>();
    final color = Theme.of(context).primaryColor;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(Icons.person, color: color),
            title: const Text('나와의 대화'),
            subtitle: const Text('나 혼자 쓰는 채팅방 (여러 개 만들 수 있어요)',
                style: TextStyle(fontSize: 11)),
            onTap: () => Navigator.pop(ctx, 'self'),
          ),
          ListTile(
            leading: Icon(Icons.chat_bubble_outline, color: color),
            title: const Text('새 채팅'),
            subtitle: const Text('다른 사람 또는 그룹', style: TextStyle(fontSize: 11)),
            onTap: () => Navigator.pop(ctx, 'new'),
          ),
        ]),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'self') {
      final room = await appState.createSelfChat();
      if (mounted) _openConv('self:${room['id']}');
    } else if (choice == 'new') {
      await _startNewChat();
    }
  }

  Future<void> _startNewChat() async {
    final ctrl = TextEditingController();
    final appState = context.read<AppStateProvider>();
    final groups = appState.shareGroups;
    final color = Theme.of(context).primaryColor;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => DefaultTabController(
        length: 2,
        child: AlertDialog(
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          title: const Text('새 채팅', style: TextStyle(fontSize: 16)),
          content: SizedBox(
            width: double.maxFinite,
            height: 270,
            child: Column(
              children: [
                TabBar(
                  labelColor: color,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: color,
                  tabs: const [Tab(text: '1:1'), Tab(text: '그룹')],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // 1:1 탭 — 이메일/닉네임 입력 후 대화 시작
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: ctrl,
                              autofocus: true,
                              decoration: const InputDecoration(
                                  labelText: '이메일 또는 닉네임',
                                  isDense: true, border: OutlineInputBorder()),
                              onSubmitted: (v) => Navigator.pop(
                                  ctx, v.trim().isEmpty ? null : 'u:${v.trim()}'),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                final k = ctrl.text.trim();
                                if (k.isEmpty) return;
                                Navigator.pop(ctx, 'u:$k');
                              },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: color, foregroundColor: Colors.white),
                              icon: const Icon(Icons.chat_bubble_outline, size: 18),
                              label: const Text('대화 시작'),
                            ),
                          ],
                        ),
                      ),
                      // 그룹 탭 — 새 그룹 만들기 + 내 그룹 목록
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => Navigator.pop(ctx, '__newgroup__'),
                              icon: Icon(Icons.group_add, color: color, size: 18),
                              label: const Text('새 그룹 만들기'),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: groups.isEmpty
                                  ? Center(
                                      child: Text('내 그룹이 없습니다.\n위 버튼으로 새 그룹을 만들어 보세요.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontSize: 12, color: Colors.grey.shade500)))
                                  : ListView(
                                      children: groups
                                          .map((g) => ListTile(
                                                dense: true,
                                                leading: Icon(Icons.group, color: color, size: 20),
                                                title: Text('${g['name']}'),
                                                subtitle: Text('${g['memberCount'] ?? 0}명',
                                                    style: const TextStyle(fontSize: 11)),
                                                onTap: () =>
                                                    Navigator.pop(ctx, 'g:${g['name']}'),
                                              ))
                                          .toList(),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    if (result == '__newgroup__') {
      // 그룹 생성/멤버 관리 다이얼로그 → 생성 후 목록 갱신(빈 그룹도 대화방으로 노출)
      await showShareGroupManageDialog(context);
      if (mounted) context.read<AppStateProvider>().reloadShareGroups();
      return;
    }
    _openConv(result);
  }

  /// 대화 참여자 수(나 포함) — 아이콘 사람 수 산정용.
  /// 나와의 채팅(상대가 나 자신)=1, 1:1=2(나+상대),
  /// 내 그룹=memberCount(나 제외)+1, 수신 그룹=recipients(발신자 제외)+발신자.
  int _peopleCount(_Conv c, Map<String, Map<String, dynamic>> ownedByName, String myEmail) {
    if (c.isSelf) return 1; // 나와의 대화 = 나 1명
    if (!c.isGroup) {
      final other = c.email ?? '';
      return (other.isNotEmpty && other == myEmail) ? 1 : 2;
    }
    final owned = ownedByName[c.label];
    if (owned != null) {
      final mc = (owned['memberCount'] as num?)?.toInt() ?? 0;
      return mc + 1; // 멤버(나 제외) + 나
    }
    int maxR = 0;
    for (final it in c.items) {
      final r = (it.data['recipients'] as List?)?.length ?? 0;
      if (r > maxR) maxR = r;
    }
    return maxR > 0 ? maxR + 1 : 2;
  }

  /// 참여자 아바타 — 인원수만큼(1~5명, 5명 이상은 5명) 사람 아이콘을 가로로 겹쳐 보여준다.
  /// 1명은 단독으로 크게 표시한다.
  Widget _peopleAvatar(int count, Color color, bool owned) {
    final n = count.clamp(1, 5);
    if (n == 1) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(Icons.person, color: color, size: 22),
      );
    }
    const s = 15.0;    // 개별 사람 아이콘 크기
    const step = 8.0;  // 겹침 간격
    final w = s + (n - 1) * step;
    return CircleAvatar(
      radius: 20,
      backgroundColor: color.withValues(alpha: owned ? 0.2 : 0.12),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: w,
          height: s,
          child: Stack(
            children: [
              for (int i = 0; i < n; i++)
                Positioned(
                  left: i * step,
                  child: Icon(Icons.person, size: s, color: color),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 대화 목록 한 줄 (상대/그룹). 탭하면 대화방 진입(잠금 그룹은 비밀번호 확인).
  Widget _convRow(_Conv c, Map<String, Map<String, dynamic>> ownedByName, Color color,
      String myEmail) {
    final owned = c.isGroup ? ownedByName[c.label] : null;
    final isOwned = owned != null;
    // 발신자(그룹 소유자)는 항상 열림. 수신자는 그룹 비번이 있으면 한 번 입력해 해제.
    final recvPw = (c.isGroup && !isOwned) ? c.recvGroupPassword : null;
    final locked = recvPw != null && recvPw.isNotEmpty && !_unlockedGroups.contains(c.label);
    final last = c.last;
    // 뱃지 = 미읽음(마지막으로 연 이후 받은 메시지/공유). 대화방에 들어가면 사라진다.
    final lastRead = _convLastRead[c.key];
    final pending = c.items
        .where((it) => it.received && (lastRead == null || it.at.isAfter(lastRead)))
        .length;

    String subtitle;
    if (last == null) {
      subtitle = '대화를 시작해 보세요';
    } else if (last.isMessage) {
      subtitle = '${last.received ? '' : '나: '}${last.data['content']?.toString() ?? ''}';
    } else {
      final dir = last.received ? '받음' : '보냄';
      subtitle = '$dir · ${_stripShareExt(last.data['fileName']?.toString() ?? '')}';
    }

    return ListTile(
      leading: _peopleAvatar(_peopleCount(c, ownedByName, myEmail), color, isOwned),
      title: Row(children: [
        Flexible(
          child: Text(c.label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        if (locked)
          Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.lock, size: 14, color: color)),
      ]),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (last != null)
                Text(_shareWhen(last.data['sharedAt']),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              if (pending > 0)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                  child: Text('$pending',
                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          // 세로 ... 메뉴 — 방나가기(나와의 대화는 삭제)
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey.shade500, size: 20),
            padding: EdgeInsets.zero,
            tooltip: '메뉴',
            onSelected: (v) {
              if (v == 'leave') _leaveConv(c);
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                value: 'leave',
                child: Row(children: [
                  Icon(c.isSelf ? Icons.delete_outline : Icons.logout,
                      size: 18, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(c.isSelf ? '대화 삭제' : '방 나가기',
                      style: const TextStyle(color: Colors.red)),
                ]),
              ),
            ],
          ),
        ],
      ),
      onTap: () {
        if (locked) {
          _promptGroupPassword(c.label, recvPw, c.key, c.lastAt);
          return;
        }
        _openConv(c.key, c.lastAt);
      },
    );
  }

  /// 채팅방 — 헤더(뒤로 + 상대명, 소유 그룹이면 멤버추가) + 말풍선(받음 좌/보냄 우, 시간순).
  Widget _buildChatRoom(_Conv c, Map<String, Map<String, dynamic>> ownedByName,
      Color color, AppStateProvider appState) {
    final owned = c.isGroup ? ownedByName[c.label] : null;
    // 소유 그룹이면 owned의 groupId, 아니면 수신 그룹의 id(멤버도 그룹 대화·공유 가능)
    final groupId = (owned?['groupId'] as num?)?.toInt() ?? c.recvGroupId;
    final items = [...c.items]..sort((a, b) => a.at.compareTo(b.at)); // 오래된→최신(아래로)
    // 진입/전송 직후 맨 아래(최신)로 스크롤 — 렌더 완료 후 1회.
    if (_scrollChatToBottom && items.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _jumpChatToBottom();
        _scrollChatToBottom = false;
      });
    }
    return Column(
      children: [
        Material(
          color: color.withValues(alpha: 0.08),
          child: Row(children: [
            IconButton(
                icon: const Icon(Icons.arrow_back), color: color,
                onPressed: () {
                  setState(() => _openConvKey = null);
                  // 목록 복귀 → 칩 바 + FAB 다시 표시
                  context.read<AppStateProvider>().setHomeChatOpen(false);
                }),
            Icon(c.isGroup ? Icons.group : Icons.person, size: 18, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(c.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            if (c.isGroup && owned != null)
              IconButton(
                icon: const Icon(Icons.group_add), color: color, tooltip: '멤버 추가',
                onPressed: () async {
                  await showGroupMembersDialog(context, groupId!, c.label);
                  if (mounted) context.read<AppStateProvider>().reloadShareGroups();
                }),
          ]),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text('대화를 시작해 보세요.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)))
              : RefreshIndicator(
                  onRefresh: () => appState.loadShares(),
                  child: ListView.builder(
                    controller: _chatScrollCtrl,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final it = items[i];
                      final cur = DateTime(it.at.year, it.at.month, it.at.day);
                      final prev = i == 0 ? null : items[i - 1].at;
                      final showDay = prev == null ||
                          DateTime(prev.year, prev.month, prev.day) != cur;
                      return Column(children: [
                        if (showDay) _dateHeader(cur, color),
                        _bubble(it, color, appState),
                      ]);
                    },
                  ),
                ),
        ),
        // 하단 메시지 입력 — 1:1 또는 내가 소유한 그룹에서만(그룹 메시지는 소유자만 발신)
        if (!c.isGroup || groupId != null)
          _chatInput(c, groupId, color, appState)
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            color: Colors.grey.shade100,
            child: Text('이 그룹은 소유자만 메시지를 보낼 수 있습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ),
      ],
    );
  }

  /// 대화방 하단 메시지 입력창.
  Widget _chatInput(_Conv c, int? groupId, Color color, AppStateProvider appState) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: color.withValues(alpha: 0.15))),
        ),
        child: Row(children: [
          // 파일 공유 — 전체 파일 목록에서 골라 이 대화에 공유(나와의 대화는 로컬 텍스트 전용이라 숨김)
          if (!c.isSelf)
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: color),
              tooltip: '파일 공유',
              onPressed: () => _showFileShareSheet(c, groupId, appState),
            ),
          Expanded(
            // 하드웨어 Enter → 전송, Shift+Enter → 줄바꿈. 소프트 키보드는 textInputAction.send.
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    (event.logicalKey == LogicalKeyboardKey.enter ||
                        event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
                    !HardwareKeyboard.instance.isShiftPressed) {
                  _sendMsg(c, groupId, appState);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                controller: _msgCtrl,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: '메시지 입력',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onSubmitted: (_) => _sendMsg(c, groupId, appState),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: Icon(Icons.send, color: color),
            onPressed: () => _sendMsg(c, groupId, appState),
          ),
        ]),
      ),
    );
  }

  Future<void> _sendMsg(_Conv c, int? groupId, AppStateProvider appState) async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    _scrollChatToBottom = true; // 전송 후 최신이 보이도록
    // 나와의 대화(로컬 셀프 채팅) — 서버 전송 없이 로컬에 저장.
    if (c.isSelf) {
      await appState.addSelfChatMessage(c.key.substring(5), text); // 'self:' 제거
      return;
    }
    final r = await appState.sendChatMessage(
      targetType: c.isGroup ? 'group' : 'user',
      recipientKey: c.isGroup ? null : (c.email ?? c.key.substring(2)),
      groupId: c.isGroup ? groupId : null,
      content: text,
    );
    if (mounted && !r.ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(r.message ?? '전송 실패')));
    }
  }

  /// + 버튼 — 전체 리튼의 파일 목록을 모아 시트로 보여주고, 고른 파일을 이 대화에 공유.
  Future<void> _showFileShareSheet(_Conv c, int? groupId, AppStateProvider appState) async {
    final color = Theme.of(context).primaryColor;
    final fs = FileStorageService.instance;
    final appDir = await getApplicationDocumentsDirectory();
    final entries = <_FileEntry>[];
    for (final lit in appState.littens) {
      for (final t in await fs.loadTextFiles(lit.id)) {
        entries.add(_FileEntry(
          type: t.isFromSTT ? 'stt_text' : 'text',
          name: t.displayTitle,
          icon: Icons.notes,
          path: '${appDir.path}/littens/${lit.id}/text/${t.id}.html',
          fileName: '${t.displayTitle}.html',
          contentType: 'text/html',
        ));
      }
      for (final a in await fs.loadAudioFiles(lit.id)) {
        entries.add(_FileEntry(
          type: a.isFromSTT ? 'stt_audio' : 'audio',
          name: a.fileName,
          icon: Icons.mic,
          path: a.filePath,
          fileName: '${a.fileName}.m4a',
          contentType: 'audio/m4a',
        ));
      }
      for (final h in await fs.loadHandwritingFiles(lit.id)) {
        final isPdf = h.imagePath.toLowerCase().endsWith('.pdf');
        entries.add(_FileEntry(
          type: 'handwriting',
          name: h.displayTitle,
          icon: Icons.draw,
          path: h.imagePath,
          fileName: '${h.displayTitle}${isPdf ? '.pdf' : '.png'}',
          contentType: isPdf ? 'application/pdf' : 'image/png',
        ));
      }
      for (final at in await fs.loadAttachmentFiles(lit.id)) {
        entries.add(_FileEntry(
          type: 'attachment',
          name: at.fileName,
          icon: Icons.attach_file,
          path: at.filePath,
          fileName: at.fileName,
          contentType: at.mimeType,
        ));
      }
    }
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Icon(Icons.share, size: 18, color: color),
                const SizedBox(width: 6),
                Text('파일 공유 — ${c.label}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Text('공유할 파일이 없습니다.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)))
                  : ListView.builder(
                      controller: scrollCtrl,
                      itemCount: entries.length,
                      itemBuilder: (_, i) {
                        final e = entries[i];
                        return ListTile(
                          dense: true,
                          leading: Icon(e.icon, color: color, size: 20),
                          title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () => Navigator.pop(ctx, e),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ).then((picked) async {
      if (picked is! _FileEntry || !mounted) return;
      final res = await appState.shareFile(
        filePath: picked.path,
        fileType: picked.type,
        fileName: picked.fileName,
        contentType: picked.contentType,
        targetType: c.isGroup ? 'group' : 'user',
        recipientKey: c.isGroup ? null : (c.email ?? c.key.substring(2)),
        groupId: c.isGroup ? groupId : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(res['success'] == true
                ? '공유했습니다.'
                : (res['message']?.toString() ?? '공유 실패'))));
      }
    });
  }

  /// 간결한 말풍선 — 받음=좌측, 보냄=우측. 채팅 메시지는 텍스트, 공유는 아이콘+파일명+시간.
  Widget _bubble(_ShareItem it, Color color, AppStateProvider appState) {
    // 채팅 메시지 말풍선
    if (it.isMessage) {
      final received = it.received;
      final content = it.data['content']?.toString() ?? '';
      final url = _firstUrl(content); // URL 포함 시 하단에 미리보기 카드
      return Align(
        alignment: received ? Alignment.centerLeft : Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: received ? Colors.grey.shade200 : color.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment:
                received ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(content, style: const TextStyle(fontSize: 14)),
              if (url != null) ...[
                const SizedBox(height: 6),
                _urlPreviewCard(url, color),
              ],
              const SizedBox(height: 2),
              Text(_shareWhen(it.data['sentAt']),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ],
          ),
        ),
      );
    }

    final received = it.received;
    final fname = _stripShareExt(it.data['fileName']?.toString() ?? '');
    final status = it.data['status']?.toString() ?? '';
    String? hint;
    if (received) {
      hint = status == 'pending' ? '받기 대기' : status == 'accepted' ? '저장됨' : status == 'rejected' ? '거절됨' : null;
    } else {
      final acc = (it.data['acceptedCount'] as num?)?.toInt() ?? 0;
      final pend = (it.data['pendingCount'] as num?)?.toInt() ?? 0;
      hint = '수락 $acc · 대기 $pend';
    }
    final bubble = GestureDetector(
      // 탭 → 공유 내용(스냅샷) 바로 미리보기. 길게 누르면 부가 동작(수신자 상태·공유 취소 등).
      onTap: () => _openSharedSnapshot(it),
      onLongPress: () => _showBubbleActions(it, appState),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: received ? Colors.grey.shade100 : color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_shareFileTypeIcon(it.data['fileType']?.toString()), size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(fname, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ]),
            const SizedBox(height: 3),
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (hint != null) ...[
                Text(hint, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                const SizedBox(width: 6),
              ],
              Text(_shareWhen(it.data['sharedAt']),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ]),
            if (received && status == 'pending')
              Row(mainAxisSize: MainAxisSize.min, children: [
                TextButton(
                  onPressed: () => appState.rejectReceivedShare(it.data),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 30)),
                  child: const Text('거절', style: TextStyle(color: Colors.red, fontSize: 12)),
                ),
                FilledButton(
                  onPressed: () async {
                    final r = await appState.acceptReceivedShare(it.data);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(r.ok ? '저장했습니다.' : (r.message ?? '수락 실패'))));
                    }
                  },
                  style: FilledButton.styleFrom(
                      backgroundColor: color,
                      padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: const Size(0, 30)),
                  child: const Text('수락', style: TextStyle(fontSize: 12)),
                ),
              ]),
          ],
        ),
      ),
    );
    return Align(alignment: received ? Alignment.centerLeft : Alignment.centerRight, child: bubble);
  }

  /// 말풍선 탭 — 상황별 동작(보낸 것: 수신자 상태/취소, 받은 거절: 삭제 등).
  void _showBubbleActions(_ShareItem it, AppStateProvider appState) {
    final received = it.received;
    final status = it.data['status']?.toString() ?? '';
    final actions = <Widget>[];
    // 공유 내용 보기 — 보관된 로컬 스냅샷(공유 시점 내용)을 미리보기.
    actions.add(ListTile(
      leading: const Icon(Icons.visibility_outlined),
      title: const Text('공유 내용 보기'),
      subtitle: const Text('공유했을 때의 내용', style: TextStyle(fontSize: 11)),
      onTap: () async {
        Navigator.pop(context);
        await _openSharedSnapshot(it);
      },
    ));
    if (!received) {
      final recips = (it.data['recipients'] as List?) ?? const [];
      if (recips.isNotEmpty) {
        actions.add(ListTile(
          leading: const Icon(Icons.people_outline),
          title: const Text('수신자 상태'),
          subtitle: Text(recips
              .map((r) => '${(r as Map)['memberId']} (${r['status']})')
              .join('\n')),
        ));
      }
      final shareId = (it.data['shareId'] as num?)?.toInt();
      if (shareId != null) {
        actions.add(ListTile(
          leading: const Icon(Icons.undo, color: Colors.red),
          title: const Text('공유 취소', style: TextStyle(color: Colors.red)),
          onTap: () async {
            Navigator.pop(context);
            await appState.cancelSentShare(shareId);
          },
        ));
      }
    } else if (status == 'rejected') {
      actions.add(ListTile(
        leading: const Icon(Icons.delete_outline, color: Colors.red),
        title: const Text('삭제', style: TextStyle(color: Colors.red)),
        onTap: () {
          Navigator.pop(context);
          final id = (it.data['deliveryId'] as num?)?.toInt();
          if (id != null) appState.dismissReceivedShare(id);
        },
      ));
    } else if (status == 'accepted') {
      actions.add(const ListTile(
          leading: Icon(Icons.check_circle, color: Colors.green),
          title: Text('수락되어 저장됨')));
    }
    if (actions.isEmpty) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: actions)),
    );
  }

  /// 말풍선의 공유 파일을 보관된 로컬 스냅샷으로 미리보기.
  /// 보낸 것은 shareId, 받은 것은 deliveryId로 스냅샷을 조회한다.
  Future<void> _openSharedSnapshot(_ShareItem it) async {
    final svc = SharedSnapshotService.instance;
    final appState = context.read<AppStateProvider>();
    SharedSnapshot? snap;
    if (it.received) {
      final did = (it.data['deliveryId'] as num?)?.toInt();
      if (did != null) snap = await svc.findReceived(did);
      // 폴백: deliveryId로 못 찾으면 shareId로 시도
      if (snap == null) {
        final sid = (it.data['shareId'] as num?)?.toInt();
        if (sid != null) snap = await svc.findByShareId(sid);
      }
      // 백필: 스냅샷이 없으면(옛 공유 등) 서버에서 다시 받아 보관 후 미리보기.
      if (snap == null && (it.data['status']?.toString() ?? '') == 'accepted') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('공유 내용을 불러오는 중...'), duration: Duration(seconds: 1)));
        }
        snap = await appState.ensureReceivedSnapshot(it.data);
      }
    } else {
      final sid = (it.data['shareId'] as num?)?.toInt();
      if (sid != null) snap = await svc.findSent(sid);
    }
    if (!mounted) return;
    if (snap == null) {
      // 상태별 안내: 미수락 받은 공유 / 보관 이전에 만든 옛 공유
      final status = it.data['status']?.toString() ?? '';
      final msg = it.received
          ? (status == 'accepted'
              ? '공유 내용을 불러올 수 없습니다. 발신자가 공유를 취소했을 수 있습니다.'
              : '먼저 수락하면 공유 내용을 볼 수 있습니다.')
          : '이 공유는 보관 기능 이전에 전송되어 내용을 볼 수 없습니다. 이후 공유부터 보관됩니다.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
    await showSharedSnapshot(context, snap);
  }

  static final RegExp _urlRe = RegExp(r'https?://[^\s]+', caseSensitive: false);

  /// 메시지 본문에서 첫 번째 http(s) URL을 찾는다(없으면 null). 끝의 문장부호는 제거.
  String? _firstUrl(String text) {
    final m = _urlRe.firstMatch(text);
    if (m == null) return null;
    var url = m.group(0)!;
    // 문장 끝에 붙은 흔한 마침표류 제거
    while (url.isNotEmpty && '.,)]}>"\''.contains(url[url.length - 1])) {
      url = url.substring(0, url.length - 1);
    }
    return url.isEmpty ? null : url;
  }

  /// URL 미리보기 카드 — 링크/도메인 + 열기. 탭하면 인앱 브라우저로 연다.
  Widget _urlPreviewCard(String url, Color color) {
    String host = url;
    try {
      host = Uri.parse(url).host;
    } catch (_) {}
    return GestureDetector(
      onTap: () => _openUrl(url),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.public, size: 18, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(host,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                Text(url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.open_in_new, size: 14, color: Colors.grey.shade500),
        ]),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('링크를 열 수 없습니다.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('링크를 열 수 없습니다.')));
      }
    }
  }

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
  final String group; // 그룹명 (없으면 빈 문자열 → 개인)
  final bool isMessage; // true면 채팅 메시지(텍스트), false면 파일 공유
  _ShareItem({
    required this.received,
    required this.data,
    required this.at,
    required this.group,
    this.isMessage = false,
  });
}

/// 채팅 대화 단위 — 상대(개인 이메일) 또는 그룹. 받은/보낸 공유를 모아 둔다.
class _Conv {
  final String key;       // 'g:그룹명' 또는 'u:이메일'
  final bool isGroup;
  final int? groupId;     // 내가 소유한 그룹일 때만
  final String? email;    // 개인 대화 상대 이메일
  String label;           // 표시명(그룹명 또는 닉네임/이메일)
  String? recvGroupPassword; // 수신 그룹(남의 그룹)의 비밀번호 — 수신자 잠금 해제 검증용
  int? recvGroupId;       // 수신 그룹의 id — 멤버가 그룹 대화/공유에 사용
  final bool isSelf;      // 나와의 대화(로컬 셀프 채팅방)인지
  final List<_ShareItem> items = [];
  _Conv({required this.key, required this.isGroup, this.groupId, this.email,
      required this.label, this.isSelf = false});

  DateTime get lastAt => items.isEmpty
      ? DateTime(2000)
      : items.map((e) => e.at).reduce((a, b) => a.isAfter(b) ? a : b);

  _ShareItem? get last {
    if (items.isEmpty) return null;
    var m = items.first;
    for (final e in items) {
      if (e.at.isAfter(m.at)) m = e;
    }
    return m;
  }
}

/// + 파일 공유 시트의 파일 한 건.
class _FileEntry {
  final String type;        // text/stt_text/audio/stt_audio/handwriting/attachment
  final String name;        // 표시명
  final IconData icon;
  final String path;        // 로컬 파일 경로
  final String fileName;    // 업로드 파일명(확장자 포함)
  final String? contentType;
  _FileEntry({
    required this.type,
    required this.name,
    required this.icon,
    required this.path,
    required this.fileName,
    this.contentType,
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

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/litten.dart';
import 'login_screen.dart';
import '../services/app_state_provider.dart';
import '../services/file_storage_service.dart';
import '../services/shared_snapshot_service.dart';
import '../widgets/share_compose_dialog.dart';
import '../widgets/shared_snapshot_viewer.dart';
import '../widgets/common/tab_count_title.dart';
import '../widgets/common/round_chat_bubble_icon.dart';

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
    // 칩 바는 '채팅' 모드이고 대화방이 안 열렸을 때만 표시한다.
    //  - 대화방 안: 숨김(입력창이 하단 메뉴 바로 위까지)
    //  - 공유받음/공유한 모드: 숨김(파일 일자순 목록만)
    final app = context.watch<AppStateProvider>();
    final showChip = !app.homeChatOpen && app.homeChatView == 'chat';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _ShareSection(key: _shareKey)),
        if (showChip) const _HomeChipBar(),
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
/// 새 채팅 + 동그라미는 우측 하단 FAB(MainTabScreen)로 빠졌고,
/// 바 가운데에는 전체탭 제목처럼 수신(↓)·발신(↑) 파일 카운트를 표시한다.
class _HomeChipBar extends StatelessWidget {
  const _HomeChipBar();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    final app = context.watch<AppStateProvider>();
    // 채팅의 모든 파일(수신 + 발신 + 나와의 대화)을 종류별로 집계 — 전체탭 제목과 동일 형식.
    final files = <Map<String, dynamic>>[
      ...app.sharesReceived,
      ...app.sharesSent,
      ...app.selfChatFiles.map((e) => e['item'] as Map<String, dynamic>),
    ];
    // 종류별 카운트(fileType + 파일명 확장자로 pdf/사진/비디오 구분 — 전체탭 아이콘과 일치).
    final counts = <String, int>{};
    for (final f in files) {
      final k = _shareFileKind(
          f['fileType']?.toString(), f['fileName']?.toString());
      counts.update(k, (v) => v + 1, ifAbsent: () => 1);
    }

    // 카운트 0이면 숨김. 순서: 메모→필기→PDF→녹음→녹음메모→파일→사진→비디오.
    // 칩을 누르면 해당 종류 파일 목록으로 전환(같은 칩 재탭 시 대화 목록 복귀).
    final selectedKind = app.homeChatFileKind;
    final chips = <Widget>[];
    void add(String kind, IconData icon, int n) {
      if (n <= 0) return;
      if (chips.isNotEmpty) chips.add(const SizedBox(width: 12));
      final selected = selectedKind == kind;
      chips.add(GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.read<AppStateProvider>().setHomeChatFileKind(kind),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: selected
              ? BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10))
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 상단 탭제목(TabCountTitle)과 동일한 아이콘 17 / 카운트 10.4 크기로 통일.
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 2),
              // 카운트를 살짝 아래로 내려 탭제목의 '하단정렬' 느낌과 맞춘다(레이아웃 불변, 시각만 이동).
              Transform.translate(
                offset: const Offset(0, 2),
                child: Text('$n',
                    style: TextStyle(
                        fontSize: 10.4,
                        fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                        color: color)),
              ),
            ],
          ),
        ),
      ));
    }
    add('memo', Icons.notes, counts['memo'] ?? 0);
    add('summary_memo', Icons.summarize, counts['summary_memo'] ?? 0);
    add('quiz_memo', Icons.quiz, counts['quiz_memo'] ?? 0);
    add('canvas', Icons.draw, counts['canvas'] ?? 0);
    add('pdf', Icons.picture_as_pdf, counts['pdf'] ?? 0);
    add('audio', Icons.mic, counts['audio'] ?? 0);
    add('stt', Icons.record_voice_over, counts['stt'] ?? 0);
    add('files', Icons.description, counts['files'] ?? 0);
    add('photo', Icons.photo_camera, counts['photo'] ?? 0);
    add('video', Icons.videocam, counts['video'] ?? 0);

    // 아이콘(칩)이 아닌 빈 영역을 탭하면 종류 무관 '전체' 파일을 일자순으로 표시한다.
    // (각 칩은 자체 GestureDetector가 있어 해당 종류로 동작하고, 그 외 영역만 'all'로 처리)
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.read<AppStateProvider>().setHomeChatFileKind('all'),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border(top: BorderSide(color: color.withValues(alpha: 0.15))),
        ),
        // 노트(_CreateChipBar)·캘린더 칩 바와 동일한 세로 패딩(9) + 콘텐츠 높이(28.0)로
        // 바 전체 높이를 그 둘(123px ≒ 46.9dp)과 정확히 일치시킨다(= 9*2 + 28.0).
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: SizedBox(
          height: 28.0,
          child: Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: chips),
          ),
        ),
      ),
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

/// 공유 파일을 전체탭과 동일한 "종류 키"로 분류한다(fileType + 파일명 확장자).
/// memo·canvas·pdf·audio·stt·photo·video·files
String _shareFileKind(String? t, [String? fileName, String? contentType]) {
  final n = (fileName ?? '').toLowerCase();
  final ct = (contentType ?? '').toLowerCase();
  switch (t) {
    case 'text':
      return 'memo';
    case 'smry_text':
      return 'summary_memo'; // 요약을 담은 메모
    case 'quiz_text':
      return 'quiz_memo'; // 퀴즈를 담은 메모
    case 'audio':
      return 'audio';
    case 'stt_text':
    case 'stt_audio':
      return 'stt'; // 녹음 메모(STT)
    case 'handwriting':
      return n.endsWith('.pdf') ? 'pdf' : 'canvas'; // 필기 이미지 vs PDF
    default:
      // 파일명 확장자 또는 contentType(image/*·video/*)으로 판별 — 받은 공유는 파일명에 확장자가
      // 없어도 서버가 준 contentType으로 사진/영상 아이콘을 보냄쪽과 일치시킨다.
      if (RegExp(r'\.(jpg|jpeg|png|gif|webp|heic|heif|bmp)$').hasMatch(n) ||
          ct.startsWith('image/')) return 'photo';
      if (RegExp(r'\.(mp4|mov|avi|mkv|webm|m4v)$').hasMatch(n) ||
          ct.startsWith('video/')) return 'video';
      return 'files';
  }
}

/// 공유 파일 아이콘 — 전체탭 제목/리스트와 동일한 매핑.
IconData _shareFileTypeIcon(String? t, [String? fileName, String? contentType]) {
  switch (_shareFileKind(t, fileName, contentType)) {
    case 'memo':
      return Icons.notes;
    case 'summary_memo':
      return Icons.summarize; // 요약 메모
    case 'quiz_memo':
      return Icons.quiz; // 퀴즈 메모
    case 'canvas':
      return Icons.draw;
    case 'pdf':
      return Icons.picture_as_pdf;
    case 'audio':
      return Icons.mic;
    case 'stt':
      return Icons.record_voice_over;
    case 'photo':
      return Icons.photo_camera;
    case 'video':
      return Icons.videocam;
    default:
      return Icons.description;
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
        // '공유한' 카운트 = 서버로 보낸 공유 + 나와의 대화에 추가한 파일.
        final outN = app.sharesSent.length + app.selfChatFileCount;
        // 표시 모드 전환(라디오식): 채팅(기본 선택) | 공유받음 | 공유한.
        // 선택된 것만 밝게(active) 보이고, 받음/보냄은 선택 시 공유 파일을 일자순 리스트로 보여준다.
        final mode = app.homeChatView;
        return TabCountTitle([
          [
            TabCount(Icons.chat_bubble_outline, chatN,
                iconWidget: RoundChatBubbleIcon(filled: mode == 'chat', size: 20),
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

class _ShareSectionState extends State<_ShareSection>
    with SingleTickerProviderStateMixin {
  // 하단 칩 종류 파일 목록 패널 슬라이드업(0→50%) 애니메이션.
  late final AnimationController _paneAnim;
  String? _reqPaneKind; // 마지막으로 애니메이션 구동에 반영한 종류
  String? _paneKind; // 패널에 표시 중인 종류(닫히는 동안 유지)
  // 현재 열린 대화방 key (null이면 대화 목록 화면). 'g:그룹명' 또는 'u:이메일'
  // 열린 대화방 key는 AppStateProvider.homeOpenConvKey(단일 소스)를 사용한다.
  // 비밀번호를 한 번 맞춰 잠금 해제된 그룹 이름 (다음부터 안 물어봄 — 영구 저장)
  // 잠금 그룹 인증 상태는 AppStateProvider(영구 저장, 앱 시작 시 1회 로드)에서 관리한다.
  // 대화방 하단 메시지 입력
  final TextEditingController _msgCtrl = TextEditingController();
  // 대화방 메시지 리스트 스크롤 — 진입/전송 시 맨 아래(최신)로 이동
  final ScrollController _chatScrollCtrl = ScrollController();
  bool _scrollChatToBottom = false;
  // 대화별 마지막 읽은 시각 (미읽음 메시지 뱃지용 — 영구 저장)
  final Map<String, DateTime> _convLastRead = {};
  static const String _convReadKey = 'conv_last_read';
  // 방나가기(숨김) 상태는 AppStateProvider(로컬 캐시 + 서버 동기화)에서 관리한다.

  @override
  void dispose() {
    _msgCtrl.dispose();
    _chatScrollCtrl.dispose();
    _paneAnim.dispose();
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
  /// 대화를 읽음으로 표시(미읽음 뱃지 제거) + 영구 저장.
  /// [upTo]는 이 대화의 최신 항목 시각(c.lastAt). 메시지 at은 서버 시각이라 기기 로컬 now보다
  /// 앞설 수 있으므로(타임존 차이), now와 최신 항목 시각 중 더 늦은 시각으로 읽음 처리해야
  /// 미읽음 카운트가 확실히 0이 된다.
  void _markConvRead(String key, [DateTime? upTo]) {
    final now = DateTime.now();
    final t = (upTo != null && upTo.isAfter(now)) ? upTo : now;
    _convLastRead[key] = t;
    SharedPreferences.getInstance().then((p) => p.setString(
        _convReadKey,
        jsonEncode(_convLastRead.map((k, v) => MapEntry(k, v.toIso8601String())))));
    if (mounted) setState(() {});
  }

  void _openConv(String key, [DateTime? readUpTo]) {
    _markConvRead(key, readUpTo); // 진입 시 읽음 처리(최신 항목 시각까지)
    _scrollChatToBottom = true; // 진입 시 최신(맨 아래)이 보이도록
    // 대화방 상태는 provider 단일 소스 — 진입 시 열린 대화방 key를 설정하면
    // build(watch)가 대화방을 표시하고 하단 칩 바·새 채팅 FAB가 숨겨진다.
    context.read<AppStateProvider>().setHomeOpenConvKey(key);
  }

  @override
  void initState() {
    super.initState();
    _paneAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _loadConvRead();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppStateProvider>();
      app.loadShares();
      app.loadSelfChats();
      app.loadHiddenConvs();
    });
  }

  /// 대화 이름 수정 다이얼로그 — 그룹/1:1/나와의 대화 모두.
  /// 나와의 대화는 실제 이름 변경, 그룹/1:1은 내 화면 표시 이름(로컬 별칭) 지정.
  Future<void> _renameConv(_Conv c) async {
    final appState = context.read<AppStateProvider>();
    // 내가 소유한 그룹이면 groupId를 찾아 서버 이름변경(다기기·멤버 동기화) 대상으로 삼는다.
    int? ownedGid;
    if (c.isGroup && c.key.startsWith('g:')) {
      final origName = c.key.substring(2);
      for (final g in appState.shareGroups) {
        if ((g['name']?.toString() ?? '') == origName) {
          ownedGid = (g['groupId'] as num?)?.toInt();
          break;
        }
      }
    }
    // 내 것(나와의 대화·소유 그룹)은 실제 이름 변경, 남의 그룹·1:1은 로컬 별칭.
    final isRealRename = c.isSelf || ownedGid != null;
    final ctrl = TextEditingController(text: c.label);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이름 수정', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: '채팅방 이름', isDense: true, border: OutlineInputBorder()),
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            ),
            if (!isRealRename)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('내 화면에만 표시되는 이름입니다.',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              )
            else if (ownedGid != null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('참여한 모든 사람에게 반영됩니다.',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('저장')),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    if (c.isSelf) {
      await appState.renameSelfChat(c.key.substring(5), newName); // 'self:' 제거
    } else if (ownedGid != null) {
      // 소유 그룹 — 서버에서 실제 이름 변경(다기기·멤버 동기화).
      final ok = await appState.renameShareGroup(ownedGid, newName);
      if (ok) {
        await appState.setConvCustomName(c.key, ''); // 남아있던 로컬 별칭 제거
        // 그룹명이 바뀌면 대화 key도 'g:새이름'으로 바뀌므로 열린 방 key도 갱신.
        if (appState.homeOpenConvKey == c.key) {
          appState.setHomeOpenConvKey('g:$newName');
        }
      } else if (mounted) {
        // 서버 실패 시 최소한 내 화면 별칭이라도 적용.
        await appState.setConvCustomName(c.key, newName);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('서버 이름 변경 실패 — 내 화면에만 적용했습니다.')));
      }
    } else {
      await appState.setConvCustomName(c.key, newName); // 남의 그룹·1:1 → 로컬 별칭
    }
  }

  /// 방나가기/삭제 — 해당 대화의 공유 파일(보관 스냅샷 + 목록 항목)을 모두 정리한다.
  /// 나와의 대화는 방 자체 삭제, 그 외는 숨김(서버 동기화 · 새 활동이 오면 다시 보임).
  Future<void> _leaveConv(_Conv c) async {
    final appState = context.read<AppStateProvider>();
    final isSelf = c.isSelf;
    // 이 대화에 속한 공유 파일 식별 (메시지 제외).
    final deliveryIds = <int>[];
    final shareIds = <int>[];
    for (final it in c.items) {
      if (it.isMessage) continue;
      if (it.received) {
        final d = (it.data['deliveryId'] as num?)?.toInt();
        if (d != null) deliveryIds.add(d);
      } else {
        final s = (it.data['shareId'] as num?)?.toInt();
        if (s != null) shareIds.add(s);
      }
    }
    final fileCount = deliveryIds.length + shareIds.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isSelf ? '대화 삭제' : '방 나가기', style: const TextStyle(fontSize: 16)),
        content: Text(isSelf
            ? '"${c.label}"을(를) 삭제할까요? 이 안의 내용도 함께 삭제됩니다.'
            : '"${c.label}" 대화에서 나갈까요?'
                '${fileCount > 0 ? '\n이 대화에 공유된 파일 $fileCount개도 목록에서 삭제됩니다.' : ''}'
                '\n(새 메시지·공유가 오면 다시 표시됩니다.)'),
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
    // 1) 보관된 스냅샷(공유 시점 복사본) 삭제
    final snapKeys = [
      ...deliveryIds.map((d) => 'recv:$d'),
      ...shareIds.map((s) => 'sent:$s'),
    ];
    await SharedSnapshotService.instance.deleteByKeys(snapKeys);
    // 2) 공유 항목을 내 목록에서 제거(받은=dismiss, 보낸=로컬 숨김) → 카운트도 함께 줄어듦
    for (final d in deliveryIds) {
      await appState.dismissReceivedShare(d);
    }
    for (final s in shareIds) {
      await appState.dismissSentShare(s);
    }
    // 3) 방 자체 처리
    if (isSelf) {
      await appState.deleteSelfChat(c.key.substring(5));
    } else {
      await appState.hideConversation(c.key); // 로컬 즉시 + 서버 동기화
    }
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
      await context.read<AppStateProvider>().unlockGroup(name); // 영구 저장(재시작 유지)
      if (!mounted) return;
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

    // 하단 칩 선택 시: 해당 종류 파일 목록 패널을 아래에서 위로 50%까지 슬라이드업(대화 목록은 위에 유지).
    final kindFilter = appState.homeChatOpen ? null : appState.homeChatFileKind;
    if (kindFilter != _reqPaneKind) {
      _reqPaneKind = kindFilter;
      if (kindFilter != null) _paneKind = kindFilter;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (kindFilter != null) {
          _paneAnim.forward();
        } else {
          _paneAnim.reverse();
        }
      });
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
      // 개인 대화 라벨: 닉네임이 있으면 닉네임만, 없으면 아이디(이메일)만. (닉네임 우선)
      // 서버가 senderName/수신자 name을 '현재 닉네임'으로 주므로 상대가 닉네임을 바꾸면 반영된다.
      if (!isGroup) {
        final em = email ?? '';
        if (it.received) {
          // 받은 항목: 발신자(상대) 현재 닉네임
          final sn = it.data['senderName']?.toString() ?? '';
          if (sn.isNotEmpty && sn != em) conv.label = sn;
        } else {
          // 보낸 항목: 수신자(상대) 현재 닉네임 (보낸 전용 대화 대비)
          final recips = (it.data['recipients'] as List?) ?? const [];
          if (recips.isNotEmpty) {
            final rn = (recips.first as Map)['name']?.toString() ?? '';
            if (rn.isNotEmpty && rn != em) conv.label = rn;
          }
        }
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
        final isFile = m['type'] == 'file';
        conv.items.add(_ShareItem(
            received: false,
            data: isFile
                ? {
                    'fileName': m['fileName'],
                    'fileType': m['fileType'],
                    'sharedAt': m['sentAt'],
                    '__selfFile': true,
                    '__chatId': id,
                    '__item': m,
                  }
                : m,
            at: _parseAt(m['sentAt']),
            group: '', isMessage: !isFile));
      }
    }

    // 사용자가 지정한 대화 표시 이름(로컬 별칭) 적용 — 그룹/1:1. (나와의 대화는 sc['name'] 사용)
    for (final conv in convs.values) {
      final custom = appState.convCustomName(conv.key);
      if (custom != null && custom.isNotEmpty) conv.label = custom;
    }

    // 열린 대화방 — 없으면(새 채팅 등) key로 임시 대화 생성. 상태는 provider 단일 소스.
    _Conv? open;
    final openKey = appState.homeOpenConvKey;
    if (openKey != null) {
      open = convs[openKey];
      if (open == null) {
        final k = openKey;
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

    final convList = convs.values
        .where((c) => !appState.isConversationHidden(c.key, c.lastAt))
        .toList()
      ..sort((a, b) => b.lastAt.compareTo(a.lastAt));
    // 아이콘 사람 수 산정 시 '나와의 채팅'(상대가 나 자신) 판별용 내 이메일(memberId).
    final myEmail = appState.currentUser?.id ?? '';

    // 새 채팅 진입점은 하단 칩 바의 + 버튼으로 일원화(기존 우측 하단 FAB 제거).
    final convBody = RefreshIndicator(
      onRefresh: () async {
        // 당겨서 새로고침 — 공유 + 나와의 대화(이름/항목)까지 다시 동기화.
        await appState.loadShares();
        await appState.loadSelfChats();
      },
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
    // 대화 목록은 위에 유지 + 하단 칩 종류 파일 패널을 아래에서 0→50%로 스무스하게 슬라이드업.
    return LayoutBuilder(
      builder: (context, constraints) {
        final halfH = constraints.maxHeight * 0.5;
        return AnimatedBuilder(
          animation: _paneAnim,
          builder: (context, _) {
            final t = Curves.easeOut.transform(_paneAnim.value);
            final paneH = halfH * t;
            return Column(
              children: [
                Expanded(child: convBody),
                SizedBox(
                  height: paneH,
                  child: paneH < 1
                      ? const SizedBox.shrink()
                      : ClipRect(
                          child: OverflowBox(
                            minHeight: 0,
                            maxHeight: halfH,
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              height: halfH,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  border: Border(
                                      top: BorderSide(color: color.withValues(alpha: 0.15))),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 6,
                                        offset: const Offset(0, -2)),
                                  ],
                                ),
                                child: _paneKind != null
                                    ? _buildChatFileKindList(appState, color, _paneKind!)
                                    : const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 공유받음/공유한 모드 — 파일 건을 일자순(최신→과거)으로 나열. 탭하면 미리보기.
  /// '공유한' 모드에는 나와의 대화에 추가한 파일도 함께 포함(제목 카운트와 일치).
  Widget _buildSharedFileList(String mode, AppStateProvider appState, Color color) {
    final received = mode == 'received';
    // 각 행: {fileType, fname, subtitle, dateIso, onTap}
    final rows = <Map<String, dynamic>>[];
    final raw = received ? appState.sharesReceived : appState.sharesSent;
    for (final s in raw) {
      final it = _ShareItem(
          received: received, data: s, at: _parseAt(s['sharedAt']),
          group: (s['groupName']?.toString() ?? '').trim());
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
      rows.add({
        'fileType': s['fileType'],
        'fileName': s['fileName'], // 아이콘 판별용 원본 파일명(확장자 포함)
        'contentType': s['contentType'],
        'fname': _stripShareExt(s['fileName']?.toString() ?? ''),
        'subtitle': '${received ? '보낸이' : '받는이'}: $peer',
        'dateIso': s['sharedAt']?.toString() ?? '',
        'onTap': () => _openSharedSnapshot(it),
      });
    }
    // 공유한 모드 — 나와의 대화 파일 포함
    if (!received) {
      for (final f in appState.selfChatFiles) {
        final item = f['item'] as Map<String, dynamic>;
        final chatId = f['chatId']?.toString() ?? '';
        final selfIt = _ShareItem(
            received: false,
            data: {
              'fileName': item['fileName'], 'fileType': item['fileType'],
              'sharedAt': item['sentAt'], '__selfFile': true,
              '__chatId': chatId, '__item': item,
            },
            at: _parseAt(item['sentAt']), group: '');
        rows.add({
          'fileType': item['fileType'],
          'fileName': item['fileName'],
          'contentType': item['contentType'],
          'fname': _stripShareExt(item['fileName']?.toString() ?? ''),
          'subtitle': '나와의 대화: ${f['chatName']}',
          'dateIso': item['sentAt']?.toString() ?? '',
          'onTap': () => _openSelfChatFile(selfIt),
        });
      }
    }
    rows.sort((a, b) => _parseAt(b['dateIso']).compareTo(_parseAt(a['dateIso'])));
    return RefreshIndicator(
      onRefresh: () => appState.loadShares(),
      child: rows.isEmpty
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
              itemCount: rows.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: color.withValues(alpha: 0.08)),
              itemBuilder: (_, i) {
                final r = rows[i];
                return ListTile(
                  leading: Icon(_shareFileTypeIcon(r['fileType']?.toString(), r['fileName']?.toString(), r['contentType']?.toString()), color: color),
                  title: Text(r['fname']?.toString() ?? '',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text(r['subtitle']?.toString() ?? '',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  trailing: Text(_shareWhen(r['dateIso']),
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                  onTap: r['onTap'] as VoidCallback,
                );
              },
            ),
    );
  }

  /// + 버튼 진입점 — 새 채팅 팝업(1:1 / 그룹 / 나).
  void startNewChat() => _startNewChat();

  Future<void> _startNewChat() async {
    final appState = context.read<AppStateProvider>();
    // 채팅은 로그인 필수 — 비로그인 시 회원가입/로그인 안내
    if (!appState.isLoggedIn) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('로그인 필요', style: TextStyle(fontSize: 16)),
          content: const Text('채팅 기능은 회원가입 후 로그인이 필요합니다.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
              child: const Text('로그인'),
            ),
          ],
        ),
      );
      return;
    }
    final groups = appState.shareGroups;
    final color = Theme.of(context).primaryColor;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => DefaultTabController(
        length: 3,
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
                  tabs: const [Tab(text: '1:1'), Tab(text: '그룹'), Tab(text: '나')],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // 1:1 탭 — 이메일/닉네임 검색 후(가입 회원 확인) 대화 시작
                      _NewChatOneToOneTab(
                        color: color,
                        onSearch: (q) => appState.authService.searchMember(q),
                        onStart: (email) => Navigator.pop(ctx, 'u:$email'),
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
                      // 나 탭 — 나와의 대화(로컬 셀프 채팅) 만들기. 여러 개 가능.
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('나 혼자 쓰는 채팅방이에요.\n메모처럼 자유롭게 기록할 수 있어요. (여러 개 가능)',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.pop(ctx, '__selfchat__'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: color, foregroundColor: Colors.white),
                              icon: const Icon(Icons.person, size: 18),
                              label: const Text('나와의 대화'),
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
    if (result == '__selfchat__') {
      final room = await appState.createSelfChat();
      if (mounted) _openConv('self:${room['id']}');
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
    // 그룹 인원: 여러 근거 중 가장 큰 값(가장 정확한 인원)을 채택 — 데이터 누락 시 과소집계 방지.
    //  1) 대화에 등장한 참여자(발신자+수신자들+나) distinct
    //  2) recipients 개수(+발신자)
    //  3) 서버가 준 그룹 멤버 수(오너 제외) + 1(오너)  ← 받은 그룹 정확 산정
    //  4) 내가 만든 그룹의 memberCount + 1(나)
    final people = <String>{};
    if (myEmail.isNotEmpty) people.add(myEmail);
    int maxR = 0;
    int byServer = 0;
    for (final it in c.items) {
      final sender = it.data['senderMemberId']?.toString() ?? '';
      if (sender.isNotEmpty) people.add(sender);
      final recips = (it.data['recipients'] as List?) ?? const [];
      for (final r in recips) {
        final rid = (r is Map) ? (r['memberId']?.toString() ?? '') : (r?.toString() ?? '');
        if (rid.isNotEmpty) people.add(rid);
      }
      if (recips.length > maxR) maxR = recips.length;
      final gmc = it.data['groupMemberCount'];
      if (gmc is num) {
        final total = gmc.toInt() + 1; // +오너
        if (total > byServer) byServer = total;
      }
    }
    final origGroupName = c.key.startsWith('g:') ? c.key.substring(2) : c.label;
    final owned = ownedByName[origGroupName];
    final mcPlus = owned != null ? (((owned['memberCount'] as num?)?.toInt() ?? 0) + 1) : 0;
    final byRecips = maxR > 0 ? maxR + 1 : 0;
    int result = people.length;
    for (final v in [byRecips, byServer, mcPlus]) {
      if (v > result) result = v;
    }
    return result > 0 ? result : 2;
  }

  /// 참여자 아바타 — 인원수만큼(1~5명, 5명 이상은 5명) 사람 아이콘을 가로로 겹쳐 보여준다.
  /// 1명은 단독으로 크게 표시한다.
  Widget _peopleAvatar(int count, Color color, bool owned, {bool mine = false}) {
    final n = count.clamp(1, 5);
    final Widget avatar;
    if (n == 1) {
      avatar = CircleAvatar(
        radius: 20,
        backgroundColor: color.withValues(alpha: mine ? 0.2 : 0.12),
        child: Icon(Icons.person, color: color, size: 22),
      );
    } else {
      const s = 15.0;    // 개별 사람 아이콘 크기
      const step = 8.0;  // 겹침 간격
      final w = s + (n - 1) * step;
      avatar = CircleAvatar(
        radius: 20,
        backgroundColor: color.withValues(alpha: (owned || mine) ? 0.2 : 0.12),
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
    if (!mine) return avatar;
    // 내가 만든 대화창(소유 그룹·나와의 대화) — 우하단 별 뱃지로 구분.
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Icon(Icons.star, size: 10, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// 대화 목록 한 줄 (상대/그룹). 탭하면 대화방 진입(잠금 그룹은 비밀번호 확인).
  Widget _convRow(_Conv c, Map<String, Map<String, dynamic>> ownedByName, Color color,
      String myEmail) {
    // 소유 그룹 판별은 원래 그룹명(key 'g:이름') 기준 — 표시 이름을 바꿔도 정확히 유지.
    final origGroupName = (c.isGroup && c.key.startsWith('g:')) ? c.key.substring(2) : null;
    final owned = origGroupName != null ? ownedByName[origGroupName] : null;
    final isOwned = owned != null;
    // 발신자(그룹 소유자)는 항상 열림. 수신자는 그룹 비번이 있으면 한 번 입력해 해제.
    final recvPw = (c.isGroup && !isOwned) ? c.recvGroupPassword : null;
    final locked = recvPw != null && recvPw.isNotEmpty &&
        !context.read<AppStateProvider>().isGroupUnlocked(c.label);
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
      leading: _peopleAvatar(_peopleCount(c, ownedByName, myEmail), color, isOwned,
          mine: isOwned || c.isSelf),
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
          // 세로 ... 메뉴 — (내가 만든 나와의 대화) 이름 수정 + 방나가기/삭제
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey.shade500, size: 20),
            padding: EdgeInsets.zero,
            tooltip: '메뉴',
            onSelected: (v) {
              if (v == 'leave') _leaveConv(c);
              else if (v == 'rename') _renameConv(c);
            },
            itemBuilder: (_) => [
              // 내가 만든 채팅방(나와의 대화 + 내가 만든 그룹)만 이름 수정 가능. 1:1/받은 그룹은 제외.
              if (c.isSelf || isOwned)
                PopupMenuItem<String>(
                  value: 'rename',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, size: 18, color: color),
                    const SizedBox(width: 8),
                    const Text('이름 수정'),
                  ]),
                ),
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
    // 소유 그룹 판별은 원래 그룹명(key 'g:이름') 기준 — 이름을 바꿔도 정확히 유지.
    // (c.label은 로컬 별칭으로 바뀔 수 있어 ownedByName 조회 키로 쓰면 안 됨)
    final origName = (c.isGroup && c.key.startsWith('g:')) ? c.key.substring(2) : null;
    final owned = origName != null ? ownedByName[origName] : null;
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
                  // 나가기 전 최신 항목 시각까지 읽음 처리 → 방에서 본(새로고침 포함) 내용은 미읽음 카운트에서 제거.
                  _markConvRead(c.key, c.lastAt);
                  // 목록 복귀(provider 단일 소스) → 칩 바 + FAB 다시 표시
                  context.read<AppStateProvider>().setHomeOpenConvKey(null);
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
                  onRefresh: () async {
                    // 위로 당기면 대화 내용(공유+메시지) 새로고침 + 읽음 처리.
                    await appState.loadShares();
                    _markConvRead(c.key, c.lastAt);
                  },
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
                        _bubble(it, color, appState, c.isGroup),
                      ]);
                    },
                  ),
                ),
        ),
        // 하단 메시지 입력 — 모든 참여자가 대화 가능(1:1·그룹 소유자·그룹 멤버 모두).
        // (향후 '공지' 형태는 생성자만 입력 가능하도록 분기 예정)
        _chatInput(c, groupId, color, appState),
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
          // 파일 추가/공유 — 전체 파일 목록에서 골라 이 대화에 추가(나와의 대화는 로컬 첨부).
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: color),
            tooltip: c.isSelf ? '파일 추가' : '파일 공유',
            onPressed: () => _showFileShareSheet(c, groupId, appState),
          ),
          Expanded(
            // Enter → 줄바꿈(다음 줄). 전송은 오른쪽 전송 버튼으로.
            child: TextField(
              controller: _msgCtrl,
              minLines: 1,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: '메시지 입력',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
      groupName: c.isGroup ? c.key.substring(2) : null,
      content: text,
    );
    if (mounted && !r.ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(r.message ?? '전송 실패')));
    }
  }

  /// + 버튼 — 전체 리튼의 파일 목록을 모아 시트로 보여주고, 고른 파일을 이 대화에 공유.
  /// 파일 공유 시트의 날짜 구분 헤더 — 메인 파일 리스트와 동일 형식(오늘/어제/yyyy년 M월 d일 (E)).
  Widget _fileDateHeader(DateTime date, Color color) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final String label;
    if (date == today) {
      label = '오늘';
    } else if (date == yesterday) {
      label = '어제';
    } else {
      label = DateFormat('yyyy년 M월 d일 (E)', 'ko').format(date);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Row(children: [
        Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: color.withValues(alpha: 0.2))),
      ]),
    );
  }

  Future<void> _showFileShareSheet(_Conv c, int? groupId, AppStateProvider appState) async {
    final color = Theme.of(context).primaryColor;
    final fs = FileStorageService.instance;
    final appDir = await getApplicationDocumentsDirectory();
    final entries = <_FileEntry>[];
    for (final lit in appState.littens) {
      for (final t in await fs.loadTextFiles(lit.id)) {
        // 요약/퀴즈를 담은 메모는 공유해도 아이콘이 유지되도록 fileType에 출처를 실어 보낸다.
        final String textType = t.isFromSTT
            ? 'stt_text'
            : t.sourceKind == 'summary'
                ? 'smry_text'
                : t.sourceKind == 'quiz'
                    ? 'quiz_text'
                    : 'text';
        final IconData textIcon = t.sourceKind == 'summary'
            ? Icons.summarize
            : t.sourceKind == 'quiz'
                ? Icons.quiz
                : Icons.notes;
        entries.add(_FileEntry(
          id: t.id,
          type: textType,
          name: t.displayTitle,
          icon: textIcon,
          path: '${appDir.path}/littens/${lit.id}/text/${t.id}.html',
          fileName: '${t.displayTitle}.html',
          contentType: 'text/html',
          date: t.createdAt,
        ));
      }
      for (final a in await fs.loadAudioFiles(lit.id)) {
        entries.add(_FileEntry(
          id: a.id,
          type: a.isFromSTT ? 'stt_audio' : 'audio',
          name: a.fileName,
          icon: Icons.mic,
          path: a.filePath,
          fileName: '${a.fileName}.m4a',
          contentType: 'audio/m4a',
          date: a.createdAt,
        ));
      }
      for (final h in await fs.loadHandwritingFiles(lit.id)) {
        final isPdf = h.imagePath.toLowerCase().endsWith('.pdf');
        entries.add(_FileEntry(
          id: h.id,
          type: 'handwriting',
          name: h.displayTitle,
          icon: Icons.draw,
          path: h.imagePath,
          fileName: '${h.displayTitle}${isPdf ? '.pdf' : '.png'}',
          contentType: isPdf ? 'application/pdf' : 'image/png',
          date: h.createdAt,
        ));
      }
      for (final at in await fs.loadAttachmentFiles(lit.id)) {
        entries.add(_FileEntry(
          id: at.id,
          type: 'attachment',
          name: at.fileName,
          icon: Icons.attach_file,
          path: at.filePath,
          fileName: at.fileName,
          contentType: at.mimeType,
          date: at.createdAt,
        ));
      }
    }
    // 최신순 정렬(날짜 구분 헤더용) — 메인 파일 리스트와 동일 컨벤션.
    entries.sort((a, b) => b.date.compareTo(a.date));
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
                        // 날짜(연월일)가 바뀌는 지점마다 헤더 삽입(오늘/어제/yyyy년 M월 d일 (E)).
                        final cur = DateTime(e.date.year, e.date.month, e.date.day);
                        final prev = i == 0 ? null : entries[i - 1].date;
                        final showDay = prev == null ||
                            DateTime(prev.year, prev.month, prev.day) != cur;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showDay) _fileDateHeader(cur, color),
                            ListTile(
                              dense: true,
                              leading: Icon(e.icon, color: color, size: 20),
                              title: Text(e.name,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              onTap: () => Navigator.pop(ctx, e),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ).then((picked) async {
      if (picked is! _FileEntry || !mounted) return;
      // 나와의 대화 — 서버 공유가 아니라 로컬 셀프챗에 파일 추가(+ 서버 동기화).
      if (c.isSelf) {
        _scrollChatToBottom = true;
        await appState.addSelfChatFile(c.key.substring(5),
            sourcePath: picked.path, fileName: picked.fileName,
            fileType: picked.type, contentType: picked.contentType);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('파일을 추가했습니다.')));
        }
        return;
      }
      final res = await appState.shareFile(
        filePath: picked.path,
        fileType: picked.type,
        fileName: picked.fileName,
        contentType: picked.contentType,
        targetType: c.isGroup ? 'group' : 'user',
        recipientKey: c.isGroup ? null : (c.email ?? c.key.substring(2)),
        groupId: c.isGroup ? groupId : null,
      );
      if (res['success'] == true) {
        // 전체 파일 리스트의 공유 아이콘 활성 표시(전체탭에서 공유한 것과 동일 처리)
        await appState.markFileShared(picked.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(res['success'] == true
                ? '공유했습니다.'
                : (res['message']?.toString() ?? '공유 실패'))));
      }
    });
  }

  /// 셀프챗 파일 항목 미리보기 — 로컬 경로 확보(필요 시 서버 다운로드) 후 스냅샷 뷰어 재사용.
  Future<void> _openSelfChatFile(_ShareItem it) async {
    final appState = context.read<AppStateProvider>();
    final chatId = it.data['__chatId']?.toString() ?? '';
    final item = it.data['__item'];
    if (item is! Map<String, dynamic>) return;
    final path = await appState.ensureSelfChatFileLocal(chatId, item);
    if (!mounted) return;
    if (path == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('파일을 열 수 없습니다.')));
      return;
    }
    final snap = SharedSnapshot(
      key: 'selffile:${item['localId']}',
      direction: 'sent',
      fileName: item['fileName']?.toString() ?? 'file',
      fileType: item['fileType']?.toString() ?? 'attachment',
      contentType: item['contentType']?.toString(),
      path: path,
      sharedAt: item['sentAt']?.toString() ?? '',
      peer: '나',
    );
    await showSharedSnapshot(context, snap);
  }

  /// 하단 칩 탭 시 — 해당 종류(사진/필기/파일 등)의 채팅 파일(받은·보낸·나와의 대화)을 리스트로 표시.
  Widget _buildChatFileKindList(
      AppStateProvider appState, Color color, String kind) {
    const kindLabels = {
      'all': '전체',
      'memo': '메모', 'summary_memo': '요약 메모', 'quiz_memo': '퀴즈 메모',
      'canvas': '필기', 'pdf': 'PDF', 'audio': '녹음',
      'stt': '녹음메모', 'files': '파일', 'photo': '사진', 'video': '동영상',
    };
    // 'all'이면 종류 필터 없이 모든 파일을 일자순으로 보여준다(칩 바 빈 영역 탭).
    final bool showAll = kind == 'all';
    final rows = <Map<String, dynamic>>[];
    // 받은 공유
    for (final s in appState.sharesReceived) {
      if (!showAll &&
          _shareFileKind(s['fileType']?.toString(), s['fileName']?.toString(),
              s['contentType']?.toString()) != kind) {
        continue;
      }
      final it = _ShareItem(
          received: true, data: s, at: _parseAt(s['sharedAt']),
          group: (s['groupName']?.toString() ?? '').trim());
      final sender = s['senderName']?.toString().isNotEmpty == true
          ? s['senderName'].toString()
          : (s['senderMemberId']?.toString() ?? '');
      rows.add({
        'fileType': s['fileType'], 'fileName': s['fileName'], 'contentType': s['contentType'],
        'fname': _stripShareExt(s['fileName']?.toString() ?? ''),
        'subtitle': '받음 · $sender',
        'dateIso': s['sharedAt']?.toString() ?? '',
        'onTap': () => _openSharedSnapshot(it),
      });
    }
    // 보낸 공유
    for (final s in appState.sharesSent) {
      if (!showAll &&
          _shareFileKind(s['fileType']?.toString(), s['fileName']?.toString(),
              s['contentType']?.toString()) != kind) {
        continue;
      }
      final it = _ShareItem(
          received: false, data: s, at: _parseAt(s['sharedAt']),
          group: (s['groupName']?.toString() ?? '').trim());
      final g = (s['groupName']?.toString() ?? '').trim();
      final recips = (s['recipients'] as List?) ?? const [];
      final to = g.isNotEmpty
          ? g
          : (recips.isNotEmpty ? ((recips.first as Map)['memberId']?.toString() ?? '') : '');
      rows.add({
        'fileType': s['fileType'], 'fileName': s['fileName'], 'contentType': s['contentType'],
        'fname': _stripShareExt(s['fileName']?.toString() ?? ''),
        'subtitle': '보냄 · $to',
        'dateIso': s['sharedAt']?.toString() ?? '',
        'onTap': () => _openSharedSnapshot(it),
      });
    }
    // 나와의 대화 파일
    for (final f in appState.selfChatFiles) {
      final item = f['item'] as Map<String, dynamic>;
      if (!showAll &&
          _shareFileKind(item['fileType']?.toString(), item['fileName']?.toString(),
              item['contentType']?.toString()) != kind) {
        continue;
      }
      final selfIt = _ShareItem(
          received: false,
          data: {
            'fileName': item['fileName'], 'fileType': item['fileType'],
            'sharedAt': item['sentAt'], '__selfFile': true,
            '__chatId': f['chatId'], '__item': item,
          },
          at: _parseAt(item['sentAt']), group: '');
      rows.add({
        'fileType': item['fileType'], 'fileName': item['fileName'], 'contentType': item['contentType'],
        'fname': _stripShareExt(item['fileName']?.toString() ?? ''),
        'subtitle': '나와의 대화: ${f['chatName']}',
        'dateIso': item['sentAt']?.toString() ?? '',
        'onTap': () => _openSelfChatFile(selfIt),
      });
    }
    rows.sort((a, b) => _parseAt(b['dateIso']).compareTo(_parseAt(a['dateIso'])));

    // 상단 헤더 없이 리스트만 표시(칩 재탭으로 닫음).
    return rows.isEmpty
        ? Center(
            child: Text('${kindLabels[kind] ?? kind} 파일이 없습니다.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500)))
        : ListView.separated(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            itemCount: rows.length,
            separatorBuilder: (_, i) =>
                Divider(height: 1, color: color.withValues(alpha: 0.08)),
            itemBuilder: (_, i) {
              final r = rows[i];
              return ListTile(
                leading: Icon(
                    _shareFileTypeIcon(r['fileType']?.toString(),
                        r['fileName']?.toString(), r['contentType']?.toString()),
                    color: color),
                title: Text(r['fname']?.toString() ?? '',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: Text(r['subtitle']?.toString() ?? '',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                trailing: Text(_shareWhen(r['dateIso']),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                onTap: r['onTap'] as VoidCallback,
              );
            },
          );
  }

  /// 간결한 말풍선 — 받음=좌측, 보냄=우측. 채팅 메시지는 텍스트, 공유는 아이콘+파일명+시간.
  Widget _bubble(_ShareItem it, Color color, AppStateProvider appState,
      [bool isGroup = false]) {
    // 그룹 대화에서 '받은' 항목은 보낸 사람(닉네임 우선, 없으면 이메일)을 말풍선 위에 표시.
    // 1:1은 상대가 한 명이라 제목으로 충분하므로 생략.
    final String? senderLabel = (isGroup && it.received)
        ? ((it.data['senderName']?.toString().trim().isNotEmpty ?? false)
            ? it.data['senderName'].toString()
            : (it.data['senderMemberId']?.toString().trim().isNotEmpty ?? false)
                ? it.data['senderMemberId'].toString()
                : null)
        : null;
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
              if (senderLabel != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(senderLabel,
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                ),
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
    final isSelfFile = it.data['__selfFile'] == true;
    String? hint;
    if (isSelfFile) {
      hint = null; // 나와의 대화 파일 — 수락/대기 개념 없음
    } else if (received) {
      hint = status == 'pending' ? '받기 대기' : status == 'accepted' ? '저장됨' : status == 'rejected' ? '거절됨' : null;
    } else {
      final acc = (it.data['acceptedCount'] as num?)?.toInt() ?? 0;
      final pend = (it.data['pendingCount'] as num?)?.toInt() ?? 0;
      hint = '수락 $acc · 대기 $pend';
    }
    final bubble = GestureDetector(
      // 탭 → 공유 내용(스냅샷) 바로 미리보기. 길게 누르면 부가 동작(수신자 상태·공유 취소 등).
      onTap: () => isSelfFile ? _openSelfChatFile(it) : _openSharedSnapshot(it),
      onLongPress: isSelfFile ? null : () => _showBubbleActions(it, appState),
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
            if (senderLabel != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(senderLabel,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: color)),
              ),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_shareFileTypeIcon(it.data['fileType']?.toString(), it.data['fileName']?.toString(), it.data['contentType']?.toString()), size: 16, color: color),
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
  final String id;          // 원본 파일 id — 공유 후 전체리스트 공유아이콘 활성 표시(markFileShared)용
  final String type;        // text/stt_text/audio/stt_audio/handwriting/attachment
  final String name;        // 표시명
  final IconData icon;
  final String path;        // 로컬 파일 경로
  final String fileName;    // 업로드 파일명(확장자 포함)
  final String? contentType;
  final DateTime date;      // 생성일시(날짜 구분 헤더·정렬용)
  _FileEntry({
    required this.id,
    required this.type,
    required this.name,
    required this.icon,
    required this.path,
    required this.fileName,
    required this.date,
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
              Icon(_shareFileTypeIcon(share['fileType']?.toString(), share['fileName']?.toString()), size: 18, color: color),
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
              Icon(_shareFileTypeIcon(share['fileType']?.toString(), share['fileName']?.toString()), size: 18, color: color),
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

/// 새 채팅 다이얼로그의 1:1 탭.
/// 이메일 또는 닉네임을 입력 → [검색]으로 가입 회원 조회 → 찾으면 [대화 시작] 활성화.
/// 닉네임으로 찾아도 실제 상대는 이메일(id) 기준으로 연결한다.
class _NewChatOneToOneTab extends StatefulWidget {
  final Color color;
  final Future<Map<String, dynamic>> Function(String query) onSearch;
  final void Function(String email) onStart;
  const _NewChatOneToOneTab({
    required this.color,
    required this.onSearch,
    required this.onStart,
  });

  @override
  State<_NewChatOneToOneTab> createState() => _NewChatOneToOneTabState();
}

class _NewChatOneToOneTabState extends State<_NewChatOneToOneTab> {
  final _ctrl = TextEditingController();
  bool _searching = false;
  bool _searched = false; // 검색을 한 번이라도 시도했는지
  String? _resolvedEmail; // 검색으로 확인된 상대 이메일(id)
  String? _resolvedName; // 검색으로 확인된 상대 닉네임

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// 입력을 바꾸면 이전 검색 결과를 무효화(대화 시작 재비활성화).
  void _resetIfNeeded() {
    if (_searched || _resolvedEmail != null) {
      setState(() {
        _searched = false;
        _resolvedEmail = null;
        _resolvedName = null;
      });
    }
  }

  Future<void> _doSearch() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일 또는 닉네임을 입력해주세요.')),
      );
      return;
    }
    setState(() => _searching = true);
    final res = await widget.onSearch(q);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _searched = true;
      if (res['found'] == true) {
        _resolvedEmail = res['id']?.toString();
        _resolvedName = res['name']?.toString();
      } else {
        _resolvedEmail = null;
        _resolvedName = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final found = _resolvedEmail != null;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 입력 + 검색 버튼
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: '이메일 또는 닉네임',
                      isDense: true,
                      border: OutlineInputBorder()),
                  onChanged: (_) => _resetIfNeeded(),
                  onSubmitted: (_) => _doSearch(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: _searching ? null : _doSearch,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: color, foregroundColor: Colors.white),
                  child: _searching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('검색'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 검색 결과 안내
          if (_searched && found)
            Row(
              children: [
                const Icon(Icons.check_circle, size: 16, color: Colors.green),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    (_resolvedName != null && _resolvedName!.isNotEmpty)
                        ? '${_resolvedName!} ($_resolvedEmail)'
                        : _resolvedEmail!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ),
              ],
            ),
          if (_searched && !found)
            const Text('해당 사용자를 찾을 수 없습니다.',
                style: TextStyle(fontSize: 12, color: Colors.red)),
          const SizedBox(height: 12),
          // 검색 성공 시에만 활성화
          ElevatedButton.icon(
            onPressed: found ? () => widget.onStart(_resolvedEmail!) : null,
            style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.white70),
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text('대화 시작'),
          ),
        ],
      ),
    );
  }
}

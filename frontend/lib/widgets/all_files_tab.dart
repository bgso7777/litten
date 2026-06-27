import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/app_localizations.dart';
import '../services/app_state_provider.dart';
import '../services/audio_service.dart';
import '../services/file_storage_service.dart';
import '../services/litten_service.dart';
import '../services/sync_service.dart';
import '../models/text_file.dart';
import '../models/handwriting_file.dart';
import '../models/audio_file.dart';
import '../models/attachment_file.dart';
import 'text_tab.dart';
import 'handwriting_tab.dart';
import 'syncfusion_pdf_editor.dart';
import 'youtube_video_detail_dialog.dart';
import 'youtube_video_player_sheet.dart';
import '../services/youtube_transcript_service.dart';
import '../services/local_youtube_channel_service.dart';
import '../services/youtube_rss_service.dart';
import '../services/channel_watch_service.dart';
import '../models/channel_watch_state.dart';
import '../services/youtube_webview_transcript_service.dart';
import '../services/youtube_http_transcript_service.dart';
import 'youtube_transcript_sheet.dart';
import 'dialogs/summary_dialog.dart';
import 'dialogs/stt_memo_settings_dialog.dart';
import '../models/quiz_item.dart';
import '../utils/quiz_parser.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'share_compose_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'youtube_tab.dart';
import 'dart:io';
import '../services/api_service.dart';
import '../models/youtube_channel.dart';

// ───────────────────────────── 파일 타입 통합 래퍼 ─────────────────────────────

enum _FileType { text, handwriting, audio, attachment }

/// 전체탭 상단 필터 — 종류별로 목록을 걸러 본다.
/// all=전체, text=메모, audio=녹음, stt=녹음 메모(isFromSTT), handwriting=필기,
/// attachment=파일, youtube=영상 채널
enum _FileFilter { all, text, audio, stt, handwriting, attachment, photo, video, youtube }

// 전체탭 필터 키 순서(드롭다운 표시 순서). AppStateProvider.allTabFileFilter와 _FileFilter.name 동일 문자열.
const List<String> kAllTabFilterKeys = ['all', 'text', 'audio', 'stt', 'handwriting', 'attachment', 'photo', 'video', 'youtube'];

IconData _allTabFilterIcon(String key) {
  switch (key) {
    case 'text':
      return Icons.notes;
    case 'audio':
      return Icons.mic;
    case 'stt':
      return Icons.record_voice_over;
    case 'handwriting':
      return Icons.draw;
    case 'attachment':
      return Icons.drive_folder_upload;
    case 'photo':
      return Icons.photo_camera;
    case 'video':
      return Icons.videocam;
    case 'youtube':
      return Icons.subscriptions;
    case 'all':
    default:
      return Icons.filter_list;
  }
}

String _allTabFilterLabel(BuildContext context, String key) {
  final l10n = AppLocalizations.of(context);
  switch (key) {
    case 'text':
      return l10n?.memoLabel ?? '메모';
    case 'audio':
      return l10n?.audioTab ?? '녹음';
    case 'stt':
      return l10n?.voiceMemoLabel ?? '녹음 메모';
    case 'handwriting':
      return l10n?.handwritingTab ?? '필기';
    case 'attachment':
      return '파일';
    case 'photo':
      return '사진';
    case 'video':
      return '비디오';
    case 'youtube':
      return '영상 채널';
    case 'all':
    default:
      return '전체';
  }
}

class _MergedFile {
  final _FileType type;
  final dynamic file; // TextFile | HandwritingFile | AudioFile | AttachmentFile
  // 정렬·날짜그룹 기준 시각 = 파일의 최근 수정 시각(updatedAt). 최근 수정 파일이 상위로 온다.
  final DateTime sortAt;
  _MergedFile({required this.type, required this.file, required this.sortAt});
}

/// 텍스트 · 필기 · 녹음 파일을 하나의 탭에서 모두 보여주는 통합 뷰
/// [showOnlySTT] = true 이면 음성메모(STT)로 생성된 파일만 표시
/// [showOnlyAttachments] = true 이면 첨부파일(docx, xlsx 등)만 표시
class AllFilesTab extends StatefulWidget {
  final bool showOnlySTT;
  final bool showOnlyAttachments;
  const AllFilesTab({super.key, this.showOnlySTT = false, this.showOnlyAttachments = false});

  @override
  State<AllFilesTab> createState() => _AllFilesTabState();
}

class _AllFilesTabState extends State<AllFilesTab> {
  List<TextFile> _textFiles = [];
  List<HandwritingFile> _pdfFiles = [];
  List<HandwritingFile> _canvasFiles = [];
  List<AudioFile> _audioFiles = [];
  List<AttachmentFile> _attachmentFiles = [];
  List<YoutubeChannel> _youtubeChannels = [];
  bool _loadingChannels = false;
  // 영상 채널 표시 ON 시 자동 로드를 1회만 트리거하기 위한 플래그 (무한 리로드 방지)
  bool _youtubeAutoLoadRequested = false;
  final Map<String, Map<int, List<YoutubeVideo>>> _videoPageData = {};
  final Map<String, int> _videoTotalPages = {};
  final Set<String> _loadingVideoKeys = {}; // "${channelId}_${page}"
  final Set<String> _expandedChannels = {};
  final Map<String, int> _channelVideoPage = {};
  // 로컬(비로그인) 모드: RSS로 받은 전체 영상 캐시(채널별) → 3개씩 페이지로 슬라이스
  final Map<String, List<YoutubeVideo>> _localRssCache = {};
  static const int _localPageSize = 3;
  // 무료(Free) 플랜의 채널별 영상 페이지 상한(로컬 RSS). 스탠다드 이상은 서버 전체 페이지.
  static const int _freeMaxPages = 5;
  // 채널별 확인 상태(로컬) + 최신 영상 게시일(RSS) — 새 영상 아이콘/정렬용
  Map<String, ChannelWatchState> _watchStates = {};
  final Map<String, DateTime?> _latestVideoAt = {};
  // 채널 추가(등록) 시각 — 전체탭 시간순 정렬에서 "추가하면 맨 위"를 위해 사용.
  // 최초 발견 채널은 최신 영상일자로 시드(점프 방지), 이후 새로 추가된 채널만 now() 기록.
  static const String _kChannelAddedAtKey = 'yt_channel_added_at';
  Map<String, DateTime> _channelAddedAt = {};
  // 새 영상이 생겨 상단 NEW 영역으로 끌어올려진(고정된) 채널 ID 집합.
  // 새 영상 발생 시 핀 → 펼쳐서 확인 후 다시 닫으면 핀 해제(원래 생성일시 위치로 복귀).
  final Set<String> _newPinnedChannels = {};
  // 클라우드 동기화·공유는 프리미엄(서버 보관) 전용 → 무료/스탠다드는 숨김
  bool get _isPremiumPlus =>
      Provider.of<AppStateProvider>(context, listen: false).isPremiumPlusUser;
  // ⭐ 영상별 요약 존재 여부 (videoId → 요약 1개 이상 있으면 true)
  final Map<String, bool> _videoHasSummary = {};
  final Map<String, bool> _videoHasQuiz = {}; // 영상별 저장된 퀴즈 존재 여부
  // ⭐ 영상 상세 캐시 (videoId → 상세, 팝업에서 lazy 로드 후 재사용)
  final Map<int, YoutubeVideo> _youtubeVideoDetailCache = {};
  final Set<int> _loadingYoutubeVideoDetails = {};
  final _transcriptService = YoutubeTranscriptService();
  final _webViewTranscriptService = YoutubeWebViewTranscriptService();
  final _httpTranscriptService = YoutubeHttpTranscriptService();
  final _youtubeRssService = YoutubeRssService();
  String? _youtubeToken;
  final _apiService = ApiService();
  bool _loading = false;
  String? _activeLittenId = '__init__';
  int _lastFileListVersion = 0; // ⭐ 마지막으로 로드한 파일 목록 버전
  int _lastYoutubeRefreshTick = 0; // ⭐ 마지막으로 처리한 영상 채널 새로고침 신호

  // 현재 전체화면으로 열린 에디터
  _EditorType? _openEditor;
  HandwritingInitialAction _handwritingAction = HandwritingInitialAction.none;
  bool _autoCreate = false;
  TextFile? _selectedTextFile; // ⭐ 선택된 텍스트 파일
  HandwritingFile? _selectedHandwritingFile; // ⭐ 선택된 필기 파일
  String? _initialPdfPath; // ⭐ PDF 파일 경로 (파일 선택 후 전달)
  String? _initialPdfFileName; // ⭐ PDF 파일명
  String? _initialImagePath; // ⭐ 사진(이미지 첨부) 탭 시 필기로 편집할 이미지 경로

  // 인라인 녹음 / 재생 상태
  final AudioService _audioService = AudioService();
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  // 병합 정렬 파일 목록 (updatedAt 내림차순 = 최근 수정 파일이 상위)
  List<_MergedFile> get _mergedFiles {
    if (widget.showOnlyAttachments) {
      final list = _attachmentFiles
          .map((f) => _MergedFile(type: _FileType.attachment, file: f, sortAt: f.updatedAt))
          .toList();
      list.sort((a, b) => b.sortAt.compareTo(a.sortAt));
      return list;
    }
    final textSrc = widget.showOnlySTT ? _textFiles.where((f) => f.isFromSTT).toList() : _textFiles;
    final audioSrc = widget.showOnlySTT ? _audioFiles.where((f) => f.isFromSTT).toList() : _audioFiles;
    final list = <_MergedFile>[
      ...textSrc.map((f) => _MergedFile(type: _FileType.text, file: f, sortAt: f.updatedAt)),
      if (!widget.showOnlySTT) ...[
        ..._pdfFiles.map((f) => _MergedFile(type: _FileType.handwriting, file: f, sortAt: f.updatedAt)),
        ..._canvasFiles.map((f) => _MergedFile(type: _FileType.handwriting, file: f, sortAt: f.updatedAt)),
        ..._attachmentFiles.map((f) => _MergedFile(type: _FileType.attachment, file: f, sortAt: f.updatedAt)),
      ],
      ...audioSrc.map((f) => _MergedFile(type: _FileType.audio, file: f, sortAt: f.updatedAt)),
    ];
    list.sort((a, b) => b.sortAt.compareTo(a.sortAt));
    return list;
  }

  @override
  void initState() {
    super.initState();
    _audioService.addListener(_onAudioStateChanged);
    _loadYoutubeChannels();
    // 앱/탭 전환 후 돌아왔을 때 AudioService 녹음 상태 복원
    if (_audioService.isRecording) {
      _isRecording = true;
      _recordingDuration = _audioService.recordingDuration;
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordingDuration += const Duration(seconds: 1));
      });
      debugPrint('🔄 [AllFilesTab] initState - 녹음 중 상태 복원');
    }
  }

  void _onAudioStateChanged() {
    if (!mounted) return;
    final nowRecording = _audioService.isRecording;
    if (nowRecording == _isRecording) {
      setState(() {});
      return;
    }
    if (nowRecording) {
      // STT 등 외부에서 녹음 시작됨 → 타이머 시작
      _recordingTimer?.cancel();
      _recordingDuration = Duration.zero;
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordingDuration += const Duration(seconds: 1));
      });
      debugPrint('🔄 [AllFilesTab] 외부 녹음 시작 감지 (STT 등)');
    } else {
      // 외부에서 녹음 종료 (STT 등) → 파일 목록 새로고침 (isFromSTT 아이콘 즉시 반영)
      _recordingTimer?.cancel();
      _recordingDuration = Duration.zero;
      debugPrint('🔄 [AllFilesTab] 외부 녹음 종료 감지 - 파일 목록 새로고침');
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      _loadFiles(appState);
    }
    setState(() => _isRecording = nowRecording);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final littenId = appState.selectedLitten?.id;
    if (littenId != _activeLittenId) {
      _activeLittenId = littenId;
      _loadFiles(appState);
    }
  }

  Future<void> _loadFiles(AppStateProvider appState) async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      // undefined 또는 미선택이면 전체 파일, 그 외는 해당 리튼 파일만
      final selectedLitten = appState.selectedLitten;
      final filterById = (selectedLitten != null && selectedLitten.title != 'undefined')
          ? selectedLitten.id
          : null;
      final allFiles = await appState.getAllFiles();

      final List<TextFile> textFiles = [];
      final List<HandwritingFile> hwFiles = [];
      final List<AudioFile> audioFiles = [];

      for (final f in allFiles) {
        if (filterById != null && f['littenId'] != filterById) continue;
        final type = f['type'] as String;
        if (type == 'text') textFiles.add(f['file'] as TextFile);
        else if (type == 'handwriting') hwFiles.add(f['file'] as HandwritingFile);
        else if (type == 'audio') audioFiles.add(f['file'] as AudioFile);
      }

      // ⭐ 첨부 파일 로드 (선택 리튼만 또는 모든 리튼)
      final List<AttachmentFile> attachmentFiles = [];
      if (filterById != null) {
        attachmentFiles.addAll(
          await FileStorageService.instance.loadAttachmentFiles(filterById),
        );
      } else {
        for (final l in appState.littens) {
          attachmentFiles.addAll(
            await FileStorageService.instance.loadAttachmentFiles(l.id),
          );
        }
      }

      if (mounted) {
        setState(() {
          _textFiles = textFiles;
          _pdfFiles = hwFiles.where((f) => f.type == HandwritingType.pdfConvert).toList();
          _canvasFiles = hwFiles.where((f) => f.type == HandwritingType.drawing).toList();
          _audioFiles = audioFiles;
          _attachmentFiles = attachmentFiles;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [AllFilesTab] 파일 로드 실패: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 전체탭 당겨서 새로고침: 클라우드 동기화 후 파일 목록과 영상(구독 채널)을 함께 갱신한다.
  /// 동기화를 먼저 await해야 다른 기기에서 수정/추가한 내용이 내려온 뒤 로컬을 다시 읽는다.
  /// (이게 없으면 로컬만 재로드해 다른 기기 수정분이 반영되지 않음)
  Future<void> _refreshFilesAndVideos(AppStateProvider appState) async {
    debugPrint('🔄 [AllFilesTab] 당겨서 새로고침 - 동기화 + 파일 + 영상');
    // 1) 클라우드 동기화(다른 기기 변경분 다운로드 + 로컬 미동기화 업로드)
    final littenIds = appState.littens.map((l) => l.id).toList();
    await SyncService.instance.syncOnNoteTab(littenIds);
    // 2) 로컬 파일 + 영상 채널 갱신
    await Future.wait([
      _loadFiles(appState),
      _loadYoutubeChannels(),
    ]);
  }

  Future<void> _loadYoutubeChannels() async {
    if (widget.showOnlySTT || widget.showOnlyAttachments) return;
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    if (!appState.showYoutubeInAllTab) {
      debugPrint('[AllFilesTab] 전체탭 영상 채널 표시 OFF - 로드 생략');
      if (mounted) setState(() { _youtubeChannels = []; _loadingChannels = false; });
      appState.setYoutubeChannelCount(0); // 제목 카운트 동기화
      return;
    }
    debugPrint('[AllFilesTab] _loadYoutubeChannels 진입');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      // 비로그인(로컬 모드): 단말 저장소의 로컬 채널 로드
      _youtubeToken = null;
      final locals = await LocalYoutubeChannelService.load();
      debugPrint('[AllFilesTab] 로컬 채널 수: ${locals.length}');
      await _applyNewVideoData(locals); // 새 영상 판단·정렬
      if (mounted) setState(() {
        _youtubeChannels = locals;
        _loadingChannels = false;
        _videoPageData.clear();
        _videoTotalPages.clear();
        _loadingVideoKeys.clear();
        _expandedChannels.clear();
        _channelVideoPage.clear();
        _localRssCache.clear();
      });
      appState.setYoutubeChannelCount(locals.length); // 제목 카운트 동기화
      return;
    }
    _youtubeToken = token;
    if (mounted) setState(() => _loadingChannels = true);
    try {
      final channels = await _apiService.getYoutubeChannels(token: token, page: 0, size: 100);
      await _applyNewVideoData(channels); // 새 영상 판단·정렬(최신 영상 순)
      debugPrint('[AllFilesTab] 채널 수: ${channels.length}');
      if (mounted) setState(() {
        _youtubeChannels = channels;
        _loadingChannels = false;
        _videoPageData.clear();
        _videoTotalPages.clear();
        _loadingVideoKeys.clear();
        _expandedChannels.clear();
        _channelVideoPage.clear();
        _localRssCache.clear();
      });
      appState.setYoutubeChannelCount(channels.length); // 제목 카운트 동기화
    } catch (e) {
      debugPrint('❌ [AllFilesTab] 채널 로드 실패: $e');
      if (mounted) setState(() => _loadingChannels = false);
    }
  }

  /// 채널 로드 후 공통 처리: 확인 상태 로드 + 각 채널 최신 영상 게시일(RSS) + 새 영상 순 정렬
  Future<void> _applyNewVideoData(List<YoutubeChannel> channels) async {
    _watchStates = await ChannelWatchService.loadAll();
    await _loadLatestVideoTimes(channels);
    await _reconcileChannelAddedAt(channels);
    // 새 영상이 있는 채널은 상단 NEW 영역으로 고정(핀). 확인 후 닫을 때 _toggleChannel에서 해제한다.
    for (final ch in channels) {
      if (_hasNewVideo(ch)) _newPinnedChannels.add(ch.channelId);
    }
    // 구독 해제된 채널의 핀 정리
    final ids = channels.map((c) => c.channelId).toSet();
    _newPinnedChannels.removeWhere((id) => !ids.contains(id));
    channels.sort(_compareChannels);
  }

  /// 채널 추가 시각 맵 동기화. 최초 1회(저장값 없음)에는 모든 채널을 최신 영상일자로 시드해
  /// 일괄 상단 점프를 막고, 이후 새로 등록된 채널만 now()로 기록해 "추가하면 맨 위"가 되게 한다.
  Future<void> _reconcileChannelAddedAt(List<YoutubeChannel> channels) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kChannelAddedAtKey);
    final firstBuild = raw == null;
    final map = <String, DateTime>{};
    if (raw != null) {
      try {
        (jsonDecode(raw) as Map<String, dynamic>).forEach((k, v) {
          final t = DateTime.tryParse(v.toString());
          if (t != null) map[k] = t;
        });
      } catch (_) {}
    }
    final now = DateTime.now();
    final present = <String>{};
    for (final ch in channels) {
      present.add(ch.channelId);
      if (map.containsKey(ch.channelId)) continue;
      // 최초 빌드: 영상일자로 시드(점프 방지) / 이후: 신규 추가 → now()로 맨 위
      map[ch.channelId] = firstBuild
          ? (_latestVideoAt[ch.channelId] ?? DateTime.fromMillisecondsSinceEpoch(0))
          : now;
    }
    map.removeWhere((k, _) => !present.contains(k)); // 구독 해제 채널 정리
    await prefs.setString(
      _kChannelAddedAtKey,
      jsonEncode(map.map((k, v) => MapEntry(k, v.toIso8601String()))),
    );
    _channelAddedAt = map;
  }

  /// 각 채널 최신 영상 게시일을 RSS로 병렬 조회 (무인증)
  Future<void> _loadLatestVideoTimes(List<YoutubeChannel> channels) async {
    await Future.wait(channels.map((ch) async {
      final vids = await _youtubeRssService.fetchChannelVideos(ch.channelId);
      if (vids.isNotEmpty && vids.first.publishedAt != null) {
        _latestVideoAt[ch.channelId] = DateTime.tryParse(vids.first.publishedAt!);
      }
    }));
  }

  /// 채널에 아직 확인 안 한 새 영상이 있는지 (최신 영상 > 마지막 확인 시각, 확인 기록 없으면 새 영상)
  bool _hasNewVideo(YoutubeChannel ch) {
    final latest = _latestVideoAt[ch.channelId];
    if (latest == null) return false;
    final seen = _watchStates[ch.channelId]?.lastSeenAt;
    if (seen == null) return true;
    return latest.isAfter(seen);
  }

  /// 정렬: 새 영상 있는 채널 우선 → 최신 영상 게시일 내림차순 → id 내림차순
  // 등록순(채널을 추가한 순서) 정렬: id 오름차순. (전체탭에서 파일은 수정일순, 영상은 등록순으로 합쳐 표시)
  int _compareChannels(YoutubeChannel a, YoutubeChannel b) {
    return a.id.compareTo(b.id);
  }

  /// 채널을 펼쳐 영상을 확인한 것으로 처리 (최신 영상 시각 저장 → 새 영상 아이콘 끔)
  Future<void> _markChannelSeen(YoutubeChannel ch) async {
    if (!_hasNewVideo(ch)) return;
    await ChannelWatchService.markSeen(ch.channelId, latestAt: _latestVideoAt[ch.channelId], now: DateTime.now());
    _watchStates = await ChannelWatchService.loadAll();
    if (mounted) setState(() {});
  }

  Future<void> _loadVideoPage(String channelId, int page) async {
    final key = '${channelId}_$page';
    if (_loadingVideoKeys.contains(key)) return;
    if (_videoPageData[channelId]?[page] != null) return;

    // 영상 소스/페이지 한도는 구독 플랜 기준으로 가른다.
    // - 무료(Free): 로컬 RSS만, 채널별 최대 5페이지(=3×5≈15개).
    // - 스탠다드 이상(isPremiumUser): 서버에 저장된 전체를 페이지별로(서버 제목 기준).
    final isPaid = Provider.of<AppStateProvider>(context, listen: false).isPremiumUser;

    if (!isPaid) {
      setState(() => _loadingVideoKeys.add(key));
      try {
        var all = _localRssCache[channelId];
        if (all == null) {
          all = await _youtubeRssService.fetchChannelVideos(channelId);
          _localRssCache[channelId] = all;
        }
        final pageVids = all.skip(page * _localPageSize).take(_localPageSize).toList();
        debugPrint('[AllFilesTab] 무료 로컬 영상 로드 ($channelId) page $page: ${pageVids.length}/${all.length}개');
        if (mounted) setState(() {
          _videoPageData.putIfAbsent(channelId, () => {})[page] = pageVids;
          // 무료는 최대 5페이지로 상한
          _videoTotalPages[channelId] = (all!.length / _localPageSize).ceil().clamp(1, _freeMaxPages);
          _loadingVideoKeys.remove(key);
        });
        _loadVideoSummaryFlags(pageVids); // 요약 존재 여부 비동기 조회
      } catch (e) {
        debugPrint('❌ [AllFilesTab] 무료 RSS 영상 로드 실패 ($channelId): $e');
        if (mounted) setState(() {
          _videoPageData.putIfAbsent(channelId, () => {})[page] = [];
          _loadingVideoKeys.remove(key);
        });
      }
      return;
    }

    // 스탠다드 이상: 서버 전체 페이지 (프리미엄=토큰, 스탠다드 비로그인=게스트 device-uuid)
    setState(() => _loadingVideoKeys.add(key));
    try {
      final result = _youtubeToken != null
          ? await _apiService.getYoutubeVideos(token: _youtubeToken!, channelId: channelId, page: page, size: _localPageSize)
          : await _apiService.getYoutubeVideos(channelId: channelId, page: page, size: _localPageSize);
      // 빈 응답(videos 0 && totalPages 0)은 타임아웃/오류로 간주한다. 서버가 일시 지연될 때
      // 기존 페이지 수(예: 26)를 0으로 무너뜨리고 빈 페이지를 캐시하면 '영상 없음'으로 잘못 보이고
      // 재시도도 막힌다. → 캐시하지 않고 로딩 키만 풀어 다음 진입/넘김 때 재시도되게 둔다.
      if (result.videos.isEmpty && result.totalPages == 0) {
        debugPrint('[AllFilesTab] 서버 영상 로드 빈 응답(일시 실패 추정) - page $page 보류, 재시도 가능');
        if (mounted) setState(() => _loadingVideoKeys.remove(key));
        return;
      }
      debugPrint('[AllFilesTab] 서버 영상 로드 ($channelId, page $page): ${result.videos.length}개, 총 ${result.totalPages}페이지');
      if (mounted) setState(() {
        _videoPageData.putIfAbsent(channelId, () => {})[page] = result.videos;
        _videoTotalPages[channelId] = result.totalPages;
        _loadingVideoKeys.remove(key);
      });
      _loadVideoSummaryFlags(result.videos); // 요약 존재 여부 비동기 조회
    } catch (e) {
      debugPrint('❌ [AllFilesTab] 서버 영상 로드 실패 ($channelId, page $page): $e');
      // 실패 페이지를 캐시하지 않아 재시도 가능하게 둔다(페이지 수도 보존).
      if (mounted) setState(() => _loadingVideoKeys.remove(key));
    }
  }

  /// 영상 목록의 각 영상에 대해 요약 존재 여부를 조회해 _videoHasSummary 갱신
  /// (summaryLevel:0 → 저장된 최고 레벨 반환, null이면 요약 없음)
  Future<void> _loadVideoSummaryFlags(List<YoutubeVideo> videos) async {
    for (final v in videos) {
      final vid = v.videoId;
      if (vid.isEmpty || _videoHasSummary.containsKey(vid)) continue;
      final cache = await _apiService.getYoutubeSummaryCache(videoId: vid, token: _youtubeToken);
      if (!mounted) return;
      setState(() => _videoHasSummary[vid] = cache != null);
      // 퀴즈 존재 여부도 조회 (요약과 독립)
      final quiz = await _apiService.getYoutubeQuizCache(videoId: vid, token: _youtubeToken);
      if (!mounted) return;
      setState(() => _videoHasQuiz[vid] = quiz != null);
    }
  }

  /// 단일 영상의 요약/퀴즈 존재 여부 재조회 (요약 팝업을 닫은 직후 아이콘 갱신용)
  Future<void> _refreshVideoSummaryFlag(String videoId) async {
    if (videoId.isEmpty) return;
    final cache = await _apiService.getYoutubeSummaryCache(videoId: videoId, token: _youtubeToken);
    if (!mounted) return;
    setState(() => _videoHasSummary[videoId] = cache != null);
    final quiz = await _apiService.getYoutubeQuizCache(videoId: videoId, token: _youtubeToken);
    if (!mounted) return;
    setState(() => _videoHasQuiz[videoId] = quiz != null);
  }

  void _toggleChannel(YoutubeChannel ch) {
    final id = ch.channelId;
    if (_expandedChannels.contains(id)) {
      // 영상을 확인(펼침 시 _markChannelSeen)한 뒤 닫으면 상단 NEW 영역 고정 해제 → 원래 위치 복귀.
      setState(() {
        _expandedChannels.remove(id);
        if (!_hasNewVideo(ch)) _newPinnedChannels.remove(id);
      });
    } else {
      setState(() => _expandedChannels.add(id));
      _loadVideoPage(id, _channelVideoPage[id] ?? 0);
      _markChannelSeen(ch); // 채널을 펼쳐 확인 → 새 영상 아이콘 끔
    }
  }

  /// 영상 구독 채널 삭제 (로컬/서버 자동 분기)
  Future<void> _unsubscribeYoutubeChannel(YoutubeChannel ch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('구독 삭제'),
        content: Text('"${ch.channelName}"\n구독을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    debugPrint('[AllFilesTab] 채널 구독 삭제 - ${ch.channelName} (token: ${_youtubeToken != null})');
    if (_youtubeToken == null) {
      // 로컬(비로그인) 채널 삭제
      await LocalYoutubeChannelService.removeByChannelId(ch.channelId);
    } else {
      await _apiService.unsubscribeYoutubeChannel(token: _youtubeToken!, channelPk: ch.id);
    }
    if (mounted) await _loadYoutubeChannels();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${ch.channelName}" 구독을 삭제했습니다.')),
      );
    }
  }

  Future<void> _loadYoutubeVideoDetail(YoutubeVideo video) async {
    final videoId = video.id;
    if (_loadingYoutubeVideoDetails.contains(videoId)) return;
    setState(() => _loadingYoutubeVideoDetails.add(videoId));
    debugPrint('[AllFilesTab] _loadYoutubeVideoDetail - videoId: $videoId, hasTranscript: ${video.hasTranscript}');
    try {
      if (video.hasTranscript) {
        // 서버 DB에 자막 있음 → 상세 조회
        final detail = await _apiService.getYoutubeVideoDetail(token: _youtubeToken!, videoId: videoId);
        final storedText = detail?.transcriptText ?? '';
        final isInvalidTranscript = storedText.startsWith('DIAG:') || storedText.startsWith('ERROR:');
        if (detail != null && !isInvalidTranscript) {
          if (mounted) setState(() {
            _youtubeVideoDetailCache[videoId] = detail;
            _loadingYoutubeVideoDetails.remove(videoId);
          });
          return;
        }
        debugPrint('[AllFilesTab] 잘못 저장된 자막 감지 - WebView 재수집: $storedText');
        // hasTranscript=true지만 내용 무효 → 아래 WebView 재수집으로 계속
      }

      // 자막 없음 or 잘못된 자막 → 3단계 순차 시도
      // 1단계: 프론트 직접 HTTP
      debugPrint('[AllFilesTab] HTTP 자막 수집 시작 - videoId: ${video.videoId}');
      String? transcript = await _httpTranscriptService.fetchTranscript(video.videoId);

      // 2단계: 백엔드 yt-dlp (downsub.com과 동일 기술, PoToken 자체 처리)
      if ((transcript == null || transcript.isEmpty) && _youtubeToken != null) {
        debugPrint('[AllFilesTab] HTTP 실패 → 백엔드 yt-dlp 시도 - videoId: ${video.videoId}');
        transcript = await _apiService.extractYoutubeTranscriptViaYtDlp(
          token: _youtubeToken!, videoId: video.videoId,
        );
        if (transcript != null && transcript.isNotEmpty) {
          debugPrint('[AllFilesTab] yt-dlp 자막 수집 성공 - videoId: ${video.videoId}');
        }
      }

      // 3단계: WebView 폴백 (일시 비활성화)
      // if (transcript == null || transcript.isEmpty) {
      //   debugPrint('[AllFilesTab] yt-dlp 실패 → WebView 폴백 - videoId: ${video.videoId}');
      //   transcript = await _webViewTranscriptService.fetchTranscript(context, video.videoId);
      // }

      if (!mounted) return;
      if (transcript != null && transcript.isNotEmpty) {
        final syntheticVideo = YoutubeVideo(
          id: video.id, channelId: video.channelId, videoId: video.videoId,
          title: video.title, publishedAt: video.publishedAt,
          transcriptText: transcript, summary: video.summary, status: 'done',
          hasTranscript: true,
        );
        setState(() {
          _youtubeVideoDetailCache[videoId] = syntheticVideo;
          _loadingYoutubeVideoDetails.remove(videoId);
        });
        debugPrint('[AllFilesTab] 자막 수집 성공 - videoId: ${video.videoId}');
        _apiService.saveYoutubeTranscript(
          token: _youtubeToken!, videoId: video.videoId, transcript: transcript,
        );
      } else {
        debugPrint('[AllFilesTab] 자막 자동 수집 실패 - videoId: ${video.videoId}');
        if (mounted) {
          setState(() => _loadingYoutubeVideoDetails.remove(videoId));
          // _showManualTranscriptSheet(video); // 수동 WebView 시트 비활성화
        }
      }
    } catch (e) {
      debugPrint('[AllFilesTab] ❌ 영상 상세 로드 실패: $e');
      if (mounted) setState(() => _loadingYoutubeVideoDetails.remove(videoId));
    }
  }

  void _showManualTranscriptSheet(YoutubeVideo video) {
    YoutubeTranscriptSheet.show(
      context,
      videoId: video.videoId,
      videoTitle: video.title,
      onTranscriptFound: (transcript) async {
        debugPrint('[AllFilesTab] 수동 자막 수집 성공 - videoId: ${video.videoId}');
        final syntheticVideo = YoutubeVideo(
          id: video.id, channelId: video.channelId, videoId: video.videoId,
          title: video.title, publishedAt: video.publishedAt,
          transcriptText: transcript, summary: video.summary, status: 'done',
          hasTranscript: true,
        );
        if (mounted) setState(() => _youtubeVideoDetailCache[video.id] = syntheticVideo);
        _apiService.saveYoutubeTranscript(
          token: _youtubeToken!, videoId: video.videoId, transcript: transcript,
        );
      },
    );
  }


  String _youtubeShortDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }

  Widget _youtubeAutoSettingIcon(IconData icon, bool enabled, String tooltip, VoidCallback? onTap) {
    final color = Theme.of(context).primaryColor;
    final isDisabled = onTap == null;
    final iconColor = isDisabled ? Colors.grey.shade200 : (enabled ? color : Colors.grey.shade300);
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(icon, size: 16, color: iconColor),
        ),
      ),
    );
  }

  Future<void> _toggleYoutubeChannelOption(YoutubeChannel ch, String option) async {
    if (_youtubeToken == null) return;
    final updated = switch (option) {
      'title'   => ch.copyWith(autoTitle: !ch.autoTitle),
      'memo'    => ch.copyWith(autoMemo: !ch.autoMemo),
      'summary' => ch.copyWith(autoSummary: !ch.autoSummary),
      'quiz'  => ch.copyWith(autoQuiz: !ch.autoQuiz),
      _ => ch,
    };
    setState(() {
      final idx = _youtubeChannels.indexWhere((c) => c.id == ch.id);
      if (idx != -1) _youtubeChannels[idx] = updated;
    });
    final ok = await _apiService.updateYoutubeChannelSettings(
      token: _youtubeToken!,
      channelPk: ch.id,
      autoTitle: updated.autoTitle,
      autoMemo: updated.autoMemo,
      autoSummary: updated.autoSummary,
      autoQuiz: updated.autoQuiz,
    );
    if (!ok && mounted) {
      setState(() {
        final idx = _youtubeChannels.indexWhere((c) => c.id == ch.id);
        if (idx != -1) _youtubeChannels[idx] = ch;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정 변경에 실패했습니다.')),
      );
    }
  }

  Widget _buildVideoTile(YoutubeVideo video, YoutubeChannel ch) {
    final canOpen = ch.autoMemo && video.isDone && !video.hasNoTranscript;
    final dotColor = video.isDone
        ? Colors.green
        : video.hasNoTranscript
            ? Colors.orange
            : Colors.blue;
    final hasSummary = _videoHasSummary[video.videoId] == true;
    final hasQuiz = _videoHasQuiz[video.videoId] == true;
    return InkWell(
      onTap: () async {
        await showYoutubeVideoPlayerSheet(
          context: context,
          video: video,
          channel: ch,
          token: _youtubeToken,
        );
        // 팝업에서 요약했을 수 있으니 아이콘 상태 재조회
        _refreshVideoSummaryFlag(video.videoId);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(56, 7, 12, 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                width: 7, height: 7,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
            ),
            Expanded(
              child: Text(
                video.title,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 요약 아이콘: 요약이 1개라도 있으면 활성(테마색·탭하면 요약 보기), 없으면 비활성(연회색)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: hasSummary
                  ? () => showYoutubeSummarySheet(
                        context: context,
                        videoId: video.videoId,
                        channelName: ch.channelName,
                        videoTitle: video.title,
                        token: _youtubeToken,
                        initialMode: 'summary',
                      )
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: hasSummary ? Theme.of(context).primaryColor : Colors.grey.shade300,
                ),
              ),
            ),
            // 퀴즈 아이콘: 저장된 퀴즈가 있으면 활성(탭하면 퀴즈 보기). 생성은 영상 플레이어 시트에서.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: hasQuiz
                  ? () => showYoutubeSummarySheet(
                        context: context,
                        videoId: video.videoId,
                        channelName: ch.channelName,
                        videoTitle: video.title,
                        token: _youtubeToken,
                        initialMode: 'quiz',
                      )
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Icon(
                  Icons.lightbulb_outline,
                  size: 18,
                  color: hasQuiz ? Theme.of(context).primaryColor : Colors.grey.shade300,
                ),
              ),
            ),
            if (video.publishedAt != null)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(_youtubeShortDate(video.publishedAt!),
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }

  /// 영상 상세 팝업 (헤더: 채널명/제목/일시, 본문: 요약 또는 전사)
  void _showVideoDetailDialog(YoutubeVideo video, YoutubeChannel ch) {
    if (_youtubeToken == null) return;
    // 캐시에 없으면 lazy 로드
    if (!_youtubeVideoDetailCache.containsKey(video.id)) {
      _loadYoutubeVideoDetail(video);
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => YoutubeVideoDetailDialog(
        channelName: ch.channelName,
        video: video,
        detailCache: _youtubeVideoDetailCache,
        loadingSet: _loadingYoutubeVideoDetails,
      ),
    );
  }

  Widget _buildVideoPagination(String channelId, int page, int totalPages) {
    final color = Theme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 2, 12, 4),
      child: Row(
        children: [
          if (page > 0)
            InkWell(
              onTap: () { setState(() => _channelVideoPage[channelId] = page - 1); _loadVideoPage(channelId, page - 1); },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chevron_left, size: 16, color: color),
                    Text('이전', style: TextStyle(fontSize: 12, color: color)),
                  ],
                ),
              ),
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Text(
              '${page + 1} / $totalPages',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
          if (page < totalPages - 1)
            InkWell(
              onTap: () { setState(() => _channelVideoPage[channelId] = page + 1); _loadVideoPage(channelId, page + 1); },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('다음', style: TextStyle(fontSize: 12, color: color)),
                    Icon(Icons.chevron_right, size: 16, color: color),
                  ],
                ),
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  // ⭐ STT 자동 시작 플래그 추가
  bool _autoStartSTT = false;

  SttMemoSettings? _sttMemoSettings; // 음성 메모 설정

  void _openEditorView(_EditorType type, {
    HandwritingInitialAction action = HandwritingInitialAction.none,
    bool autoCreate = false,
    bool autoStartSTT = false,
    TextFile? textFile,
    HandwritingFile? handwritingFile,
    SttMemoSettings? sttSettings,
    String? initialPdfPath,
    String? initialPdfFileName,
    String? initialImagePath,
  }) {
    setState(() {
      _openEditor = type;
      _handwritingAction = action;
      _initialImagePath = initialImagePath;
      _autoCreate = autoCreate;
      _autoStartSTT = autoStartSTT;
      _selectedTextFile = textFile;
      _selectedHandwritingFile = handwritingFile;
      _sttMemoSettings = sttSettings;
      _initialPdfPath = initialPdfPath;
      _initialPdfFileName = initialPdfFileName;
    });
  }

  Future<void> _closeEditor() async {
    setState(() {
      _openEditor = null;
      _initialPdfPath = null;
      _initialPdfFileName = null;
      _initialImagePath = null;
    });
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    // 타이틀 카운트(필기/메모 등) 갱신 — 에디터에서 추가/삭제된 파일 반영
    await appState.updateFileCount();
    if (mounted) await _loadFiles(appState);
  }

  @override
  void dispose() {
    _audioService.removeListener(_onAudioStateChanged);
    _recordingTimer?.cancel();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final litten = appState.selectedLitten;
    if (litten == null) return;

    if (_isRecording) {
      _recordingTimer?.cancel();
      final audioFile = await _audioService.stopRecording(litten);
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordingDuration = Duration.zero;
        });
        _loadFiles(appState);
        // 상단 파일 카운트 배지(totalAudioCount 등)는 _loadFiles가 갱신하지 않으므로 별도로 재계산.
        // (녹음 직후 마이크 카운트가 안 늘던 문제)
        appState.updateFileCount();
      }
      if (audioFile != null) {
        SyncService.instance.uploadFile(
          littenId: audioFile.littenId,
          localId: audioFile.id,
          fileType: 'audio',
          fileName: audioFile.fileName,
          filePath: audioFile.filePath,
          localUpdatedAt: audioFile.updatedAt,
        );
      }
    } else {
      final success = await _audioService.startRecording(litten, undefinedPrefix: AppLocalizations.of(context)?.audioTab ?? '녹음');
      if (success && mounted) {
        setState(() {
          _isRecording = true;
          _recordingDuration = Duration.zero;
        });
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _recordingDuration += const Duration(seconds: 1));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, _) {
        final littenId = appState.selectedLitten?.id;
        final currentFileListVersion = appState.fileListVersion;

        // 리튼 ID가 변경되었거나 파일 목록 버전이 변경된 경우 파일 목록 새로고침
        if (littenId != _activeLittenId || currentFileListVersion != _lastFileListVersion) {
          _activeLittenId = littenId;
          _lastFileListVersion = currentFileListVersion;
          debugPrint('🔄 [AllFilesTab] 파일 목록 새로고침 - 리튼: $littenId, 버전: $currentFileListVersion');
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadFiles(appState));
        }

        // 전체탭 영상 채널 표시 설정이 변경된 경우 채널 목록 재로드
        // ⚠️ 결과가 0개여도 한 번만 로드하도록 플래그로 가드 (무한 리로드 방지)
        final showYoutube = appState.showYoutubeInAllTab;
        if (showYoutube && !_youtubeAutoLoadRequested) {
          _youtubeAutoLoadRequested = true;
          _lastYoutubeRefreshTick = appState.youtubeRefreshTick;
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadYoutubeChannels());
        } else if (showYoutube && appState.youtubeRefreshTick != _lastYoutubeRefreshTick) {
          // 노트탭 진입 등으로 새로고침 신호가 오면 서버에서 채널 재조회(다른 기기 추가/삭제 반영)
          _lastYoutubeRefreshTick = appState.youtubeRefreshTick;
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadYoutubeChannels());
        } else if (!showYoutube) {
          _youtubeAutoLoadRequested = false;
          if (_youtubeChannels.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _youtubeChannels = []);
            });
          }
        }

        // 에디터가 열려있으면 전체 화면으로 표시
        if (_openEditor != null) {
          return _buildEditorView(appState);
        }

        return Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else
                    _buildFileList(),
                  // STT 전용 / 첨부 전용 모드는 기존 단일 FAB 유지
                  if (widget.showOnlySTT || widget.showOnlyAttachments)
                    Positioned(
                      bottom: 28,
                      left: 0,
                      right: 0,
                      child: widget.showOnlySTT
                          ? _buildSttOnlyFab(color: Theme.of(context).primaryColor)
                          : _buildAttachmentsOnlyFab(color: Theme.of(context).primaryColor),
                    ),
                  // ── 기존 일반 노트 스피드다이얼 FAB — 메인메뉴 위 칩 행(_CreateChipBar)으로 대체.
                  //    빠르게 되돌릴 수 있도록 주석으로 보존(이 블록 주석 해제 + 아래 _CreateChipBar 제거 시 복구). ──
                  // Positioned(
                  //   bottom: 28,
                  //   left: 0,
                  //   right: 0,
                  //   child: _BottomFabRow(
                  //     onText: () async { if (await _blockedByLimit('text')) return; _openEditorView(_EditorType.text, autoCreate: true); },
                  //     onTextWithSTT: () async { if (await _blockedByLimit('stt')) return; _openEditorView(_EditorType.text, autoCreate: true, autoStartSTT: true); },
                  //     onFiles: _addAttachmentFromFiles,
                  //     onCanvas: () async { if (await _blockedByLimit('handwriting')) return; _openEditorView(_EditorType.handwriting, action: HandwritingInitialAction.createCanvas); },
                  //     onAudio: () async { if (!_isRecording && await _blockedByLimit('audio')) return; _toggleRecording(); },
                  //     onYoutube: () async {
                  //       await showYoutubeChannelSheet(context);
                  //       if (mounted) await _loadYoutubeChannels();
                  //     },
                  //     isRecording: _isRecording,
                  //     recordingDuration: _recordingDuration,
                  //   ),
                  // ),
                ],
              ),
            ),
            // ⭐ 일반 노트 모드: 메인메뉴 바로 위에 항상 표시되는 생성 칩 행(가로 스크롤).
            //    +(노트) → + → 목록의 2단계 펼침을 없애고, 칩 한 번 탭으로 즉시 생성.
            if (!widget.showOnlySTT && !widget.showOnlyAttachments)
              _CreateChipBar(
                onText: () async { if (await _blockedByLimit('text')) return; _openEditorView(_EditorType.text, autoCreate: true); },
                onTextWithSTT: () async { if (await _blockedByLimit('stt')) return; _openEditorView(_EditorType.text, autoCreate: true, autoStartSTT: true); },
                onFiles: _addAttachmentFromFiles,
                onCanvas: () async { if (await _blockedByLimit('handwriting')) return; _openEditorView(_EditorType.handwriting, action: HandwritingInitialAction.createCanvas); },
                onAudio: () async { if (!_isRecording && await _blockedByLimit('audio')) return; _toggleRecording(); },
                onPhoto: _addPhoto,
                onVideo: _addVideo,
                onYoutube: () async {
                  await showYoutubeChannelSheet(context);
                  // 시트에서 채널 등록 시 전체탭 영상 섹션 즉시 반영
                  if (mounted) await _loadYoutubeChannels();
                },
                isRecording: _isRecording,
                recordingDuration: _recordingDuration,
              ),
          ],
        );
      },
    );
  }

  Widget _buildEditorView(AppStateProvider appState) {
    switch (_openEditor!) {
      case _EditorType.text:
        return TextTab(
          key: ValueKey(_selectedTextFile?.id ?? _autoCreate),
          autoCreate: _autoCreate,
          autoStartSTT: _autoStartSTT,
          onClose: _closeEditor,
          initialFile: _selectedTextFile,
          sttSettings: _sttMemoSettings,
        );
      case _EditorType.handwriting:
        // ⭐ 선택된 파일의 imagePath가 .pdf로 끝나면 Syncfusion PDF 에디터로 진입
        final selFile = _selectedHandwritingFile;
        if (selFile != null && selFile.imagePath.toLowerCase().endsWith('.pdf')) {
          return SyncfusionPdfEditor(
            key: ValueKey('syncfusion_${selFile.id}'),
            file: selFile,
            onClose: _closeEditor,
          );
        }
        return HandwritingTab(
          key: ValueKey(_selectedHandwritingFile?.id ?? _initialImagePath ?? _initialPdfPath ?? _handwritingAction),
          initialAction: _handwritingAction,
          onClose: _closeEditor,
          initialFile: _selectedHandwritingFile,
          initialPdfPath: _initialPdfPath,
          initialPdfFileName: _initialPdfFileName,
          initialImagePath: _initialImagePath,
        );
    }
  }

  Widget _buildSttOnlyFab({required Color color}) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: FloatingActionButton(
          heroTag: 'stt_memo_fab',
          backgroundColor: color,
          foregroundColor: Colors.white,
          onPressed: () => _openEditorView(_EditorType.text, autoCreate: true, autoStartSTT: true),
          child: const Icon(Icons.record_voice_over),
        ),
      ),
    );
  }

  Widget _buildAttachmentsOnlyFab({required Color color}) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: FloatingActionButton(
          heroTag: 'attachments_only_fab',
          backgroundColor: color,
          foregroundColor: Colors.white,
          onPressed: _addAttachmentFromFiles,
          child: const Icon(Icons.drive_folder_upload),
        ),
      ),
    );
  }

  // 현재 전체탭 필터(공유 상태). 탭바 버튼의 드롭다운에서 변경되며 Provider로 공유된다.
  _FileFilter get _fileFilter {
    final s = Provider.of<AppStateProvider>(context, listen: false).allTabFileFilter;
    return _FileFilter.values.firstWhere((e) => e.name == s, orElse: () => _FileFilter.all);
  }

  // 상단 필터에 따라 파일 목록을 거른다. (youtube는 파일이 아닌 채널이라 파일 목록은 비움)
  List<_MergedFile> _applyFilter(List<_MergedFile> src) {
    switch (_fileFilter) {
      case _FileFilter.all:
        return src;
      case _FileFilter.youtube:
        return const <_MergedFile>[];
      case _FileFilter.text:
        return src.where((m) => m.type == _FileType.text && !(m.file as TextFile).isFromSTT).toList();
      case _FileFilter.audio:
        return src.where((m) => m.type == _FileType.audio && !(m.file as AudioFile).isFromSTT).toList();
      case _FileFilter.stt:
        return src.where((m) =>
            (m.type == _FileType.text && (m.file as TextFile).isFromSTT) ||
            (m.type == _FileType.audio && (m.file as AudioFile).isFromSTT)).toList();
      case _FileFilter.handwriting:
        return src.where((m) => m.type == _FileType.handwriting).toList();
      case _FileFilter.attachment:
        // 파일 = 사진/비디오를 제외한 일반 첨부
        return src.where((m) =>
            m.type == _FileType.attachment &&
            !(m.file as AttachmentFile).isImage &&
            !(m.file as AttachmentFile).isVideo).toList();
      case _FileFilter.photo:
        return src.where((m) =>
            m.type == _FileType.attachment && (m.file as AttachmentFile).isImage).toList();
      case _FileFilter.video:
        return src.where((m) =>
            m.type == _FileType.attachment && (m.file as AttachmentFile).isVideo).toList();
    }
  }

  // 제목 아이콘 토글로 숨긴 종류인지 판정 (text/audio/canvas/pdf/files/photo/video)
  bool _hiddenByTitleToggle(_MergedFile m, Set<String> hidden) {
    if (hidden.isEmpty) return false;
    switch (m.type) {
      case _FileType.text:
        // STT(녹음 메모) 텍스트는 'stt', 일반 텍스트는 'text'
        return hidden.contains((m.file as TextFile).isFromSTT ? 'stt' : 'text');
      case _FileType.audio:
        // STT(녹음 메모) 오디오는 'stt', 일반 녹음은 'audio'
        return hidden.contains((m.file as AudioFile).isFromSTT ? 'stt' : 'audio');
      case _FileType.handwriting:
        final isPdf = (m.file as HandwritingFile).type == HandwritingType.pdfConvert;
        return hidden.contains(isPdf ? 'pdf' : 'canvas');
      case _FileType.attachment:
        final a = m.file as AttachmentFile;
        if (a.isImage) return hidden.contains('photo');
        if (a.isVideo) return hidden.contains('video');
        return hidden.contains('files');
    }
  }

  Widget _buildFileList() {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final hidden = appState.allTabHiddenTypes;
    // 단일 필터(드롭다운, 현재 히든) + 제목 아이콘 토글 숨김을 함께 적용
    final merged = _applyFilter(_mergedFiles)
        .where((m) => !_hiddenByTitleToggle(m, hidden))
        .toList();
    final showYoutubeSection = !widget.showOnlySTT && !widget.showOnlyAttachments
        && (_fileFilter == _FileFilter.all || _fileFilter == _FileFilter.youtube)
        && !hidden.contains('youtube')
        && appState.showYoutubeInAllTab
        && (_youtubeChannels.isNotEmpty || _loadingChannels);

    if (merged.isEmpty && !showYoutubeSection) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.showOnlySTT
                  ? Icons.record_voice_over
                  : widget.showOnlyAttachments
                      ? Icons.drive_folder_upload
                      : Icons.folder_open,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Builder(builder: (ctx) {
              final l10n = AppLocalizations.of(ctx);
              return Text(
                widget.showOnlySTT
                    ? (l10n?.noVoiceMemos ?? '녹음 메모가 없습니다.\n아래 버튼으로 시작하세요.')
                    : widget.showOnlyAttachments
                        ? '파일이 없습니다.\n아래 버튼으로 추가하세요.'
                        : (l10n?.noFilesPrompt ?? '첫 기록을 시작해보세요\n아래 버튼으로 듣기·쓰기·필기를 추가할 수 있어요'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500]),
              );
            }),
          ],
        ),
      );
    }

    // 전체탭 정렬 구조 (2영역):
    //  ① 상단 NEW 영역: 새 영상이 생겨 고정(핀)된 채널들. "영상이 추가된 순서"(최신 영상 게시일
    //     _latestVideoAt 내림차순)로 모아 맨 위에 노출. 확인 후 닫으면 핀이 풀려 ②로 내려간다.
    //  ② 기본 영역: 파일=수정일(updatedAt), 채널=생성(등록)일시(_channelAddedAt)를 하나의
    //     시간순 목록으로 섞어 내림차순 정렬.
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);

    // 전체(all) 필터에서 "새 영상이 있는(NEW 핀) 채널"이 있으면:
    //  위 50% = 새 영상 채널, 아래 50% = 나머지(파일 + 새 영상 없는 일반 채널 시간순 통합).
    // 새 영상 채널이 없으면 분할하지 않고 기존 통합 리스트를 유지한다.
    final hasNewVideoChannels = showYoutubeSection &&
        _youtubeChannels.any((ch) => _newPinnedChannels.contains(ch.channelId));
    if (_fileFilter == _FileFilter.all && hasNewVideoChannels) {
      return _buildSplitChannelFileView(merged, epoch);
    }

    final topChannels = showYoutubeSection
        ? _youtubeChannels.where((ch) => _newPinnedChannels.contains(ch.channelId)).toList()
        : <YoutubeChannel>[];
    // 영상이 추가된 순서 = 최신 영상 게시일 내림차순
    topChannels.sort((a, b) =>
        (_latestVideoAt[b.channelId] ?? epoch).compareTo(_latestVideoAt[a.channelId] ?? epoch));

    final baseItems = <({DateTime sortAt, _MergedFile? file, YoutubeChannel? channel})>[
      for (final f in merged) (sortAt: f.sortAt, file: f, channel: null),
      if (showYoutubeSection)
        for (final ch in _youtubeChannels)
          if (!_newPinnedChannels.contains(ch.channelId))
            // 채널 정렬 기준 = 실제 등록일시(서버 registeredAt) 우선, 없으면 기존 추정값(_channelAddedAt) 폴백
            (sortAt: ch.registeredAt ?? _channelAddedAt[ch.channelId] ?? epoch, file: null, channel: ch),
    ];
    baseItems.sort((a, b) => b.sortAt.compareTo(a.sortAt));

    final items = <({DateTime sortAt, _MergedFile? file, YoutubeChannel? channel})>[
      for (final ch in topChannels)
        (sortAt: _latestVideoAt[ch.channelId] ?? epoch, file: null, channel: ch),
      ...baseItems,
    ];
    final int topCount = topChannels.length;

    final listSliver = SliverPadding(
      padding: const EdgeInsets.only(bottom: 80),
      sliver: SliverList.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final entry = items[index];
          final at = entry.sortAt;
          final currentDate = DateTime(at.year, at.month, at.day);
          // 상단 NEW 영역(고정 채널)은 날짜 헤더 없이 카드만 노출한다.
          final bool isTop = index < topCount;
          // 직전 항목 비교는 기본 영역 안에서만(상단 영역 항목은 비교 대상에서 제외).
          final prevAt = (index == 0 || index - 1 < topCount) ? null : items[index - 1].sortAt;
          // 날짜 헤더: 기본 영역에서 직전 항목과 날짜가 다를 때만. 게시일 미상(epoch, 2000년 이전)은 헤더 생략.
          final showDateHeader = !isTop && at.year >= 2000 &&
              (prevAt == null || DateTime(prevAt.year, prevAt.month, prevAt.day) != currentDate);

          final f = entry.file;
          final Widget card = f != null
              ? switch (f.type) {
                  _FileType.text => _buildTextCard(f.file as TextFile),
                  _FileType.handwriting => _buildHandwritingCard(f.file as HandwritingFile),
                  _FileType.audio => _buildAudioCard(f.file as AudioFile),
                  _FileType.attachment => _buildAttachmentCard(f.file as AttachmentFile),
                }
              : _buildYoutubeChannelCard(entry.channel!);

          if (showDateHeader) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_buildDateHeader(currentDate), card],
            );
          }
          return card;
        },
      ),
    );

    return RefreshIndicator(
      onRefresh: () => _refreshFilesAndVideos(appState),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [listSliver],
      ),
    );
  }

  /// 전체(all) 필터 전용 분할 뷰.
  ///  • 위 50%  = 새 영상이 있는(NEW 핀) 채널만 (최신 영상 게시일 내림차순)
  ///  • 아래 50% = 파일 + 새 영상 없는 일반 채널을 시간순(수정일/등록일)으로 통합
  Widget _buildSplitChannelFileView(List<_MergedFile> merged, DateTime epoch) {
    final color = Theme.of(context).primaryColor;
    final appState = Provider.of<AppStateProvider>(context, listen: false);

    // 위 50%: 새 영상이 있는(NEW 핀) 채널 — 최신 영상 게시일 내림차순
    final newChannels = _youtubeChannels
        .where((ch) => _newPinnedChannels.contains(ch.channelId))
        .toList()
      ..sort((a, b) => (_latestVideoAt[b.channelId] ?? epoch)
          .compareTo(_latestVideoAt[a.channelId] ?? epoch));

    // 아래 50%: 파일 + 새 영상 없는 일반 채널 — 시간순 통합 내림차순
    final baseItems = <({DateTime sortAt, _MergedFile? file, YoutubeChannel? channel})>[
      for (final f in merged) (sortAt: f.sortAt, file: f, channel: null),
      for (final ch in _youtubeChannels)
        if (!_newPinnedChannels.contains(ch.channelId))
          (sortAt: ch.registeredAt ?? _channelAddedAt[ch.channelId] ?? epoch, file: null, channel: ch),
    ]..sort((a, b) => b.sortAt.compareTo(a.sortAt));

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
      children: [
        // ── 위: 새 영상이 있는 채널 — 채널 수만큼만 차지(최대 50%), 넘치면 내부 스크롤 ──
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.5),
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            itemCount: newChannels.length,
            itemBuilder: (context, index) => _buildYoutubeChannelCard(newChannels[index]),
          ),
        ),
        Divider(height: 1, color: color.withValues(alpha: 0.2)),
        // ── 아래: 파일 + 일반 채널(시간순 통합) — 남은 공간 전부 ──
        Expanded(
          child: baseItems.isEmpty
              ? Center(
                  child: Text('항목이 없습니다.',
                      style: TextStyle(color: Colors.grey[500])),
                )
              : RefreshIndicator(
                  onRefresh: () => _refreshFilesAndVideos(appState),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.only(top: 4, bottom: 80),
                        sliver: SliverList.builder(
                          itemCount: baseItems.length,
                          itemBuilder: (context, index) {
                            final entry = baseItems[index];
                            final at = entry.sortAt;
                            final currentDate = DateTime(at.year, at.month, at.day);
                            final prevAt = index == 0 ? null : baseItems[index - 1].sortAt;
                            final showDateHeader = at.year >= 2000 &&
                                (prevAt == null ||
                                    DateTime(prevAt.year, prevAt.month, prevAt.day) != currentDate);
                            final f = entry.file;
                            final Widget card = f != null
                                ? switch (f.type) {
                                    _FileType.text => _buildTextCard(f.file as TextFile),
                                    _FileType.handwriting => _buildHandwritingCard(f.file as HandwritingFile),
                                    _FileType.audio => _buildAudioCard(f.file as AudioFile),
                                    _FileType.attachment => _buildAttachmentCard(f.file as AttachmentFile),
                                  }
                                : _buildYoutubeChannelCard(entry.channel!);
                            if (showDateHeader) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [_buildDateHeader(currentDate), card],
                              );
                            }
                            return card;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
        );
      },
    );
  }

  Widget _buildYoutubeChannelCard(YoutubeChannel ch) {
    final color = Theme.of(context).primaryColor;
    final isExpanded = _expandedChannels.contains(ch.channelId);
    final currentPage = _channelVideoPage[ch.channelId] ?? 0;
    final isLoadingVideos = _loadingVideoKeys.contains('${ch.channelId}_$currentPage');
    // 로컬/서버 모두 페이지당 3개씩 (페이지네이션은 _buildVideoPagination에서 처리)
    final videos = _videoPageData[ch.channelId]?[currentPage] ?? [];

    return Card(
      // 항목 높이 1.5배: 헤더 세로 패딩 3→10
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 채널명 앞 구독 아이콘 (파일 카드 leading과 동일한 32px 슬롯 + 12 간격으로 정렬)
                SizedBox(
                  width: 32,
                  height: 21,
                  child: Center(child: Icon(Icons.subscriptions, color: color, size: 18)),
                ),
                const SizedBox(width: 12),
                // 채널명 (탭 시 영상 리스트 펼침/접힘)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _toggleChannel(ch),
                    child: Text(
                      ch.channelName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // 새 영상 아이콘 — 아직 확인 안 한 새 영상이 있으면 활성(빨강), 없으면 회색
                Tooltip(
                  message: _hasNewVideo(ch) ? '새 영상 있음' : '새 영상 없음',
                  child: Icon(
                    Icons.fiber_new,
                    size: 20,
                    color: _hasNewVideo(ch) ? Colors.red : Colors.grey.shade300,
                  ),
                ),
                const SizedBox(width: 4),
                if (isLoadingVideos)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                // 제일 우측: 더보기(⋮) 메뉴 — 파일 카드와 일관(삭제만)
                _moreMenuBtn(
                  color: color,
                  onDelete: () => _unsubscribeYoutubeChannel(ch),
                ),
              ],
            ),
          ),
          if (isExpanded) ...[
            Divider(height: 1, indent: 56, color: color.withValues(alpha: 0.15)),
            if (videos.isEmpty && !isLoadingVideos)
              const Padding(
                padding: EdgeInsets.fromLTRB(56, 10, 12, 10),
                child: Text('아직 처리된 영상이 없습니다.', style: TextStyle(color: Colors.grey, fontSize: 13)),
              )
            else ...[
              ...videos.map((v) => _buildVideoTile(v, ch)),
              ...() {
                final totalPages = _videoTotalPages[ch.channelId] ?? 1;
                return totalPages > 1 ? [_buildVideoPagination(ch.channelId, currentPage, totalPages)] : <Widget>[];
              }(),
            ],
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  Widget _buildDateHeader(DateTime date) {
    final primaryColor = Theme.of(context).primaryColor;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    String label;
    if (date == today) {
      label = '오늘';
    } else if (date == yesterday) {
      label = '어제';
    } else {
      label = DateFormat('yyyy년 M월 d일 (E)', 'ko').format(date);
    }

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: primaryColor.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }

  // ── 클라우드 동기화 상태 아이콘 (trailing용, 툴팁 포함) ──
  // 24x24 통일 동기화 아이콘 (모든 상태에 아이콘 표시)
  Widget _buildSyncIconUnified(SyncStatus status, {DateTime? cloudUpdatedAt, DateTime? updatedAt}) {
    // 클라우드 동기화는 프리미엄(서버 보관) 전용 → 무료/스탠다드는 아이콘 숨김
    if (!_isPremiumPlus) return const SizedBox.shrink();
    final timeStr = (cloudUpdatedAt ?? updatedAt)?.toString().substring(0, 16) ?? '';
    final primaryColor = Theme.of(context).primaryColor;
    Widget icon;
    String tooltipText = timeStr;
    switch (status) {
      case SyncStatus.synced:
        icon = Icon(Icons.cloud_done, size: 16, color: primaryColor);
        break;
      case SyncStatus.pending:
        icon = Icon(Icons.cloud_upload_outlined, size: 16, color: Colors.orange.shade400);
        break;
      case SyncStatus.syncing:
        icon = const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.5));
        break;
      case SyncStatus.error:
        icon = const Icon(Icons.cloud_off, size: 16, color: Colors.red);
        break;
      case SyncStatus.none:
        // 동기화 안 됨 - 회색 cloud_off 아이콘
        icon = Icon(Icons.cloud_off_outlined, size: 16, color: Colors.grey.shade400);
        tooltipText = '동기화 안 됨';
        break;
    }
    return Tooltip(
      message: tooltipText,
      child: SizedBox(width: 24, height: 24, child: Center(child: icon)),
    );
  }

  // 통일된 24x24 ⋮ 메뉴 (수정/삭제)
  Widget _moreMenuBtn({
    required Color color,
    VoidCallback? onEdit, // null이면 '수정' 항목 생략 (예: 영상 채널은 삭제만)
    required VoidCallback onDelete,
  }) {
    return SizedBox(
      width: 24,
      height: 24,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        iconSize: 16,
        icon: Icon(Icons.more_vert, color: color, size: 16),
        tooltip: AppLocalizations.of(context)?.menuTooltip ?? '메뉴',
        onSelected: (value) {
          if (value == 'edit') onEdit?.call();
          else if (value == 'delete') onDelete();
        },
        itemBuilder: (ctx) {
          final l10n = AppLocalizations.of(ctx);
          return [
            if (onEdit != null)
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    const Icon(Icons.edit_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(l10n?.editLabel ?? '수정'),
                  ],
                ),
              ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(l10n?.delete ?? '삭제', style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ];
        },
      ),
    );
  }

  // 통일된 24x24 아이콘 버튼 (placeholder는 icon: null)
  /// 퀴즈 아이콘 — 파일에 추출된 항목이 있으면 활성(테마색),
  /// 없으면 비활성(연회색). 활성 상태에서 탭하면 리마인드 탭으로 이동.
  /// 아이콘: 전구(lightbulb) 안에 소문자 'q'를 넣은 합성 모양.
  Widget _buildQuizIcon(String fileId, Color color) {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final count = appState.quizItemsForFile(fileId).length;
    final active = count > 0;
    final iconColor = active ? color : Colors.grey.shade400;
    return SizedBox(
      width: 24,
      height: 24,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: active
              ? () {
                  debugPrint('💡 [AllFilesTab] 퀴즈 아이콘 탭 - 파일 $fileId, $count개 → 리마인드 탭 이동');
                  appState.changeTabIndex(3); // 5탭: 홈0·캘린더1·+2·리마인드3·설정4
                }
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Tooltip(
            message: active ? '퀴즈 $count개' : '퀴즈 없음',
            child: Center(child: _quizBulbIcon(iconColor, 18)),
          ),
        ),
      ),
    );
  }

  /// 꽉 찬 전구(lightbulb) 안에 흰색 소문자 'q'를 올린 퀴즈 아이콘.
  /// (외곽선 전구 위에 글자를 겹치면 전구선과 섞여 깨져 보여, 채운 전구 + 흰 q로 또렷하게)
  Widget _quizBulbIcon(Color color, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.lightbulb, size: size, color: color),
          // 전구 유리(위쪽 둥근 부분) 중앙에 흰 q — 살짝 위로 올려 또렷하게
          Positioned(
            top: size * 0.07,
            child: Text(
              'q',
              style: TextStyle(
                fontSize: size * 0.5,
                height: 1.0,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn({
    IconData? icon,
    Color? color,
    VoidCallback? onPressed,
    String? tooltip,
  }) {
    if (icon == null) {
      return const SizedBox(width: 24, height: 24);
    }
    return SizedBox(
      width: 24,
      height: 24,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Tooltip(
            message: tooltip ?? '',
            child: Icon(icon, color: color, size: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildSyncIcon(SyncStatus status, {DateTime? cloudUpdatedAt, DateTime? updatedAt}) {
    final isPremium = Provider.of<AppStateProvider>(context, listen: false).isPremiumPlusUser;
    if (!isPremium || status == SyncStatus.none) {
      return const SizedBox(width: 16, height: 16);
    }

    final timeStr = (cloudUpdatedAt ?? updatedAt)?.toString().substring(0, 16) ?? '';
    final primaryColor = Theme.of(context).primaryColor;
    Widget icon;
    switch (status) {
      case SyncStatus.synced:
        icon = Icon(Icons.cloud_done, size: 16, color: primaryColor);
        break;
      case SyncStatus.pending:
        icon = Icon(Icons.cloud_upload_outlined, size: 16, color: Colors.orange.shade400);
        break;
      case SyncStatus.syncing:
        icon = const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.5));
        break;
      case SyncStatus.error:
        icon = const Icon(Icons.cloud_off, size: 16, color: Colors.red);
        break;
      case SyncStatus.none:
        return const SizedBox(width: 16, height: 16);
    }
    return Tooltip(
      message: timeStr,
      child: SizedBox(width: 16, height: 16, child: Center(child: icon)),
    );
  }

  // ── 텍스트 카드 ──
  Widget _buildTextCard(TextFile file) {
    final color = Theme.of(context).primaryColor;
    final isFromSTT = file.isFromSTT;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: InkWell(
        onTap: () => _openEditorView(_EditorType.text, textFile: file),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Leading 아이콘
              SizedBox(
                width: 32,
                height: 32,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: color.withValues(alpha: 0.1),
                      child: Icon(Icons.notes, color: color, size: 18),
                    ),
                    if (isFromSTT)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 17,
                          height: 17,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(Icons.record_voice_over, size: 10, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // 제목 영역 (60%)
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      file.title.isNotEmpty
                          ? file.title
                          : '${AppLocalizations.of(context)?.memoLabel ?? '메모'} ${DateFormat('yyMMddHHmm').format(file.createdAt)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                          AppLocalizations.of(context)?.characterCount(file.characterCount) ?? '${file.characterCount}자',
                          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
              // 아이콘 영역 (40%) - 5개 아이콘 균일 분배
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 순서: 요약 · 퀴즈 · 클라우드 · 공유
                    _iconBtn(
                      icon: Icons.auto_awesome,
                      color: file.hasSummary ? color : Colors.grey.shade400,
                      tooltip: file.hasSummary
                          ? (AppLocalizations.of(context)?.viewSummary ?? '요약 보기')
                          : (AppLocalizations.of(context)?.noSummary ?? '요약 없음'),
                      onPressed: () => _showSummaryDialog(file),
                    ),
                    _buildQuizIcon(file.id, color),
                    _buildSyncIconUnified(file.syncStatus, cloudUpdatedAt: file.cloudUpdatedAt, updatedAt: file.updatedAt),
                    if (_isPremiumPlus)
                      _iconBtn(
                        icon: Icons.share_outlined,
                        color: Provider.of<AppStateProvider>(context, listen: false).isFileShared(file.id) ? color : Colors.grey.shade400, // 공유했으면 활성(색상)
                        tooltip: AppLocalizations.of(context)?.share ?? '공유',
                        onPressed: () => _openShareSheet(
                          title: file.displayTitle,
                          onUser: () => _shareTextFileToUser(file),
                          onExternal: () => _shareTextFile(file),
                        ),
                      ),
                    _moreMenuBtn(
                      color: color,
                      onEdit: () => _showRenameTextDialog(file),
                      onDelete: () => _showDeleteDialog(file.displayTitle, () => _deleteTextFile(file)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 필기 카드 ──
  Widget _buildHandwritingCard(HandwritingFile file) {
    final color = Theme.of(context).primaryColor;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: InkWell(
        onTap: () => _openEditorView(_EditorType.handwriting, handwritingFile: file),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Leading 아이콘:
              // - .pdf 원본 파일(Syncfusion 흐름): 순수 PDF 아이콘
              // - .png 다중 페이지 PDF 변환(기존 흐름): 필기 + PDF 뱃지
              // - 일반 필기: 필기 아이콘
              SizedBox(
                width: 32,
                height: 32,
                child: () {
                  final isPdfDoc = file.imagePath.toLowerCase().endsWith('.pdf');
                  if (isPdfDoc) {
                    return CircleAvatar(
                      radius: 16,
                      backgroundColor: color.withValues(alpha: 0.1),
                      child: Icon(Icons.picture_as_pdf, color: color, size: 18),
                    );
                  }
                  return Stack(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: color.withValues(alpha: 0.1),
                        child: Icon(Icons.draw, color: color, size: 18),
                      ),
                      if (file.type == HandwritingType.pdfConvert)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 17,
                            height: 17,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Icon(Icons.picture_as_pdf, size: 10, color: Colors.white),
                          ),
                        ),
                    ],
                  );
                }(),
              ),
              const SizedBox(width: 12),
              // 제목 영역 (60%)
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      file.displayTitle,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (file.isMultiPage) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                            AppLocalizations.of(context)?.pageCount(file.totalPages) ?? '${file.totalPages}페이지',
                            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ],
                ),
              ),
              // 아이콘 영역 (40%) - 5개 아이콘 균일 분배
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 순서: 요약 · 퀴즈 · 클라우드 · 공유
                    // 요약/퀴즈는 메모(텍스트) 파일만 지원 — 그 외 파일은 빈 자리(간격 유지)
                    _iconBtn(icon: null),
                    _iconBtn(icon: null),
                    _buildSyncIconUnified(file.syncStatus, cloudUpdatedAt: file.cloudUpdatedAt, updatedAt: file.updatedAt),
                    if (_isPremiumPlus)
                      _iconBtn(
                        icon: Icons.share_outlined,
                        color: Provider.of<AppStateProvider>(context, listen: false).isFileShared(file.id) ? color : Colors.grey.shade400, // 공유했으면 활성(색상)
                        tooltip: AppLocalizations.of(context)?.share ?? '공유',
                        onPressed: () => _openShareSheet(
                          title: file.displayTitle,
                          onUser: () => _shareHandwritingFileToUser(file),
                          onExternal: () => _shareHandwritingFile(file),
                        ),
                      ),
                    _moreMenuBtn(
                      color: color,
                      onEdit: () => _showRenameHandwritingDialog(file),
                      onDelete: () => _showDeleteDialog(file.displayTitle, () => _deleteHandwritingFile(file)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 선택된 PDF 경로를 받아 Syncfusion 흐름으로 HandwritingFile 등록 + 에디터 진입
  /// (노트 + → 파일에서 PDF 선택 시 호출)
  Future<void> _registerPdfForSyncfusion(
    String pdfPath,
    String pdfName,
    dynamic selectedLitten,
    AppStateProvider appState,
  ) async {
    // PDF 가져오기는 필기 파일(pdfConvert)로 등록되므로 필기 개수 제한을 적용한다.
    final block = await appState.createBlockReason('handwriting');
    if (block != null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(block)));
      return;
    }
    try {
      // 1) 리튼의 handwriting 폴더로 PDF 원본 복사
      final docDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${docDir.path}/littens/${selectedLitten.id}/handwriting');
      if (!await dir.exists()) await dir.create(recursive: true);
      // 2) HandwritingFile 메타데이터 (imagePath = 절대 PDF 경로, 단일 파일)
      // 제목에 .pdf 확장자를 그대로 노출한다(목록에서 PDF임을 표시 + 동기화 fileName과 일치).
      final newFile = HandwritingFile(
        littenId: selectedLitten.id,
        title: pdfName,
        imagePath: '',
        type: HandwritingType.pdfConvert,
      );
      final savedPdfPath = '${dir.path}/${newFile.id}.pdf';
      await File(pdfPath).copy(savedPdfPath);
      final saved = newFile.copyWith(imagePath: savedPdfPath);

      // 3) 메타데이터 저장 + 리튼 연결
      final stored = await FileStorageService.instance
          .loadHandwritingFiles(selectedLitten.id);
      stored.add(saved);
      await FileStorageService.instance
          .saveHandwritingFiles(selectedLitten.id, stored);
      await LittenService().addHandwritingFileToLitten(
        selectedLitten.id,
        saved.id,
      );

      // 3-1) 클라우드 업로드 — 변환된 PDF 원본을 .pdf 이름으로 올려 다른 기기에서 PDF로 복원되게 한다.
      // (이 호출이 없어 변환 PDF가 공유되지 않던 문제 수정. fileName 확장자 .pdf로 수신측이 PDF임을 인지)
      SyncService.instance.uploadFile(
        littenId: selectedLitten.id,
        localId: saved.id,
        fileType: 'handwriting',
        fileName: pdfName, // "{제목}.pdf"
        filePath: savedPdfPath,
        localUpdatedAt: saved.updatedAt,
      );

      // 4) 파일 카운트/목록 갱신
      if (mounted) {
        await appState.updateFileCount();
        appState.notifyFileListChanged();
        await _loadFiles(appState);
        // 5) 새 에디터로 진입
        _openEditorView(_EditorType.handwriting, handwritingFile: saved);
      }
      debugPrint('✅ Syncfusion PDF 등록: ${saved.id} ($savedPdfPath)');
    } catch (e, st) {
      debugPrint('❌ PDF 등록 실패: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF를 추가하지 못했습니다: $e')),
        );
      }
    }
  }

  /// 임의의 파일을 선택해 노트에 첨부 (분석/보관/공유 용)
  /// 전체 탭에서 에디터(메모/필기 등)를 열기 **전에** 개수 제한을 체크한다.
  /// 초과 시 안내 스낵바를 띄우고 true(차단) 반환 → 탭 이동/에디터 진입을 막아 전체 탭에 머문다.
  Future<bool> _blockedByLimit(String kind) async {
    final block = await Provider.of<AppStateProvider>(context, listen: false).createBlockReason(kind);
    if (block != null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(block)));
      return true;
    }
    return false;
  }

  Future<void> _addAttachmentFromFiles() async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final selectedLitten = appState.selectedLitten;
    if (selectedLitten == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('리튼을 먼저 선택해주세요'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // ⭐ "노트 > + > 파일"을 누른 즉시 첨부 개수 제한을 체크 — 한도 초과면 파일 선택기를 열기 전에 안내
    final attachBlock = await appState.createBlockReason('attachment');
    if (attachBlock != null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(attachBlock)));
      return;
    }

    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
      );
    } catch (e) {
      debugPrint('❌ 파일 선택 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일을 가져오지 못했습니다: $e')),
        );
      }
      return;
    }
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    if (picked.path == null) return;

    // ⭐ PDF 파일이면 Syncfusion 에디터 흐름으로 등록 (첨부 파일 아닌 HandwritingFile)
    // → 제한 체크는 _registerPdfForSyncfusion 내부에서 'handwriting'(필기) 기준으로 수행
    if (picked.name.toLowerCase().endsWith('.pdf')) {
      await _registerPdfForSyncfusion(
        picked.path!,
        picked.name,
        selectedLitten,
        appState,
      );
      return;
    }

    try {
      // 1) 리튼의 attachments 폴더로 복사 (원본 그대로)
      final docDir = await getApplicationDocumentsDirectory();
      final attachDir = Directory(
        '${docDir.path}/littens/${selectedLitten.id}/attachments',
      );
      if (!await attachDir.exists()) {
        await attachDir.create(recursive: true);
      }

      final ts = DateTime.now().millisecondsSinceEpoch;
      final safeName = picked.name.replaceAll(RegExp(r'[\\/]'), '_');
      final savedPath = '${attachDir.path}/${ts}_$safeName';
      await File(picked.path!).copy(savedPath);
      final fileSize = await File(savedPath).length();

      // 2) AttachmentFile 메타데이터 저장
      final attachment = AttachmentFile(
        littenId: selectedLitten.id,
        fileName: picked.name,
        filePath: savedPath,
        sizeBytes: fileSize,
      );
      final stored = await FileStorageService.instance
          .loadAttachmentFiles(selectedLitten.id);
      stored.add(attachment);
      await FileStorageService.instance
          .saveAttachmentFiles(selectedLitten.id, stored);

      // 3) 리튼-첨부파일 연결
      await LittenService().addAttachmentFileToLitten(
        selectedLitten.id,
        attachment.id,
      );

      // 3.5) 클라우드 동기화 업로드 (프리미엄+로그인 시 내부에서 판단)
      SyncService.instance.uploadFile(
        littenId: selectedLitten.id,
        localId: attachment.id,
        fileType: 'attachment',
        fileName: attachment.fileName,
        filePath: attachment.filePath,
        localUpdatedAt: attachment.updatedAt,
      );

      // 4) 파일 카운트 갱신 + 목록 새로고침
      if (mounted) {
        await appState.updateFileCount();
        appState.notifyFileListChanged();
        await _loadFiles(appState);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${picked.name}" 파일이 추가되었습니다')),
        );
      }
      debugPrint('✅ 첨부 파일 추가 완료: ${attachment.id}');
    } catch (e, st) {
      debugPrint('❌ 첨부 파일 추가 실패: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일 추가에 실패했습니다: $e')),
        );
      }
    }
  }

  // ── 사진/비디오 추가 (image_picker → 첨부파일로 저장) ──
  // 사진은 첨부(이미지)로 저장되어 파일 리스트에 나타나고, 리스트에서 탭하면 필기로 편집된다.
  Future<void> _addPhoto() => _pickMedia(isVideo: false);
  Future<void> _addVideo() => _pickMedia(isVideo: true);

  Future<void> _pickMedia({required bool isVideo}) async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final selectedLitten = appState.selectedLitten;
    if (selectedLitten == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('리튼을 먼저 선택해주세요'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    // 첨부 개수 제한(사진/비디오도 첨부로 저장되므로 'attachment' 기준)
    final block = await appState.createBlockReason('attachment');
    if (block != null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(block)));
      return;
    }

    // 입력 소스 선택 시트 (카메라 / 갤러리)
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(isVideo ? '카메라로 촬영' : '카메라로 촬영'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리에서 선택'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final picker = ImagePicker();
      final XFile? picked = isVideo
          ? await picker.pickVideo(source: source)
          : await picker.pickImage(source: source);
      if (picked == null) return;
      // 파일명: 다른 파일과 동일하게 "사진/비디오 YYMMDDHHmmss" + 원본 확장자
      final now = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      final stamp = '${now.year.toString().substring(2)}${two(now.month)}${two(now.day)}'
          '${two(now.hour)}${two(now.minute)}${two(now.second)}';
      final base = picked.name.isNotEmpty ? picked.name : picked.path;
      final dot = base.lastIndexOf('.');
      final ext = dot >= 0 ? base.substring(dot) : (isVideo ? '.mp4' : '.jpg');
      final name = '${isVideo ? '비디오' : '사진'} $stamp$ext';
      await _saveAttachmentFromPath(picked.path, name);
    } catch (e) {
      debugPrint('❌ 미디어 가져오기 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('가져오지 못했습니다: $e')),
        );
      }
    }
  }

  // 선택/촬영한 미디어를 첨부파일로 저장(복사 → 메타 → 리튼 연결 → 동기화 → 목록 갱신)
  Future<void> _saveAttachmentFromPath(String srcPath, String fileName) async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final selectedLitten = appState.selectedLitten;
    if (selectedLitten == null) return;
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final attachDir = Directory('${docDir.path}/littens/${selectedLitten.id}/attachments');
      if (!await attachDir.exists()) await attachDir.create(recursive: true);

      final ts = DateTime.now().millisecondsSinceEpoch;
      final safeName = fileName.replaceAll(RegExp(r'[\\/]'), '_');
      final savedPath = '${attachDir.path}/${ts}_$safeName';
      await File(srcPath).copy(savedPath);
      final fileSize = await File(savedPath).length();

      final attachment = AttachmentFile(
        littenId: selectedLitten.id,
        fileName: fileName,
        filePath: savedPath,
        sizeBytes: fileSize,
      );
      final stored = await FileStorageService.instance.loadAttachmentFiles(selectedLitten.id);
      stored.add(attachment);
      await FileStorageService.instance.saveAttachmentFiles(selectedLitten.id, stored);
      await LittenService().addAttachmentFileToLitten(selectedLitten.id, attachment.id);

      SyncService.instance.uploadFile(
        littenId: selectedLitten.id,
        localId: attachment.id,
        fileType: 'attachment',
        fileName: attachment.fileName,
        filePath: attachment.filePath,
        localUpdatedAt: attachment.updatedAt,
      );

      if (mounted) {
        await appState.updateFileCount();
        appState.notifyFileListChanged();
        await _loadFiles(appState);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$fileName" 추가되었습니다')),
        );
      }
      debugPrint('✅ 미디어 첨부 저장 완료: ${attachment.id}');
    } catch (e) {
      debugPrint('❌ 미디어 첨부 저장 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    }
  }

  // ── 첨부 파일 카드 ──
  Widget _buildAttachmentCard(AttachmentFile file) {
    final color = Theme.of(context).primaryColor;
    final ext = file.extension.toUpperCase();
    final isConvertible = _isLibreOfficeSupported(file.extension);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      // 사진(이미지 첨부)은 탭하면 필기 편집기로 열려 그 위에 그릴 수 있다.
      // (우측 동기화/공유/더보기 버튼은 각자 탭을 소비하므로 영향 없음)
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: file.isImage
            ? () async {
                if (await _blockedByLimit('handwriting')) return;
                _openEditorView(_EditorType.handwriting, initialImagePath: file.filePath);
              }
            : null,
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Leading 아이콘 (이미지/비디오는 사진/비디오 아이콘으로 일치)
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(
                file.isImage
                    ? Icons.photo_camera
                    : file.isVideo
                        ? Icons.videocam
                        : Icons.description,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            // 제목 영역
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    file.displayTitle,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (ext.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            ext,
                            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
                          ),
                        ),
                      if (ext.isNotEmpty) const SizedBox(width: 4),
                      Text(
                        _formatBytes(file.sizeBytes),
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 아이콘 영역
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 순서: 요약 · 퀴즈 · 클라우드 · 공유
                  // 요약/퀴즈는 메모(텍스트) 파일만 지원 — 그 외 파일은 빈 자리(간격 유지)
                  _iconBtn(icon: null),
                  _iconBtn(icon: null),
                  _buildSyncIconUnified(file.syncStatus, cloudUpdatedAt: file.cloudUpdatedAt, updatedAt: file.updatedAt),
                  if (_isPremiumPlus)
                    _iconBtn(
                      icon: Icons.share_outlined,
                      color: Provider.of<AppStateProvider>(context, listen: false).isFileShared(file.id) ? color : Colors.grey.shade400, // 공유했으면 활성(색상)
                      tooltip: AppLocalizations.of(context)?.share ?? '공유',
                      onPressed: () => _openShareSheet(
                        title: file.fileName,
                        onUser: () => _shareAttachmentFileToUser(file),
                        onExternal: () => _shareAttachment(file),
                      ),
                    ),
                  // ... 더보기 메뉴
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      iconSize: 16,
                      icon: Icon(Icons.more_vert, color: color, size: 16),
                      tooltip: '메뉴',
                      onSelected: (value) {
                        if (value == 'convert') _convertAttachmentToPdf(file);
                        else if (value == 'rename') _showRenameAttachmentDialog(file);
                        else if (value == 'delete') _showDeleteDialog(file.displayTitle, () => _deleteAttachment(file));
                      },
                      itemBuilder: (ctx) => [
                        if (isConvertible)
                          const PopupMenuItem(
                            value: 'convert',
                            child: Row(
                              children: [
                                Icon(Icons.picture_as_pdf_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('PDF 변환'),
                              ],
                            ),
                          ),
                        PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              const Icon(Icons.edit_outlined, size: 18),
                              const SizedBox(width: 8),
                              Text(AppLocalizations.of(ctx)?.editLabel ?? '수정'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              const SizedBox(width: 8),
                              Text(AppLocalizations.of(ctx)?.delete ?? '삭제',
                                  style: const TextStyle(color: Colors.red)),
                            ],
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
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
  }

  /// 텍스트 파일을 외부 앱으로 공유 (HTML 제거한 평문 + 제목).
  Future<void> _shareTextFile(TextFile file) async {
    try {
      final plain = file.preview.trim();
      if (plain.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('공유할 내용이 없습니다')),
          );
        }
        return;
      }
      final text =
          file.displayTitle.isNotEmpty ? '${file.displayTitle}\n\n$plain' : plain;
      await Share.share(text, subject: file.displayTitle);
    } catch (e) {
      debugPrint('❌ 텍스트 공유 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('공유에 실패했습니다: $e')),
        );
      }
    }
  }

  /// 필기 파일(PNG/PDF)을 외부 앱으로 공유.
  Future<void> _shareHandwritingFile(HandwritingFile file) async {
    try {
      final f = File(file.imagePath);
      if (!await f.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('파일을 찾을 수 없습니다')),
          );
        }
        return;
      }
      await Share.shareXFiles([XFile(file.imagePath)], subject: file.displayTitle);
    } catch (e) {
      debugPrint('❌ 필기 공유 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('공유에 실패했습니다: $e')),
        );
      }
    }
  }

  /// 오디오 파일(m4a)을 외부 앱으로 공유.
  Future<void> _shareAudioFile(AudioFile file) async {
    try {
      final f = File(file.filePath);
      if (!await f.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('파일을 찾을 수 없습니다')),
          );
        }
        return;
      }
      await Share.shareXFiles([XFile(file.filePath)], subject: file.fileName);
    } catch (e) {
      debugPrint('❌ 오디오 공유 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('공유에 실패했습니다: $e')),
        );
      }
    }
  }

  // ── 사용자에게 공유 (백엔드 경유) ──
  /// 공유 작성 다이얼로그를 띄우고, 선택한 대상(개인/그룹)에게 파일을 공유한다.
  Future<void> _shareFileToUser({
    required String fileId,
    required String fileType,
    required String filePath,
    required String fileName,
    String? contentType,
  }) async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    if (!appState.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 후 사용자 공유가 가능합니다.')));
      return;
    }
    // 보내기는 프리미엄 전용 (받기는 모든 플랜 가능)
    if (!appState.isPremiumPlusUser) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공유 보내기는 프리미엄 플랜에서 가능합니다.')));
      return;
    }
    // 최신 그룹 목록 확보(다이얼로그 그룹 선택용)
    await appState.reloadShareGroups();
    if (!mounted) return;
    final result = await showShareComposeDialog(context, fileLabel: fileName);
    if (result == null || !mounted) return;
    final res = await appState.shareFile(
      filePath: filePath,
      fileType: fileType,
      fileName: fileName,
      contentType: contentType,
      littenTitle: appState.selectedLitten?.title,
      targetType: result.targetType,
      recipientKey: result.recipientKey,
      groupId: result.groupId,
      message: result.message,
    );
    if (!mounted) return;
    final ok = res['success'] == true;
    if (ok) await appState.markFileShared(fileId); // 공유 아이콘 활성 표시
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? '공유했습니다 (${res['recipientCount'] ?? 1}명)'
          : (res['message']?.toString() ?? '공유에 실패했습니다.')),
    ));
  }

  Future<void> _shareTextFileToUser(TextFile file) async {
    final appDir = await getApplicationDocumentsDirectory();
    final path = '${appDir.path}/littens/${file.littenId}/text/${file.id}.html';
    await _shareFileToUser(
        fileId: file.id, fileType: 'text', filePath: path,
        fileName: '${file.displayTitle}.html', contentType: 'text/html');
  }

  Future<void> _shareAudioFileToUser(AudioFile file) async {
    await _shareFileToUser(
        fileId: file.id, fileType: 'audio', filePath: file.filePath,
        fileName: '${file.fileName}.m4a', contentType: 'audio/m4a');
  }

  Future<void> _shareHandwritingFileToUser(HandwritingFile file) async {
    final isPdf = file.imagePath.toLowerCase().endsWith('.pdf');
    await _shareFileToUser(
        fileId: file.id, fileType: 'handwriting', filePath: file.imagePath,
        fileName: '${file.displayTitle}${isPdf ? '.pdf' : '.png'}',
        contentType: isPdf ? 'application/pdf' : 'image/png');
  }

  Future<void> _shareAttachmentFileToUser(AttachmentFile file) async {
    await _shareFileToUser(
        fileId: file.id, fileType: 'attachment', filePath: file.filePath,
        fileName: file.fileName, contentType: file.mimeType);
  }

  /// 공유 아이콘 탭 시: '사용자에게 공유 / 외부 앱' 선택 시트.
  void _openShareSheet({
    required String title,
    required VoidCallback onUser,
    required VoidCallback onExternal,
  }) {
    final color = Theme.of(context).primaryColor;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(children: [
                Icon(Icons.share, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
            ListTile(
              leading: Icon(Icons.send, color: color),
              title: const Text('사용자에게 공유'),
              subtitle: const Text('리튼 사용자/그룹에게 보내기'),
              onTap: () {
                Navigator.pop(ctx);
                onUser();
              },
            ),
            ListTile(
              leading: Icon(Icons.ios_share, color: color),
              title: const Text('외부 앱으로 공유'),
              subtitle: const Text('카카오톡·메일 등 다른 앱'),
              onTap: () {
                Navigator.pop(ctx);
                onExternal();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _shareAttachment(AttachmentFile file) async {
    try {
      final f = File(file.filePath);
      if (!await f.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('파일을 찾을 수 없습니다')),
          );
        }
        return;
      }
      await Share.shareXFiles([XFile(file.filePath)], subject: file.fileName);
    } catch (e) {
      debugPrint('❌ 공유 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('공유에 실패했습니다: $e')),
        );
      }
    }
  }

  Future<void> _deleteAttachment(AttachmentFile file) async {
    try {
      await FileStorageService.instance.deleteAttachmentFile(file);
      await LittenService().removeAttachmentFileFromLitten(file.littenId, file.id);
      // 클라우드 동기화 삭제 (다른 기기에도 전파)
      if (file.cloudId != null) {
        SyncService.instance.deleteFile(
          littenId: file.littenId,
          localId: file.id,
          cloudId: file.cloudId!,
          fileType: 'attachment',
        );
      }
      if (mounted) {
        setState(() {
          _attachmentFiles.removeWhere((f) => f.id == file.id);
        });
        final appState = Provider.of<AppStateProvider>(context, listen: false);
        await appState.updateFileCount();
        appState.notifyFileListChanged();
      }
    } catch (e) {
      debugPrint('❌ 첨부 파일 삭제 실패: $e');
    }
  }

  // ── 첨부 파일 이름 변경 ──
  void _showRenameAttachmentDialog(AttachmentFile file) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: file.fileName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.rename ?? '이름 변경'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n?.fileNameHint ?? '파일 이름'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n?.cancel ?? '취소')),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                Navigator.pop(ctx);
                await _renameAttachmentFile(file, newName);
              }
            },
            child: Text(l10n?.confirm ?? '확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameAttachmentFile(AttachmentFile file, String newName) async {
    try {
      final storage = FileStorageService.instance;
      final allFiles = await storage.loadAttachmentFiles(file.littenId);
      final updated = allFiles.map((f) => f.id == file.id ? f.copyWith(fileName: newName) : f).toList();
      await storage.saveAttachmentFiles(file.littenId, updated);
      if (mounted) {
        final appState = Provider.of<AppStateProvider>(context, listen: false);
        await _loadFiles(appState);
      }
      debugPrint('✅ [AllFilesTab] 첨부파일 이름 변경: ${file.fileName} → $newName');
    } catch (e) {
      debugPrint('❌ [AllFilesTab] 첨부파일 이름 변경 실패: $e');
    }
  }

  // LibreOffice headless가 지원하는 파일 포맷
  static const Set<String> _libreOfficeFormats = {
    'doc', 'docx',       // Word
    'xls', 'xlsx',       // Excel
    'ppt', 'pptx',       // PowerPoint
    'odt', 'ods', 'odp', // OpenDocument
    'rtf',               // Rich Text
    'csv',               // CSV
  };

  bool _isLibreOfficeSupported(String extension) =>
      _libreOfficeFormats.contains(extension.toLowerCase());

  void _showAttachmentInfoSheet(AttachmentFile file) {
    final isConvertible = _isLibreOfficeSupported(file.extension);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.drive_folder_upload, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      file.fileName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('크기: ${_formatBytes(file.sizeBytes)}'),
              Text('확장자: ${file.extension.isEmpty ? '-' : file.extension}'),
              Text('추가: ${DateFormat('yyyy-MM-dd HH:mm').format(file.createdAt)}'),
              if (isConvertible) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('PDF 변환'),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _convertAttachmentToPdf(file);
                    },
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _convertAttachmentToPdf(AttachmentFile file) async {
    debugPrint('🔄 [AllFilesTab] _convertAttachmentToPdf 진입 - fileName: ${file.fileName}');

    // 로그인(토큰) 확인
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('로그인 필요'),
          content: const Text('PDF 변환은 로그인 후 이용할 수 있습니다.\n설정 > 계정에서 로그인해 주세요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }

    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final selectedLitten = appState.selectedLitten;
    if (selectedLitten == null) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('PDF 변환 중...'),
          ],
        ),
      ),
    );

    try {
      debugPrint('📡 [AllFilesTab] API 호출 - filePath: ${file.filePath}, hasToken: true');
      final pdfBytes = await ApiService().convertToPdf(
        filePath: file.filePath,
        fileName: file.fileName,
        token: token,
      );

      final tempDir = await getTemporaryDirectory();
      final nameWithoutExt = file.fileName.contains('.')
          ? file.fileName.substring(0, file.fileName.lastIndexOf('.'))
          : file.fileName;
      final pdfName = '$nameWithoutExt.pdf';
      final tempPdfPath = '${tempDir.path}/$pdfName';
      await File(tempPdfPath).writeAsBytes(pdfBytes);
      debugPrint('✅ [AllFilesTab] PDF 임시 저장 완료 - path: $tempPdfPath');

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      await _registerPdfForSyncfusion(tempPdfPath, pdfName, selectedLitten, appState);
    } catch (e) {
      debugPrint('❌ [AllFilesTab] PDF 변환 실패: $e');
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF 변환에 실패했습니다: $e')),
        );
      }
    }
  }

  // ── 녹음 카드 ──
  Widget _buildAudioCard(AudioFile file) {
    final color = Theme.of(context).primaryColor;
    final isCurrentPlaying = _audioService.currentPlayingFile?.id == file.id;
    final isPlaying = isCurrentPlaying && _audioService.isPlaying;

    // ⭐ 휴리스틱: 같은 리튼의 STT 텍스트가 60초 이내에 있으면 음성메모 쌍으로 인식
    // (기존 데이터에서 isFromSTT가 누락된 경우 대비)
    final isPairedSTT = file.isFromSTT || _textFiles.any((t) =>
      t.isFromSTT &&
      t.littenId == file.littenId &&
      (t.createdAt.difference(file.createdAt).inSeconds).abs() <= 60
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: InkWell(
        onTap: () => _playAudio(file),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Leading 아이콘
              SizedBox(
                width: 32,
                height: 32,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: isPlaying ? Colors.blue : color.withValues(alpha: 0.1),
                      child: Icon(
                        isPlaying ? Icons.pause : Icons.mic,
                        color: isPlaying ? Colors.white : color,
                        size: 18,
                      ),
                    ),
                    if (isPairedSTT)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 17,
                          height: 17,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(Icons.record_voice_over, size: 10, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // 제목 영역 (60%)
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      file.fileName,
                      style: TextStyle(fontSize: 13, fontWeight: isCurrentPlaying ? FontWeight.bold : FontWeight.normal),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isCurrentPlaying) ...[
                      const SizedBox(height: 4),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2.0,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
                        ),
                        child: Slider(
                          value: _audioService.totalDuration.inMilliseconds > 0
                              ? _audioService.playbackDuration.inMilliseconds.toDouble()
                              : 0.0,
                          min: 0.0,
                          max: _audioService.totalDuration.inMilliseconds.toDouble(),
                          onChanged: (v) => _audioService.seekAudio(Duration(milliseconds: v.toInt())),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(_audioService.playbackDuration),
                                style: const TextStyle(fontSize: 11, color: Colors.blue)),
                            Text(_formatDuration(_audioService.totalDuration),
                                style: const TextStyle(fontSize: 11, color: Colors.blue)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 아이콘 영역 (40%) - 5개 아이콘 균일 분배
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 순서: 요약 · 퀴즈 · 클라우드 · 공유
                    // 요약/퀴즈는 메모(텍스트) 파일만 지원 — 그 외 파일은 빈 자리(간격 유지)
                    _iconBtn(icon: null),
                    _iconBtn(icon: null),
                    _buildSyncIconUnified(file.syncStatus, cloudUpdatedAt: file.cloudUpdatedAt, updatedAt: file.updatedAt),
                    if (_isPremiumPlus)
                      _iconBtn(
                        icon: Icons.share_outlined,
                        color: Provider.of<AppStateProvider>(context, listen: false).isFileShared(file.id) ? color : Colors.grey.shade400, // 공유했으면 활성(색상)
                        tooltip: '공유',
                        onPressed: () => _openShareSheet(
                          title: file.fileName,
                          onUser: () => _shareAudioFileToUser(file),
                          onExternal: () => _shareAudioFile(file),
                        ),
                      ),
                    _moreMenuBtn(
                      color: color,
                      onEdit: () => _showRenameAudioDialog(file),
                      onDelete: () => _showDeleteDialog(file.fileName, () => _deleteAudioFile(file)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── 재생 ──
  Future<void> _playAudio(AudioFile file) async {
    if (_audioService.currentPlayingFile?.id == file.id) {
      if (_audioService.isPlaying) {
        await _audioService.pauseAudio();
      } else {
        await _audioService.resumeAudio();
      }
    } else {
      await _audioService.playAudio(file);
    }
  }

  // ── 삭제 공통 다이얼로그 ──
  void _showDeleteDialog(String name, VoidCallback onConfirm) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.deleteFile ?? '파일 삭제'),
        content: Text(l10n?.confirmDeleteFileMessage(name) ?? '"$name"을(를) 삭제하시겠습니까?\n\n이 작업은 취소할 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n?.cancel ?? '취소')),
          TextButton(
            onPressed: () { Navigator.pop(ctx); onConfirm(); },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n?.delete ?? '삭제'),
          ),
        ],
      ),
    );
  }

  // ── 음성 메모 설정 다이얼로그 ──
  void _showSttMemoSettings() async {
    debugPrint('🎤 [AllFilesTab] 음성 메모 설정 다이얼로그 열기');
    final settings = await showDialog<SttMemoSettings>(
      context: context,
      builder: (ctx) => const SttMemoSettingsDialog(),
    );
    if (settings != null && mounted) {
      debugPrint('🎤 [AllFilesTab] 음성 메모 설정 완료 - 주기: ${settings.summaryIntervalMinutes}분');
      _openEditorView(_EditorType.text, autoCreate: true, autoStartSTT: true, sttSettings: settings);
    }
  }

  // ── 요약 다이얼로그 ──
  void _showSummaryDialog(TextFile file) async {
    debugPrint('✨ [AllFilesTab] 요약 다이얼로그 열기 - 파일: ${file.displayTitle}');

    // 다이얼로그를 닫지 않고 요약할 때마다 콜백으로 저장한다(이력에 누적·표시).
    await showDialog<SummaryResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SummaryDialog(
        file: file,
        onSummarized: (r) {
          debugPrint('✨ [AllFilesTab] 요약 결과 수신(콜백) - 파일에 추가');
          _appendSummaryToFile(file, r);
        },
      ),
    );
  }

  Future<void> _appendSummaryToFile(TextFile file, SummaryResult result) async {
    try {
      // 다이얼로그를 닫지 않고 연속 요약할 수 있으므로, 매번 스토리지의 최신 파일 상태를
      // 기준으로 누적한다(원본 file 기준이면 직전 요약이 누락됨).
      final storage = FileStorageService.instance;
      final allFiles = await storage.loadTextFiles(file.littenId);
      final current = allFiles.firstWhere((f) => f.id == file.id, orElse: () => file);
      debugPrint('✨ [AllFilesTab] 파일 저장 시작 - 최신 content 길이: ${current.content.length}');

      // 요약을 HTML 단락으로 변환 (hr·이모지·인라인스타일 제거 → html_editor_enhanced 호환)
      final summaryLines = result.summary
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();

      final summaryHtml = summaryLines
          .map((line) => '<p>${_escapeHtmlText(line.trim())}</p>')
          .join('');

      final separator = '<p>- - - - - - - - - - - - - - -</p>';
      const levelNames = {1: '한줄 요약', 2: '간단 요약', 3: '일반 요약', 4: '상세 요약', 5: '거의 전체'};
      final levelName = levelNames[result.summaryLevel] ?? '일반 요약';
      final header = '<p><strong>[AI 요약] Lv.${result.summaryLevel} $levelName | ${result.summaryLanguage}</strong></p>';

      final base = current.content.isEmpty ? '<p><br></p>' : current.content;
      final appendedContent = '$base$separator$header$summaryHtml';

      debugPrint('✨ [AllFilesTab] appendedContent 길이: ${appendedContent.length}');

      // 새 요약을 이력 맨 앞에 추가
      final newRecord = SummaryRecord(
        summary: result.summary,
        createdAt: DateTime.now(),
        level: result.summaryLevel,
        summaryLanguage: result.summaryLanguage,
        textLanguage: result.textLanguage,
      );
      final newHistory = [newRecord, ...current.summaryHistory];

      final updatedFile = current.copyWith(
        content: appendedContent,
        summary: result.summary,
        summaryHistory: newHistory,
      );

      debugPrint('✨ [AllFilesTab] 기존 파일 수: ${allFiles.length}');

      final updated = allFiles.map((f) => f.id == file.id ? updatedFile : f).toList();
      final saved = await storage.saveTextFiles(file.littenId, updated);
      debugPrint('✨ [AllFilesTab] 저장 결과: $saved');

      if (!saved) {
        throw Exception('파일 저장 실패 (SharedPreferences 오류)');
      }

      // 요약이 반영된 본문을 실제 .html 파일에도 기록한다.
      // (saveTextFiles는 메타데이터(JSON)만 저장 — .html을 갱신하지 않으면 동기화 업로드가
      //  요약 없는 옛 본문을 올린다)
      await storage.saveTextFileContent(updatedFile);

      // 클라우드 동기화: 요약으로 본문이 바뀌었으므로 즉시 서버에 반영한다.
      // (기존엔 .html 미기록 + 업로드 트리거 부재로, 요약한 파일이 다른 기기에 동기화되지 않던 문제 수정)
      final htmlFilePath =
          '${(await getApplicationDocumentsDirectory()).path}/littens/${updatedFile.littenId}/text/${updatedFile.id}.html';
      if (updatedFile.cloudId != null) {
        SyncService.instance.updateFile(
          littenId: updatedFile.littenId,
          localId: updatedFile.id,
          cloudId: updatedFile.cloudId!,
          fileType: 'text',
          filePath: htmlFilePath,
          localUpdatedAt: updatedFile.updatedAt,
          fileName: SyncService.textUploadFileName(updatedFile.id, updatedFile.title),
        );
      } else {
        SyncService.instance.uploadFile(
          littenId: updatedFile.littenId,
          localId: updatedFile.id,
          fileType: 'text',
          fileName: SyncService.textUploadFileName(updatedFile.id, updatedFile.title),
          filePath: htmlFilePath,
          localUpdatedAt: updatedFile.updatedAt,
        );
      }

      // 파일 목록 새로고침
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      await _loadFiles(appState);

      // 퀴즈 추출 및 저장 (요약 단위로 그룹화)
      final quizItems = QuizParser.parse(
        summaryText: result.summary,
        fileId: file.id,
        fileName: file.displayTitle,
        littenId: file.littenId,
        fileType: QuizFileType.text,
        summaryLevel: result.summaryLevel,
      );
      if (quizItems.isNotEmpty) {
        appState.addQuizItems(quizItems);
        debugPrint('✨ [AllFilesTab] 퀴즈 ${quizItems.length}개 추가 완료');
      }

      // 리마인드 '요약' 섹션 + 로컬 별도 파일에 요약 기록 (퀴즈 마커 제거한 순수 요약)
      final fullSummary = result.summary;
      final markerIdx = fullSummary.indexOf('─── 📌 퀴즈 ───');
      final pureSummary =
          markerIdx != -1 ? fullSummary.substring(0, markerIdx).trim() : fullSummary.trim();
      await appState.recordSummary(
        littenId: file.littenId,
        sourceFileId: file.id,
        sourceType: 'text',
        title: file.displayTitle,
        summaryText: pureSummary,
        summaryLevel: result.summaryLevel,
        summaryGroupId:
            quizItems.isNotEmpty ? quizItems.first.summaryGroupId : null,
      );

      debugPrint('✨ [AllFilesTab] 요약 저장 완료');

      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(quizItems.isNotEmpty
                ? (l10n?.summaryAddedWithQuiz(quizItems.length) ?? '요약이 추가되었습니다. 퀴즈 ${quizItems.length}개 생성')
                : (l10n?.summaryAdded ?? '요약이 파일에 추가되었습니다.')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [AllFilesTab] 요약 파일 저장 실패: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n?.summarySaveFailed(e.toString()) ?? '요약 저장 실패: $e')),
        );
      }
    }
  }

  // HTML 텍스트에서 특수문자 이스케이프 (editor의 JS 템플릿 리터럴 안전성 보장)
  String _escapeHtmlText(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  // ── 텍스트 이름 변경 ──
  void _showRenameTextDialog(TextFile file) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: file.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.rename ?? '이름 변경'),
        content: TextField(controller: controller, autofocus: true, decoration: InputDecoration(hintText: l10n?.fileNameHint ?? '파일 이름')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n?.cancel ?? '취소')),
          TextButton(
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                Navigator.pop(ctx);
                await _renameTextFile(file, newTitle);
              }
            },
            child: Text(l10n?.confirm ?? '확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameTextFile(TextFile file, String newTitle) async {
    try {
      final storage = FileStorageService.instance;
      final allFiles = await storage.loadTextFiles(file.littenId);
      final updated = allFiles.map((f) => f.id == file.id ? f.copyWith(title: newTitle) : f).toList();
      await storage.saveTextFiles(file.littenId, updated);
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      await appState.refreshLittens();
      await _loadFiles(appState);
    } catch (e) {
      debugPrint('❌ [AllFilesTab] 텍스트 이름 변경 실패: $e');
    }
  }

  Future<void> _deleteTextFile(TextFile file) async {
    try {
      final storage = FileStorageService.instance;
      await storage.deleteTextFile(file);
      final allFiles = await storage.loadTextFiles(file.littenId);
      final updated = allFiles.where((f) => f.id != file.id).toList();
      await storage.saveTextFiles(file.littenId, updated);
      final littenService = LittenService();
      await littenService.removeTextFileFromLitten(file.littenId, file.id);
      if (file.cloudId != null) {
        SyncService.instance.deleteFile(
          littenId: file.littenId,
          localId: file.id,
          cloudId: file.cloudId!,
          fileType: 'text',
        );
      }
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      await appState.updateFileCount();
      await _loadFiles(appState);
    } catch (e) {
      debugPrint('❌ [AllFilesTab] 텍스트 삭제 실패: $e');
    }
  }

  // ── 필기 이름 변경 ──
  void _showRenameHandwritingDialog(HandwritingFile file) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: file.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.rename ?? '이름 변경'),
        content: TextField(controller: controller, autofocus: true, decoration: InputDecoration(hintText: l10n?.fileNameHint ?? '파일 이름')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n?.cancel ?? '취소')),
          TextButton(
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                Navigator.pop(ctx);
                await _renameHandwritingFile(file, newTitle);
              }
            },
            child: Text(l10n?.confirm ?? '확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameHandwritingFile(HandwritingFile file, String newTitle) async {
    try {
      final storage = FileStorageService.instance;
      final allFiles = await storage.loadHandwritingFiles(file.littenId);
      final updated = allFiles.map((f) => f.id == file.id ? f.copyWith(title: newTitle) : f).toList();
      await storage.saveHandwritingFiles(file.littenId, updated);
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      await appState.refreshLittens();
      await _loadFiles(appState);
    } catch (e) {
      debugPrint('❌ [AllFilesTab] 필기 이름 변경 실패: $e');
    }
  }

  Future<void> _deleteHandwritingFile(HandwritingFile file) async {
    try {
      final storage = FileStorageService.instance;
      await storage.deleteHandwritingFile(file);
      final allFiles = await storage.loadHandwritingFiles(file.littenId);
      final updated = allFiles.where((f) => f.id != file.id).toList();
      await storage.saveHandwritingFiles(file.littenId, updated);
      final littenService = LittenService();
      await littenService.removeHandwritingFileFromLitten(file.littenId, file.id);
      if (file.cloudId != null) {
        SyncService.instance.deleteFile(
          littenId: file.littenId,
          localId: file.id,
          cloudId: file.cloudId!,
          fileType: 'handwriting',
        );
      }
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      await appState.updateFileCount();
      await _loadFiles(appState);
    } catch (e) {
      debugPrint('❌ [AllFilesTab] 필기 삭제 실패: $e');
    }
  }

  // ── 녹음 이름 변경 ──
  void _showRenameAudioDialog(AudioFile file) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: file.fileName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.rename ?? '이름 변경'),
        content: TextField(controller: controller, autofocus: true, decoration: InputDecoration(hintText: l10n?.fileNameHint ?? '파일 이름')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n?.cancel ?? '취소')),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                Navigator.pop(ctx);
                await _renameAudioFile(file, newName);
              }
            },
            child: Text(l10n?.confirm ?? '확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameAudioFile(AudioFile file, String newName) async {
    try {
      await _audioService.renameAudioFile(file, newName);
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      await _loadFiles(appState);
    } catch (e) {
      debugPrint('❌ [AllFilesTab] 녹음 이름 변경 실패: $e');
    }
  }

  Future<void> _deleteAudioFile(AudioFile file) async {
    try {
      await _audioService.deleteAudioFile(file);
      // 클라우드 동기화 (cloudId가 있을 때만)
      if (file.cloudId != null) {
        SyncService.instance.deleteFile(
          littenId: file.littenId,
          localId: file.id,
          cloudId: file.cloudId!,
          fileType: 'audio',
        );
      }
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      await appState.updateFileCount();
      await _loadFiles(appState);
    } catch (e) {
      debugPrint('❌ [AllFilesTab] 녹음 삭제 실패: $e');
    }
  }
}

enum _EditorType { text, handwriting }

// ───────────────────────────── 하단 FAB 버튼 행 ─────────────────────────────

class _BottomFabRow extends StatefulWidget {
  final VoidCallback onText;
  final VoidCallback onTextWithSTT;
  final VoidCallback onFiles;
  final VoidCallback onCanvas;
  final VoidCallback onAudio;
  final VoidCallback? onYoutube;
  final bool isRecording;
  final Duration recordingDuration;

  const _BottomFabRow({
    required this.onText,
    required this.onTextWithSTT,
    required this.onFiles,
    required this.onCanvas,
    required this.onAudio,
    this.onYoutube,
    this.isRecording = false,
    this.recordingDuration = Duration.zero,
  });

  @override
  State<_BottomFabRow> createState() => _BottomFabRowState();
}

class _BottomFabRowState extends State<_BottomFabRow> {
  bool _isExpanded = false;

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void initState() {
    super.initState();
    // 녹음 중인 상태로 위젯이 (재)생성되면 처음부터 확장
    _isExpanded = widget.isRecording;
  }

  @override
  void didUpdateWidget(_BottomFabRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !oldWidget.isRecording) {
      // 녹음 시작 → 다이얼 강제 열기
      setState(() => _isExpanded = true);
    } else if (!widget.isRecording && oldWidget.isRecording) {
      // 녹음 종료 → 다이얼 닫기
      setState(() => _isExpanded = false);
    }
  }

  void _handleAction(VoidCallback action) {
    setState(() => _isExpanded = false);
    action();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    final appState = Provider.of<AppStateProvider>(context);
    final fabVis = appState.allTabFabVisibility;

    final dialItems = <Widget>[];
    final l10n = AppLocalizations.of(context);
    // ⭐ 순서(위→아래): 영상 → 파일 → 필기 → 음성 메모 → 녹음 → 메모
    if (fabVis.contains('youtube') && widget.onYoutube != null) {
      dialItems.addAll([
        _SpeedDialItem(
          label: '영상',
          customChild: YoutubeSpeedDialIcon(),
          color: color,
          onTap: () => _handleAction(widget.onYoutube!),
        ),
        const SizedBox(height: 8),
      ]);
    }
    // ⭐ 파일: 임의의 파일 첨부 (PDF면 Syncfusion 에디터로 자동 분기)
    if (fabVis.contains('files')) {
      dialItems.addAll([
        _SpeedDialItem(label: '파일', icon: Icons.drive_folder_upload, color: color,
            onTap: () => _handleAction(widget.onFiles)),
        const SizedBox(height: 8),
      ]);
    }
    if (fabVis.contains('canvas')) {
      dialItems.addAll([
        _SpeedDialItem(label: l10n?.handwritingTab ?? '필기', icon: Icons.draw, color: color,
            onTap: () => _handleAction(widget.onCanvas)),
        const SizedBox(height: 8),
      ]);
    }
    if (fabVis.contains('stt')) {
      dialItems.addAll([
        _SpeedDialItem(
          label: l10n?.voiceMemoLabel ?? '녹음 메모',
          // 녹음(마이크)+메모를 한꺼번에 추가함을 나타내는 합성 아이콘.
          // icon은 표시용이 아니라 Hero 태그 식별용(다른 항목과 겹치지 않는 값).
          icon: Icons.record_voice_over,
          customChild: const RecordMemoSpeedDialIcon(),
          color: color,
          onTap: () => _handleAction(widget.onTextWithSTT),
        ),
        const SizedBox(height: 8),
      ]);
    }
    if (fabVis.contains('audio')) {
      dialItems.addAll([
        _SpeedDialItem(
          label: widget.isRecording
              ? (l10n?.recordingStatus(_formatDuration(widget.recordingDuration)) ?? '녹음중... ${_formatDuration(widget.recordingDuration)}')
              : (l10n?.audioTab ?? '녹음'),
          icon: widget.isRecording ? Icons.stop : Icons.mic,
          color: color,
          onTap: widget.onAudio,
        ),
        const SizedBox(height: 8),
      ]);
    }
    if (fabVis.contains('text')) {
      dialItems.addAll([
        _SpeedDialItem(label: l10n?.memoLabel ?? '메모', icon: Icons.notes, color: color,
            onTap: () => _handleAction(widget.onText)),
        const SizedBox(height: 8),
      ]);
    }
    // 마지막 SizedBox(height:8) 제거
    if (dialItems.isNotEmpty && dialItems.last is SizedBox) {
      dialItems.removeLast();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isExpanded && dialItems.isNotEmpty) ...[
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 8),
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: dialItems,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _FabBtn(
              icon: _isExpanded ? Icons.close : Icons.add,
              color: color,
              heroTag: 'fab_add_toggle',
              onTap: () {
                // 녹음 중엔 다이얼 닫기 불가
                if (widget.isRecording) return;
                setState(() => _isExpanded = !_isExpanded);
              },
            ),
            const SizedBox(width: 16), // ⭐ 8 → 16으로 변경하여 메뉴 버튼들과 정렬
          ],
        ),
      ],
    );
  }
}

/// 메인메뉴 바로 위에 항상 표시되는 "생성 칩 행"(가로 스크롤).
/// 기존 스피드다이얼(_BottomFabRow)의 항목/순서/표시조건(fabVis)을 그대로 따르되,
/// 2단계 펼침 없이 칩 한 번 탭으로 즉시 생성한다. 스타일은 캘린더 힌트칩과 통일.
class _CreateChipBar extends StatefulWidget {
  final VoidCallback onText;
  final VoidCallback onTextWithSTT;
  final VoidCallback onFiles;
  final VoidCallback onCanvas;
  final VoidCallback onAudio;
  final VoidCallback? onPhoto;
  final VoidCallback? onVideo;
  final VoidCallback? onYoutube;
  final bool isRecording;
  final Duration recordingDuration;

  const _CreateChipBar({
    required this.onText,
    required this.onTextWithSTT,
    required this.onFiles,
    required this.onCanvas,
    required this.onAudio,
    this.onPhoto,
    this.onVideo,
    this.onYoutube,
    this.isRecording = false,
    this.recordingDuration = Duration.zero,
  });

  @override
  State<_CreateChipBar> createState() => _CreateChipBarState();
}

class _CreateChipBarState extends State<_CreateChipBar> {
  final ScrollController _scrollController = ScrollController(); // 액션 칩 가로 스크롤
  int _lastChipResetToken = 0; // 마지막으로 처리한 칩 스크롤 리셋 토큰

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _chip(BuildContext context,
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap,
      bool active = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        // "전체 0" 탭 버튼 기반 3색 구성(바탕은 약간 더 진하게):
        //   바탕 primaryColor alpha 0.15 / 테두리 alpha 0.2 / 아이콘·글씨 primaryColor.
        //   (녹음 중일 때만 짙은 바탕 + 흰색으로 강조)
        color: active ? color : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            // 개별 칩(알약) 자체 높이를 더 줄여(5→3) 바 안에서 영역 구분이 잘 되게 함
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: color.withValues(alpha: active ? 1.0 : 0.2), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: active ? Colors.white : color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    final l10n = AppLocalizations.of(context);
    final appState = Provider.of<AppStateProvider>(context);
    final fabVis = appState.allTabFabVisibility;

    // 노트(+) 탭을 (재)진입하면 토큰이 증가 → 칩 가로 스크롤을 처음으로 되돌린다.
    // 점프가 실제로 성공(hasClients)했을 때만 토큰을 소비해, 화면 밖 리빌드로 토큰만
    // 소비되고 정작 스크롤은 안 되는 경우를 방지한다.
    final resetToken = appState.chipScrollResetToken;
    if (resetToken != _lastChipResetToken) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
          _lastChipResetToken = resetToken;
        }
      });
    }

    final chips = <Widget>[];
    // 순서(좌→우): 메모 → 필기 → 녹음 → 녹음 메모 → 사진 → 비디오 → 영상 채널 → 파일
    if (fabVis.contains('text')) {
      chips.add(_chip(context,
          icon: Icons.notes, label: l10n?.memoLabel ?? '메모', color: color, onTap: widget.onText));
    }
    if (fabVis.contains('canvas')) {
      chips.add(_chip(context,
          icon: Icons.draw, label: l10n?.handwritingTab ?? '필기', color: color, onTap: widget.onCanvas));
    }
    if (fabVis.contains('audio')) {
      chips.add(_chip(context,
          icon: widget.isRecording ? Icons.stop : Icons.mic,
          label: widget.isRecording
              ? (l10n?.recordingStatus(_formatDuration(widget.recordingDuration)) ??
                  '녹음중... ${_formatDuration(widget.recordingDuration)}')
              : (l10n?.audioTab ?? '녹음'),
          color: color,
          onTap: widget.onAudio,
          active: widget.isRecording));
    }
    if (fabVis.contains('stt')) {
      chips.add(_chip(context,
          icon: Icons.record_voice_over,
          label: l10n?.voiceMemoLabel ?? '녹음 메모',
          color: color,
          onTap: widget.onTextWithSTT));
    }
    // 사진 / 비디오 — 첨부파일로 저장된다. (설정 '전체탭 빠른 추가 표시'로 on/off)
    if (fabVis.contains('photo') && widget.onPhoto != null) {
      chips.add(_chip(context,
          icon: Icons.photo_camera, label: '사진', color: color, onTap: widget.onPhoto!));
    }
    if (fabVis.contains('video') && widget.onVideo != null) {
      chips.add(_chip(context,
          icon: Icons.videocam, label: '비디오', color: color, onTap: widget.onVideo!));
    }
    if (fabVis.contains('youtube') && widget.onYoutube != null) {
      chips.add(_chip(context,
          icon: Icons.subscriptions, label: '영상 채널', color: color, onTap: widget.onYoutube!));
    }
    if (fabVis.contains('files')) {
      chips.add(_chip(context,
          icon: Icons.drive_folder_upload, label: '파일', color: color, onTap: widget.onFiles));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        // 버튼들이 놓인 하단 바 배경을 탭 제목 바탕색과 동일하게 (primaryColor alpha 0.08)
        color: color.withValues(alpha: 0.08),
        border: Border(top: BorderSide(color: color.withValues(alpha: 0.15))),
      ),
      // 바(칩 영역) 자체 높이를 약간 키움 (세로 패딩 4 → 7)
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        child: Row(children: chips),
      ),
    );
  }
}

class _SpeedDialItem extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Widget? customChild;
  final Color color;
  final VoidCallback onTap;

  const _SpeedDialItem({
    required this.label,
    this.icon,
    this.customChild,
    required this.color,
    required this.onTap,
  }) : assert(icon != null || customChild != null, '아이콘 또는 customChild 중 하나는 필수입니다');

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 8), // 좌측 여백 추가
        Expanded(
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            elevation: 2,
            shadowColor: color.withValues(alpha: 0.3),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _FabBtn(
          icon: icon,
          customChild: customChild,
          color: color,
          heroTag: 'speed_dial_${icon?.codePoint ?? 'custom'}',
          onTap: onTap,
          mini: true,
        ),
      ],
    );
  }
}

class _FabBtn extends StatelessWidget {
  final IconData? icon;
  final Widget? customChild;
  final Color color;
  final VoidCallback onTap;
  final Object? heroTag;
  final bool mini;

  const _FabBtn({
    this.icon,
    this.customChild,
    required this.color,
    required this.onTap,
    this.heroTag,
    this.mini = false,
  }) : assert(icon != null || customChild != null, '아이콘 또는 customChild 중 하나는 필수입니다');

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: heroTag ?? (icon?.codePoint.toString() ?? 'custom'),
      onPressed: onTap,
      backgroundColor: color,
      foregroundColor: Colors.white,
      mini: mini,
      child: customChild ?? Icon(icon!, size: mini ? 20 : 24),
    );
  }
}

/// 녹음 메모용 스피드다이얼 아이콘 — 마이크(녹음) + 메모 배지를 겹쳐 표시.
/// 녹음과 메모가 한꺼번에 추가됨을 시각적으로 나타낸다.
class RecordMemoSpeedDialIcon extends StatelessWidget {
  const RecordMemoSpeedDialIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.mic, size: 20, color: Colors.white),
        Positioned(
          right: -5, bottom: -4,
          child: Container(
            width: 13, height: 13,
            decoration: BoxDecoration(
              color: color, shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: const Center(child: Icon(Icons.edit_note, size: 9, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────── 탭 버튼 위젯 ─────────────────────────────

/// DraggableTabLayout 탭 버튼에 표시할 일정명 + 3개 아이콘 + 파일수 위젯
class AllFilesTabButton extends StatelessWidget {
  // ⭐ 전체탭 제목 영역 종류 필터 표시 여부. 현재 히든. 다시 보이려면 true.
  static const bool _showAllTabFilter = false;
  final int textCount;
  final int canvasCount;
  final int pdfCount;
  final int audioCount;
  final int attachmentCount;
  final String? littenTitle;

  const AllFilesTabButton({
    super.key,
    required this.textCount,
    required this.canvasCount,
    required this.pdfCount,
    required this.audioCount,
    required this.attachmentCount,
    this.littenTitle,
    bool isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayTitle = (littenTitle == null || littenTitle == 'undefined') ? '' : littenTitle!;
    return Consumer<AppStateProvider>(
      builder: (context, appState, _) {
        final fabVis = appState.allTabFabVisibility;

        final visItems = <Widget>[];
        // 카운트가 0이면 아이콘/카운트 숨김 — 1개 이상일 때만 표시
        void maybeAdd(String id, IconData icon, int count) {
          if (fabVis.contains(id) && count > 0) {
            if (visItems.isNotEmpty) visItems.add(const SizedBox(width: 8));
            visItems.add(_iconCount(context, appState, id, icon, count));
          }
        }
        // 카운트가 0보다 클 때만 추가 (설정과 무관) — pdf/사진/비디오/영상채널용
        void addIfPositive(String key, IconData icon, int count) {
          if (count > 0) {
            if (visItems.isNotEmpty) visItems.add(const SizedBox(width: 8));
            visItems.add(_iconCount(context, appState, key, icon, count));
          }
        }
        // 첨부 중 사진/비디오 분리 — '파일'은 사진/비디오 제외분만 표시
        final photoCount = appState.actualPhotoCount;
        final videoCount = appState.actualVideoCount;
        final otherFiles = (attachmentCount - photoCount - videoCount).clamp(0, 1 << 31);
        // 녹음 메모(STT)를 메모/녹음에서 분리: 메모=비STT 텍스트, 녹음=비STT 오디오, 녹음메모=STT(텍스트+오디오)
        final sttTextCount = appState.actualSttTextCount;
        final sttAudioCount = appState.actualSttMemoCount;
        final memoCount = (textCount - sttTextCount).clamp(0, 1 << 31);
        final recordingCount = (audioCount - sttAudioCount).clamp(0, 1 << 31);
        final sttCount = sttTextCount + sttAudioCount;
        // 순서를 생성 칩(메인메뉴 +)과 일치: 메모 → 필기(+PDF) → 녹음 → 녹음메모 → 사진 → 비디오 → 영상채널 → 파일
        maybeAdd('text', Icons.notes, memoCount);
        maybeAdd('canvas', Icons.draw, canvasCount);
        addIfPositive('pdf', Icons.picture_as_pdf, pdfCount);
        maybeAdd('audio', Icons.mic, recordingCount);
        maybeAdd('stt', Icons.record_voice_over, sttCount);
        addIfPositive('photo', Icons.photo_camera, photoCount);
        addIfPositive('video', Icons.videocam, videoCount);
        // 영상 채널(구독) — 채널이 1개 이상일 때 표시
        addIfPositive('youtube', Icons.subscriptions, appState.actualYoutubeChannelCount);
        maybeAdd('files', Icons.description, otherFiles);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (displayTitle.isNotEmpty) ...[
              Text(displayTitle, overflow: TextOverflow.ellipsis),
              if (visItems.isNotEmpty) const SizedBox(width: 6),
            ],
            ...visItems,
            // 제일 우측: 종류 필터 드롭다운 (기본 '전체', 탭하면 아래로 펼쳐져 아이콘 선택)
            // ⭐ 현재 히든 처리 — 다시 보이려면 _showAllTabFilter = true 로 변경.
            //    카운트 아이콘들과 헷갈리지 않도록 구분선 + 여백으로 분리한다.
            if (_showAllTabFilter) ...[
              if (visItems.isNotEmpty || displayTitle.isNotEmpty) ...[
                const SizedBox(width: 10),
                Container(
                  width: 1,
                  height: 16,
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.35),
                ),
                const SizedBox(width: 6),
              ],
              _buildFilterDropdown(context, appState),
            ],
          ],
        );
      },
    );
  }

  // 전체탭 필터별 카운트. (memo=비STT 텍스트, recording=비STT 녹음, stt=STT 텍스트+녹음)
  int _filterCount(AppStateProvider s, String key) {
    final memo = (s.actualTextCount - s.actualSttTextCount).clamp(0, 1 << 31);
    final recording = (s.actualAudioCount - s.actualSttMemoCount).clamp(0, 1 << 31);
    final stt = s.actualSttTextCount + s.actualSttMemoCount;
    final total = s.actualTextCount + s.actualAudioCount +
        s.actualHandwritingCount + s.actualAttachmentCount;
    switch (key) {
      case 'text':
        return memo;
      case 'audio':
        return recording;
      case 'stt':
        return stt;
      case 'handwriting':
        return s.actualHandwritingCount;
      case 'attachment':
        // 파일 = 사진/비디오 제외 일반 첨부
        return (s.actualAttachmentCount - s.actualPhotoCount - s.actualVideoCount).clamp(0, 1 << 31);
      case 'photo':
        return s.actualPhotoCount;
      case 'video':
        return s.actualVideoCount;
      case 'youtube':
        return s.actualYoutubeChannelCount;
      case 'all':
      default:
        return total;
    }
  }

  // 탭 제목 안 종류 필터 드롭다운. 선택 시 AppStateProvider에 반영 → 전체탭 목록이 걸러진다.
  Widget _buildFilterDropdown(BuildContext context, AppStateProvider appState) {
    final color = Theme.of(context).primaryColor;
    final current = appState.allTabFileFilter;
    return PopupMenuButton<String>(
      tooltip: '필터',
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under, // 필터 트리거 바로 아래로 펼쳐지게
      // 펼침 메뉴 좌우 폭 축소(≈68 → ≈54, 추가 20%↓)
      constraints: const BoxConstraints(minWidth: 54, maxWidth: 54),
      onSelected: (v) => appState.setAllTabFileFilter(v),
      itemBuilder: (ctx) => [
        for (final k in kAllTabFilterKeys)
          PopupMenuItem<String>(
            value: k,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            // 아이콘만 표시(카운트 없음). 선택 항목은 테마색 강조, 이름은 툴팁으로만.
            child: Center(
              child: Tooltip(
                message: _allTabFilterLabel(ctx, k),
                child: Icon(_allTabFilterIcon(k),
                    size: 20, color: current == k ? color : Colors.grey.shade600),
              ),
            ),
          ),
      ],
      // 트리거: 현재 선택된 필터 아이콘 + 해당 카운트 + 펼침 화살표
      // (선택 상태를 아이콘으로 구분할 수 있게 — 전체일 때만 filter_list 아이콘)
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_allTabFilterIcon(current), size: 18, color: color),
          const SizedBox(width: 3),
          Text('${_filterCount(appState, current)}',
              style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
          Icon(Icons.arrow_drop_down, size: 18, color: color),
        ],
      ),
    );
  }

  // 종류별 아이콘+카운트. 탭하면 해당 종류를 리스트에서 숨김/표시 토글한다.
  // 숨김 상태: 흐리게 + 카운트 normal, 표시 상태: 기본(활성 탭에서 bold 상속).
  Widget _iconCount(BuildContext context, AppStateProvider appState, String key, IconData icon, int count) {
    final hidden = appState.allTabHiddenTypes.contains(key);
    // 카운트 숫자 폰트를 아이콘보다 약간 작게(읽힐 정도, 기본의 0.8배) 줄이고 아이콘에 바짝 붙인다.
    final countFontSize = (DefaultTextStyle.of(context).style.fontSize ?? 13) * 0.8;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => appState.toggleAllTabHiddenType(key),
      child: Opacity(
        opacity: hidden ? 0.4 : 1.0,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          // 작은 카운트 숫자를 가운데가 아니라 아이콘 하단에 맞춘다.
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Icon(icon),
            const SizedBox(width: 2),
            Text(
              count.toString(),
              // 폰트는 아이콘보다 약간 작게. 숨김이면 normal로 고정, 표시면 상위 weight(활성 탭 bold) 상속
              style: TextStyle(
                fontSize: countFontSize,
                fontWeight: hidden ? FontWeight.normal : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

}

// ───────────────────────────── 녹음 상태 바 ─────────────────────────────

class _RecordingStatusBar extends StatelessWidget {
  final Duration duration;

  const _RecordingStatusBar({required this.duration});

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.mic, size: 16, color: Theme.of(context).primaryColor),
          const SizedBox(width: 6),
          const Text('녹음 중...', style: TextStyle(fontSize: 13)),
          const Spacer(),
          Text(_format(duration),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

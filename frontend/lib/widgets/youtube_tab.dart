import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/youtube_channel.dart';
import '../services/api_service.dart';
import '../services/app_state_provider.dart';
import '../services/youtube_transcript_service.dart';
import '../services/youtube_webview_transcript_service.dart';
import '../services/local_youtube_channel_service.dart';
import '../services/youtube_rss_service.dart';
import '../services/channel_watch_service.dart';
import '../models/channel_watch_state.dart';
import '../config/plan_limits.dart';
import 'youtube_video_detail_dialog.dart';
import 'youtube_video_player_sheet.dart';

// ── 채널 구독 관리 시트 (탭 FAB + 스피드다이얼 공용) ─────────────────────────

Future<void> showYoutubeChannelSheet(BuildContext context) async {
  debugPrint('[YoutubeChannelSheet] showYoutubeChannelSheet 진입');
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  if (!context.mounted) return;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _YoutubeChannelSheet(token: token),
  );
}

class _YoutubeChannelSheet extends StatefulWidget {
  final String? token;
  const _YoutubeChannelSheet({this.token});

  @override
  State<_YoutubeChannelSheet> createState() => _YoutubeChannelSheetState();
}

class _YoutubeChannelSheetState extends State<_YoutubeChannelSheet> {
  final _apiService = ApiService();
  final _channelIdCtrl = TextEditingController();
  final _focusNode = FocusNode();

  List<YoutubeChannel> _channels = [];
  bool _loadingChannels = false;
  int _channelPage = 0;
  bool _hasMoreChannels = false;
  static const int _channelsPerPage = 5;

  // 구독 추가 상태
  String _selectedPlatform = 'youtube';
  bool _validating = false;
  bool _searching = false;        // 채널명 검색 중
  bool _subscribing = false;      // 구독 요청 중
  Map<String, String>? _validated; // 검증된 채널 정보 (null이면 미검증)
  String? _validateError;
  List<Map<String, String>> _searchResults = [];
  String? _resolvedChannelId;

  bool _autoTitle = true;
  bool _autoMemo = false;
  bool _autoSummary = false;
  String _summaryType = SummaryTypes.defaultValue;
  bool _autoQuiz = false;
  String _quizType = QuizTypes.defaultValue;
  final _quizCustomCtrl = TextEditingController(text: '7');

  @override
  void initState() {
    super.initState();
    _loadChannels();
    _channelIdCtrl.addListener(_onIdChanged);
  }

  @override
  void dispose() {
    _channelIdCtrl.removeListener(_onIdChanged);
    _channelIdCtrl.dispose();
    _focusNode.dispose();
    _quizCustomCtrl.dispose();
    super.dispose();
  }

  void _onIdChanged() {
    if (_validated != null || _validateError != null || _resolvedChannelId != null || _searchResults.isNotEmpty) {
      setState(() {
        _validated = null;
        _validateError = null;
        _resolvedChannelId = null;
        _searchResults = [];
      });
    }
  }

  /// 비로그인(토큰 없음) = 로컬 모드. 채널을 단말 로컬에만 저장한다.
  bool get _localMode => widget.token == null || widget.token!.isEmpty;

  /// 로컬 모드에서 등록 가능한 채널 수 (플랜별: 무료 2 / 그 외 무제한)
  int _localChannelLimit(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    return PlanLimits.youtubeChannels(appState.subscriptionType);
  }

  Future<void> _loadChannels({bool loadMore = false}) async {
    debugPrint('[_YoutubeChannelSheet] _loadChannels 진입 - loadMore: $loadMore, localMode: $_localMode');
    // 로컬 모드: 단말 저장소에서 로드
    if (_localMode) {
      final locals = await LocalYoutubeChannelService.load();
      if (mounted) setState(() { _channels = locals; _hasMoreChannels = false; });
      return;
    }
    if (widget.token == null || widget.token!.isEmpty) return;
    if (!loadMore) {
      _channelPage = 0;
      if (mounted) setState(() { _channels = []; _hasMoreChannels = false; });
    }
    setState(() => _loadingChannels = true);
    final newChannels = await _apiService.getYoutubeChannels(
      token: widget.token!,
      page: _channelPage,
      size: _channelsPerPage,
    );
    debugPrint('[_YoutubeChannelSheet] 채널 수: ${newChannels.length} (page: $_channelPage)');
    if (mounted) {
      setState(() {
        _channels.addAll(newChannels);
        _hasMoreChannels = newChannels.length == _channelsPerPage;
        if (_hasMoreChannels) _channelPage++;
        _loadingChannels = false;
      });
    }
  }

  Future<void> _validate() async {
    final id = _channelIdCtrl.text.trim();
    if (id.isEmpty || widget.token == null) return;
    debugPrint('[_YoutubeChannelSheet] _validate - channelId: $id');
    _focusNode.unfocus();
    setState(() { _validating = true; _validated = null; _validateError = null; });
    final info = await _apiService.getYoutubeChannelInfo(token: widget.token!, channelId: id);
    debugPrint('[_YoutubeChannelSheet] 검증 결과: $info');
    if (mounted) {
      setState(() {
        _validating = false;
        if (info != null) {
          _validated = info;
        } else {
          _validateError = '채널을 찾을 수 없습니다. 채널 ID를 확인해 주세요.';
        }
      });
    }
  }

  Future<void> _searchChannels() async {
    final query = _channelIdCtrl.text.trim();
    if (query.isEmpty) return;
    debugPrint('[_YoutubeChannelSheet] _searchChannels - query: $query');
    _focusNode.unfocus();
    setState(() { _searching = true; _searchResults = []; _validated = null; _validateError = null; _resolvedChannelId = null; });
    try {
      final uri = Uri.https('www.youtube.com', '/results', {'search_query': query});
      final response = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8',
      }).timeout(const Duration(seconds: 15));
      debugPrint('[_YoutubeChannelSheet] _searchChannels status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final channels = _parseChannelRenderers(response.body);
        debugPrint('[_YoutubeChannelSheet] _searchChannels found: ${channels.length}');
        if (mounted) {
          setState(() {
            _searchResults = channels;
            if (channels.length == 1) _selectChannel(channels.first);
            else if (channels.isEmpty) _validateError = '채널을 찾을 수 없습니다.';
          });
        }
      } else {
        if (mounted) setState(() => _validateError = '검색 요청이 실패했습니다. (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('[_YoutubeChannelSheet] _searchChannels error: $e');
      if (mounted) setState(() => _validateError = '채널 검색 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  List<Map<String, String>> _parseChannelRenderers(String html) {
    const marker = 'var ytInitialData = ';
    final markerIdx = html.indexOf(marker);
    if (markerIdx == -1) return [];
    final jsonStart = markerIdx + marker.length;
    int depth = 0;
    int jsonEnd = -1;
    for (int i = jsonStart; i < html.length; i++) {
      final c = html[i];
      if (c == '{') depth++;
      else if (c == '}') {
        depth--;
        if (depth == 0) { jsonEnd = i + 1; break; }
      }
    }
    if (jsonEnd == -1) return [];
    try {
      final data = jsonDecode(html.substring(jsonStart, jsonEnd));
      final results = <Map<String, String>>[];
      _findChannelRenderers(data, results);
      return results;
    } catch (e) {
      debugPrint('[_YoutubeChannelSheet] JSON parse error: $e');
      return [];
    }
  }

  void _findChannelRenderers(dynamic data, List<Map<String, String>> results) {
    if (data is Map) {
      if (data.containsKey('channelRenderer')) {
        final cr = data['channelRenderer'];
        if (cr is Map) {
          final channelId = cr['channelId'] as String?;
          final title = (cr['title'] as Map?)?['simpleText'] as String?;
          final thumbnailList = ((cr['thumbnail'] as Map?)?['thumbnails'] as List?);
          String? thumbnail = (thumbnailList?.isNotEmpty == true) ? thumbnailList!.last['url'] as String? : null;
          if (thumbnail?.startsWith('//') == true) thumbnail = 'https:$thumbnail';
          if (channelId != null && title != null) {
            results.add({'channelId': channelId, 'channelName': title, 'channelThumbnail': thumbnail ?? ''});
          }
        }
      }
      for (final value in data.values) _findChannelRenderers(value, results);
    } else if (data is List) {
      for (final item in data) _findChannelRenderers(item, results);
    }
  }

  void _selectChannel(Map<String, String> ch) {
    debugPrint('[_YoutubeChannelSheet] _selectChannel: ${ch['channelId']} / ${ch['channelName']}');
    setState(() {
      _resolvedChannelId = ch['channelId'];
      _validated = ch;
      _searchResults = [];
      _validateError = null;
    });
  }

  Future<void> _subscribe() async {
    if (_validated == null) return;
    final channelId = _resolvedChannelId ?? _channelIdCtrl.text.trim();
    final channelName = _validated!['channelName'] ?? channelId;

    // ── 로컬 모드(비로그인): 단말에 저장, 플랜별 개수 제한 ──
    if (_localMode) {
      final limit = _localChannelLimit(context);
      if (limit != -1 && _channels.length >= limit) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('무료 플랜은 채널 $limit개까지 등록할 수 있어요. 더 추가하려면 로그인하세요.')),
        );
        return;
      }
      debugPrint('[_YoutubeChannelSheet] _subscribe(local) - channelId: $channelId');
      setState(() => _subscribing = true);
      // 비로그인 게스트도 서버에 채널을 등록한다 (device-uuid 헤더 인증 → 백엔드 스케줄러가 영상 수집).
      // 자동 요약/퀴즈는 프리미엄 전용이므로 false로 강제한다.
      final serverChannel = await _apiService.subscribeYoutubeChannel(
        channelId: channelId,
        channelName: channelName,
        channelThumbnail: _validated!['channelThumbnail'] ?? '',
        autoTitle: true,
        autoMemo: false,
        autoSummary: false,
        autoQuiz: false,
      );
      debugPrint('[_YoutubeChannelSheet] _subscribe(local) - 서버 등록 결과 PK: ${serverChannel?.id}');
      // 서버 PK가 있으면 그대로 로컬에 저장(해제 시 unsubscribe 가능). 서버 실패 시 로컬 합성 ID로 폴백.
      final localChannel = YoutubeChannel(
        id: serverChannel?.id ?? DateTime.now().millisecondsSinceEpoch,
        memberId: serverChannel?.memberId ?? 'local',
        channelId: channelId,
        channelName: channelName,
        channelThumbnail: _validated!['channelThumbnail'] ?? '',
        isActive: true,
        // 로컬(비로그인) 모드: 전체탭 "등록일 기준" 정렬을 위해 로컬 등록일시를 저장한다.
        // 로그인 모드는 서버 subscribedAt(insertDateTime)을 사용.
        registeredAt: serverChannel?.registeredAt ?? DateTime.now(),
      );
      final updated = await LocalYoutubeChannelService.add(localChannel);
      if (mounted) {
        // 전체탭 영상 섹션이 바로 보이도록 설정 자동 활성화
        await Provider.of<AppStateProvider>(context, listen: false)
            .setShowYoutubeInAllTab(true);
      }
      if (mounted) {
        setState(() {
          _subscribing = false;
          _channels = updated;
          _channelIdCtrl.clear();
          _validated = null;
          _validateError = null;
          _resolvedChannelId = null;
          _searchResults = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$channelName" 구독이 완료되었습니다.')),
        );
      }
      return;
    }

    final quizCustomCount = _quizType == QuizTypes.custom
        ? int.tryParse(_quizCustomCtrl.text.trim())
        : null;
    if (_autoQuiz && _quizType == QuizTypes.custom &&
        (quizCustomCount == null || quizCustomCount <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('퀴즈 개수를 1 이상의 숫자로 입력해 주세요.')),
      );
      return;
    }
    debugPrint('[_YoutubeChannelSheet] _subscribe - channelId: $channelId');
    setState(() => _subscribing = true);
    final result = await _apiService.subscribeYoutubeChannel(
      token: widget.token!,
      channelId: channelId,
      channelName: channelName,
      channelThumbnail: _validated!['channelThumbnail'] ?? '',
      autoTitle: _autoTitle,
      autoMemo: _autoMemo,
      autoSummary: _autoSummary,
      summaryType: _autoSummary ? _summaryType : null,
      autoQuiz: _autoQuiz,
      quizType: _autoQuiz ? _quizType : null,
      quizCustomCount: quizCustomCount,
    );
    debugPrint('[_YoutubeChannelSheet] 구독 결과: ${result?.channelId}');
    if (mounted) {
      setState(() {
        _subscribing = false;
        if (result != null) {
          // 초기화
          _channelIdCtrl.clear();
          _validated = null;
          _validateError = null;
          _resolvedChannelId = null;
          _searchResults = [];
          _autoTitle = true;
          _autoMemo = false;
          _autoSummary = false;
          _summaryType = SummaryTypes.defaultValue;
          _autoQuiz = false;
          _quizType = QuizTypes.defaultValue;
        }
      });
      if (result != null) {
        await _loadChannels();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"$channelName" 구독이 완료되었습니다.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('구독 등록에 실패했습니다.')),
        );
      }
    }
  }

  Future<void> _unsubscribe(YoutubeChannel ch) async {
    debugPrint('[_YoutubeChannelSheet] _unsubscribe - channelPk: ${ch.id}');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('구독 해제'),
        content: Text('"${ch.channelName}"\n구독을 해제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('해제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    // 로컬 모드: 단말 저장소에서 제거
    if (_localMode) {
      final updated = await LocalYoutubeChannelService.removeByChannelId(ch.channelId);
      if (mounted) {
        setState(() => _channels = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${ch.channelName}" 구독이 해제되었습니다.')),
        );
      }
      return;
    }
    if (widget.token == null) return;
    final ok = await _apiService.unsubscribeYoutubeChannel(token: widget.token!, channelPk: ch.id);
    if (ok && mounted) {
      await _loadChannels();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${ch.channelName}" 구독이 해제되었습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    final canSearch = _channelIdCtrl.text.trim().isNotEmpty && !_searching && !_subscribing && _validated == null;
    final canSubscribe = _validated != null && !_subscribing;
    // 로컬 모드 한도 계산
    final limit = _localMode ? _localChannelLimit(context) : -1;
    final localLimitReached = _localMode && limit != -1 && _channels.length >= limit;
    final showAddArea = !localLimitReached;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Icon(Icons.subscriptions_outlined, color: Theme.of(context).primaryColor, size: 20),
                const SizedBox(width: 8),
                const Text('영상', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 로컬 모드(비로그인) 안내 배너
                  if (_localMode) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        limit == -1
                            ? '로그인 없이 채널을 등록할 수 있어요.\n자동 요약·퀴즈는 로그인 후 사용 가능합니다.'
                            : '로그인 없이 채널 $limit개를 등록할 수 있어요.\n자동 요약·퀴즈는 로그인 후 사용 가능합니다.',
                        style: TextStyle(fontSize: 12, color: color, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // ── 채널 추가 영역 (로컬 한도 도달 시 숨김) ──
                  if (showAddArea) ...[
                    const Text('채널 추가', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                    const SizedBox(height: 8),

                    // 플랫폼 선택 드롭다운 + 채널명 입력 + 검색 버튼
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 플랫폼 선택
                        Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedPlatform,
                              isDense: true,
                              items: [
                                DropdownMenuItem(
                                  value: 'youtube',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.play_circle, color: color, size: 18),
                                      const SizedBox(width: 4),
                                      const Text('유튜브', style: TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ],
                              onChanged: _searching || _subscribing ? null : (v) {
                                if (v != null) setState(() { _selectedPlatform = v; _channelIdCtrl.clear(); });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 채널명 입력
                        Expanded(
                          child: TextField(
                            controller: _channelIdCtrl,
                            focusNode: _focusNode,
                            enabled: _validated == null && !_searching,
                            decoration: InputDecoration(
                              hintText: '채널명 검색',
                              labelText: '채널명',
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              errorText: _validateError,
                              suffixIcon: _validated != null
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : null,
                            ),
                            // 입력 즉시 검색 버튼 활성/비활성 갱신
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => canSearch ? _searchChannels() : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 검색 버튼
                        SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed: canSearch ? _searchChannels : null,
                            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                            child: _searching
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('검색'),
                          ),
                        ),
                      ],
                    ),

                    // 검색 결과 목록 (여러 채널)
                    if (_searchResults.length > 1) ...[
                      const SizedBox(height: 8),
                      const Text('채널을 선택하세요', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      ..._searchResults.map((ch) => _buildSearchResultItem(ch, color)),
                    ],

                    // 선택된 채널 표시
                    if (_validated != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            if ((_validated!['channelThumbnail'] ?? '').isNotEmpty)
                              CircleAvatar(backgroundImage: NetworkImage(_validated!['channelThumbnail']!), radius: 14)
                            else
                              Icon(Icons.play_circle_outline, color: color, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _validated!['channelName'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() { _validated = null; _resolvedChannelId = null; _searchResults = []; }),
                              child: const Icon(Icons.close, size: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // 자동화 옵션 (로그인 시에만 제공 — 서버 자동 처리)
                    if (!_localMode) ...[
                    const Text('자동화 설정', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                    const SizedBox(height: 4),
                    _OptionCheckbox(
                      icon: Icons.title,
                      label: '영상 제목',
                      description: '새 영상 제목을 자동으로 저장',
                      value: _autoTitle,
                      onChanged: (v) => setState(() => _autoTitle = v),
                    ),
                    _OptionCheckbox(
                      icon: Icons.notes,
                      label: '메모',
                      description: '영상 내용을 텍스트 메모로 저장',
                      value: _autoMemo,
                      onChanged: (v) => setState(() => _autoMemo = v),
                    ),
                    _OptionCheckbox(
                      icon: Icons.auto_awesome,
                      label: '요약',
                      description: 'AI가 내용을 자동 요약',
                      value: _autoSummary,
                      onChanged: (v) => setState(() => _autoSummary = v),
                    ),
                    if (_autoSummary)
                      _ExpandedRadioOptions(
                        values: SummaryTypes.values,
                        selected: _summaryType,
                        labelOf: SummaryTypes.label,
                        onChanged: (v) => setState(() => _summaryType = v),
                      ),
                    _OptionCheckbox(
                      icon: Icons.notifications_none,
                      label: '퀴즈',
                      description: '요약 내용을 퀴즈 항목으로 등록',
                      value: _autoQuiz,
                      onChanged: (v) => setState(() => _autoQuiz = v),
                    ),
                    if (_autoQuiz)
                      _ExpandedRadioOptions(
                        values: QuizTypes.values,
                        selected: _quizType,
                        labelOf: (t) => QuizTypes.label(t),
                        onChanged: (v) => setState(() => _quizType = v),
                        trailingFor: (v) => v == QuizTypes.custom
                            ? SizedBox(
                                width: 64,
                                child: TextField(
                                  controller: _quizCustomCtrl,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  decoration: const InputDecoration(
                                    hintText: 'N',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ], // end if (!_localMode) 자동화 옵션

                    const SizedBox(height: 12),

                    // 구독 버튼
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: canSubscribe ? _subscribe : null,
                        icon: _subscribing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.subscriptions_outlined, size: 18),
                        label: const Text('구독하기'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ], // end if (showAddArea)

                  // 로컬 한도 도달 안내 (무료 1개 제한)
                  if (localLimitReached) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '무료 플랜은 채널 1개까지 등록할 수 있어요.\n더 추가하려면 로그인 후 이용하세요.',
                        style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                      ),
                    ),
                  ],

                  // ── 구독 중인 채널 목록 ──
                  const SizedBox(height: 20),
                    Row(
                      children: [
                        const Text('구독 중인 채널', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                        const SizedBox(width: 6),
                        if (_loadingChannels)
                          const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5)),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_channels.isEmpty && !_loadingChannels)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: Text('구독 중인 채널이 없습니다.', style: TextStyle(color: Colors.grey, fontSize: 13))),
                      )
                    else ...[
                      ..._channels.map((ch) => _buildChannelRow(ch, color)),
                      if (_hasMoreChannels)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: TextButton.icon(
                            onPressed: _loadingChannels ? null : () => _loadChannels(loadMore: true),
                            icon: _loadingChannels
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5))
                                : const Icon(Icons.expand_more, size: 18),
                            label: const Text('더 보기', style: TextStyle(fontSize: 13)),
                          ),
                        ),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleChannelOption(YoutubeChannel ch, String option) async {
    if (widget.token == null) return;
    debugPrint('[_YoutubeChannelSheet] _toggleChannelOption - channelPk: ${ch.id}, option: $option');
    // 요약/퀴즈: type 선택 시트
    if (option == 'summary') {
      await showSummarySettingSheet(
        context,
        token: widget.token!,
        channel: ch,
        apiService: _apiService,
        onUpdated: (updated) => setState(() {
          final idx = _channels.indexWhere((c) => c.id == ch.id);
          if (idx != -1) _channels[idx] = updated;
        }),
      );
      return;
    }
    if (option == 'quiz') {
      await showQuizSettingSheet(
        context,
        token: widget.token!,
        channel: ch,
        apiService: _apiService,
        onUpdated: (updated) => setState(() {
          final idx = _channels.indexWhere((c) => c.id == ch.id);
          if (idx != -1) _channels[idx] = updated;
        }),
      );
      return;
    }
    // title / memo: 낙관적 토글
    final updated = switch (option) {
      'title' => ch.copyWith(autoTitle: !ch.autoTitle),
      'memo'  => ch.copyWith(autoMemo: !ch.autoMemo),
      _ => ch,
    };
    setState(() {
      final idx = _channels.indexWhere((c) => c.id == ch.id);
      if (idx != -1) _channels[idx] = updated;
    });
    final ok = await _apiService.updateYoutubeChannelSettings(
      token: widget.token!,
      channelPk: ch.id,
      autoTitle: updated.autoTitle,
      autoMemo: updated.autoMemo,
    );
    if (!ok && mounted) {
      setState(() {
        final idx = _channels.indexWhere((c) => c.id == ch.id);
        if (idx != -1) _channels[idx] = ch;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정 변경에 실패했습니다.')),
      );
    }
  }

  Widget _buildSearchResultItem(Map<String, String> ch, Color color) {
    final thumbnail = ch['channelThumbnail'] ?? '';
    return InkWell(
      onTap: () => _selectChannel(ch),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            if (thumbnail.isNotEmpty)
              CircleAvatar(backgroundImage: NetworkImage(thumbnail), radius: 16)
            else
              const Icon(Icons.account_circle, size: 32, color: Colors.grey),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ch['channelName'] ?? '',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelRow(YoutubeChannel ch, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(ch.channelName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
              ),
              // 제일 오른쪽: 구독 삭제 아이콘만
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                onPressed: () => _unsubscribe(ch),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
          // 자동화 토글은 로그인(서버) 채널에서만 — 로컬 채널은 미지원
          if (!_localMode) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                YoutubeToggleChip(label: '제목',   color: Colors.teal,   active: ch.autoTitle,   onTap: () => _toggleChannelOption(ch, 'title')),
                YoutubeToggleChip(label: '메모',   color: Colors.indigo, active: ch.autoMemo,    onTap: () => _toggleChannelOption(ch, 'memo')),
                YoutubeToggleChip(label: '요약',   color: Colors.blue,   active: ch.autoSummary, onTap: () => _toggleChannelOption(ch, 'summary')),
                YoutubeToggleChip(label: '퀴즈', color: Colors.orange, active: ch.autoQuiz,  onTap: () => _toggleChannelOption(ch, 'quiz')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── YoutubeTab (노트 탭 내 콘텐츠) ──────────────────────────────────────────

class YoutubeTab extends StatefulWidget {
  const YoutubeTab({super.key});

  @override
  State<YoutubeTab> createState() => _YoutubeTabState();
}

class _YoutubeTabState extends State<YoutubeTab> with AutomaticKeepAliveClientMixin {
  final _apiService = ApiService();

  List<YoutubeChannel> _channels = [];
  final Map<String, Map<int, List<YoutubeVideo>>> _videoPageData = {};
  final Map<String, int> _videoTotalPages = {};
  final Set<String> _loadingVideoKeys = {}; // "${channelId}_${page}"
  final Set<String> _expandedChannels = {};
  final Map<String, int> _channelVideoPage = {};
  // ⭐ 영상 상세 캐시 (videoId → 상세, 팝업에서 lazy 로드 후 재사용)
  final Map<int, YoutubeVideo> _videoDetailCache = {};
  final Set<int> _loadingVideoDetails = {};
  // 영상별 요약 존재 여부 (videoId → 요약 1개 이상 저장됨) — 요약 아이콘 활성화 판단용
  final Map<String, bool> _videoHasSummary = {};
  final Map<String, bool> _videoHasQuiz = {}; // 영상별 저장된 퀴즈 존재 여부
  final _transcriptService = YoutubeTranscriptService();
  final _webViewTranscriptService = YoutubeWebViewTranscriptService();
  final _rssService = YoutubeRssService();
  bool _loading = true;
  String? _token;
  String _lastTabId = '';
  // 비로그인(스탠다드) = 로컬 모드. 채널/영상을 단말 로컬·RSS로 처리한다.
  bool get _localMode => _token == null || _token!.isEmpty;
  // 채널별 확인 상태(로컬 저장) + 채널별 최신 영상 게시일(RSS 조회) — 새 영상 판단/정렬용
  Map<String, ChannelWatchState> _watchStates = {};
  final Map<String, DateTime?> _latestVideoAt = {};
  // 로컬 모드: RSS로 받은 전체 영상 캐시(채널별) → 3개씩 페이지로 슬라이스
  final Map<String, List<YoutubeVideo>> _localRssCache = {};
  static const int _localPageSize = 3;
  // 무료(Free) 플랜의 채널별 영상 페이지 상한(로컬 RSS). 스탠다드 이상은 서버 전체 페이지.
  static const int _freeMaxPages = 5;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    debugPrint('[YoutubeTab] _init 진입');
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    // 비로그인 게스트 식별용 device-uuid 보장 (앱 다른 경로에서 미설정 시 폴백)
    ApiService.deviceUuid ??= prefs.getString('device_uuid');
    // 로그인 여부와 무관하게 로드 (비로그인=로컬, 로그인=서버)
    await _loadChannels();
  }

  Future<void> _loadChannels() async {
    setState(() => _loading = true);
    // 비로그인(스탠다드): 로컬 저장 채널 / 로그인: 서버 채널
    final channels = _localMode
        ? await LocalYoutubeChannelService.load()
        : await _apiService.getYoutubeChannels(token: _token!, page: 0, size: 100);
    // 확인 상태 로드 + 각 채널 최신 영상 게시일(RSS) 조회 → 새 영상 판단·정렬에 사용
    _watchStates = await ChannelWatchService.loadAll();
    await _loadLatestVideoTimes(channels);
    channels.sort(_compareChannels); // 새 영상 있는 채널을 위로
    debugPrint('[YoutubeTab] 채널 수: ${channels.length} (localMode: $_localMode)');
    if (mounted) {
      setState(() {
        _channels = channels;
        _loading = false;
        // 영상 리스트 자동 표시: 모든 채널을 펼친 상태로 둔다 (등록·새로고침 직후 바로 영상이 보이도록)
        _expandedChannels
          ..clear()
          ..addAll(channels.map((c) => c.channelId));
      });
      Provider.of<AppStateProvider>(context, listen: false).setYoutubeChannelCount(channels.length);
      // 각 채널의 첫 페이지 영상을 로드한다.
      // 로컬 모드는 _loadLatestVideoTimes에서 채운 _localRssCache를 재활용하므로 추가 네트워크가 없다.
      for (final ch in channels) {
        _loadVideoPage(ch.channelId, _channelVideoPage[ch.channelId] ?? 0);
      }
    }
  }

  /// 각 채널의 최신 영상 게시일을 RSS로 병렬 조회해 _latestVideoAt를 채운다.
  /// (RSS는 무인증이라 로그인/비로그인 모두 사용 가능)
  /// 로컬 모드에서는 여기서 받은 영상 리스트를 그대로 _localRssCache에 저장해,
  /// 채널을 펼칠 때 추가 네트워크 요청 없이 즉시 영상 목록을 보여준다.
  Future<void> _loadLatestVideoTimes(List<YoutubeChannel> channels) async {
    await Future.wait(channels.map((ch) async {
      final vids = await _rssService.fetchChannelVideos(ch.channelId);
      if (_localMode) _localRssCache[ch.channelId] = vids; // 영상 리스트 재활용
      if (vids.isNotEmpty && vids.first.publishedAt != null) {
        _latestVideoAt[ch.channelId] = DateTime.tryParse(vids.first.publishedAt!);
      }
    }));
  }

  /// 채널에 사용자가 아직 확인하지 않은 새 영상이 있는지 판단한다.
  /// 최신 영상 게시일 > 마지막 확인 시각 → 새 영상. 확인 기록 없으면 새 영상으로 본다.
  bool _hasNewVideo(YoutubeChannel ch) {
    final latest = _latestVideoAt[ch.channelId];
    if (latest == null) return false;
    final seen = _watchStates[ch.channelId]?.lastSeenAt;
    if (seen == null) return true;
    return latest.isAfter(seen);
  }

  /// 정렬: 새 영상 있는 채널 우선 → 그다음 최신 영상 시각 내림차순 → 마지막 id 내림차순
  int _compareChannels(YoutubeChannel a, YoutubeChannel b) {
    final an = _hasNewVideo(a), bn = _hasNewVideo(b);
    if (an != bn) return an ? -1 : 1;
    final at = _latestVideoAt[a.channelId], bt = _latestVideoAt[b.channelId];
    if (at != null && bt != null) return bt.compareTo(at);
    if (at != null) return -1;
    if (bt != null) return 1;
    return b.id.compareTo(a.id);
  }

  Future<void> _refresh() async {
    debugPrint('[YoutubeTab] _refresh - 자동 새로고침');
    _videoPageData.clear();
    _videoTotalPages.clear();
    _loadingVideoKeys.clear();
    _expandedChannels.clear();
    _channelVideoPage.clear();
    _localRssCache.clear();
    await _loadChannels();
  }

  Future<void> _loadVideoPage(String channelId, int page) async {
    final key = '${channelId}_$page';
    if (_loadingVideoKeys.contains(key)) return;
    if (_videoPageData[channelId]?[page] != null) return;
    setState(() => _loadingVideoKeys.add(key));

    // 영상 소스/페이지 한도는 구독 플랜 기준으로 가른다(전체탭과 동일 기준).
    // - 무료(Free): 로컬 RSS만, 채널별 최대 5페이지(=3×5≈15개).
    // - 스탠다드 이상(isPremiumUser): 서버에 저장된 전체를 페이지별로(서버 제목 기준).
    final isPaid = Provider.of<AppStateProvider>(context, listen: false).isPremiumUser;

    if (!isPaid) {
      try {
        var all = _localRssCache[channelId];
        if (all == null) {
          all = await _rssService.fetchChannelVideos(channelId);
          _localRssCache[channelId] = all;
        }
        final pageVids = all.skip(page * _localPageSize).take(_localPageSize).toList();
        debugPrint('[YoutubeTab] 무료 RSS 영상 로드 ($channelId) page $page: ${pageVids.length}/${all.length}개');
        if (mounted) setState(() {
          _videoPageData.putIfAbsent(channelId, () => {})[page] = pageVids;
          _videoTotalPages[channelId] = (all!.length / _localPageSize).ceil().clamp(1, _freeMaxPages);
          _loadingVideoKeys.remove(key);
        });
        _loadVideoSummaryFlags(pageVids); // 요약 존재 여부 비동기 조회 → 아이콘 활성화
      } catch (e) {
        debugPrint('❌ [YoutubeTab] 무료 RSS 영상 로드 실패 ($channelId): $e');
        if (mounted) setState(() {
          _videoPageData.putIfAbsent(channelId, () => {})[page] = [];
          _loadingVideoKeys.remove(key);
        });
      }
      return;
    }

    // 스탠다드 이상: 서버 전체 페이지 (프리미엄=토큰, 스탠다드 비로그인=게스트 device-uuid)
    final hasToken = _token != null && _token!.isNotEmpty;
    try {
      final result = hasToken
          ? await _apiService.getYoutubeVideos(token: _token!, channelId: channelId, page: page, size: _localPageSize)
          : await _apiService.getYoutubeVideos(channelId: channelId, page: page, size: _localPageSize);
      // 빈 응답(videos 0 && totalPages 0)은 타임아웃/오류로 간주 — 페이지 수 보존 + 캐시 안 함(재시도 가능).
      if (result.videos.isEmpty && result.totalPages == 0) {
        debugPrint('[YoutubeTab] 서버 영상 로드 빈 응답(일시 실패 추정) - page $page 보류, 재시도 가능');
        if (mounted) setState(() => _loadingVideoKeys.remove(key));
        return;
      }
      debugPrint('[YoutubeTab] 서버 영상 로드 ($channelId, page $page): ${result.videos.length}개, 총 ${result.totalPages}페이지');
      if (mounted) setState(() {
        _videoPageData.putIfAbsent(channelId, () => {})[page] = result.videos;
        _videoTotalPages[channelId] = result.totalPages;
        _loadingVideoKeys.remove(key);
      });
      _loadVideoSummaryFlags(result.videos); // 요약 존재 여부 비동기 조회 → 아이콘 활성화
    } catch (e) {
      debugPrint('❌ [YoutubeTab] 서버 영상 로드 실패 ($channelId, page $page): $e');
      if (mounted) setState(() => _loadingVideoKeys.remove(key));
    }
  }

  /// 영상 목록의 각 영상에 대해 요약 존재 여부를 조회해 _videoHasSummary 갱신.
  /// (summaryLevel:0 → 저장된 최고 레벨 반환, null이면 요약 없음)
  Future<void> _loadVideoSummaryFlags(List<YoutubeVideo> videos) async {
    for (final v in videos) {
      final vid = v.videoId;
      if (vid.isEmpty || _videoHasSummary.containsKey(vid)) continue;
      final cache = await _apiService.getYoutubeSummaryCache(videoId: vid, token: _token);
      if (!mounted) return;
      setState(() => _videoHasSummary[vid] = cache != null);
      // 퀴즈 존재 여부도 조회 (요약과 독립 — 요약 없이 만든 퀴즈 포함)
      final quiz = await _apiService.getYoutubeQuizCache(videoId: vid, token: _token);
      if (!mounted) return;
      setState(() => _videoHasQuiz[vid] = quiz != null);
    }
  }

  /// 단일 영상의 요약/퀴즈 존재 여부 재조회 (요약 시트를 닫은 직후 아이콘 갱신용)
  Future<void> _refreshVideoSummaryFlag(String videoId) async {
    if (videoId.isEmpty) return;
    final cache = await _apiService.getYoutubeSummaryCache(videoId: videoId, token: _token);
    if (!mounted) return;
    setState(() => _videoHasSummary[videoId] = cache != null);
    final quiz = await _apiService.getYoutubeQuizCache(videoId: videoId, token: _token);
    if (!mounted) return;
    setState(() => _videoHasQuiz[videoId] = quiz != null);
  }

  void _toggleChannel(YoutubeChannel ch) {
    final id = ch.channelId;
    if (_expandedChannels.contains(id)) {
      setState(() => _expandedChannels.remove(id));
    } else {
      setState(() => _expandedChannels.add(id));
      _loadVideoPage(id, _channelVideoPage[id] ?? 0);
      _markChannelSeen(ch); // 채널을 펼쳐 확인 → 새 영상 아이콘 끔
    }
  }

  /// 채널을 펼쳐 영상을 확인한 것으로 처리한다 (최신 영상 시각 저장 → 아이콘 비활성).
  Future<void> _markChannelSeen(YoutubeChannel ch) async {
    if (!_hasNewVideo(ch)) return; // 이미 확인됨
    final latest = _latestVideoAt[ch.channelId];
    await ChannelWatchService.markSeen(ch.channelId, latestAt: latest, now: DateTime.now());
    _watchStates = await ChannelWatchService.loadAll();
    if (mounted) setState(() {});
  }

  /// 채널 구독 삭제 (⋮ 메뉴) — 로컬/서버 자동 분기, 확인 다이얼로그 후 목록 재로드
  Future<void> _deleteChannel(YoutubeChannel ch) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('구독 삭제'),
        content: Text('"${ch.channelName}" 채널 구독을 삭제할까요?'),
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
    if (ok != true) return;
    try {
      if (_localMode) {
        // 서버에 등록돼 있던 채널이면 해제(수집 중단). 서버 PK가 아니면 서버에서 무시되므로 안전.
        await _apiService.unsubscribeYoutubeChannel(channelPk: ch.id);
        await LocalYoutubeChannelService.removeByChannelId(ch.channelId);
      } else {
        await _apiService.unsubscribeYoutubeChannel(token: _token!, channelPk: ch.id);
      }
      await ChannelWatchService.remove(ch.channelId);
    } catch (e) {
      debugPrint('[YoutubeTab] 채널 삭제 실패: $e');
    }
    if (mounted) await _loadChannels();
  }

  Future<void> _loadVideoDetail(YoutubeVideo video) async {
    final videoId = video.id;
    if (_loadingVideoDetails.contains(videoId)) return;
    setState(() => _loadingVideoDetails.add(videoId));
    debugPrint('[YoutubeTab] _loadVideoDetail - videoId: $videoId, hasTranscript: ${video.hasTranscript}');
    try {
      if (video.hasTranscript) {
        // 서버 DB에 자막 있음 → 상세 조회
        final detail = await _apiService.getYoutubeVideoDetail(token: _token!, videoId: videoId);
        final storedText = detail?.transcriptText ?? '';
        final isInvalidTranscript = storedText.startsWith('DIAG:') || storedText.startsWith('ERROR:');
        if (detail != null && !isInvalidTranscript) {
          if (mounted) setState(() {
            _videoDetailCache[videoId] = detail;
            _loadingVideoDetails.remove(videoId);
          });
          return;
        }
        debugPrint('[YoutubeTab] 잘못 저장된 자막 감지 - WebView 재수집: $storedText');
        // hasTranscript=true지만 내용 무효 → 아래 WebView 재수집으로 계속
      }

      // 자막 없음 or 잘못된 자막 → WebView로 YouTube 자막 수집
      debugPrint('[YoutubeTab] WebView 자막 수집 시작 - videoId: ${video.videoId}');
      final transcript = await _webViewTranscriptService.fetchTranscript(context, video.videoId);
      if (!mounted) return;
      if (transcript != null && transcript.isNotEmpty) {
        final syntheticVideo = YoutubeVideo(
          id: video.id, channelId: video.channelId, videoId: video.videoId,
          title: video.title, publishedAt: video.publishedAt,
          transcriptText: transcript, summary: video.summary, status: 'done',
          hasTranscript: true,
        );
        setState(() {
          _videoDetailCache[videoId] = syntheticVideo;
          _loadingVideoDetails.remove(videoId);
        });
        debugPrint('[YoutubeTab] 자막 수집 성공 - videoId: ${video.videoId}');
        _apiService.saveYoutubeTranscript(
          token: _token!, videoId: video.videoId, transcript: transcript,
        );
      } else {
        debugPrint('[YoutubeTab] 자막 수집 실패 - videoId: ${video.videoId}');
        if (mounted) setState(() => _loadingVideoDetails.remove(videoId));
      }
    } catch (e) {
      debugPrint('[YoutubeTab] ❌ 영상 상세 로드 실패: $e');
      if (mounted) setState(() => _loadingVideoDetails.remove(videoId));
    }
  }

  Future<void> _toggleChannelOption(YoutubeChannel ch, String option) async {
    if (_token == null) return;
    // 요약/퀴즈는 type 선택이 필요하므로 시트로 분기
    if (option == 'summary') {
      await showSummarySettingSheet(
        context,
        token: _token!,
        channel: ch,
        apiService: _apiService,
        onUpdated: (updated) => setState(() {
          final idx = _channels.indexWhere((c) => c.id == ch.id);
          if (idx != -1) _channels[idx] = updated;
        }),
      );
      return;
    }
    if (option == 'quiz') {
      await showQuizSettingSheet(
        context,
        token: _token!,
        channel: ch,
        apiService: _apiService,
        onUpdated: (updated) => setState(() {
          final idx = _channels.indexWhere((c) => c.id == ch.id);
          if (idx != -1) _channels[idx] = updated;
        }),
      );
      return;
    }
    // title / memo: 단순 토글
    final updated = switch (option) {
      'title' => ch.copyWith(autoTitle: !ch.autoTitle),
      'memo'  => ch.copyWith(autoMemo: !ch.autoMemo),
      _ => ch,
    };
    setState(() {
      final idx = _channels.indexWhere((c) => c.id == ch.id);
      if (idx != -1) _channels[idx] = updated;
    });
    final ok = await _apiService.updateYoutubeChannelSettings(
      token: _token!,
      channelPk: ch.id,
      autoTitle: updated.autoTitle,
      autoMemo: updated.autoMemo,
    );
    if (!ok && mounted) {
      setState(() {
        final idx = _channels.indexWhere((c) => c.id == ch.id);
        if (idx != -1) _channels[idx] = ch;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정 변경에 실패했습니다.')),
      );
    }
  }

  String _shortDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }

  Future<void> _openManagementSheet() async {
    await showYoutubeChannelSheet(context);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // 탭 전환 감지 → youtube 탭 진입 시 자동 새로고침
    final currentTabId = context.select<AppStateProvider, String>((p) => p.currentWritingTabId);
    if (currentTabId == 'youtube' && _lastTabId != 'youtube' && !_loading) {
      _lastTabId = currentTabId;
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _refresh(); });
    } else if (currentTabId != _lastTabId) {
      _lastTabId = currentTabId;
    }

    return Stack(
      children: [
        _buildBody(),
        // 채널 관리 시트는 로컬 모드(비로그인)도 지원하므로 항상 노출
        Positioned(
          right: 16, bottom: 16,
          child: FloatingActionButton.small(
            heroTag: 'youtube_tab_fab',
            onPressed: _openManagementSheet,
            tooltip: '채널 구독 관리',
            backgroundColor: Theme.of(context).primaryColor,
            child: const YoutubeSpeedDialIcon(),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    // 스탠다드(비로그인)도 로컬 채널을 표시한다 — 로그인 요구 화면 제거.
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_channels.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.subscriptions_outlined, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text('구독 중인 채널이 없습니다.', style: TextStyle(fontSize: 15)),
              const SizedBox(height: 6),
              const Text('아래 + 버튼으로 채널을 추가하세요.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        // 채널이 적어 화면이 다 차지 않아도 아래로 당겨 새로고침이 되도록 항상 스크롤 허용
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 80),
        itemCount: _channels.length,
        itemBuilder: (_, i) => _buildChannelCard(_channels[i]),
      ),
    );
  }

  // ── 채널 카드 (노트 카드와 동일한 구조) ──────────────────────────────────
  Widget _buildChannelCard(YoutubeChannel ch) {
    final color = Theme.of(context).primaryColor;
    final isExpanded = _expandedChannels.contains(ch.channelId);
    final currentPage = _channelVideoPage[ch.channelId] ?? 0;
    final isLoadingVideos = _loadingVideoKeys.contains('${ch.channelId}_$currentPage');
    final videos = _videoPageData[ch.channelId]?[currentPage] ?? [];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          // ── 채널 헤더 행 (전체 탭과 동일 구조: [구독아이콘][제목][새영상][⋮삭제]) ──
          // 항목 높이 1.5배: 헤더 세로 패딩 3→10
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 32, height: 21,
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
                // ⋮ 메뉴 (삭제) — 전체 탭과 동일
                SizedBox(
                  width: 24, height: 24,
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    icon: Icon(Icons.more_vert, color: color, size: 16),
                    tooltip: '메뉴',
                    onSelected: (v) { if (v == 'delete') _deleteChannel(ch); },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('삭제', style: TextStyle(color: Colors.red)),
                        ]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── 영상 목록 (펼쳐졌을 때) ──
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

  Widget _autoSettingIcon(IconData icon, bool enabled, String tooltip, VoidCallback? onTap) {
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

  // ── 영상 타일 ──────────────────────────────────────────────────────────────
  Widget _buildVideoTile(YoutubeVideo video, YoutubeChannel ch) {
    final dotColor = video.isDone
        ? Colors.green
        : video.hasNoTranscript
            ? Colors.orange
            : Colors.blue;
    final hasSummary = _videoHasSummary[video.videoId] == true;
    final hasQuiz = _videoHasQuiz[video.videoId] == true;

    return InkWell(
      // ⭐ 흐릿한 항목도 클릭 가능 — YouTube 플레이어 시트 표시
      onTap: () => _showVideoPlayerSheet(video, ch),
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
                // 제목은 처리 상태와 무관하게 항상 검은색으로 표시(가독성)
                style: const TextStyle(fontSize: 13, color: Colors.black),
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
                        token: _token,
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
                        token: _token,
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
                child: Text(_shortDate(video.publishedAt!),
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }

  /// YouTube IFrame 임베드 + 요약 버튼 시트
  Future<void> _showVideoPlayerSheet(YoutubeVideo video, YoutubeChannel ch) async {
    await showYoutubeVideoPlayerSheet(
      context: context,
      video: video,
      channel: ch,
      token: _token,
    );
    // 플레이어 시트에서 요약했을 수 있으니 아이콘 상태 재조회
    _refreshVideoSummaryFlag(video.videoId);
  }

  /// 영상 상세 팝업 (헤더: 채널명/제목/일시, 본문: 요약 또는 전사)
  void _showVideoDetailDialog(YoutubeVideo video, YoutubeChannel ch) {
    if (_token == null) return;
    if (!_videoDetailCache.containsKey(video.id)) {
      _loadVideoDetail(video);
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
        detailCache: _videoDetailCache,
        loadingSet: _loadingVideoDetails,
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
}

// ── 공용 위젯 ────────────────────────────────────────────────────────────────

class _OptionCheckbox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _OptionCheckbox({
    required this.icon,
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          children: [
            Icon(icon, size: 18, color: value ? Theme.of(context).primaryColor : Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: value ? Theme.of(context).primaryColor : Colors.grey[700])),
                  Text(description, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            Checkbox(value: value, onChanged: (v) => onChanged(v ?? value)),
          ],
        ),
      ),
    );
  }
}

/// 구독 채널의 요약 설정 변경 시트 (auto + summaryType).
/// 변경 성공 시 [onUpdated]를 호출하고 true 반환.
Future<bool> showSummarySettingSheet(
  BuildContext context, {
  required String token,
  required YoutubeChannel channel,
  required ApiService apiService,
  required void Function(YoutubeChannel updated) onUpdated,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _SummarySettingSheet(
      token: token, channel: channel, apiService: apiService, onUpdated: onUpdated,
    ),
  );
  return result ?? false;
}

/// 구독 채널의 퀴즈 설정 변경 시트 (auto + quizType + CUSTOM 시 N).
Future<bool> showQuizSettingSheet(
  BuildContext context, {
  required String token,
  required YoutubeChannel channel,
  required ApiService apiService,
  required void Function(YoutubeChannel updated) onUpdated,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _QuizSettingSheet(
      token: token, channel: channel, apiService: apiService, onUpdated: onUpdated,
    ),
  );
  return result ?? false;
}

class _SummarySettingSheet extends StatefulWidget {
  final String token;
  final YoutubeChannel channel;
  final ApiService apiService;
  final void Function(YoutubeChannel updated) onUpdated;
  const _SummarySettingSheet({
    required this.token, required this.channel, required this.apiService, required this.onUpdated,
  });
  @override
  State<_SummarySettingSheet> createState() => _SummarySettingSheetState();
}

class _SummarySettingSheetState extends State<_SummarySettingSheet> {
  late bool _enabled = widget.channel.autoSummary;
  late String _type = widget.channel.summaryType ?? SummaryTypes.defaultValue;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await widget.apiService.updateYoutubeChannelSettings(
      token: widget.token,
      channelPk: widget.channel.id,
      autoSummary: _enabled,
      summaryType: _enabled ? _type : null,
      clearSummaryType: !_enabled,
    );
    if (!mounted) return;
    if (ok) {
      widget.onUpdated(widget.channel.copyWith(
        autoSummary: _enabled,
        summaryType: _enabled ? _type : null,
        clearSummaryType: !_enabled,
      ));
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정 저장에 실패했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingSheetScaffold(
      icon: Icons.auto_awesome,
      title: '요약 설정',
      enabled: _enabled,
      onToggle: (v) => setState(() => _enabled = v),
      saving: _saving,
      onSave: _save,
      child: _ExpandedRadioOptions(
        values: SummaryTypes.values,
        selected: _type,
        labelOf: SummaryTypes.label,
        onChanged: (v) => setState(() => _type = v),
      ),
    );
  }
}

class _QuizSettingSheet extends StatefulWidget {
  final String token;
  final YoutubeChannel channel;
  final ApiService apiService;
  final void Function(YoutubeChannel updated) onUpdated;
  const _QuizSettingSheet({
    required this.token, required this.channel, required this.apiService, required this.onUpdated,
  });
  @override
  State<_QuizSettingSheet> createState() => _QuizSettingSheetState();
}

class _QuizSettingSheetState extends State<_QuizSettingSheet> {
  late bool _enabled = widget.channel.autoQuiz;
  late String _type = widget.channel.quizType ?? QuizTypes.defaultValue;
  late final TextEditingController _customCtrl = TextEditingController(
    text: (widget.channel.quizCustomCount ?? 7).toString(),
  );
  bool _saving = false;

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    int? customCount;
    if (_enabled && _type == QuizTypes.custom) {
      customCount = int.tryParse(_customCtrl.text.trim());
      if (customCount == null || customCount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('퀴즈 개수를 1 이상의 숫자로 입력해 주세요.')),
        );
        return;
      }
    }
    setState(() => _saving = true);
    final ok = await widget.apiService.updateYoutubeChannelSettings(
      token: widget.token,
      channelPk: widget.channel.id,
      autoQuiz: _enabled,
      quizType: _enabled ? _type : null,
      clearQuizType: !_enabled,
      quizCustomCount: customCount,
      clearQuizCustomCount: !_enabled || _type != QuizTypes.custom,
    );
    if (!mounted) return;
    if (ok) {
      widget.onUpdated(widget.channel.copyWith(
        autoQuiz: _enabled,
        quizType: _enabled ? _type : null,
        clearQuizType: !_enabled,
        quizCustomCount: customCount,
        clearQuizCustomCount: !_enabled || _type != QuizTypes.custom,
      ));
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정 저장에 실패했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingSheetScaffold(
      icon: Icons.notifications_none,
      title: '퀴즈 설정',
      enabled: _enabled,
      onToggle: (v) => setState(() => _enabled = v),
      saving: _saving,
      onSave: _save,
      child: _ExpandedRadioOptions(
        values: QuizTypes.values,
        selected: _type,
        labelOf: (t) => QuizTypes.label(t),
        onChanged: (v) => setState(() => _type = v),
        trailingFor: (v) => v == QuizTypes.custom
            ? SizedBox(
                width: 64,
                child: TextField(
                  controller: _customCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: 'N',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    border: OutlineInputBorder(),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

/// 시트 공통 스캐폴드 — 헤더 / on-off 스위치 / 옵션 / 저장 버튼.
class _SettingSheetScaffold extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final bool saving;
  final VoidCallback onSave;
  final Widget child;
  const _SettingSheetScaffold({
    required this.icon, required this.title, required this.enabled,
    required this.onToggle, required this.saving, required this.onSave, required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                  Switch(value: enabled, onChanged: saving ? null : onToggle),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: enabled ? 1 : 0.4,
                child: IgnorePointer(ignoring: !enabled, child: child),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saving ? null : onSave,
                  child: saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('저장'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 체크박스 ON 시 인라인으로 펼쳐지는 단일 선택 라디오 옵션 목록.
/// 옵션마다 후행 위젯(예: CUSTOM 시 숫자 입력)을 붙일 수 있다.
class _ExpandedRadioOptions extends StatelessWidget {
  final List<String> values;
  final String selected;
  final String Function(String) labelOf;
  final ValueChanged<String> onChanged;
  final Widget? Function(String)? trailingFor;

  const _ExpandedRadioOptions({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.trailingFor,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Container(
      margin: const EdgeInsets.fromLTRB(26, 0, 0, 4),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: values.map((v) {
          final isSelected = v == selected;
          final trailing = trailingFor?.call(v);
          return InkWell(
            onTap: () => onChanged(v),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    size: 16,
                    color: isSelected ? color : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      labelOf(v),
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? color : Colors.grey[800],
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing,
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class YoutubeToggleChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const YoutubeToggleChip({
    super.key,
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.5) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: active ? color : Colors.grey,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// 탭 헤더 아이콘 (메모 + 테마색 배지)
class YoutubeTabIcon extends StatelessWidget {
  const YoutubeTabIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notes),
        Positioned(
          right: -5, bottom: -3,
          child: Container(
            width: 11, height: 11,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const Center(child: Icon(Icons.play_arrow, size: 8, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}

/// 영상 상세 내용 시트 (제목 탭 시 내용만 lazy 로드)
class YoutubeVideoDetailSheet extends StatefulWidget {
  final int videoId;
  final String title;
  final String? publishedAt;
  final String token;
  final ApiService apiService;

  const YoutubeVideoDetailSheet({
    super.key,
    required this.videoId,
    required this.title,
    this.publishedAt,
    required this.token,
    required this.apiService,
  });

  @override
  State<YoutubeVideoDetailSheet> createState() => _YoutubeVideoDetailSheetState();
}

class _YoutubeVideoDetailSheetState extends State<YoutubeVideoDetailSheet> {
  YoutubeVideo? _detail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final detail = await widget.apiService.getYoutubeVideoDetail(
      token: widget.token,
      videoId: widget.videoId,
    );
    if (mounted) setState(() { _detail = detail; _loading = false; });
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      minChildSize: 0.3,
      builder: (_, sc) => Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    controller: sc,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        if (widget.publishedAt != null) ...[
                          const SizedBox(height: 4),
                          Text(_formatDate(widget.publishedAt!),
                              style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        if (_detail == null)
                          const Text('내용을 불러올 수 없습니다.', style: TextStyle(color: Colors.grey))
                        else if (_detail!.hasSummary)
                          Text(_detail!.summary!, style: const TextStyle(fontSize: 15, height: 1.7))
                        else if (_detail!.transcriptText != null && _detail!.transcriptText!.isNotEmpty)
                          Text(_detail!.transcriptText!, style: const TextStyle(fontSize: 15, height: 1.7))
                        else
                          const Text('내용이 없습니다.', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// 스피드다이얼 아이콘 (메모 + 테마색 배지, 흰색)
class YoutubeSpeedDialIcon extends StatelessWidget {
  const YoutubeSpeedDialIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notes, size: 20, color: Colors.white),
        Positioned(
          right: -5, bottom: -4,
          child: Container(
            width: 12, height: 12,
            decoration: BoxDecoration(
              color: color, shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: const Center(child: Icon(Icons.play_arrow, size: 8, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}

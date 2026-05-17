import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/youtube_channel.dart';
import '../services/api_service.dart';
import '../services/app_state_provider.dart';

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
  bool _autoRemind = false;

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

  Future<void> _loadChannels({bool loadMore = false}) async {
    debugPrint('[_YoutubeChannelSheet] _loadChannels 진입 - loadMore: $loadMore');
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
    if (_validated == null || widget.token == null) return;
    final channelId = _resolvedChannelId ?? _channelIdCtrl.text.trim();
    final channelName = _validated!['channelName'] ?? channelId;
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
      autoRemind: _autoRemind,
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
          _autoRemind = false;
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
    if (confirmed != true || widget.token == null) return;
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
    final hasToken = widget.token != null && widget.token!.isNotEmpty;
    final color = Theme.of(context).primaryColor;
    final canSearch = _channelIdCtrl.text.trim().isNotEmpty && !_searching && !_subscribing && _validated == null;
    final canSubscribe = _validated != null && !_subscribing;

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
                const Text('영상 구독', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                  if (!hasToken) ...[
                    // 로그인 필요
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(Icons.lock_outline, size: 36, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('로그인이 필요합니다.', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    // ── 채널 추가 영역 ──
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

                    // 자동화 옵션
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
                    _OptionCheckbox(
                      icon: Icons.notifications_none,
                      label: '리마인드',
                      description: '요약 내용을 리마인드 항목으로 등록',
                      value: _autoRemind,
                      onChanged: (v) => setState(() => _autoRemind = v),
                    ),

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
    final updated = switch (option) {
      'title'  => ch.copyWith(autoTitle: !ch.autoTitle),
      'memo'   => ch.copyWith(autoMemo: !ch.autoMemo),
      'summary' => ch.copyWith(autoSummary: !ch.autoSummary),
      'remind' => ch.copyWith(autoRemind: !ch.autoRemind),
      _ => ch,
    };
    // 낙관적 업데이트 (즉시 반영)
    setState(() {
      final idx = _channels.indexWhere((c) => c.id == ch.id);
      if (idx != -1) _channels[idx] = updated;
    });
    debugPrint('[_YoutubeChannelSheet] _toggleChannelOption - channelPk: ${ch.id}, option: $option');
    final ok = await _apiService.updateYoutubeChannelSettings(
      token: widget.token!,
      channelPk: ch.id,
      autoTitle: updated.autoTitle,
      autoMemo: updated.autoMemo,
      autoSummary: updated.autoSummary,
      autoRemind: updated.autoRemind,
    );
    if (!ok && mounted) {
      // 실패 시 원복
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
              const Icon(Icons.play_circle_outline, color: Colors.red, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(ch.channelName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                onPressed: () => _unsubscribe(ch),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: [
              YoutubeToggleChip(label: '제목',   color: Colors.teal,   active: ch.autoTitle,   onTap: () => _toggleChannelOption(ch, 'title')),
              YoutubeToggleChip(label: '메모',   color: Colors.indigo, active: ch.autoMemo,    onTap: () => _toggleChannelOption(ch, 'memo')),
              YoutubeToggleChip(label: '요약',   color: Colors.blue,   active: ch.autoSummary, onTap: () => _toggleChannelOption(ch, 'summary')),
              YoutubeToggleChip(label: '리마인드', color: Colors.orange, active: ch.autoRemind,  onTap: () => _toggleChannelOption(ch, 'remind')),
            ],
          ),
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
  bool _loading = true;
  String? _token;
  String _lastTabId = '';

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
    if (_token == null || _token!.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    await _loadChannels();
  }

  Future<void> _loadChannels() async {
    if (_token == null) return;
    setState(() => _loading = true);
    final channels = await _apiService.getYoutubeChannels(token: _token!, page: 0, size: 100);
    channels.sort((a, b) => b.id.compareTo(a.id));
    debugPrint('[YoutubeTab] 채널 수: ${channels.length}');
    if (mounted) {
      setState(() { _channels = channels; _loading = false; });
      Provider.of<AppStateProvider>(context, listen: false).setYoutubeChannelCount(channels.length);
    }
  }

  Future<void> _refresh() async {
    debugPrint('[YoutubeTab] _refresh - 자동 새로고침');
    _videoPageData.clear();
    _videoTotalPages.clear();
    _loadingVideoKeys.clear();
    _expandedChannels.clear();
    _channelVideoPage.clear();
    await _loadChannels();
  }

  Future<void> _loadVideoPage(String channelId, int page) async {
    if (_token == null) return;
    final key = '${channelId}_$page';
    if (_loadingVideoKeys.contains(key)) return;
    if (_videoPageData[channelId]?[page] != null) return;
    setState(() => _loadingVideoKeys.add(key));
    final result = await _apiService.getYoutubeVideos(token: _token!, channelId: channelId, page: page, size: 3);
    debugPrint('[YoutubeTab] 영상 로드 ($channelId, page $page): ${result.videos.length}개, 총 ${result.totalPages}페이지');
    if (mounted) setState(() {
      _videoPageData.putIfAbsent(channelId, () => {})[page] = result.videos;
      _videoTotalPages[channelId] = result.totalPages;
      _loadingVideoKeys.remove(key);
    });
  }

  void _toggleChannel(YoutubeChannel ch) {
    final id = ch.channelId;
    if (_expandedChannels.contains(id)) {
      setState(() => _expandedChannels.remove(id));
    } else {
      setState(() => _expandedChannels.add(id));
      _loadVideoPage(id, _channelVideoPage[id] ?? 0);
    }
  }

  Future<void> _toggleChannelOption(YoutubeChannel ch, String option) async {
    if (_token == null) return;
    final updated = switch (option) {
      'title'   => ch.copyWith(autoTitle: !ch.autoTitle),
      'memo'    => ch.copyWith(autoMemo: !ch.autoMemo),
      'summary' => ch.copyWith(autoSummary: !ch.autoSummary),
      'remind'  => ch.copyWith(autoRemind: !ch.autoRemind),
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
      autoSummary: updated.autoSummary,
      autoRemind: updated.autoRemind,
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

  void _showContentSheet(YoutubeVideo video) {
    if (_token == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => YoutubeVideoDetailSheet(
        videoId: video.id,
        title: video.title,
        publishedAt: video.publishedAt,
        token: _token!,
        apiService: _apiService,
      ),
    );
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

  void _showChannelPopup(YoutubeChannel ch) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final current = _channels.firstWhere((c) => c.id == ch.id, orElse: () => ch);
          final themeColor = Theme.of(context).primaryColor;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.play_circle_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(current.channelName,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('자동화 설정', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    YoutubeToggleChip(
                      label: '제목',
                      color: themeColor,
                      active: current.autoTitle,
                      onTap: () { _toggleChannelOption(current, 'title'); setSheetState(() {}); },
                    ),
                    YoutubeToggleChip(
                      label: '메모',
                      color: current.autoTitle ? themeColor : Colors.grey,
                      active: current.autoMemo && current.autoTitle,
                      onTap: current.autoTitle
                          ? () { _toggleChannelOption(current, 'memo'); setSheetState(() {}); }
                          : () {},
                    ),
                    YoutubeToggleChip(
                      label: '요약',
                      color: current.autoTitle ? themeColor : Colors.grey,
                      active: current.autoSummary && current.autoTitle,
                      onTap: current.autoTitle
                          ? () { _toggleChannelOption(current, 'summary'); setSheetState(() {}); }
                          : () {},
                    ),
                    YoutubeToggleChip(
                      label: '리마인드',
                      color: current.autoTitle ? themeColor : Colors.grey,
                      active: current.autoRemind && current.autoTitle,
                      onTap: current.autoTitle
                          ? () { _toggleChannelOption(current, 'remind'); setSheetState(() {}); }
                          : () {},
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
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
        if (_token != null && _token!.isNotEmpty)
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
    if (_token == null || _token!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text('로그인이 필요합니다.', style: TextStyle(fontSize: 15)),
              const SizedBox(height: 6),
              const Text('설정 > 계정에서 로그인 후 이용하세요.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ),
      );
    }
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
          // ── 채널 헤더 행 ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Leading: 채널 아이콘 (속도 다이얼과 동일한 노트+배지 스타일)
                SizedBox(
                  width: 32, height: 32,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: color.withValues(alpha: 0.1),
                        child: Icon(Icons.notes, color: color, size: 18),
                      ),
                      Positioned(
                        right: -1, bottom: -1,
                        child: Container(
                          width: 13, height: 13,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Center(child: Icon(Icons.play_arrow, size: 8, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // 채널명 (탭 시 설정 팝업)
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: () => _showChannelPopup(ch),
                    child: Text(
                      ch.channelName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // 자동화 설정 아이콘들
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _autoSettingIcon(Icons.title, ch.autoTitle, '제목', () => _toggleChannelOption(ch, 'title')),
                      _autoSettingIcon(Icons.notes, ch.autoMemo, '메모', ch.autoTitle ? () => _toggleChannelOption(ch, 'memo') : null),
                      _autoSettingIcon(Icons.auto_awesome, ch.autoSummary, '요약', ch.autoTitle ? () => _toggleChannelOption(ch, 'summary') : null),
                      _autoSettingIcon(Icons.notifications_none, ch.autoRemind, '리마인드', ch.autoTitle ? () => _toggleChannelOption(ch, 'remind') : null),
                      // 펼치기 아이콘
                      GestureDetector(
                        onTap: () => _toggleChannel(ch),
                        child: isLoadingVideos
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : Icon(
                                isExpanded ? Icons.expand_less : Icons.expand_more,
                                color: Colors.grey, size: 20,
                              ),
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
    // autoMemo가 켜져 있고 done 상태(자막 없음 제외)일 때만 탭 가능 (상세 내용은 탭 시 lazy 로드)
    final canOpen = ch.autoMemo && video.isDone && !video.hasNoTranscript;
    final dotColor = video.isDone
        ? Colors.green
        : video.hasNoTranscript
            ? Colors.orange
            : Colors.blue;

    return InkWell(
      onTap: canOpen ? () => _showContentSheet(video) : null,
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
                style: TextStyle(
                  fontSize: 13,
                  color: canOpen ? null : Colors.grey,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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

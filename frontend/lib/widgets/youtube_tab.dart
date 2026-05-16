import 'package:flutter/material.dart';
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

  // 구독 추가 상태
  bool _validating = false;       // 채널 검증 중
  bool _subscribing = false;      // 구독 요청 중
  Map<String, String>? _validated; // 검증된 채널 정보 (null이면 미검증)
  String? _validateError;

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
    // 채널 ID가 바뀌면 검증 결과 초기화
    if (_validated != null || _validateError != null) {
      setState(() { _validated = null; _validateError = null; });
    }
  }

  Future<void> _loadChannels() async {
    debugPrint('[_YoutubeChannelSheet] _loadChannels 진입');
    if (widget.token == null || widget.token!.isEmpty) return;
    setState(() => _loadingChannels = true);
    final channels = await _apiService.getYoutubeChannels(token: widget.token!);
    channels.sort((a, b) => b.id.compareTo(a.id));
    debugPrint('[_YoutubeChannelSheet] 채널 수: ${channels.length}');
    if (mounted) setState(() { _channels = channels; _loadingChannels = false; });
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

  Future<void> _subscribe() async {
    if (_validated == null || widget.token == null) return;
    final channelId = _channelIdCtrl.text.trim();
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
    final canValidate = _channelIdCtrl.text.trim().isNotEmpty && !_validating && !_subscribing;
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
                const Icon(Icons.subscriptions_outlined, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                const Text('유튜브 구독', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

                    // 채널 ID 입력 + 확인 버튼
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _channelIdCtrl,
                            focusNode: _focusNode,
                            decoration: InputDecoration(
                              hintText: 'UCxxxxxxxxxxxxxxxx',
                              labelText: '채널 ID',
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              errorText: _validateError,
                              suffixIcon: _validated != null
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : null,
                            ),
                            onSubmitted: (_) => canValidate ? _validate() : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed: canValidate ? _validate : null,
                            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                            child: _validating
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('확인'),
                          ),
                        ),
                      ],
                    ),

                    // 검증된 채널명 표시
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
                            const Icon(Icons.play_circle_outline, color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _validated!['channelName'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
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
                    else
                      ..._channels.map((ch) => _buildChannelRow(ch, color)),
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
              _ToggleChip(label: '제목',   color: Colors.teal,   active: ch.autoTitle,   onTap: () => _toggleChannelOption(ch, 'title')),
              _ToggleChip(label: '메모',   color: Colors.indigo, active: ch.autoMemo,    onTap: () => _toggleChannelOption(ch, 'memo')),
              _ToggleChip(label: '요약',   color: Colors.blue,   active: ch.autoSummary, onTap: () => _toggleChannelOption(ch, 'summary')),
              _ToggleChip(label: '리마인드', color: Colors.orange, active: ch.autoRemind,  onTap: () => _toggleChannelOption(ch, 'remind')),
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
  final Map<String, List<YoutubeVideo>> _videoMap = {};
  final Set<String> _loadingChannels = {};
  final Set<String> _expandedChannels = {};
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
    final channels = await _apiService.getYoutubeChannels(token: _token!);
    channels.sort((a, b) => b.id.compareTo(a.id));
    debugPrint('[YoutubeTab] 채널 수: ${channels.length}');
    if (mounted) setState(() { _channels = channels; _loading = false; });
  }

  Future<void> _refresh() async {
    debugPrint('[YoutubeTab] _refresh - 자동 새로고침');
    _videoMap.clear();
    await _loadChannels();
  }

  Future<void> _loadVideos(String channelId) async {
    if (_token == null || _videoMap.containsKey(channelId)) return;
    setState(() => _loadingChannels.add(channelId));
    final videos = await _apiService.getYoutubeVideos(token: _token!, channelId: channelId);
    debugPrint('[YoutubeTab] 영상 수 ($channelId): ${videos.length}');
    if (mounted) setState(() { _videoMap[channelId] = videos; _loadingChannels.remove(channelId); });
  }

  void _toggleChannel(YoutubeChannel ch) {
    final id = ch.channelId;
    if (_expandedChannels.contains(id)) {
      setState(() => _expandedChannels.remove(id));
    } else {
      setState(() => _expandedChannels.add(id));
      _loadVideos(id);
    }
  }

  void _showContentSheet(YoutubeVideo video) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        minChildSize: 0.3,
        builder: (_, sc) => Column(
          children: [
            Container(margin: const EdgeInsets.symmetric(vertical: 8), width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            Expanded(
              child: SingleChildScrollView(
                controller: sc,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(video.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    if (video.publishedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(_formatDate(video.publishedAt!), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    if (video.hasSummary)
                      Text(video.summary!, style: const TextStyle(fontSize: 15, height: 1.7))
                    else if (video.transcriptText != null && video.transcriptText!.isNotEmpty)
                      Text(video.transcriptText!, style: const TextStyle(fontSize: 15, height: 1.7))
                    else
                      const Text('내용이 없습니다.', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    } catch (_) { return iso; }
  }

  String _shortDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
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
        if (_token != null && _token!.isNotEmpty)
          Positioned(
            right: 16, bottom: 16,
            child: FloatingActionButton.small(
              heroTag: 'youtube_tab_fab',
              onPressed: _openManagementSheet,
              tooltip: '채널 구독 관리',
              backgroundColor: Colors.red,
              child: const Icon(Icons.add, color: Colors.white),
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
    final isLoadingVideos = _loadingChannels.contains(ch.channelId);
    final videos = _videoMap[ch.channelId] ?? [];

    final borderRadius = BorderRadius.circular(12);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          // ── 채널 헤더 행 ──
          InkWell(
            onTap: () => _toggleChannel(ch),
            borderRadius: borderRadius,
            child: Padding(
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
                              color: Colors.red,
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
                  // 채널명
                  Expanded(
                    flex: 3,
                    child: Text(
                      ch.channelName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 자동화 설정 아이콘들
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _autoSettingIcon(Icons.title, Colors.teal, ch.autoTitle, '제목'),
                        _autoSettingIcon(Icons.notes, Colors.indigo, ch.autoMemo, '메모'),
                        _autoSettingIcon(Icons.auto_awesome, Colors.blue, ch.autoSummary, '요약'),
                        _autoSettingIcon(Icons.notifications_none, Colors.orange, ch.autoRemind, '리마인드'),
                        // 펼치기 아이콘
                        if (isLoadingVideos)
                          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        else
                          Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            color: Colors.grey, size: 20,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
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
            else
              ...videos.map((v) => _buildVideoTile(v, ch)),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  Widget _autoSettingIcon(IconData icon, Color color, bool enabled, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Icon(icon, size: 16, color: enabled ? color : Colors.grey.shade300),
    );
  }

  // ── 영상 타일 ──────────────────────────────────────────────────────────────
  Widget _buildVideoTile(YoutubeVideo video, YoutubeChannel ch) {
    // autoMemo가 켜져 있고 영상에 내용이 있을 때만 탭 가능
    final hasContent = video.isDone && (video.hasSummary || (video.transcriptText != null && video.transcriptText!.isNotEmpty));
    final canOpen = ch.autoMemo && hasContent;
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

class _ToggleChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _ToggleChip({
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

/// 탭 헤더 아이콘 (메모 + 빨간 배지)
class YoutubeTabIcon extends StatelessWidget {
  const YoutubeTabIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notes),
        Positioned(
          right: -5, bottom: -3,
          child: Container(
            width: 11, height: 11,
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            child: const Center(child: Icon(Icons.play_arrow, size: 8, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}

/// 스피드다이얼 아이콘 (메모 + 빨간 배지, 흰색)
class YoutubeSpeedDialIcon extends StatelessWidget {
  const YoutubeSpeedDialIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notes, size: 20, color: Colors.white),
        Positioned(
          right: -5, bottom: -4,
          child: Container(
            width: 12, height: 12,
            decoration: BoxDecoration(
              color: Colors.red, shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: const Center(child: Icon(Icons.play_arrow, size: 8, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}

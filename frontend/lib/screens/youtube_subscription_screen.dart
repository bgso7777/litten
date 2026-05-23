import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/youtube_channel.dart';
import '../services/api_service.dart';
import '../services/youtube_transcript_service.dart';

class YoutubeSubscriptionScreen extends StatefulWidget {
  const YoutubeSubscriptionScreen({super.key});

  @override
  State<YoutubeSubscriptionScreen> createState() => _YoutubeSubscriptionScreenState();
}

class _YoutubeSubscriptionScreenState extends State<YoutubeSubscriptionScreen> {
  final _apiService = ApiService();
  final _channelIdController = TextEditingController();

  List<YoutubeChannel> _channels = [];
  bool _loading = true;
  String? _token;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    debugPrint('[YoutubeSubscriptionScreen] _init 진입');
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    debugPrint('[YoutubeSubscriptionScreen] token: ${_token != null ? "있음" : "없음"}');
    if (_token == null || _token!.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    await _loadChannels();
  }

  Future<void> _loadChannels() async {
    debugPrint('[YoutubeSubscriptionScreen] _loadChannels 진입');
    if (_token == null) return;
    setState(() => _loading = true);
    final channels = await _apiService.getYoutubeChannels(token: _token!);
    debugPrint('[YoutubeSubscriptionScreen] 채널 수: ${channels.length}');
    if (mounted) {
      setState(() {
        _channels = channels;
        _loading = false;
      });
    }
  }

  Future<void> _showAddChannelDialog() async {
    debugPrint('[YoutubeSubscriptionScreen] _showAddChannelDialog 진입');
    _channelIdController.clear();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('채널 구독 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '유튜브 채널 ID를 입력하세요.\n(예: UC1234567890abcdef)',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _channelIdController,
              decoration: const InputDecoration(
                hintText: 'UCxxxxxxxxxxxxxxxx',
                border: OutlineInputBorder(),
                labelText: '채널 ID',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _validateAndSubscribe(_channelIdController.text.trim());
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _validateAndSubscribe(String channelId) async {
    debugPrint('[YoutubeSubscriptionScreen] _validateAndSubscribe - channelId: $channelId');
    if (channelId.isEmpty) return;
    if (_token == null) return;

    // 로딩 다이얼로그 표시
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final info = await _apiService.getYoutubeChannelInfo(token: _token!, channelId: channelId);
    debugPrint('[YoutubeSubscriptionScreen] 채널 정보: $info');

    if (!mounted) return;
    Navigator.pop(context); // 로딩 닫기

    if (info == null) {
      _showError('채널을 찾을 수 없습니다.\n채널 ID를 확인해 주세요.');
      return;
    }

    final channelName = info['channelName'] ?? channelId;
    final channelThumbnail = info['channelThumbnail'] ?? '';

    // 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('채널 구독'),
        content: Text('"$channelName"\n\n이 채널을 구독하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('구독'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await _apiService.subscribeYoutubeChannel(
      token: _token!,
      channelId: channelId,
      channelName: channelName,
      channelThumbnail: channelThumbnail,
    );
    debugPrint('[YoutubeSubscriptionScreen] 구독 결과: ${result?.channelId}');

    if (!mounted) return;
    Navigator.pop(context); // 로딩 닫기

    if (result != null) {
      await _loadChannels();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$channelName" 구독이 완료되었습니다.')),
      );
    } else {
      _showError('구독 등록에 실패했습니다.');
    }
  }

  Future<void> _unsubscribe(YoutubeChannel channel) async {
    debugPrint('[YoutubeSubscriptionScreen] _unsubscribe - channelPk: ${channel.id}');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('구독 해제'),
        content: Text('"${channel.channelName}"\n\n구독을 해제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('해제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (_token == null) return;

    final ok = await _apiService.unsubscribeYoutubeChannel(token: _token!, channelPk: channel.id);
    debugPrint('[YoutubeSubscriptionScreen] 구독 해제 결과: $ok');
    if (ok && mounted) {
      await _loadChannels();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${channel.channelName}" 구독이 해제되었습니다.')),
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('오류'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _openVideos(YoutubeChannel channel) {
    debugPrint('[YoutubeSubscriptionScreen] _openVideos - channelId: ${channel.channelId}');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => YoutubeVideosScreen(channel: channel, token: _token!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('유튜브 구독'),
        actions: [
          if (_token != null && _token!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: '채널 추가',
              onPressed: _showAddChannelDialog,
            ),
        ],
      ),
      body: _buildBody(),
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
              Icon(Icons.lock_outline, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                '유튜브 구독 기능은 로그인이 필요합니다.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                '설정 > 계정 에서 로그인해 주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_channels.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.subscriptions_outlined, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                '구독 중인 채널이 없습니다.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                '오른쪽 위 + 버튼으로 채널 ID를 입력해 추가하세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChannels,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _channels.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) => _buildChannelTile(_channels[i]),
      ),
    );
  }

  Widget _buildChannelTile(YoutubeChannel channel) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.red.shade100,
        child: channel.channelThumbnail.isNotEmpty
            ? ClipOval(
                child: Image.network(
                  channel.channelThumbnail,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.play_circle_outline, color: Colors.red),
                ),
              )
            : const Icon(Icons.play_circle_outline, color: Colors.red),
      ),
      title: Text(channel.channelName, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(channel.channelId, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'videos') _openVideos(channel);
          if (v == 'unsubscribe') _unsubscribe(channel);
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'videos', child: Text('영상 요약 보기')),
          const PopupMenuItem(
            value: 'unsubscribe',
            child: Text('구독 해제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
      onTap: () => _openVideos(channel),
    );
  }

  @override
  void dispose() {
    _channelIdController.dispose();
    super.dispose();
  }
}

// ── 채널 영상 요약 목록 화면 ─────────────────────────────────────────────────

class YoutubeVideosScreen extends StatefulWidget {
  final YoutubeChannel channel;
  final String token;

  const YoutubeVideosScreen({super.key, required this.channel, required this.token});

  @override
  State<YoutubeVideosScreen> createState() => _YoutubeVideosScreenState();
}

class _YoutubeVideosScreenState extends State<YoutubeVideosScreen> {
  final _apiService = ApiService();
  List<YoutubeVideo> _videos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    debugPrint('[YoutubeVideosScreen] _loadVideos 진입 - channelId: ${widget.channel.channelId}');
    setState(() => _loading = true);
    final result = await _apiService.getYoutubeVideos(token: widget.token, channelId: widget.channel.channelId);
    debugPrint('[YoutubeVideosScreen] 영상 수: ${result.videos.length}');
    if (mounted) {
      setState(() {
        _videos = result.videos;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.channel.channelName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVideos,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_videos.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.video_library_outlined, size: 56, color: Colors.grey),
              SizedBox(height: 16),
              Text('아직 처리된 영상이 없습니다.', style: TextStyle(fontSize: 16)),
              SizedBox(height: 8),
              Text(
                '새 영상이 업로드되면 자동으로 요약됩니다.\n(5분마다 확인)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVideos,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _videos.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) => _buildVideoTile(_videos[i]),
      ),
    );
  }

  Widget _buildVideoTile(YoutubeVideo video) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (video.isDone) {
      statusColor = Colors.green;
      statusLabel = '자막 있음';
      statusIcon = Icons.check_circle_outline;
    } else if (video.hasNoTranscript) {
      statusColor = Colors.orange;
      statusLabel = '자막 없음';
      statusIcon = Icons.closed_caption_disabled;
    } else {
      statusColor = Colors.blue;
      statusLabel = '수집 대기';
      statusIcon = Icons.hourglass_top;
    }

    return ListTile(
      leading: Icon(statusIcon, color: statusColor, size: 28),
      title: Text(
        video.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (video.publishedAt != null)
            Text(
              _formatDate(video.publishedAt!),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          Row(
            children: [
              Icon(statusIcon, size: 12, color: statusColor),
              const SizedBox(width: 4),
              Text(statusLabel, style: TextStyle(fontSize: 12, color: statusColor)),
            ],
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openVideoDetail(video),
    );
  }

  void _openVideoDetail(YoutubeVideo video) {
    debugPrint('[YoutubeVideosScreen] _openVideoDetail - videoId: ${video.videoId}');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => YoutubeVideoDetailScreen(video: video, token: widget.token),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

// ── 영상 자막 상세 화면 ──────────────────────────────────────────────────────

class YoutubeVideoDetailScreen extends StatefulWidget {
  final YoutubeVideo video;
  final String token;

  const YoutubeVideoDetailScreen({super.key, required this.video, required this.token});

  @override
  State<YoutubeVideoDetailScreen> createState() => _YoutubeVideoDetailScreenState();
}

class _YoutubeVideoDetailScreenState extends State<YoutubeVideoDetailScreen> {
  final _apiService = ApiService();
  final _transcriptService = YoutubeTranscriptService();

  YoutubeVideo? _video;
  bool _loading = true;
  bool _fetching = false;   // YouTube에서 직접 수집 중
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  /// 서버에서 최신 영상 상세(자막 포함) 조회 후, 자막 없으면 폰에서 직접 수집.
  Future<void> _loadDetail() async {
    debugPrint('[YoutubeVideoDetailScreen] _loadDetail - videoId: ${widget.video.videoId}');
    setState(() { _loading = true; _errorMsg = null; });

    // 서버에서 자막 포함 전체 데이터 조회
    final detail = await _apiService.getYoutubeVideoDetail(
      token: widget.token,
      videoId: widget.video.id,
    );
    final current = detail ?? widget.video;

    if (!mounted) return;

    if (current.hasTranscript) {
      setState(() { _video = current; _loading = false; });
      return;
    }

    // 자막 없으면 폰에서 YouTube 직접 수집
    setState(() { _video = current; _loading = false; _fetching = true; });
    await _fetchFromYoutube(current);
  }

  Future<void> _fetchFromYoutube(YoutubeVideo video) async {
    debugPrint('[YoutubeVideoDetailScreen] YouTube 직접 수집 시작 - videoId: ${video.videoId}');
    setState(() { _fetching = true; _errorMsg = null; });

    final transcript = await _transcriptService.fetchTranscript(video.videoId);

    if (!mounted) return;

    if (transcript == null || transcript.isEmpty) {
      setState(() {
        _fetching = false;
        _errorMsg = '자막을 가져올 수 없습니다.\n이 영상은 자막이 제공되지 않을 수 있습니다.';
      });
      debugPrint('[YoutubeVideoDetailScreen] 자막 수집 실패 - videoId: ${video.videoId}');
      return;
    }

    // 화면에 반영
    setState(() {
      _video = YoutubeVideo(
        id: video.id,
        channelId: video.channelId,
        videoId: video.videoId,
        title: video.title,
        publishedAt: video.publishedAt,
        transcriptText: transcript,
        summary: video.summary,
        status: 'done',
      );
      _fetching = false;
    });

    // 서버에 저장 (백그라운드, 실패해도 화면은 유지)
    final saved = await _apiService.saveYoutubeTranscript(
      token: widget.token,
      videoId: video.videoId,
      transcript: transcript,
    );
    debugPrint('[YoutubeVideoDetailScreen] 서버 저장 결과 - videoId: ${video.videoId}, saved: $saved');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('영상 자막'),
        actions: [
          if (_video != null && !_fetching)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '자막 다시 수집',
              onPressed: () => _fetchFromYoutube(_video!),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final video = _video ?? widget.video;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            video.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (video.publishedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              _formatDate(video.publishedAt!),
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showUrl(context, video.youtubeUrl),
            icon: const Icon(Icons.play_circle_outline, color: Colors.red),
            label: const Text('유튜브에서 보기'),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            '자막',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (_fetching)
            const Row(
              children: [
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Text('YouTube에서 자막 수집 중...', style: TextStyle(color: Colors.grey)),
              ],
            )
          else if (_errorMsg != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_errorMsg!, style: const TextStyle(color: Colors.orange)),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => _fetchFromYoutube(video),
                  child: const Text('다시 시도'),
                ),
              ],
            )
          else if (video.hasTranscript)
            Text(
              video.transcriptText!,
              style: const TextStyle(fontSize: 15, height: 1.6),
            )
          else
            const Text('자막 내용이 없습니다.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  void _showUrl(BuildContext context, String url) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(url), action: SnackBarAction(label: '닫기', onPressed: () {})),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

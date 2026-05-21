import 'dart:async';
import 'package:flutter/material.dart';
import '../models/youtube_channel.dart';

/// 영상 제목 탭 시 표시되는 상세 팝업
/// 상단: 채널명, 제목, 일시
/// 하단: 내용 (요약 또는 전사, 없으면 안내)
class YoutubeVideoDetailDialog extends StatefulWidget {
  final String channelName;
  final YoutubeVideo video;
  final Map<int, YoutubeVideo> detailCache;
  final Set<int> loadingSet;

  const YoutubeVideoDetailDialog({
    super.key,
    required this.channelName,
    required this.video,
    required this.detailCache,
    required this.loadingSet,
  });

  @override
  State<YoutubeVideoDetailDialog> createState() => _YoutubeVideoDetailDialogState();
}

class _YoutubeVideoDetailDialogState extends State<YoutubeVideoDetailDialog> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    if (!widget.detailCache.containsKey(widget.video.id)) {
      _pollTimer = Timer.periodic(const Duration(milliseconds: 400), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        if (widget.detailCache.containsKey(widget.video.id)) {
          setState(() {});
          t.cancel();
        }
      });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    final detail = widget.detailCache[video.id];
    final isLoading = widget.loadingSet.contains(video.id);

    Widget body;
    if (isLoading && detail == null) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (detail == null) {
      body = const Text('내용을 불러올 수 없습니다.', style: TextStyle(color: Colors.grey, fontSize: 14));
    } else if (detail.hasSummary) {
      body = Text(detail.summary!, style: const TextStyle(fontSize: 14, height: 1.65));
    } else if (detail.transcriptText != null && detail.transcriptText!.isNotEmpty) {
      body = Text(detail.transcriptText!, style: const TextStyle(fontSize: 14, height: 1.65));
    } else {
      body = const Text('내용이 없습니다.', style: TextStyle(color: Colors.grey, fontSize: 14));
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.play_circle_outline, color: Colors.red, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.channelName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    video.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                  if (video.publishedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(video.publishedAt!),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  body,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

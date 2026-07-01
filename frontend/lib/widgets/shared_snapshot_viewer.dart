import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../services/shared_snapshot_service.dart';

/// 공유 스냅샷(보관된 공유 파일)을 타입별로 미리보기.
/// 채팅 말풍선의 '공유 내용 보기'에서 호출한다.
Future<void> showSharedSnapshot(BuildContext context, SharedSnapshot snap) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _SnapshotSheet(snap: snap),
  );
}

class _SnapshotSheet extends StatelessWidget {
  final SharedSnapshot snap;
  const _SnapshotSheet({required this.snap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    final title = snap.fileName;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
            child: Row(
              children: [
                Icon(_iconFor(snap.fileType), color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      Text(
                        '${snap.direction == 'sent' ? '보낸 공유' : '받은 공유'} · ${_fmt(snap.sharedAt)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
          if (snap.message != null && snap.message!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('"${snap.message!.trim()}"',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
              ),
            ),
          const Divider(height: 1),
          Expanded(child: _body(context, scrollCtrl, color)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, ScrollController scrollCtrl, Color color) {
    final file = File(snap.path);
    if (!file.existsSync()) {
      return _centerMsg('보관된 파일을 찾을 수 없습니다.', color);
    }
    final ext = _ext(snap);

    // 텍스트(HTML)
    if (snap.fileType == 'text' || snap.fileType == 'stt_text' || ext == '.html' || ext == '.htm') {
      return _HtmlView(file: file);
    }
    // 이미지
    if (_isImage(ext)) {
      return InteractiveViewer(
        child: Center(child: Image.file(file, fit: BoxFit.contain)),
      );
    }
    // PDF
    if (ext == '.pdf') {
      return SfPdfViewer.file(file);
    }
    // 오디오
    if (snap.fileType == 'audio' || snap.fileType == 'stt_audio' || _isAudio(ext)) {
      return _AudioView(path: snap.path, fileName: snap.fileName);
    }
    // 그 외 — 미리보기 미지원
    return _centerMsg(
        '이 형식(${ext.isEmpty ? snap.fileType : ext})은 앱 내 미리보기를 지원하지 않습니다.\n'
        '파일은 안전하게 보관되어 있습니다.',
        color);
  }

  Widget _centerMsg(String msg, Color color) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.folder_zip_outlined, size: 40, color: color.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text(msg,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          ]),
        ),
      );

  String _ext(SharedSnapshot s) {
    final name = s.path.isNotEmpty ? s.path : s.fileName;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(dot).toLowerCase() : '';
  }

  bool _isImage(String ext) =>
      ext == '.png' || ext == '.jpg' || ext == '.jpeg' || ext == '.gif' || ext == '.webp' || ext == '.bmp';
  bool _isAudio(String ext) =>
      ext == '.m4a' || ext == '.mp3' || ext == '.wav' || ext == '.aac' || ext == '.ogg';

  IconData _iconFor(String fileType) {
    switch (fileType) {
      case 'text':
      case 'stt_text':
        return Icons.notes;
      case 'audio':
      case 'stt_audio':
        return Icons.mic;
      case 'handwriting':
        return Icons.draw;
      default:
        return Icons.attach_file;
    }
  }

  String _fmt(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final l = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}.${two(l.month)}.${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }
}

/// HTML(텍스트) 미리보기 — webview로 렌더링.
class _HtmlView extends StatefulWidget {
  final File file;
  const _HtmlView({required this.file});
  @override
  State<_HtmlView> createState() => _HtmlViewState();
}

class _HtmlViewState extends State<_HtmlView> {
  WebViewController? _controller;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final html = await widget.file.readAsString();
      // 모바일 가독성을 위해 뷰포트/여백 래핑.
      final wrapped = '''
<!DOCTYPE html><html><head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>body{margin:14px;font-size:16px;line-height:1.6;word-break:break-word;}img{max-width:100%;height:auto;}</style>
</head><body>$html</body></html>''';
      final c = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.disabled)
        ..loadHtmlString(wrapped);
      if (mounted) setState(() => _controller = c);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return const Center(child: Text('내용을 불러오지 못했습니다.'));
    }
    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return WebViewWidget(controller: _controller!);
  }
}

/// 오디오 미리보기 — 재생/일시정지 + 진행바.
class _AudioView extends StatefulWidget {
  final String path;
  final String fileName;
  const _AudioView({required this.path, required this.fileName});
  @override
  State<_AudioView> createState() => _AudioViewState();
}

class _AudioViewState extends State<_AudioView> {
  final AudioPlayer _player = AudioPlayer();
  Duration _dur = Duration.zero;
  Duration _pos = Duration.zero;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _dur = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _pos = Duration.zero;
        });
      }
    });
    _player.setSourceDeviceFile(widget.path);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
    } else {
      await _player.play(DeviceFileSource(widget.path));
      if (mounted) setState(() => _playing = true);
    }
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    final max = _dur.inMilliseconds.toDouble();
    final val = _pos.inMilliseconds.clamp(0, _dur.inMilliseconds).toDouble();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.audiotrack, size: 56, color: color.withValues(alpha: 0.7)),
          const SizedBox(height: 12),
          Text(widget.fileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 20),
          Slider(
            value: max > 0 ? val : 0,
            max: max > 0 ? max : 1,
            onChanged: max > 0
                ? (v) => _player.seek(Duration(milliseconds: v.toInt()))
                : null,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(_pos), style: const TextStyle(fontSize: 12)),
              Text(_fmt(_dur), style: const TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          IconButton(
            iconSize: 56,
            color: color,
            icon: Icon(_playing ? Icons.pause_circle_filled : Icons.play_circle_filled),
            onPressed: _toggle,
          ),
        ],
      ),
    );
  }
}

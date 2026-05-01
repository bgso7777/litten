import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/app_state_provider.dart';
import '../services/audio_service.dart';
import '../models/text_file.dart';
import '../models/handwriting_file.dart';
import '../models/audio_file.dart';
import 'text_tab.dart';
import 'handwriting_tab.dart';

/// 텍스트 · 필기 · 녹음 파일을 하나의 탭에서 모두 보여주는 통합 뷰
class AllFilesTab extends StatefulWidget {
  const AllFilesTab({super.key});

  @override
  State<AllFilesTab> createState() => _AllFilesTabState();
}

class _AllFilesTabState extends State<AllFilesTab> {
  List<TextFile> _textFiles = [];
  List<HandwritingFile> _pdfFiles = [];
  List<HandwritingFile> _canvasFiles = [];
  List<AudioFile> _audioFiles = [];
  bool _loading = false;
  String? _activeLittenId = '__init__';

  // 현재 전체화면으로 열린 에디터
  _EditorType? _openEditor;
  HandwritingInitialAction _handwritingAction = HandwritingInitialAction.none;
  bool _autoCreate = false;

  // 인라인 녹음 상태
  final AudioService _audioService = AudioService();
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

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
      final selectedId = appState.selectedLitten?.id;
      final allFiles = await appState.getAllFiles();

      final List<TextFile> textFiles = [];
      final List<HandwritingFile> hwFiles = [];
      final List<AudioFile> audioFiles = [];

      for (final f in allFiles) {
        if (selectedId != null && f['littenId'] != selectedId) continue;
        final type = f['type'] as String;
        if (type == 'text') textFiles.add(f['file'] as TextFile);
        else if (type == 'handwriting') hwFiles.add(f['file'] as HandwritingFile);
        else if (type == 'audio') audioFiles.add(f['file'] as AudioFile);
      }

      if (mounted) {
        setState(() {
          _textFiles = textFiles;
          _pdfFiles = hwFiles.where((f) => f.type == HandwritingType.pdfConvert).toList();
          _canvasFiles = hwFiles.where((f) => f.type == HandwritingType.drawing).toList();
          _audioFiles = audioFiles;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [AllFilesTab] 파일 로드 실패: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openEditorView(_EditorType type, {
    HandwritingInitialAction action = HandwritingInitialAction.none,
    bool autoCreate = false,
  }) {
    setState(() {
      _openEditor = type;
      _handwritingAction = action;
      _autoCreate = autoCreate;
    });
  }

  void _closeEditor() {
    setState(() => _openEditor = null);
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    _loadFiles(appState);
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final litten = appState.selectedLitten;
    if (litten == null) return;

    if (_isRecording) {
      _recordingTimer?.cancel();
      await _audioService.stopRecording(litten);
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordingDuration = Duration.zero;
        });
        _loadFiles(appState);
      }
    } else {
      final success = await _audioService.startRecording(litten);
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
        if (littenId != _activeLittenId) {
          _activeLittenId = littenId;
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadFiles(appState));
        }

        // 에디터가 열려있으면 전체 화면으로 표시
        if (_openEditor != null) {
          return _buildEditorView(appState);
        }

        return Stack(
          children: [
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              _buildFileList(),
            Positioned(
              bottom: _isRecording ? 48 : 16,
              left: 0,
              right: 0,
              child: _BottomFabRow(
                onText: () => _openEditorView(_EditorType.text, autoCreate: true),
                onPdf: () => _openEditorView(_EditorType.handwriting, action: HandwritingInitialAction.loadPdf),
                onCanvas: () => _openEditorView(_EditorType.handwriting, action: HandwritingInitialAction.createCanvas),
                onAudio: _toggleRecording,
                isRecording: _isRecording,
              ),
            ),
            if (_isRecording)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _RecordingStatusBar(duration: _recordingDuration),
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
          key: ValueKey(_autoCreate),
          autoCreate: _autoCreate,
          onClose: _closeEditor,
        );
      case _EditorType.handwriting:
        return HandwritingTab(
          key: ValueKey(_handwritingAction),
          initialAction: _handwritingAction,
          onClose: _closeEditor,
        );
    }
  }

  Widget _buildFileList() {
    final hasAny = _textFiles.isNotEmpty || _pdfFiles.isNotEmpty || _canvasFiles.isNotEmpty || _audioFiles.isNotEmpty;
    if (!hasAny) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('파일이 없습니다.\n위 버튼으로 추가하세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        if (_textFiles.isNotEmpty) ...[
          _SectionHeader(icon: Icons.keyboard, title: '텍스트쓰기', count: _textFiles.length),
          ..._textFiles.map((f) => _TextFileItem(file: f, onTap: () => _openEditorView(_EditorType.text))),
        ],
        if (_pdfFiles.isNotEmpty) ...[
          _SectionHeader(icon: Icons.picture_as_pdf, title: 'PDF필기', count: _pdfFiles.length),
          ..._pdfFiles.map((f) => _HwFileItem(file: f, onTap: () => _openEditorView(_EditorType.handwriting))),
        ],
        if (_canvasFiles.isNotEmpty) ...[
          _SectionHeader(icon: Icons.draw, title: '캔버스필기', count: _canvasFiles.length),
          ..._canvasFiles.map((f) => _HwFileItem(file: f, onTap: () => _openEditorView(_EditorType.handwriting))),
        ],
        if (_audioFiles.isNotEmpty) ...[
          _SectionHeader(icon: Icons.mic, title: '녹음', count: _audioFiles.length),
          ..._audioFiles.map((f) => _AudioFileItem(file: f, onTap: () {})),
        ],
      ],
    );
  }
}

enum _EditorType { text, handwriting }

// ───────────────────────────── 하단 FAB 버튼 행 ─────────────────────────────

class _BottomFabRow extends StatelessWidget {
  final VoidCallback onText;
  final VoidCallback onPdf;
  final VoidCallback onCanvas;
  final VoidCallback onAudio;
  final bool isRecording;

  const _BottomFabRow({
    required this.onText,
    required this.onPdf,
    required this.onCanvas,
    required this.onAudio,
    this.isRecording = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _FabBtn(icon: Icons.keyboard, color: color, onTap: onText),
        const SizedBox(width: 12),
        _FabBtn(icon: Icons.picture_as_pdf, color: color, onTap: onPdf),
        const SizedBox(width: 12),
        _FabBtn(icon: Icons.draw, color: color, onTap: onCanvas),
        const SizedBox(width: 12),
        if (isRecording)
          FloatingActionButton(
            heroTag: 'stop_recording',
            onPressed: onAudio,
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            mini: true,
            child: const Icon(Icons.stop, size: 20),
          )
        else
          _FabBtn(icon: Icons.mic, color: color, onTap: onAudio),
      ],
    );
  }
}

class _FabBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FabBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: icon.codePoint.toString(),
      onPressed: onTap,
      backgroundColor: color,
      foregroundColor: Colors.white,
      mini: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 2),
          const Icon(Icons.add, size: 16),
        ],
      ),
    );
  }
}

// ───────────────────────────── 섹션 헤더 ─────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;

  const _SectionHeader({required this.icon, required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Theme.of(context).primaryColor),
          const SizedBox(width: 6),
          Text(title,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor)),
          const SizedBox(width: 4),
          Text('$count', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
      ),
    );
  }
}

// ───────────────────────────── 파일 아이템들 ─────────────────────────────

class _TextFileItem extends StatelessWidget {
  final TextFile file;
  final VoidCallback onTap;

  const _TextFileItem({required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.text_snippet, size: 20),
      title: Text(file.title, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        DateFormat('MM/dd HH:mm').format(file.updatedAt),
        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
      ),
      onTap: onTap,
    );
  }
}

class _HwFileItem extends StatelessWidget {
  final HandwritingFile file;
  final VoidCallback onTap;

  const _HwFileItem({required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(
        file.type == HandwritingType.pdfConvert ? Icons.picture_as_pdf : Icons.draw,
        size: 20,
      ),
      title: Text(file.displayTitle, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${DateFormat('MM/dd HH:mm').format(file.updatedAt)}${file.isMultiPage ? '  •  ${file.pageInfo}' : ''}',
        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
      ),
      onTap: onTap,
    );
  }
}

class _AudioFileItem extends StatelessWidget {
  final AudioFile file;
  final VoidCallback onTap;

  const _AudioFileItem({required this.file, required this.onTap});

  String _formatDuration(Duration? d) {
    if (d == null) return '';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.audio_file, size: 20),
      title: Text(file.fileName, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${DateFormat('MM/dd HH:mm').format(file.createdAt)}${file.duration != null ? '  •  ${_formatDuration(file.duration)}' : ''}',
        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
      ),
      onTap: onTap,
    );
  }
}

// ───────────────────────────── 탭 버튼 위젯 ─────────────────────────────

/// DraggableTabLayout 탭 버튼에 표시할 일정명 + 3개 아이콘 + 파일수 위젯
class AllFilesTabButton extends StatelessWidget {
  final int textCount;
  final int handwritingCount;
  final int audioCount;
  final String? littenTitle;

  const AllFilesTabButton({
    super.key,
    required this.textCount,
    required this.handwritingCount,
    required this.audioCount,
    this.littenTitle,
    bool isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayTitle = (littenTitle == null || littenTitle == 'undefined') ? '' : littenTitle!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (displayTitle.isNotEmpty) ...[
          Text(displayTitle, overflow: TextOverflow.ellipsis),
          const SizedBox(width: 6),
        ],
        _iconCount(Icons.keyboard, textCount),
        const SizedBox(width: 6),
        _iconCount(Icons.draw, handwritingCount),
        const SizedBox(width: 6),
        _iconCount(Icons.mic, audioCount),
      ],
    );
  }

  Widget _iconCount(IconData icon, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon),
        const SizedBox(width: 2),
        Text(count.toString()),
      ],
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
          const Icon(Icons.mic, size: 16, color: Colors.red),
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

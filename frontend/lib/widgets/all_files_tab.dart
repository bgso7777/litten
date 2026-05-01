import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/app_state_provider.dart';
import '../services/audio_service.dart';
import '../services/file_storage_service.dart';
import '../services/litten_service.dart';
import '../models/text_file.dart';
import '../models/handwriting_file.dart';
import '../models/audio_file.dart';
import 'text_tab.dart';
import 'handwriting_tab.dart';

// ───────────────────────────── 파일 타입 통합 래퍼 ─────────────────────────────

enum _FileType { text, handwriting, audio }

class _MergedFile {
  final _FileType type;
  final dynamic file; // TextFile | HandwritingFile | AudioFile
  final DateTime createdAt;
  _MergedFile({required this.type, required this.file, required this.createdAt});
}

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

  // 인라인 녹음 / 재생 상태
  final AudioService _audioService = AudioService();
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  // 병합 정렬 파일 목록 (createdAt 내림차순)
  List<_MergedFile> get _mergedFiles {
    final list = <_MergedFile>[
      ..._textFiles.map((f) => _MergedFile(type: _FileType.text, file: f, createdAt: f.createdAt)),
      ..._pdfFiles.map((f) => _MergedFile(type: _FileType.handwriting, file: f, createdAt: f.createdAt)),
      ..._canvasFiles.map((f) => _MergedFile(type: _FileType.handwriting, file: f, createdAt: f.createdAt)),
      ..._audioFiles.map((f) => _MergedFile(type: _FileType.audio, file: f, createdAt: f.createdAt)),
    ];
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  void initState() {
    super.initState();
    _audioService.addListener(_onAudioStateChanged);
  }

  void _onAudioStateChanged() {
    if (mounted) setState(() {});
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
    final merged = _mergedFiles;
    if (merged.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('파일이 없습니다.\n아래 버튼으로 추가하세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: merged.length,
      itemBuilder: (context, index) {
        final entry = merged[index];
        switch (entry.type) {
          case _FileType.text:
            return _buildTextCard(entry.file as TextFile);
          case _FileType.handwriting:
            return _buildHandwritingCard(entry.file as HandwritingFile);
          case _FileType.audio:
            return _buildAudioCard(entry.file as AudioFile);
        }
      },
    );
  }

  // ── 텍스트 카드 ──
  Widget _buildTextCard(TextFile file) {
    final color = Theme.of(context).primaryColor;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(Icons.keyboard, color: color),
        ),
        title: Text(
          file.title.isNotEmpty
              ? file.title
              : '텍스트 ${DateFormat('yyMMddHHmm').format(file.createdAt)}',
          style: const TextStyle(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('${file.characterCount}자',
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(file.updatedAt.toString().substring(0, 16),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: color),
            onPressed: () => _showRenameTextDialog(file),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: color),
            onPressed: () => _showDeleteDialog(file.displayTitle, () => _deleteTextFile(file)),
          ),
        ]),
        onTap: () => _openEditorView(_EditorType.text),
      ),
    );
  }

  // ── 필기 카드 ──
  Widget _buildHandwritingCard(HandwritingFile file) {
    final color = Theme.of(context).primaryColor;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(
            file.type == HandwritingType.pdfConvert ? Icons.picture_as_pdf : Icons.draw,
            color: color,
          ),
        ),
        title: Text(
          file.displayTitle,
          style: const TextStyle(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(children: [
          if (file.isMultiPage) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${file.totalPages}페이지',
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(file.updatedAt.toString().substring(0, 16),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: color),
            onPressed: () => _showRenameHandwritingDialog(file),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: color),
            onPressed: () => _showDeleteDialog(file.displayTitle, () => _deleteHandwritingFile(file)),
          ),
        ]),
        onTap: () => _openEditorView(_EditorType.handwriting),
      ),
    );
  }

  // ── 녹음 카드 ──
  Widget _buildAudioCard(AudioFile file) {
    final color = Theme.of(context).primaryColor;
    final isCurrentPlaying = _audioService.currentPlayingFile?.id == file.id;
    final isPlaying = isCurrentPlaying && _audioService.isPlaying;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPlaying ? Colors.blue : color.withValues(alpha: 0.1),
          child: Icon(
            isPlaying ? Icons.pause : Icons.play_arrow,
            color: isPlaying ? Colors.white : color,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              file.fileName,
              style: TextStyle(fontWeight: isCurrentPlaying ? FontWeight.bold : FontWeight.normal),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '생성: ${file.createdAt.month}/${file.createdAt.day} ${file.createdAt.hour}:${file.createdAt.minute.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (isCurrentPlaying) ...[
              const SizedBox(height: 8),
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
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: color),
            onPressed: () => _showRenameAudioDialog(file),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: color),
            onPressed: () => _showDeleteDialog(file.fileName, () => _deleteAudioFile(file)),
          ),
        ]),
        onTap: () => _playAudio(file),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('파일 삭제'),
        content: Text('"$name"을(를) 삭제하시겠습니까?\n이 작업은 취소할 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () { Navigator.pop(ctx); onConfirm(); },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  // ── 텍스트 이름 변경 ──
  void _showRenameTextDialog(TextFile file) {
    final controller = TextEditingController(text: file.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이름 변경'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: '파일 이름')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                Navigator.pop(ctx);
                await _renameTextFile(file, newTitle);
              }
            },
            child: const Text('확인'),
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
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      await appState.updateFileCount();
      await _loadFiles(appState);
    } catch (e) {
      debugPrint('❌ [AllFilesTab] 텍스트 삭제 실패: $e');
    }
  }

  // ── 필기 이름 변경 ──
  void _showRenameHandwritingDialog(HandwritingFile file) {
    final controller = TextEditingController(text: file.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이름 변경'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: '파일 이름')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                Navigator.pop(ctx);
                await _renameHandwritingFile(file, newTitle);
              }
            },
            child: const Text('확인'),
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
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      await appState.updateFileCount();
      await _loadFiles(appState);
    } catch (e) {
      debugPrint('❌ [AllFilesTab] 필기 삭제 실패: $e');
    }
  }

  // ── 녹음 이름 변경 ──
  void _showRenameAudioDialog(AudioFile file) {
    final controller = TextEditingController(text: file.fileName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이름 변경'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: '파일 이름')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                Navigator.pop(ctx);
                await _renameAudioFile(file, newName);
              }
            },
            child: const Text('확인'),
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/app_state_provider.dart';
import '../services/audio_service.dart';
import '../services/file_storage_service.dart';
import '../services/litten_service.dart';
import '../services/sync_service.dart';
import '../models/text_file.dart';
import '../models/handwriting_file.dart';
import '../models/audio_file.dart';
import 'text_tab.dart';
import 'handwriting_tab.dart';
import 'dialogs/summary_dialog.dart';
import 'dialogs/stt_memo_settings_dialog.dart';

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
  int _lastFileListVersion = 0; // ⭐ 마지막으로 로드한 파일 목록 버전

  // 현재 전체화면으로 열린 에디터
  _EditorType? _openEditor;
  HandwritingInitialAction _handwritingAction = HandwritingInitialAction.none;
  bool _autoCreate = false;
  TextFile? _selectedTextFile; // ⭐ 선택된 텍스트 파일
  HandwritingFile? _selectedHandwritingFile; // ⭐ 선택된 필기 파일

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
      // 외부에서 녹음 종료
      _recordingTimer?.cancel();
      _recordingDuration = Duration.zero;
      debugPrint('🔄 [AllFilesTab] 외부 녹음 종료 감지');
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
  }) {
    setState(() {
      _openEditor = type;
      _handwritingAction = action;
      _autoCreate = autoCreate;
      _autoStartSTT = autoStartSTT;
      _selectedTextFile = textFile;
      _selectedHandwritingFile = handwritingFile;
      _sttMemoSettings = sttSettings;
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
      final audioFile = await _audioService.stopRecording(litten);
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordingDuration = Duration.zero;
        });
        _loadFiles(appState);
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
        final currentFileListVersion = appState.fileListVersion;

        // 리튼 ID가 변경되었거나 파일 목록 버전이 변경된 경우 파일 목록 새로고침
        if (littenId != _activeLittenId || currentFileListVersion != _lastFileListVersion) {
          _activeLittenId = littenId;
          _lastFileListVersion = currentFileListVersion;
          debugPrint('🔄 [AllFilesTab] 파일 목록 새로고침 - 리튼: $littenId, 버전: $currentFileListVersion');
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadFiles(appState));
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
                  Positioned(
                    bottom: 28, // ⭐ 애니메이션 시 아래로 쳐지지 않도록 더 위로 올림
                    left: 0,
                    right: 0,
                    child: _BottomFabRow(
                      onText: () => _openEditorView(_EditorType.text, autoCreate: true),
                      onTextWithSTT: () => _openEditorView(_EditorType.text, autoCreate: true, autoStartSTT: true),
                      onPdf: () => _openEditorView(_EditorType.handwriting, action: HandwritingInitialAction.loadPdf),
                      onCanvas: () => _openEditorView(_EditorType.handwriting, action: HandwritingInitialAction.createCanvas),
                      onAudio: _toggleRecording,
                      isRecording: _isRecording,
                      recordingDuration: _recordingDuration,
                    ),
                  ),
                ],
              ),
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
        return HandwritingTab(
          key: ValueKey(_selectedHandwritingFile?.id ?? _handwritingAction),
          initialAction: _handwritingAction,
          onClose: _closeEditor,
          initialFile: _selectedHandwritingFile, // ⭐ 선택된 파일 전달
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

  // ── 클라우드 동기화 상태 아이콘 (trailing용, 툴팁 포함) ──
  Widget _buildSyncIcon(SyncStatus status, {DateTime? cloudUpdatedAt, DateTime? updatedAt}) {
    final isPremium = Provider.of<AppStateProvider>(context, listen: false).isPremiumPlusUser;
    if (!isPremium || status == SyncStatus.none) return const SizedBox.shrink();

    final timeStr = (cloudUpdatedAt ?? updatedAt)?.toString().substring(0, 16) ?? '';
    Widget icon;
    switch (status) {
      case SyncStatus.synced:
        icon = const Icon(Icons.cloud_done, size: 16, color: Colors.blue);
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
        return const SizedBox.shrink();
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
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -1),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        leading: SizedBox(
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
        title: Text(
          file.title.isNotEmpty
              ? file.title
              : '텍스트 ${DateFormat('yyMMddHHmm').format(file.createdAt)}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('${file.characterCount}자',
                style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
          ),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          _buildSyncIcon(file.syncStatus, cloudUpdatedAt: file.cloudUpdatedAt, updatedAt: file.updatedAt),
          IconButton(
            icon: Icon(
              Icons.auto_awesome,
              color: file.hasSummary ? color : Colors.grey.shade400,
              size: 16,
            ),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            padding: EdgeInsets.zero,
            tooltip: file.hasSummary ? '요약 보기' : '요약 없음',
            onPressed: () => _showSummaryDialog(file),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: color, size: 16),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            padding: EdgeInsets.zero,
            onPressed: () => _showRenameTextDialog(file),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: color, size: 16),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            padding: EdgeInsets.zero,
            onPressed: () => _showDeleteDialog(file.displayTitle, () => _deleteTextFile(file)),
          ),
        ]),
        onTap: () => _openEditorView(_EditorType.text, textFile: file),
      ),
    );
  }

  // ── 필기 카드 ──
  Widget _buildHandwritingCard(HandwritingFile file) {
    final color = Theme.of(context).primaryColor;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -1),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(
            file.type == HandwritingType.pdfConvert ? Icons.picture_as_pdf : Icons.draw,
            color: color,
            size: 18,
          ),
        ),
        title: Text(
          file.displayTitle,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: file.isMultiPage
            ? Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${file.totalPages}페이지',
                      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
                ),
              ])
            : null,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          _buildSyncIcon(file.syncStatus, cloudUpdatedAt: file.cloudUpdatedAt, updatedAt: file.updatedAt),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: color, size: 16),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            padding: EdgeInsets.zero,
            onPressed: () => _showRenameHandwritingDialog(file),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: color, size: 16),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            padding: EdgeInsets.zero,
            onPressed: () => _showDeleteDialog(file.displayTitle, () => _deleteHandwritingFile(file)),
          ),
        ]),
        onTap: () => _openEditorView(_EditorType.handwriting, handwritingFile: file),
      ),
    );
  }

  // ── 녹음 카드 ──
  Widget _buildAudioCard(AudioFile file) {
    final color = Theme.of(context).primaryColor;
    final isCurrentPlaying = _audioService.currentPlayingFile?.id == file.id;
    final isPlaying = isCurrentPlaying && _audioService.isPlaying;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -1),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        leading: SizedBox(
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
              if (file.isFromSTT)
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          _buildSyncIcon(file.syncStatus, cloudUpdatedAt: file.cloudUpdatedAt, updatedAt: file.updatedAt),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: color, size: 16),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            padding: EdgeInsets.zero,
            onPressed: () => _showRenameAudioDialog(file),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: color, size: 16),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            padding: EdgeInsets.zero,
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

    final result = await showDialog<SummaryResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SummaryDialog(file: file),
    );

    if (result == null || !mounted) return;

    debugPrint('✨ [AllFilesTab] 요약 결과 수신 - 파일에 추가 시작');
    await _appendSummaryToFile(file, result);
  }

  Future<void> _appendSummaryToFile(TextFile file, SummaryResult result) async {
    try {
      debugPrint('✨ [AllFilesTab] 파일 저장 시작 - 원본 content 길이: ${file.content.length}');

      // 요약을 HTML 단락으로 변환 (hr·이모지·인라인스타일 제거 → html_editor_enhanced 호환)
      final summaryLines = result.summary
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();

      final summaryHtml = summaryLines
          .map((line) => '<p>${_escapeHtmlText(line.trim())}</p>')
          .join('');

      final separator = '<p>- - - - - - - - - - - - - - -</p>';
      final header = '<p><strong>[AI 요약] ${result.summaryRatio}% | ${result.summaryLanguage}</strong></p>';

      final base = file.content.isEmpty ? '<p><br></p>' : file.content;
      final appendedContent = '$base$separator$header$summaryHtml';

      debugPrint('✨ [AllFilesTab] appendedContent 길이: ${appendedContent.length}');

      final updatedFile = file.copyWith(
        content: appendedContent,
        summary: result.summary,
      );

      // 스토리지 저장
      final storage = FileStorageService.instance;
      final allFiles = await storage.loadTextFiles(file.littenId);
      debugPrint('✨ [AllFilesTab] 기존 파일 수: ${allFiles.length}');

      final updated = allFiles.map((f) => f.id == file.id ? updatedFile : f).toList();
      final saved = await storage.saveTextFiles(file.littenId, updated);
      debugPrint('✨ [AllFilesTab] 저장 결과: $saved');

      if (!saved) {
        throw Exception('파일 저장 실패 (SharedPreferences 오류)');
      }

      // 파일 목록 새로고침
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      await _loadFiles(appState);

      debugPrint('✨ [AllFilesTab] 요약 저장 완료');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('요약이 파일에 추가되었습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [AllFilesTab] 요약 파일 저장 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('요약 저장 실패: $e')),
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
  final VoidCallback onPdf;
  final VoidCallback onCanvas;
  final VoidCallback onAudio;
  final bool isRecording;
  final Duration recordingDuration;

  const _BottomFabRow({
    required this.onText,
    required this.onTextWithSTT,
    required this.onPdf,
    required this.onCanvas,
    required this.onAudio,
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
    final recordColor = widget.isRecording ? Colors.red : color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isExpanded) ...[
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SpeedDialItem(label: '필기', icon: Icons.draw, color: color,
                        onTap: () => _handleAction(widget.onCanvas)),
                    const SizedBox(height: 8),
                    _SpeedDialItem(label: 'PDF', icon: Icons.picture_as_pdf, color: color,
                        onTap: () => _handleAction(widget.onPdf)),
                    const SizedBox(height: 8),
                    _SpeedDialItem(label: '메모', icon: Icons.notes, color: color,
                        onTap: () => _handleAction(widget.onText)),
                    const SizedBox(height: 8),
                    _SpeedDialItem(
                      label: widget.isRecording
                          ? '녹음중... ${_formatDuration(widget.recordingDuration)}'
                          : '녹음',
                      icon: widget.isRecording ? Icons.stop : Icons.mic,
                      color: recordColor,
                      onTap: widget.onAudio,
                    ),
                    const SizedBox(height: 8),
                    _SpeedDialItem(
                      label: '음성 메모',
                      icon: Icons.record_voice_over,
                      color: color,
                      onTap: () => _handleAction(widget.onTextWithSTT),
                    ),
                  ],
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
        Expanded(
          child: Material(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            elevation: 0,
            child: Padding(
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
        _iconCount(Icons.notes, textCount),
        const SizedBox(width: 8),
        _iconCount(Icons.draw, handwritingCount),
        const SizedBox(width: 8),
        _iconCount(Icons.mic, audioCount),
      ],
    );
  }

  Widget _iconCount(IconData icon, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon),
        const SizedBox(width: 5),
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

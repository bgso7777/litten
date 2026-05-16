import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
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
import 'dialogs/summary_dialog.dart';
import 'dialogs/stt_memo_settings_dialog.dart';
import '../models/remind_item.dart';
import '../utils/remind_parser.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// ───────────────────────────── 파일 타입 통합 래퍼 ─────────────────────────────

enum _FileType { text, handwriting, audio, attachment }

class _MergedFile {
  final _FileType type;
  final dynamic file; // TextFile | HandwritingFile | AudioFile | AttachmentFile
  final DateTime createdAt;
  _MergedFile({required this.type, required this.file, required this.createdAt});
}

/// 텍스트 · 필기 · 녹음 파일을 하나의 탭에서 모두 보여주는 통합 뷰
/// [showOnlySTT] = true 이면 음성메모(STT)로 생성된 파일만 표시
class AllFilesTab extends StatefulWidget {
  final bool showOnlySTT;
  const AllFilesTab({super.key, this.showOnlySTT = false});

  @override
  State<AllFilesTab> createState() => _AllFilesTabState();
}

class _AllFilesTabState extends State<AllFilesTab> {
  List<TextFile> _textFiles = [];
  List<HandwritingFile> _pdfFiles = [];
  List<HandwritingFile> _canvasFiles = [];
  List<AudioFile> _audioFiles = [];
  List<AttachmentFile> _attachmentFiles = [];
  bool _loading = false;
  String? _activeLittenId = '__init__';
  int _lastFileListVersion = 0; // ⭐ 마지막으로 로드한 파일 목록 버전

  // 현재 전체화면으로 열린 에디터
  _EditorType? _openEditor;
  HandwritingInitialAction _handwritingAction = HandwritingInitialAction.none;
  bool _autoCreate = false;
  TextFile? _selectedTextFile; // ⭐ 선택된 텍스트 파일
  HandwritingFile? _selectedHandwritingFile; // ⭐ 선택된 필기 파일
  String? _initialPdfPath; // ⭐ PDF 파일 경로 (파일 선택 후 전달)
  String? _initialPdfFileName; // ⭐ PDF 파일명

  // 인라인 녹음 / 재생 상태
  final AudioService _audioService = AudioService();
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  // 병합 정렬 파일 목록 (createdAt 내림차순)
  List<_MergedFile> get _mergedFiles {
    final textSrc = widget.showOnlySTT ? _textFiles.where((f) => f.isFromSTT).toList() : _textFiles;
    final audioSrc = widget.showOnlySTT ? _audioFiles.where((f) => f.isFromSTT).toList() : _audioFiles;
    final list = <_MergedFile>[
      ...textSrc.map((f) => _MergedFile(type: _FileType.text, file: f, createdAt: f.createdAt)),
      if (!widget.showOnlySTT) ...[
        ..._pdfFiles.map((f) => _MergedFile(type: _FileType.handwriting, file: f, createdAt: f.createdAt)),
        ..._canvasFiles.map((f) => _MergedFile(type: _FileType.handwriting, file: f, createdAt: f.createdAt)),
        ..._attachmentFiles.map((f) => _MergedFile(type: _FileType.attachment, file: f, createdAt: f.createdAt)),
      ],
      ...audioSrc.map((f) => _MergedFile(type: _FileType.audio, file: f, createdAt: f.createdAt)),
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
  }) {
    setState(() {
      _openEditor = type;
      _handwritingAction = action;
      _autoCreate = autoCreate;
      _autoStartSTT = autoStartSTT;
      _selectedTextFile = textFile;
      _selectedHandwritingFile = handwritingFile;
      _sttMemoSettings = sttSettings;
      _initialPdfPath = initialPdfPath;
      _initialPdfFileName = initialPdfFileName;
    });
  }

  void _closeEditor() {
    setState(() {
      _openEditor = null;
      _initialPdfPath = null;
      _initialPdfFileName = null;
    });
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
                    bottom: 28,
                    left: 0,
                    right: 0,
                    child: widget.showOnlySTT
                        ? _buildSttOnlyFab(color: Theme.of(context).primaryColor)
                        : _BottomFabRow(
                            onText: () => _openEditorView(_EditorType.text, autoCreate: true),
                            onTextWithSTT: () => _openEditorView(_EditorType.text, autoCreate: true, autoStartSTT: true),
                            onFiles: _addAttachmentFromFiles,
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
          key: ValueKey(_selectedHandwritingFile?.id ?? _initialPdfPath ?? _handwritingAction),
          initialAction: _handwritingAction,
          onClose: _closeEditor,
          initialFile: _selectedHandwritingFile,
          initialPdfPath: _initialPdfPath,
          initialPdfFileName: _initialPdfFileName,
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

  Widget _buildFileList() {
    final merged = _mergedFiles;
    if (merged.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.showOnlySTT ? Icons.record_voice_over : Icons.folder_open,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Builder(builder: (ctx) {
              final l10n = AppLocalizations.of(ctx);
              return Text(
                widget.showOnlySTT
                    ? (l10n?.noVoiceMemos ?? '음성 메모가 없습니다.\n아래 버튼으로 시작하세요.')
                    : (l10n?.noFilesPrompt ?? '파일이 없습니다.\n아래 버튼으로 추가하세요.'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500]),
              );
            }),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: merged.length,
      itemBuilder: (context, index) {
        final entry = merged[index];

        // ⭐ 일자가 바뀌면 구분선 헤더 표시
        final currentDate = DateTime(
          entry.createdAt.year,
          entry.createdAt.month,
          entry.createdAt.day,
        );
        final showDateHeader = index == 0 ||
            DateTime(
                  merged[index - 1].createdAt.year,
                  merged[index - 1].createdAt.month,
                  merged[index - 1].createdAt.day,
                ) !=
                currentDate;

        final card = switch (entry.type) {
          _FileType.text => _buildTextCard(entry.file as TextFile),
          _FileType.handwriting => _buildHandwritingCard(entry.file as HandwritingFile),
          _FileType.audio => _buildAudioCard(entry.file as AudioFile),
          _FileType.attachment => _buildAttachmentCard(entry.file as AttachmentFile),
        };

        if (showDateHeader) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateHeader(currentDate),
              card,
            ],
          );
        }
        return card;
      },
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
    required VoidCallback onEdit,
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
          if (value == 'edit') onEdit();
          else if (value == 'delete') onDelete();
        },
        itemBuilder: (ctx) {
          final l10n = AppLocalizations.of(ctx);
          return [
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
                          : '텍스트 ${DateFormat('yyMMddHHmm').format(file.createdAt)}',
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
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSyncIconUnified(file.syncStatus, cloudUpdatedAt: file.cloudUpdatedAt, updatedAt: file.updatedAt),
                    _iconBtn(
                      icon: Icons.auto_awesome,
                      color: file.hasSummary ? color : Colors.grey.shade400,
                      tooltip: file.hasSummary
                          ? (AppLocalizations.of(context)?.viewSummary ?? '요약 보기')
                          : (AppLocalizations.of(context)?.noSummary ?? '요약 없음'),
                      onPressed: () => _showSummaryDialog(file),
                    ),
                    _iconBtn(
                      icon: Icons.share_outlined,
                      color: color,
                      tooltip: AppLocalizations.of(context)?.share ?? '공유',
                      onPressed: () {},
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
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSyncIconUnified(file.syncStatus, cloudUpdatedAt: file.cloudUpdatedAt, updatedAt: file.updatedAt),
                    _iconBtn(
                      icon: Icons.auto_awesome,
                      color: Colors.grey.shade400,
                      tooltip: AppLocalizations.of(context)?.summaryUnsupported ?? '요약 미지원',
                      onPressed: () {},
                    ),
                    _iconBtn(
                      icon: Icons.share_outlined,
                      color: color,
                      tooltip: AppLocalizations.of(context)?.share ?? '공유',
                      onPressed: () {},
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
    try {
      // 1) 리튼의 handwriting 폴더로 PDF 원본 복사
      final docDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${docDir.path}/littens/${selectedLitten.id}/handwriting');
      if (!await dir.exists()) await dir.create(recursive: true);
      final titleWithoutExt = pdfName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');

      // 2) HandwritingFile 메타데이터 (imagePath = 절대 PDF 경로, 단일 파일)
      final newFile = HandwritingFile(
        littenId: selectedLitten.id,
        title: titleWithoutExt,
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

  // ── 첨부 파일 카드 ──
  Widget _buildAttachmentCard(AttachmentFile file) {
    final color = Theme.of(context).primaryColor;
    final ext = file.extension.toUpperCase();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: InkWell(
        onTap: () => _showAttachmentInfoSheet(file),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Leading 아이콘
              CircleAvatar(
                radius: 16,
                backgroundColor: color.withValues(alpha: 0.1),
                child: Icon(Icons.attach_file, color: color, size: 18),
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
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSyncIconUnified(file.syncStatus, cloudUpdatedAt: file.cloudUpdatedAt, updatedAt: file.updatedAt),
                    _iconBtn(
                      icon: Icons.auto_awesome,
                      color: Colors.grey.shade400,
                      tooltip: '분석 (미지원)',
                      onPressed: () {},
                    ),
                    _iconBtn(
                      icon: Icons.share_outlined,
                      color: color,
                      tooltip: AppLocalizations.of(context)?.share ?? '공유',
                      onPressed: () => _shareAttachment(file),
                    ),
                    _moreMenuBtn(
                      color: color,
                      onEdit: () => _shareAttachment(file),
                      onDelete: () => _showDeleteDialog(file.displayTitle, () => _deleteAttachment(file)),
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

  void _showAttachmentInfoSheet(AttachmentFile file) {
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
                  Icon(Icons.attach_file, color: Theme.of(context).primaryColor),
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('공유'),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _shareAttachment(file);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text('삭제', style: TextStyle(color: Colors.red)),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _showDeleteDialog(file.displayTitle, () => _deleteAttachment(file));
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSyncIconUnified(file.syncStatus, cloudUpdatedAt: file.cloudUpdatedAt, updatedAt: file.updatedAt),
                    _iconBtn(
                      icon: Icons.auto_awesome,
                      color: Colors.grey.shade400,
                      tooltip: AppLocalizations.of(context)?.summaryUnsupported ?? '요약 미지원',
                      onPressed: () {},
                    ),
                    _iconBtn(
                      icon: Icons.share_outlined,
                      color: color,
                      tooltip: '공유',
                      onPressed: () {},
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
      const levelNames = {1: '한줄 요약', 2: '간단 요약', 3: '일반 요약', 4: '상세 요약', 5: '거의 전체'};
      final levelName = levelNames[result.summaryLevel] ?? '일반 요약';
      final header = '<p><strong>[AI 요약] Lv.${result.summaryLevel} $levelName | ${result.summaryLanguage}</strong></p>';

      final base = file.content.isEmpty ? '<p><br></p>' : file.content;
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
      final newHistory = [newRecord, ...file.summaryHistory];

      final updatedFile = file.copyWith(
        content: appendedContent,
        summary: result.summary,
        summaryHistory: newHistory,
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

      // 리마인드 추출 및 저장 (요약 단위로 그룹화)
      final remindItems = RemindParser.parse(
        summaryText: result.summary,
        fileId: file.id,
        fileName: file.displayTitle,
        littenId: file.littenId,
        fileType: RemindFileType.text,
        summaryLevel: result.summaryLevel,
      );
      if (remindItems.isNotEmpty) {
        appState.addRemindItems(remindItems);
        debugPrint('✨ [AllFilesTab] 리마인드 ${remindItems.length}개 추가 완료');
      }

      debugPrint('✨ [AllFilesTab] 요약 저장 완료');

      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(remindItems.isNotEmpty
                ? (l10n?.summaryAddedWithRemind(remindItems.length) ?? '요약이 추가되었습니다. 리마인드 ${remindItems.length}개 생성')
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
  final bool isRecording;
  final Duration recordingDuration;

  const _BottomFabRow({
    required this.onText,
    required this.onTextWithSTT,
    required this.onFiles,
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
    final appState = Provider.of<AppStateProvider>(context);
    final fabVis = appState.allTabFabVisibility;

    final dialItems = <Widget>[];
    final l10n = AppLocalizations.of(context);
    // ⭐ 순서: 필기 → 메모 → 녹음 → 파일 → 음성메모
    if (fabVis.contains('canvas')) {
      dialItems.addAll([
        _SpeedDialItem(label: l10n?.handwritingTab ?? '필기', icon: Icons.draw, color: color,
            onTap: () => _handleAction(widget.onCanvas)),
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
    // ⭐ 파일: 임의의 파일 첨부 (PDF면 Syncfusion 에디터로 자동 분기)
    if (fabVis.contains('files')) {
      dialItems.addAll([
        _SpeedDialItem(label: '파일', icon: Icons.attach_file, color: color,
            onTap: () => _handleAction(widget.onFiles)),
        const SizedBox(height: 8),
      ]);
    }
    if (fabVis.contains('stt')) {
      dialItems.addAll([
        _SpeedDialItem(
          label: l10n?.voiceMemoLabel ?? '음성 메모',
          icon: Icons.record_voice_over,
          color: color,
          onTap: () => _handleAction(widget.onTextWithSTT),
        ),
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

// ───────────────────────────── 탭 버튼 위젯 ─────────────────────────────

/// DraggableTabLayout 탭 버튼에 표시할 일정명 + 3개 아이콘 + 파일수 위젯
class AllFilesTabButton extends StatelessWidget {
  final int textCount;
  final int canvasCount;
  final int pdfCount;
  final int audioCount;
  final int sttMemoCount;
  final String? littenTitle;

  const AllFilesTabButton({
    super.key,
    required this.textCount,
    required this.canvasCount,
    required this.pdfCount,
    required this.audioCount,
    required this.sttMemoCount,
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
        void maybeAdd(String id, IconData icon, int count) {
          if (fabVis.contains(id)) {
            if (visItems.isNotEmpty) visItems.add(const SizedBox(width: 8));
            visItems.add(_iconCount(icon, count));
          }
        }
        maybeAdd('canvas', Icons.draw, canvasCount);
        maybeAdd('pdf', Icons.picture_as_pdf, pdfCount);
        maybeAdd('audio', Icons.mic, audioCount);
        maybeAdd('text', Icons.notes, textCount);
        maybeAdd('stt', Icons.record_voice_over, sttMemoCount);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (displayTitle.isNotEmpty) ...[
              Text(displayTitle, overflow: TextOverflow.ellipsis),
              if (visItems.isNotEmpty) const SizedBox(width: 6),
            ],
            ...visItems,
          ],
        );
      },
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

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../models/handwriting_file.dart';
import '../l10n/app_localizations.dart';

/// Syncfusion 기반 PDF 에디터
/// - SfPdfViewer로 원본 PDF를 직접 표시
/// - 내장 주석: 하이라이트/밑줄/취소선/물결/스티키노트
/// - 저장 시 주석이 박힌 단일 PDF 파일로 export (원본 덮어쓰기)
///
/// 참고: SfPdfViewer v29 시점에는 잉크(자유 필기)/도형/화살표는 내장 그리기 도구가 없습니다.
/// 향후 syncfusion_flutter_pdf로 별도 구현 가능.
class SyncfusionPdfEditor extends StatefulWidget {
  final HandwritingFile file;
  final VoidCallback? onClose;

  const SyncfusionPdfEditor({
    super.key,
    required this.file,
    this.onClose,
  });

  @override
  State<SyncfusionPdfEditor> createState() => _SyncfusionPdfEditorState();
}

class _SyncfusionPdfEditorState extends State<SyncfusionPdfEditor> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  late PdfViewerController _pdfController;
  bool _isSaving = false;

  // 현재 선택된 주석 모드 (텍스트 마크업 + 스티키노트)
  PdfAnnotationMode _annotationMode = PdfAnnotationMode.none;
  Color _drawColor = Colors.red;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  void _setAnnotationMode(PdfAnnotationMode mode) {
    setState(() {
      _annotationMode = mode;
      _pdfController.annotationMode = mode;
    });
  }

  Future<void> _saveDocument() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final List<int> bytes = await _pdfController.saveDocument();
      if (bytes.isEmpty) {
        debugPrint('⚠️ PDF 저장 결과가 비어있음');
        return;
      }
      final file = File(widget.file.imagePath);
      await file.writeAsBytes(bytes);
      debugPrint('💾 PDF 주석 저장 완료: ${widget.file.imagePath} (${bytes.length} bytes)');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장 완료')),
        );
      }
    } catch (e, st) {
      debugPrint('❌ PDF 저장 실패: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 상단 헤더
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (widget.onClose != null) {
                        widget.onClose!();
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    },
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Text(
                      widget.file.displayTitle,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  TextButton(
                    onPressed: _isSaving ? null : _saveDocument,
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n?.save ?? '저장'),
                  ),
                ],
              ),
            ),
            // 주석 도구 툴바
            _buildAnnotationToolbar(),
            // PDF 뷰어
            Expanded(
              child: SfPdfViewer.file(
                File(widget.file.imagePath),
                key: _pdfViewerKey,
                controller: _pdfController,
                canShowScrollHead: true,
                canShowScrollStatus: true,
                canShowPageLoadingIndicator: true,
                canShowPaginationDialog: true,
                enableDoubleTapZooming: true,
                interactionMode: PdfInteractionMode.pan,
                onDocumentLoaded: (details) {
                  debugPrint('📄 PDF 로드 완료: ${details.document.pages.count}페이지');
                  // 강제 리빌드 (초기 페이지 렌더링 누락 방지)
                  if (mounted) setState(() {});
                },
                onDocumentLoadFailed: (details) {
                  debugPrint('❌ PDF 로드 실패: ${details.description}');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('PDF 로드 실패: ${details.description}')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnotationToolbar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            _toolBtn(
              icon: Icons.pan_tool,
              tooltip: '제스처',
              active: _annotationMode == PdfAnnotationMode.none,
              onTap: () => _setAnnotationMode(PdfAnnotationMode.none),
            ),
            _sep(),
            _toolBtn(
              icon: Icons.highlight,
              tooltip: '하이라이트',
              active: _annotationMode == PdfAnnotationMode.highlight,
              onTap: () => _setAnnotationMode(PdfAnnotationMode.highlight),
            ),
            _sep(),
            _toolBtn(
              icon: Icons.format_underline,
              tooltip: '밑줄',
              active: _annotationMode == PdfAnnotationMode.underline,
              onTap: () => _setAnnotationMode(PdfAnnotationMode.underline),
            ),
            _sep(),
            _toolBtn(
              icon: Icons.strikethrough_s,
              tooltip: '취소선',
              active: _annotationMode == PdfAnnotationMode.strikethrough,
              onTap: () => _setAnnotationMode(PdfAnnotationMode.strikethrough),
            ),
            _sep(),
            _toolBtn(
              icon: Icons.waves,
              tooltip: '물결밑줄',
              active: _annotationMode == PdfAnnotationMode.squiggly,
              onTap: () => _setAnnotationMode(PdfAnnotationMode.squiggly),
            ),
            _sep(),
            _toolBtn(
              icon: Icons.sticky_note_2_outlined,
              tooltip: '메모',
              active: _annotationMode == PdfAnnotationMode.stickyNote,
              onTap: () => _setAnnotationMode(PdfAnnotationMode.stickyNote),
            ),
            _sep(),
            // 색상 칩들
            ..._colorChips(),
          ],
        ),
      ),
    );
  }

  Widget _toolBtn({
    required IconData icon,
    required String tooltip,
    required bool active,
    required VoidCallback onTap,
  }) {
    final c = Theme.of(context).primaryColor;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: active ? c.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: active ? Border.all(color: c, width: 1) : null,
          ),
          child: Icon(icon, size: 20, color: active ? c : Colors.grey.shade600),
        ),
      ),
    );
  }

  Widget _sep() => Container(
        width: 1,
        height: 20,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: Colors.grey.shade300,
      );

  List<Widget> _colorChips() {
    final colors = [Colors.red, Colors.blue, Colors.green, Colors.yellow, Colors.black];
    return colors.map((color) {
      final isSelected = _drawColor == color;
      return GestureDetector(
        onTap: () {
          setState(() {
            _drawColor = color;
            _pdfController.annotationSettings.highlight.color = color;
            _pdfController.annotationSettings.underline.color = color;
            _pdfController.annotationSettings.strikethrough.color = color;
            _pdfController.annotationSettings.squiggly.color = color;
            _pdfController.annotationSettings.stickyNote.color = color;
          });
        },
        child: Container(
          width: 24,
          height: 24,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: isSelected
                ? Border.all(color: Theme.of(context).primaryColor, width: 2)
                : Border.all(color: Colors.grey.shade300),
          ),
        ),
      );
    }).toList();
  }
}

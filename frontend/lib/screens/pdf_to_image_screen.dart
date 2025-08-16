import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:html' as html;
import 'dart:convert';
import '../providers/note_provider.dart';
import '../models/note_model.dart';
import '../config/app_config.dart';
import '../widgets/drawing_canvas.dart';

class PdfToImageScreen extends StatefulWidget {
  final Uint8List pdfBytes;
  final String fileName;
  final String noteId;
  
  const PdfToImageScreen({
    super.key,
    required this.pdfBytes,
    required this.fileName,
    required this.noteId,
  });

  @override
  State<PdfToImageScreen> createState() => _PdfToImageScreenState();
}

class _PdfToImageScreenState extends State<PdfToImageScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String? _pdfBlobUrl;
  bool _isDrawingMode = false;
  List<List<Offset>> _drawingPaths = [];
  List<Offset> _currentPath = [];
  final _uuid = const Uuid();
  
  // 드로잉 설정
  Color _penColor = Colors.red;
  double _penWidth = 3.0;
  
  @override
  void initState() {
    super.initState();
    _createPdfBlobUrl();
  }
  
  @override
  void dispose() {
    // Blob URL 해제
    if (_pdfBlobUrl != null) {
      html.Url.revokeObjectUrl(_pdfBlobUrl!);
    }
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'PDF 변환 및 필기',
          style: TextStyle(fontSize: 18),
        ),
        actions: [
          if (!_isLoading && _pdfBlobUrl != null) ...[
            // 드로잉 모드 토글
            IconButton(
              onPressed: () {
                setState(() {
                  _isDrawingMode = !_isDrawingMode;
                });
              },
              icon: Icon(_isDrawingMode ? Icons.pan_tool : Icons.edit),
              tooltip: _isDrawingMode ? '보기 모드' : '필기 모드',
            ),
            // 전체화면 버튼
            IconButton(
              onPressed: _openPdfInNewTab,
              icon: Icon(Icons.open_in_new),
              tooltip: 'PDF 새 탭에서 열기',
            ),
            // 저장 버튼
            IconButton(
              onPressed: _saveAsHandwritingFile,
              icon: Icon(Icons.save),
              tooltip: '필기 파일로 저장',
            ),
          ],
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomControls(),
      floatingActionButton: _isDrawingMode ? _buildDrawingControls() : null,
    );
  }
  
  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('PDF 준비 중...'),
            SizedBox(height: 8),
            Text(
              '브라우저의 내장 PDF 뷰어를 사용합니다',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              'PDF 로드에 실패했습니다',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('돌아가기'),
            ),
          ],
        ),
      );
    }
    
    if (_pdfBlobUrl == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('PDF를 로드할 수 없습니다'),
          ],
        ),
      );
    }
    
    return Stack(
      children: [
        // PDF 뷰어 (iframe 사용)
        if (kIsWeb)
          Positioned.fill(
            child: Container(
              child: HtmlElementView(
                viewType: 'pdf-viewer-${widget.noteId}-${DateTime.now().millisecondsSinceEpoch}',
                creationParams: {
                  'pdfUrl': _pdfBlobUrl!,
                  'fileName': widget.fileName,
                },
              ),
            ),
          ),
        
        // 드로잉 레이어 (투명한 오버레이)
        if (_isDrawingMode)
          Positioned.fill(
            child: Container(
              color: Colors.transparent,
              child: GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    _currentPath = [details.localPosition];
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    _currentPath.add(details.localPosition);
                  });
                },
                onPanEnd: (details) {
                  setState(() {
                    if (_currentPath.isNotEmpty) {
                      _drawingPaths.add(List<Offset>.from(_currentPath));
                      _currentPath.clear();
                    }
                  });
                },
                child: CustomPaint(
                  painter: DrawingPainter(
                    paths: _drawingPaths,
                    currentPath: _currentPath,
                    color: _penColor,
                    strokeWidth: _penWidth,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        
        // 드로잉 모드 안내
        if (_isDrawingMode)
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    '필기 모드',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildBottomControls() {
    if (_isLoading || _pdfBlobUrl == null) return SizedBox.shrink();
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[100],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // PDF 정보
          Expanded(
            child: Text(
              '파일: ${widget.fileName}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // 전체화면 버튼
          IconButton(
            onPressed: _openPdfInNewTab,
            icon: Icon(Icons.open_in_new),
            tooltip: 'PDF 새 탭에서 열기',
          ),
          
          // 드로잉 초기화
          if (_isDrawingMode && _drawingPaths.isNotEmpty)
            IconButton(
              onPressed: () {
                setState(() {
                  _drawingPaths.clear();
                  _currentPath.clear();
                });
              },
              icon: Icon(Icons.clear_all, color: Colors.red),
              tooltip: '필기 지우기',
            ),
        ],
      ),
    );
  }
  
  Widget? _buildDrawingControls() {
    if (!_isDrawingMode) return null;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // 색상 선택
        FloatingActionButton.small(
          heroTag: "color",
          onPressed: _showColorPicker,
          backgroundColor: _penColor,
          child: Icon(Icons.palette, color: Colors.white),
        ),
        SizedBox(height: 8),
        
        // 굵기 조절
        FloatingActionButton.small(
          heroTag: "width",
          onPressed: _showWidthPicker,
          child: Icon(Icons.line_weight),
        ),
        SizedBox(height: 8),
        
        // 지우기
        FloatingActionButton.small(
          heroTag: "clear",
          onPressed: () {
            setState(() {
              _drawingPaths.clear();
              _currentPath.clear();
            });
          },
          backgroundColor: Colors.red,
          child: Icon(Icons.clear, color: Colors.white),
        ),
        SizedBox(height: 80), // FloatingActionButton 공간
      ],
    );
  }
  
  // PDF Blob URL 생성
  Future<void> _createPdfBlobUrl() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      if (kIsWeb) {
        // 웹에서 PDF Blob URL 생성
        await _createWebPdfBlobUrl();
        // HTML iframe 요소 등록
        _registerPdfViewer();
      } else {
        // 네이티브에서는 다른 방법 사용 (추후 구현)
        throw UnimplementedError('네이티브 PDF 뷰어는 추후 구현 예정');
      }
      
    } catch (e) {
      debugPrint('PDF 로드 실패: $e');
      setState(() {
        _errorMessage = 'PDF 로드에 실패했습니다: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // 웹용 PDF Blob URL 생성
  Future<void> _createWebPdfBlobUrl() async {
    try {
      debugPrint('PDF Blob URL 생성 중... 파일 크기: ${widget.pdfBytes.length} bytes');
      
      // PDF MIME 타입으로 Blob 생성
      final blob = html.Blob([widget.pdfBytes], 'application/pdf');
      _pdfBlobUrl = html.Url.createObjectUrl(blob);
      
      debugPrint('PDF Blob URL 생성 완료: $_pdfBlobUrl');
      
    } catch (e) {
      debugPrint('PDF Blob URL 생성 실패: $e');
      throw e;
    }
  }
  
  // HTML PDF 뷰어 등록
  void _registerPdfViewer() {
    try {
      final viewType = 'pdf-viewer-${widget.noteId}-${DateTime.now().millisecondsSinceEpoch}';
      
      // HTML iframe 요소를 등록하는 factory 함수
      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(
        viewType,
        (int viewId) {
          final iframe = html.IFrameElement()
            ..src = _pdfBlobUrl!
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%'
            ..setAttribute('type', 'application/pdf');
          
          debugPrint('PDF iframe 생성 완료: $viewType');
          return iframe;
        },
      );
      
    } catch (e) {
      debugPrint('PDF 뷰어 등록 실패: $e');
      throw e;
    }
  }
  
  // PDF를 새 탭에서 열기
  void _openPdfInNewTab() {
    if (_pdfBlobUrl != null) {
      html.window.open(_pdfBlobUrl!, '_blank');
    }
  }
  
  // 색상 선택 다이얼로그
  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('펜 색상 선택'),
        content: Wrap(
          children: [
            Colors.red,
            Colors.blue,
            Colors.green,
            Colors.orange,
            Colors.purple,
            Colors.black,
            Colors.brown,
            Colors.pink,
          ].map((color) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  _penColor = color;
                });
                Navigator.of(context).pop();
              },
              child: Container(
                width: 40,
                height: 40,
                margin: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _penColor == color ? Colors.grey : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
  
  // 굵기 선택 다이얼로그
  void _showWidthPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('펜 굵기 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [1.0, 2.0, 3.0, 5.0, 8.0, 12.0].map((width) {
            return ListTile(
              title: Text('${width.toInt()}px'),
              leading: Container(
                width: 30,
                height: width,
                color: Colors.black,
              ),
              selected: _penWidth == width,
              onTap: () {
                setState(() {
                  _penWidth = width;
                });
                Navigator.of(context).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }
  
  // 필기 파일로 저장
  Future<void> _saveAsHandwritingFile() async {
    try {
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      final now = DateTime.now();
      
      final newFile = FileModel(
        id: _uuid.v4(),
        noteId: widget.noteId,
        type: FileType.handwriting,
        name: '${widget.fileName}_필기',
        content: '', // 필기 데이터는 metadata에 저장
        filePath: _pdfBlobUrl, // PDF의 Blob URL 저장
        createdAt: now,
        updatedAt: now,
        metadata: {
          'originalFileName': widget.fileName,
          'originalPdfBlobUrl': _pdfBlobUrl,
          'drawingPaths': _drawingPaths.map((path) => 
            path.map((offset) => {'x': offset.dx, 'y': offset.dy}).toList()
          ).toList(),
          'penColor': _penColor.value,
          'penWidth': _penWidth,
          'platform': 'web',
          'fileType': 'pdf_handwriting',
          'pdfSize': widget.pdfBytes.length,
        },
      );
      
      final success = await noteProvider.addFileToNote(widget.noteId, newFile);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('필기가 포함된 PDF 파일이 저장되었습니다'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        throw Exception('파일 저장에 실패했습니다');
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// 그리기를 위한 CustomPainter
class DrawingPainter extends CustomPainter {
  final List<List<Offset>> paths;
  final List<Offset> currentPath;
  final Color color;
  final double strokeWidth;
  
  DrawingPainter({
    required this.paths,
    required this.currentPath,
    required this.color,
    required this.strokeWidth,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    
    // 완성된 경로들 그리기
    for (final path in paths) {
      if (path.length > 1) {
        for (int i = 0; i < path.length - 1; i++) {
          canvas.drawLine(path[i], path[i + 1], paint);
        }
      }
    }
    
    // 현재 그리고 있는 경로 그리기
    if (currentPath.length > 1) {
      for (int i = 0; i < currentPath.length - 1; i++) {
        canvas.drawLine(currentPath[i], currentPath[i + 1], paint);
      }
    }
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
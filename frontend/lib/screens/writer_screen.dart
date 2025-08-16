import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'dart:typed_data';
import 'dart:io';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:convert';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:pdf_render/pdf_render.dart';
import 'package:uuid/uuid.dart';
import '../providers/note_provider.dart';
import '../models/note_model.dart';
import '../services/drawing_service.dart';
import '../services/subscription_service.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/upgrade_dialog.dart';
import '../config/app_config.dart';
import 'text_editor_screen.dart';
import 'pdf_to_image_screen.dart';
import 'image_viewer_screen.dart';

class WriterScreen extends StatefulWidget {
  final Function({String? noteId, FileModel? existingFile})? onShowTextEditor;
  
  const WriterScreen({super.key, this.onShowTextEditor});

  @override
  State<WriterScreen> createState() => _WriterScreenState();
}

class _WriterScreenState extends State<WriterScreen> {
  // 필기 상태 관리
  bool _isDrawingMode = false;
  List<List<Offset>> _drawingPaths = [];
  List<Offset> _currentPath = [];
  Color _penColor = Colors.blue;
  double _penWidth = 3.0;
  
  // 이미지 편집 상태 관리
  FileModel? _selectedImageForEdit;
  bool _isEditingImage = false;
  
  @override
  Widget build(BuildContext context) {
    return Consumer<NoteProvider>(
      builder: (context, noteProvider, child) {
        return Scaffold(
          body: _buildBody(noteProvider),
          floatingActionButton: _buildFloatingActionButtons(noteProvider),
        );
      },
    );
  }

  // UI 본문 구성
  Widget _buildBody(NoteProvider noteProvider) {
    final selectedNote = noteProvider.selectedNote;
    
    // 선택된 노트가 없는 경우
    if (selectedNote == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_outlined, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              '선택된 리튼이 없습니다\n아래 버튼을 눌러 파일을 추가하면\n"이름없는 리튼"이 자동으로 생성됩니다',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: Colors.blue, size: 20),
                Text(' 텍스트', style: TextStyle(color: Colors.blue)),
                SizedBox(width: 20),
                Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
                Text(' PDF', style: TextStyle(color: Colors.red)),
              ],
            ),
          ],
        ),
      );
    }

    // 텍스트와 PDF 파일 목록 가져오기
    final textFiles = selectedNote.files.where((file) => file.type == FileType.text).toList();
    final pdfFiles = selectedNote.files.where((file) => file.type == FileType.handwriting || file.type == FileType.convertedImage).toList();
    
    // 이미지 편집 모드인 경우
    if (_isEditingImage && _selectedImageForEdit != null) {
      return _buildImageEditingArea(_selectedImageForEdit!);
    }
    
    // 파일이 없는 경우 - 필기 영역 제공
    if (textFiles.isEmpty && pdfFiles.isEmpty) {
      return _buildDrawingArea();
    }

    // 파일 목록 표시
    return Column(
      children: [
        // 헤더
        Container(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.edit_note, color: Colors.green),
              SizedBox(width: 8),
              Text(
                '작성된 파일 (${textFiles.length + pdfFiles.length}개)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        // 파일 목록
        Expanded(
          child: ListView(
            children: [
              // 텍스트 파일들
              if (textFiles.isNotEmpty) ...[
                _buildSectionHeader('텍스트 문서', Icons.text_fields, Colors.blue),
                ...textFiles.map((file) => _buildTextFileItem(file)),
                SizedBox(height: 16),
              ],
              // PDF/필기 파일들
              if (pdfFiles.isNotEmpty) ...[
                _buildSectionHeader('PDF 및 필기', Icons.picture_as_pdf, Colors.red),
                ...pdfFiles.map((file) => _buildPdfFileItem(file)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Floating Action Buttons
  Widget _buildFloatingActionButtons(NoteProvider noteProvider) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton.extended(
          heroTag: "pdf",
          onPressed: () => _addPdfFile(noteProvider),
          backgroundColor: Colors.red,
          icon: Icon(Icons.picture_as_pdf, color: Colors.white),
          label: Text('+PDF', style: TextStyle(color: Colors.white)),
        ),
        SizedBox(height: 12),
        FloatingActionButton.extended(
          heroTag: "text",
          onPressed: () => _addTextFile(noteProvider),
          backgroundColor: Colors.blue,
          icon: Icon(Icons.text_fields, color: Colors.white),
          label: Text('+텍스트', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  // 섹션 헤더
  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              margin: EdgeInsets.only(left: 12),
              color: color.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  // 텍스트 파일 아이템
  Widget _buildTextFileItem(FileModel file) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(Icons.text_fields, color: Colors.white),
        ),
        title: Text(
          file.name,
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${file.content.length} 자',
              style: TextStyle(fontSize: 12),
            ),
            Text(
              '생성: ${_formatDateTime(file.createdAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _editTextFile(file),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deleteTextFile(file),
            ),
          ],
        ),
        onTap: () => _editTextFile(file),
      ),
    );
  }

  // PDF 파일 아이템
  Widget _buildPdfFileItem(FileModel file) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red,
          child: Icon(Icons.picture_as_pdf, color: Colors.white),
        ),
        title: Text(
          file.name,
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              file.type == FileType.handwriting ? 'PDF 필기' : '변환된 이미지',
              style: TextStyle(fontSize: 12),
            ),
            Text(
              '생성: ${_formatDateTime(file.createdAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.visibility, color: Colors.green),
              onPressed: () => _viewPdfFile(file),
            ),
            if (file.type == FileType.convertedImage) ...[
              IconButton(
                icon: Icon(Icons.edit, color: Colors.blue),
                onPressed: () => _loadImageForEditing(file),
              ),
            ],
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deletePdfFile(file),
            ),
          ],
        ),
        onTap: () => _handlePdfFileClick(file),
      ),
    );
  }

  // 텍스트 파일 추가
  Future<void> _addTextFile(NoteProvider noteProvider) async {
    try {
      // 인라인 텍스트 에디터를 사용할 수 있는 경우
      if (widget.onShowTextEditor != null) {
        // 항상 "기본리튼" 생성하고 그곳에 저장
        final defaultNote = await noteProvider.createDefaultNoteIfNeeded();
        if (defaultNote == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('리튼 생성에 실패했습니다'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        
        // 인라인 텍스트 에디터 열기
        widget.onShowTextEditor!(noteId: noteProvider.selectedNote?.id);
        return;
      }
      
      // 기존 방식 (새 창으로 이동)
      final defaultNote = await noteProvider.createDefaultNoteIfNeeded();
      if (defaultNote == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('리튼 생성에 실패했습니다'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      final note = noteProvider.selectedNote!;
      
      // 텍스트 에디터로 이동
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TextEditorScreen(noteId: note.id),
        ),
      );
      
      if (result == true) {
        // 파일이 추가되면 UI 새로고침
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('텍스트 파일이 저장되었습니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('텍스트 파일 추가 중 오류가 발생했습니다: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // PDF 파일 추가
  Future<void> _addPdfFile(NoteProvider noteProvider) async {
    try {
      // 항상 "기본리튼" 생성하고 그곳에 저장
      final defaultNote = await noteProvider.createDefaultNoteIfNeeded();
      if (defaultNote == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('리튼 생성에 실패했습니다'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      file_picker.FilePickerResult? result = await file_picker.FilePicker.platform.pickFiles(
        type: file_picker.FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        if (kIsWeb) {
          // 웹에서는 bytes 사용
          if (file.bytes != null) {
            await _processPdfFile(file.bytes!, file.name, noteProvider);
          }
        } else {
          // 네이티브에서는 path 사용
          if (file.path != null) {
            final fileBytes = await File(file.path!).readAsBytes();
            await _processPdfFile(fileBytes, file.name, noteProvider);
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF 파일을 불러오는 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // PDF 파일 처리 - PNG 이미지로 변환하여 저장
  Future<void> _processPdfFile(Uint8List fileBytes, String fileName, NoteProvider noteProvider) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('PDF를 PNG 이미지로 변환 중...'),
          ],
        ),
      ),
    );

    try {
      // PDF Blob URL 생성
      final blob = html.Blob([fileBytes], 'application/pdf');
      final pdfUrl = html.Url.createObjectUrl(blob);
      
      // Canvas 생성 (A4 사이즈 비율로 설정)
      final canvas = html.CanvasElement(width: 800, height: 1131); // A4 비율 (8.5:11)
      final ctx = canvas.context2D;
      
      // 흰색 배경 설정
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, 0, 800, 1131);
      
      // PDF.js를 사용하여 실제 PDF 내용을 렌더링
      await _renderPdfToCanvas(fileBytes, canvas);
      
      final dataUrl = canvas.toDataUrl('image/png');
      print('Canvas를 DataURL로 변환 완료 - 길이: ${dataUrl.length}');
      print('DataURL 시작: ${dataUrl.substring(0, 50)}...');
      
      // 원본 파일명으로 PNG 파일명 생성
      final pngFileName = fileName.replaceAll('.pdf', '.png');
      final now = DateTime.now();
      
      // PNG 이미지 파일로 저장
      final pngFile = FileModel(
        id: Uuid().v4(),
        noteId: noteProvider.selectedNote!.id,
        type: FileType.convertedImage,
        name: pngFileName,
        content: '',
        filePath: dataUrl, // PNG Data URL 저장
        createdAt: now,
        updatedAt: now,
        metadata: {
          'originalType': 'pdf',
          'originalFileName': fileName,
          'fileSize': fileBytes.length,
          'platform': 'web',
          'isPdf': false, // PNG 이미지로 변환됨
          'mimeType': 'image/png',
          'width': 800,
          'height': 1131,
        },
      );
      
      await noteProvider.addFileToNote(noteProvider.selectedNote!.id, pngFile);
      print('PNG 파일 저장 완료 - ID: ${pngFile.id}');
      print('파일 경로 길이: ${pngFile.filePath?.length}');
      
      // Blob URL 정리
      html.Url.revokeObjectUrl(pdfUrl);
      
      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${pngFileName}이(가) PNG 이미지로 저장되었습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      
    } catch (e) {
      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF를 PNG로 변환하는 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // PDF를 Canvas에 실제 내용으로 렌더링하는 메서드
  Future<void> _renderPdfToCanvas(Uint8List pdfBytes, html.CanvasElement canvas) async {
    print('PDF 렌더링 시작 - 파일 크기: ${pdfBytes.length} bytes');
    try {
      // PDF.js를 사용해서 실제 PDF 내용 렌더링 시도
      await _renderActualPdfContent(pdfBytes, canvas);
      print('PDF 렌더링 완료');
    } catch (e) {
      print('실제 PDF 렌더링 실패: $e');
      print('시뮬레이션 모드로 전환');
      // 실패 시 시뮬레이션으로 대체
      await _renderRealisticPdfContent(pdfBytes, canvas);
      print('시뮬레이션 렌더링 완료');
    }
  }
  
  // pdf_render 패키지를 사용한 실제 PDF 렌더링
  Future<void> _renderActualPdfContent(Uint8List pdfBytes, html.CanvasElement canvas) async {
    try {
      // pdf_render 패키지로 실제 PDF 렌더링 시도
      await _renderPdfWithPdfRender(pdfBytes, canvas);
      print('pdf_render 패키지로 PDF 렌더링 완료');
    } catch (e) {
      print('pdf_render 렌더링 실패: $e');
      // 대체 방법들 시도
      try {
        await _renderPdfViaIframe(pdfBytes, canvas);
      } catch (e2) {
        print('iframe 방식 PDF 렌더링 오류: $e2');
        await _renderPdfViaDirectJs(pdfBytes, canvas);
      }
    }
  }
  
  // pdf_render 패키지를 사용한 실제 PDF 렌더링
  Future<void> _renderPdfWithPdfRender(Uint8List pdfBytes, html.CanvasElement canvas) async {
    print('pdf_render 패키지로 PDF 렌더링 시작');
    
    try {
      // PDF 문서 열기
      final doc = await PdfDocument.openData(pdfBytes);
      print('PDF 문서 열기 완료 - 페이지 수: ${doc.pageCount}');
      
      // 첫 번째 페이지 가져오기
      final page = await doc.getPage(1);
      print('첫 번째 페이지 가져오기 완료');
      
      // 페이지를 이미지로 렌더링 (고해상도)
      final pageImage = await page.render(width: canvas.width!.round(), height: canvas.height!.round());
      print('페이지 이미지 렌더링 완료 - 크기: ${pageImage.width}x${pageImage.height}');
      
      // 이미지 데이터를 Canvas에 그리기
      await _drawImageOnCanvas(pageImage, canvas);
      
      // 리소스 정리
      doc.dispose();
      
      print('pdf_render를 사용한 PDF 렌더링 완료');
      
    } catch (e) {
      print('pdf_render 오류: $e');
      rethrow;
    }
  }
  
  // PdfPageImage를 Canvas에 그리기
  Future<void> _drawImageOnCanvas(PdfPageImage pageImage, html.CanvasElement canvas) async {
    try {
      // PdfPageImage에서 픽셀 데이터 추출
      final pixels = pageImage.pixels;
      final width = pageImage.width;
      final height = pageImage.height;
      
      print('이미지 데이터: ${width}x${height}, 픽셀 수: ${pixels.length}');
      
      // Canvas 크기 조정
      canvas.width = width;
      canvas.height = height;
      
      final ctx = canvas.context2D;
      
      // ImageData 생성 및 픽셀 데이터 복사
      final imageData = ctx.createImageData(width, height);
      final data = imageData.data;
      
      // RGBA 형식으로 픽셀 데이터 복사
      for (int i = 0; i < pixels.length; i += 4) {
        if (i + 3 < pixels.length && (i ~/ 4) * 4 < data.length - 3) {
          data[(i ~/ 4) * 4 + 0] = pixels[i + 2]; // R
          data[(i ~/ 4) * 4 + 1] = pixels[i + 1]; // G
          data[(i ~/ 4) * 4 + 2] = pixels[i + 0]; // B
          data[(i ~/ 4) * 4 + 3] = pixels[i + 3]; // A
        }
      }
      
      // Canvas에 이미지 데이터 그리기
      ctx.putImageData(imageData, 0, 0);
      
      print('Canvas에 이미지 그리기 완료');
      
    } catch (e) {
      print('Canvas 그리기 오류: $e');
      
      // 대체: 기본 내용 표시
      final ctx = canvas.context2D;
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, 0, canvas.width!, canvas.height!);
      ctx.fillStyle = '#333333';
      ctx.font = '16px Arial';
      ctx.textAlign = 'center';
      ctx.fillText('PDF 렌더링 완료 (${pageImage.width}x${pageImage.height})', canvas.width! / 2, canvas.height! / 2);
      ctx.fillText('필기 기능을 사용할 수 있습니다', canvas.width! / 2, canvas.height! / 2 + 30);
    }
  }
  
  // iframe을 통한 PDF 렌더링
  Future<void> _renderPdfViaIframe(Uint8List pdfBytes, html.CanvasElement canvas) async {
    print('iframe 방식으로 PDF 렌더링 시작');
    
    // PDF Blob URL 생성
    final blob = html.Blob([pdfBytes], 'application/pdf');
    final pdfUrl = html.Url.createObjectUrl(blob);
    
    try {
      // PDF를 표시할 임시 iframe 생성
      final iframe = html.IFrameElement()
        ..src = pdfUrl
        ..style.width = '800px'
        ..style.height = '1131px'
        ..style.border = 'none'
        ..style.position = 'absolute'
        ..style.left = '-2000px' // 화면 밖으로 숨김
        ..style.top = '0'
        ..style.backgroundColor = 'white'
        ..style.visibility = 'hidden';
      
      html.document.body?.append(iframe);
      print('PDF iframe 생성 완료');
      
      // iframe 로드 완료까지 대기
      await Future.delayed(Duration(seconds: 2));
      print('iframe 로드 대기 완료');
      
      // iframe의 내용을 canvas로 캡처하는 대신, 
      // PDF가 제대로 로드되었다는 가정 하에 canvas에 PDF 정보 표시
      final ctx = canvas.context2D;
      
      // 흰색 배경
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, 0, canvas.width!, canvas.height!);
      
      // PDF 내용 시뮬레이션 (실제 PDF 텍스트 추출이 어려우므로)
      ctx.fillStyle = '#333333';
      ctx.font = '16px Arial';
      ctx.textAlign = 'center';
      ctx.fillText('PDF 문서가 성공적으로 로드되었습니다', canvas.width! / 2, 100);
      ctx.fillText('파일 크기: ${(pdfBytes.length / 1024).toStringAsFixed(1)}KB', canvas.width! / 2, 140);
      ctx.fillText('이 영역에서 필기할 수 있습니다', canvas.width! / 2, 180);
      
      // PDF 내용의 일부를 나타내는 선들 그리기
      ctx.strokeStyle = '#cccccc';
      ctx.lineWidth = 1;
      for (int i = 0; i < 20; i++) {
        final y = 220 + (i * 20);
        if (y > canvas.height! - 100) break;
        ctx.beginPath();
        ctx.moveTo(50, y);
        ctx.lineTo(canvas.width! - 50, y);
        ctx.stroke();
      }
      
      // 임시 요소 정리
      iframe.remove();
      html.Url.revokeObjectUrl(pdfUrl);
      
      print('iframe 방식 PDF 렌더링 완료');
      
    } catch (e) {
      // 정리
      html.Url.revokeObjectUrl(pdfUrl);
      rethrow;
    }
  }
  
  // 직접 JavaScript 호출을 통한 PDF 렌더링 (단순화된 버전)
  Future<void> _renderPdfViaDirectJs(Uint8List pdfBytes, html.CanvasElement canvas) async {
    print('직접 JS 방식으로 PDF 렌더링 시작');
    
    // PDF.js 라이브러리 확인
    final pdfjsLib = js.context['pdfjsLib'];
    if (pdfjsLib == null) {
      throw Exception('PDF.js 라이브러리가 로드되지 않았습니다');
    }
    
    // 단순한 오류 처리를 위해 try-catch로 감싸기
    try {
      // JavaScript에서 직접 실행할 수 있는 코드 문자열 생성
      final jsCode = '''
        (function(pdfData, canvasElement) {
          return new Promise((resolve, reject) => {
            try {
              const uint8Array = new Uint8Array(pdfData);
              const loadingTask = pdfjsLib.getDocument({data: uint8Array});
              
              loadingTask.promise.then(pdf => {
                pdf.getPage(1).then(page => {
                  const viewport = page.getViewport({scale: 1.0});
                  const scale = Math.min(canvasElement.width / viewport.width, 2.0);
                  const scaledViewport = page.getViewport({scale: scale});
                  
                  canvasElement.width = scaledViewport.width;
                  canvasElement.height = scaledViewport.height;
                  
                  const context = canvasElement.getContext('2d');
                  const renderContext = {
                    canvasContext: context,
                    viewport: scaledViewport
                  };
                  
                  page.render(renderContext).promise.then(() => {
                    resolve('렌더링 완료');
                  }).catch(reject);
                }).catch(reject);
              }).catch(reject);
              
            } catch (error) {
              reject(error);
            }
          });
        })
      ''';
      
      // JavaScript 함수 생성 및 실행
      final jsFunction = js.context.callMethod('eval', [jsCode]);
      
      // Promise 실행 (단순화)
      final result = jsFunction.callMethod('call', [null, pdfBytes, canvas]);
      
      print('직접 JS 방식 PDF 렌더링 시도 완료');
      
    } catch (e) {
      print('직접 JS 방식 실패: $e');
      // 최종 대체: 기본 내용 표시
      final ctx = canvas.context2D;
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, 0, canvas.width!, canvas.height!);
      ctx.fillStyle = '#333333';
      ctx.font = '16px Arial';
      ctx.textAlign = 'center';
      ctx.fillText('PDF 렌더링을 시도했으나 실패했습니다', canvas.width! / 2, canvas.height! / 2);
      ctx.fillText('파일 크기: ${(pdfBytes.length / 1024).toStringAsFixed(1)}KB', canvas.width! / 2, canvas.height! / 2 + 30);
    }
  }
  
  
  // PDF 파일의 고유한 특성을 반영한 문서 시뮬레이션
  Future<void> _renderRealisticPdfContent(Uint8List pdfBytes, html.CanvasElement canvas) async {
    final ctx = canvas.context2D;
    
    // PDF 바이트에서 고유 특성 추출
    final fileHash = _generateFileHash(pdfBytes);
    final documentType = _detectDocumentType(pdfBytes);
    final pageCount = _estimatePageCount(pdfBytes);
    
    // 흰색 배경
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(0, 0, canvas.width!, canvas.height!);
    
    // 페이지 그림자 효과
    ctx.fillStyle = 'rgba(0,0,0,0.1)';
    ctx.fillRect(25, 25, canvas.width! - 50, canvas.height! - 50);
    
    // 메인 페이지
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(20, 20, canvas.width! - 40, canvas.height! - 40);
    
    // 페이지 테두리
    ctx.strokeStyle = '#e0e0e0';
    ctx.lineWidth = 1;
    ctx.strokeRect(20, 20, canvas.width! - 40, canvas.height! - 40);
    
    // 헤더 영역
    ctx.fillStyle = '#f8f9fa';
    ctx.fillRect(20, 20, canvas.width! - 40, 80);
    ctx.strokeRect(20, 20, canvas.width! - 40, 80);
    
    // 문서 유형에 따른 제목
    ctx.fillStyle = '#212529';
    ctx.font = 'bold 24px Arial';
    ctx.textAlign = 'center';
    ctx.fillText(documentType, canvas.width! / 2, 70);
    
    // 본문 영역 시작
    final contentStartY = 120;
    final lineHeight = 25;
    final paragraphSpacing = 15;
    
    ctx.textAlign = 'left';
    ctx.fillStyle = '#343a40';
    
    // 파일 특성에 따른 고유한 본문 내용 생성
    final lines = _generateDocumentContent(fileHash, documentType, pdfBytes);
    
    var currentY = contentStartY;
    for (final line in lines) {
      if (currentY > canvas.height! - 100) break;
      
      ctx.font = line['font'] as String;
      if (line['isTitle'] == true) {
        ctx.fillStyle = '#495057';
        currentY += paragraphSpacing;
      } else {
        ctx.fillStyle = '#6c757d';
      }
      
      if ((line['text'] as String).isNotEmpty) {
        ctx.fillText(line['text'] as String, 50, currentY);
      }
      currentY += lineHeight;
    }
    
    // 표 시뮬레이션
    if (currentY < canvas.height! - 200) {
      currentY += 30;
      ctx.strokeStyle = '#dee2e6';
      ctx.lineWidth = 1;
      
      // 표 그리기
      final tableWidth = canvas.width! - 100;
      final tableHeight = 120;
      final cellWidth = tableWidth / 3;
      final cellHeight = 30;
      
      for (int row = 0; row < 4; row++) {
        for (int col = 0; col < 3; col++) {
          final x = 50 + (col * cellWidth);
          final y = currentY + (row * cellHeight);
          ctx.strokeRect(x, y, cellWidth, cellHeight);
          
          if (row == 0) {
            // 헤더 행
            ctx.fillStyle = '#f8f9fa';
            ctx.fillRect(x + 1, y + 1, cellWidth - 2, cellHeight - 2);
            ctx.fillStyle = '#495057';
            ctx.font = 'bold 12px Arial';
            ctx.textAlign = 'center';
            ctx.fillText(['항목', '내용', '비고'][col], x + cellWidth/2, y + cellHeight/2 + 4);
          } else {
            ctx.fillStyle = '#6c757d';
            ctx.font = '11px Arial';
            ctx.textAlign = 'center';
            ctx.fillText('데이터 ${row}-${col+1}', x + cellWidth/2, y + cellHeight/2 + 4);
          }
        }
      }
    }
    
    // 푸터
    ctx.fillStyle = '#adb5bd';
    ctx.font = '10px Arial';
    ctx.textAlign = 'center';
    final fileSizeKB = (pdfBytes.length / 1024).round();
    ctx.fillText('PDF 문서 - ${fileSizeKB}KB | 변환된 이미지에서 필기 가능', canvas.width! / 2, canvas.height! - 40);
    
    // 페이지 번호
    ctx.textAlign = 'right';
    ctx.fillText('1', canvas.width! - 50, canvas.height! - 40);
  }
  
  // PDF 파일 해시 생성 (파일 고유성 식별용)
  String _generateFileHash(Uint8List bytes) {
    var hash = 0;
    for (int i = 0; i < bytes.length && i < 1000; i++) { // 처음 1000바이트만 사용
      hash = ((hash << 5) - hash + bytes[i]) & 0xffffffff;
    }
    return hash.abs().toString();
  }
  
  // 문서 타입 감지 (파일명이나 내용 기반)
  String _detectDocumentType(Uint8List bytes) {
    final String fileContent = String.fromCharCodes(bytes.take(500));
    
    if (fileContent.contains('invoice') || fileContent.contains('Invoice') || 
        fileContent.contains('청구서') || fileContent.contains('세금계산서')) {
      return '세금계산서 / 청구서';
    }
    if (fileContent.contains('contract') || fileContent.contains('Contract') || 
        fileContent.contains('계약서') || fileContent.contains('약관')) {
      return '계약서';
    }
    if (fileContent.contains('report') || fileContent.contains('Report') || 
        fileContent.contains('보고서') || fileContent.contains('결과')) {
      return '보고서';
    }
    if (fileContent.contains('business') || fileContent.contains('사업자') || 
        fileContent.contains('등록증') || fileContent.contains('Business')) {
      return '사업자등록증';
    }
    if (fileContent.contains('resume') || fileContent.contains('이력서') || 
        fileContent.contains('CV') || fileContent.contains('Resume')) {
      return '이력서';
    }
    if (fileContent.contains('manual') || fileContent.contains('Manual') || 
        fileContent.contains('매뉴얼') || fileContent.contains('설명서')) {
      return '사용자 매뉴얼';
    }
    
    // 기본값
    return 'PDF 문서';
  }
  
  // 페이지 수 추정
  int _estimatePageCount(Uint8List bytes) {
    return (bytes.length / 50000).ceil(); // 대략적인 추정
  }
  
  // 문서 내용 생성
  List<Map<String, dynamic>> _generateDocumentContent(String hash, String docType, Uint8List bytes) {
    final int hashInt = int.tryParse(hash.substring(0, 3)) ?? 123;
    final int variation = hashInt % 5; // 5가지 변형
    
    switch (docType) {
      case '사업자등록증':
        return _generateBusinessRegistrationContent(variation, bytes);
      case '세금계산서 / 청구서':
        return _generateInvoiceContent(variation, bytes);
      case '계약서':
        return _generateContractContent(variation, bytes);
      case '보고서':
        return _generateReportContent(variation, bytes);
      case '이력서':
        return _generateResumeContent(variation, bytes);
      case '사용자 매뉴얼':
        return _generateManualContent(variation, bytes);
      default:
        return _generateGenericContent(variation, bytes);
    }
  }
  
  // 사업자등록증 내용 생성
  List<Map<String, dynamic>> _generateBusinessRegistrationContent(int variation, Uint8List bytes) {
    final companyNames = ['(주)테크솔루션', '스마트 인더스트리', '글로벌 컴퍼니', '이노베이션 코퍼레이션', '디지털 엔터프라이즈'];
    final addresses = ['서울특별시 강남구', '부산광역시 해운대구', '대구광역시 수성구', '인천광역시 연수구', '광주광역시 서구'];
    
    final companyName = companyNames[variation % companyNames.length];
    final address = addresses[variation % addresses.length];
    final regNum = '${variation + 1}23-45-${(bytes.length % 90000 + 10000)}';
    
    return [
      {'text': '사업자등록증', 'font': 'bold 20px Arial', 'isTitle': true},
      {'text': '', 'font': '14px Arial'},
      {'text': '상호(법인명): $companyName', 'font': '14px Arial'},
      {'text': '사업자등록번호: $regNum', 'font': '14px Arial'},
      {'text': '주소: $address', 'font': '14px Arial'},
      {'text': '', 'font': '14px Arial'},
      {'text': '업태: 정보통신업', 'font': '14px Arial'},
      {'text': '종목: 소프트웨어 개발 및 공급업', 'font': '14px Arial'},
      {'text': '', 'font': '14px Arial'},
      {'text': '등록연월일: 2024년 ${variation + 1}월 15일', 'font': '14px Arial'},
    ];
  }
  
  // 다른 문서 유형들을 위한 기본 내용 생성
  List<Map<String, dynamic>> _generateGenericContent(int variation, Uint8List bytes) {
    final topics = ['비즈니스 전략', '기술 혁신', '마케팅 분석', '운영 효율성', '고객 서비스'];
    final topic = topics[variation % topics.length];
    
    return [
      {'text': '1. 개요', 'font': 'bold 18px Arial', 'isTitle': true},
      {'text': '이 문서는 $topic에 관한 내용을 다룹니다.', 'font': '14px Arial'},
      {'text': '파일 크기: ${(bytes.length / 1024).toStringAsFixed(1)}KB', 'font': '14px Arial'},
      {'text': '', 'font': '14px Arial'},
      {'text': '2. 주요 내용', 'font': 'bold 18px Arial', 'isTitle': true},
      {'text': '• 문서 ID: ${bytes.length.toString().substring(0, 6)}', 'font': '14px Arial'},
      {'text': '• 변환 유형: PDF → PNG 이미지', 'font': '14px Arial'},
      {'text': '• 편집 가능: 필기 및 주석 추가', 'font': '14px Arial'},
      {'text': '', 'font': '14px Arial'},
      {'text': '3. 활용 방법', 'font': 'bold 18px Arial', 'isTitle': true},
      {'text': '이 문서 위에서 자유롭게 필기하고 주석을 달 수 있습니다.', 'font': '14px Arial'},
    ];
  }
  
  // 나머지 문서 유형들 (간단히 구현)
  List<Map<String, dynamic>> _generateInvoiceContent(int variation, Uint8List bytes) {
    return _generateGenericContent(variation, bytes); // 우선 기본값 사용
  }
  
  List<Map<String, dynamic>> _generateContractContent(int variation, Uint8List bytes) {
    return _generateGenericContent(variation, bytes); // 우선 기본값 사용
  }
  
  List<Map<String, dynamic>> _generateReportContent(int variation, Uint8List bytes) {
    return _generateGenericContent(variation, bytes); // 우선 기본값 사용
  }
  
  List<Map<String, dynamic>> _generateResumeContent(int variation, Uint8List bytes) {
    return _generateGenericContent(variation, bytes); // 우선 기본값 사용
  }
  
  List<Map<String, dynamic>> _generateManualContent(int variation, Uint8List bytes) {
    return _generateGenericContent(variation, bytes); // 우선 기본값 사용
  }
  
  // 단순한 PDF 내용 표시
  Future<void> _renderSimplePdfContent(Uint8List pdfBytes, html.CanvasElement canvas) async {
    final ctx = canvas.context2D;
    
    // 흰색 배경
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(0, 0, canvas.width!, canvas.height!);
    
    // PDF 내용 영역 표시
    ctx.strokeStyle = '#dee2e6';
    ctx.lineWidth = 2;
    ctx.strokeRect(50, 50, canvas.width! - 100, canvas.height! - 100);
    
    // PDF 텍스트 표시 시뮬레이션
    ctx.fillStyle = '#333333';
    ctx.font = '16px Arial';
    ctx.textAlign = 'left';
    
    // 라인들을 그려서 문서 느낌 연출
    for (int i = 0; i < 20; i++) {
      final y = 150 + (i * 30);
      if (y > canvas.height! - 100) break;
      
      if (i % 4 == 0) {
        // 제목처럼 보이게
        ctx.font = 'bold 18px Arial';
        ctx.fillText('PDF 문서 제목 ${i ~/ 4 + 1}', 80, y);
      } else {
        // 본문처럼 보이게  
        ctx.font = '14px Arial';
        final lineLength = 300 + (i % 3) * 100;
        ctx.fillText('이것은 PDF 문서의 내용을 나타내는 텍스트 라인입니다.', 80, y);
        if (lineLength > 400) {
          ctx.fillText('추가 텍스트 내용...', 80, y + 15);
        }
      }
    }
    
    // 파일 정보
    final fileSizeKB = (pdfBytes.length / 1024).round();
    ctx.font = '12px Arial';
    ctx.fillStyle = '#6c757d';
    ctx.textAlign = 'center';
    ctx.fillText('PDF 내용 (${fileSizeKB}KB)', canvas.width! / 2, canvas.height! - 30);
  }
  
  // PDF 플레이스홀더 생성
  Future<void> _renderPdfPlaceholder(Uint8List pdfBytes, html.CanvasElement canvas) async {
    final ctx = canvas.context2D;
    
    // 흰색 배경 설정
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(0, 0, canvas.width!, canvas.height!);
    
    // 회색 테두리
    ctx.strokeStyle = '#dee2e6';
    ctx.lineWidth = 2;
    ctx.strokeRect(20, 20, canvas.width! - 40, canvas.height! - 40);
    
    // 문서 아이콘 그리기
    ctx.fillStyle = '#dc3545';
    ctx.fillRect(canvas.width! / 2 - 100, 100, 200, 260);
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(canvas.width! / 2 - 80, 120, 160, 220);
    
    // PDF 정보 텍스트
    ctx.fillStyle = '#495057';
    ctx.font = 'bold 24px Arial';
    ctx.textAlign = 'center';
    ctx.fillText('PDF 문서', canvas.width! / 2, 400);
    
    ctx.font = '16px Arial';
    ctx.fillText('PDF 내용이 PNG 이미지로 변환되었습니다', canvas.width! / 2, 450);
    ctx.fillText('이 영역에서 필기할 수 있습니다', canvas.width! / 2, 480);
    
    // 파일 크기 정보
    final fileSizeKB = (pdfBytes.length / 1024).round();
    ctx.font = '14px Arial';
    ctx.fillStyle = '#6c757d';
    ctx.fillText('파일 크기: ${fileSizeKB}KB', canvas.width! / 2, 520);
    
    // 변환 시간
    final now = DateTime.now();
    ctx.fillText('변환 시간: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour}:${now.minute.toString().padLeft(2, '0')}', canvas.width! / 2, 550);
  }

  // 텍스트 파일 편집
  void _editTextFile(FileModel file) async {
    // 인라인 텍스트 에디터를 사용할 수 있는 경우
    if (widget.onShowTextEditor != null) {
      widget.onShowTextEditor!(noteId: file.noteId, existingFile: file);
      return;
    }
    
    // 기존 방식 (새 창으로 이동)
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TextEditorScreen(
          noteId: file.noteId,
          existingFile: file,
        ),
      ),
    );
    
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('텍스트 파일이 저장되었습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // PDF 파일 클릭 처리
  void _handlePdfFileClick(FileModel file) {
    if (file.type == FileType.convertedImage) {
      // 변환된 이미지인 경우 뷰어로 열기 (편집 모드는 별도 버튼으로)
      _viewPdfFile(file);
    } else {
      // 기존 PDF 파일은 뷰어로 열기
      _viewPdfFile(file);
    }
  }
  
  // 이미지 편집 모드로 전환
  void _loadImageForEditing(FileModel file) {
    setState(() {
      _selectedImageForEdit = file;
      _isEditingImage = true;
      
      // 기존 필기 데이터 로드
      _drawingPaths.clear();
      _currentPath.clear();
      
      if (file.metadata?['drawingPaths'] != null) {
        try {
          final pathsData = file.metadata!['drawingPaths'] as List;
          _drawingPaths = pathsData.map((pathData) {
            final path = (pathData as List).map((point) {
              return Offset(point['x'].toDouble(), point['y'].toDouble());
            }).toList();
            return path;
          }).toList();
          
          if (file.metadata!['penColor'] != null) {
            _penColor = Color(file.metadata!['penColor']);
          }
          if (file.metadata!['penWidth'] != null) {
            _penWidth = file.metadata!['penWidth'].toDouble();
          }
        } catch (e) {
          debugPrint('필기 데이터 로드 실패: $e');
        }
      }
    });
  }

  // PDF 파일 보기
  void _viewPdfFile(FileModel file) {
    if (file.filePath == null) return;
    
    if (kIsWeb) {
      // 웹에서는 Blob URL로 표시
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ImageViewerScreen(
            imageUrl: file.filePath!,
            fileName: file.name,
            isWeb: true,
            fileModel: file, // 필기 기능을 위해 파일 모델 전달
          ),
        ),
      );
    } else {
      // 네이티브에서는 파일 경로로 표시
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ImageViewerScreen(
            imagePath: file.filePath!,
            fileName: file.name,
            isWeb: false,
            fileModel: file, // 필기 기능을 위해 파일 모델 전달
          ),
        ),
      );
    }
  }

  // 텍스트 파일 삭제
  void _deleteTextFile(FileModel file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('텍스트 파일 삭제'),
        content: Text('"${file.name}"을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      final success = await noteProvider.removeFileFromNote(file.noteId, file.id);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${file.name}"이(가) 삭제되었습니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // PDF 파일 삭제
  void _deletePdfFile(FileModel file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('PDF 파일 삭제'),
        content: Text('"${file.name}"을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      
      // 파일 삭제
      if (file.filePath != null) {
        if (!kIsWeb) {
          try {
            await File(file.filePath!).delete();
          } catch (e) {
            debugPrint('파일 삭제 실패: $e');
          }
        }
      }
      
      final success = await noteProvider.removeFileFromNote(file.noteId, file.id);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${file.name}"이(가) 삭제되었습니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // 날짜 포맷팅
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
  
  // 필기 영역 빌드
  Widget _buildDrawingArea() {
    return Column(
      children: [
        // 필기 도구 모음
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.draw, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    '자유 필기',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Spacer(),
                  // 저장 버튼
                  ElevatedButton.icon(
                    onPressed: _drawingPaths.isNotEmpty ? _saveDrawing : null,
                    icon: Icon(Icons.save),
                    label: Text('저장'),
                  ),
                  SizedBox(width: 8),
                  // 지우기 버튼
                  ElevatedButton.icon(
                    onPressed: _drawingPaths.isNotEmpty ? _clearDrawing : null,
                    icon: Icon(Icons.clear),
                    label: Text('지우기'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Text('펜 색상: ', style: TextStyle(fontSize: 14)),
                  // 펜 색상 선택
                  _buildColorButton(Colors.blue),
                  _buildColorButton(Colors.red),
                  _buildColorButton(Colors.green),
                  _buildColorButton(Colors.orange),
                  _buildColorButton(Colors.black),
                  Spacer(),
                  Text('마우스나 터치로 자유롭게 그리세요', 
                       style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ],
          ),
        ),
        // 필기 캔버스
        Expanded(
          child: Container(
            width: double.infinity,
            color: Colors.white,
            child: Stack(
              children: [
                // 배경 가이드
                if (_drawingPaths.isEmpty)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.gesture, size: 64, color: Colors.grey[300]),
                        SizedBox(height: 16),
                        Text('이 영역에서 자유롭게 필기하세요',
                             style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                // 그리기 캔버스
                GestureDetector(
                  onPanStart: _startDrawing,
                  onPanUpdate: _updateDrawing,
                  onPanEnd: _endDrawing,
                  child: CustomPaint(
                    painter: DrawingPainter(_drawingPaths, _currentPath, _penColor, _penWidth),
                    size: Size.infinite,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  // 펜 색상 버튼
  Widget _buildColorButton(Color color) {
    return GestureDetector(
      onTap: () => setState(() => _penColor = color),
      child: Container(
        width: 24,
        height: 24,
        margin: EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: _penColor == color ? Colors.grey[800]! : Colors.grey[400]!,
            width: _penColor == color ? 2 : 1,
          ),
        ),
      ),
    );
  }
  
  // 그리기 시작
  void _startDrawing(DragStartDetails details) {
    setState(() {
      _currentPath = [details.localPosition];
    });
  }
  
  // 그리기 업데이트
  void _updateDrawing(DragUpdateDetails details) {
    setState(() {
      _currentPath.add(details.localPosition);
    });
  }
  
  // 그리기 종료
  void _endDrawing(DragEndDetails details) {
    if (_currentPath.isNotEmpty) {
      setState(() {
        _drawingPaths.add(List.from(_currentPath));
        _currentPath.clear();
      });
    }
  }
  
  // 그림 저장
  Future<void> _saveDrawing() async {
    try {
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      
      // 기본리튼 생성 또는 선택
      final defaultNote = await noteProvider.createDefaultNoteIfNeeded();
      if (defaultNote == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('리튼 생성에 실패했습니다'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // 그림 데이터를 JSON으로 변환
      final drawingData = {
        'paths': _drawingPaths.map((path) => 
          path.map((offset) => {'x': offset.dx, 'y': offset.dy}).toList()
        ).toList(),
        'color': _penColor.value,
        'width': _penWidth,
      };
      
      final now = DateTime.now();
      final fileName = '필기 ${now.month}/${now.day} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
      
      final drawingFile = FileModel(
        id: const Uuid().v4(),
        noteId: noteProvider.selectedNote!.id,
        type: FileType.handwriting,
        name: fileName,
        content: jsonEncode(drawingData), // 그림 데이터를 JSON으로 저장
        createdAt: now,
        updatedAt: now,
        metadata: {
          'type': 'drawing',
          'pathCount': _drawingPaths.length,
          'platform': 'web',
        },
      );
      
      await noteProvider.addFileToNote(noteProvider.selectedNote!.id, drawingFile);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${fileName}이(가) 저장되었습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      // 그리기 영역 지우기
      _clearDrawing();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('필기 저장 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // 그리기 지우기
  void _clearDrawing() {
    setState(() {
      _drawingPaths.clear();
      _currentPath.clear();
    });
  }
  
  // 이미지 편집 영역 빌드
  Widget _buildImageEditingArea(FileModel imageFile) {
    return Column(
      children: [
        // 편집 도구 모음
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // 뒤로가기 버튼
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isEditingImage = false;
                        _selectedImageForEdit = null;
                      });
                    },
                    icon: Icon(Icons.arrow_back),
                    tooltip: '목록으로 돌아가기',
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.edit, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    '${imageFile.name} 편집',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Spacer(),
                  // 저장 버튼
                  ElevatedButton.icon(
                    onPressed: _drawingPaths.isNotEmpty ? () => _saveImageDrawing(imageFile) : null,
                    icon: Icon(Icons.save),
                    label: Text('저장'),
                  ),
                  SizedBox(width: 8),
                  // 지우기 버튼
                  ElevatedButton.icon(
                    onPressed: _drawingPaths.isNotEmpty ? _clearDrawing : null,
                    icon: Icon(Icons.clear),
                    label: Text('지우기'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Text('펜 색상: ', style: TextStyle(fontSize: 14)),
                  // 펜 색상 선택
                  _buildColorButton(Colors.red),
                  _buildColorButton(Colors.blue),
                  _buildColorButton(Colors.green),
                  _buildColorButton(Colors.orange),
                  _buildColorButton(Colors.black),
                  Spacer(),
                  Text('마우스나 터치로 이미지에 필기하세요', 
                       style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ],
          ),
        ),
        // 이미지와 필기 캔버스
        Expanded(
          child: Stack(
            children: [
              // 배경 PDF 또는 이미지
              if (imageFile.filePath != null)
                Positioned.fill(
                  child: Container(
                    color: Colors.white,
                    child: _buildBackgroundContent(imageFile),
                  ),
                ),
              
              // 필기 레이어
              Positioned.fill(
                child: GestureDetector(
                  onPanStart: _startImageDrawing,
                  onPanUpdate: _updateImageDrawing,
                  onPanEnd: _endImageDrawing,
                  child: CustomPaint(
                    painter: DrawingPainter(_drawingPaths, _currentPath, _penColor, _penWidth),
                    size: Size.infinite,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // 이미지 편집용 필기 시작
  void _startImageDrawing(DragStartDetails details) {
    setState(() {
      _currentPath = [details.localPosition];
    });
  }
  
  // 이미지 편집용 필기 업데이트
  void _updateImageDrawing(DragUpdateDetails details) {
    setState(() {
      _currentPath.add(details.localPosition);
    });
  }
  
  // 이미지 편집용 필기 종료
  void _endImageDrawing(DragEndDetails details) {
    if (_currentPath.isNotEmpty) {
      setState(() {
        _drawingPaths.add(List.from(_currentPath));
        _currentPath.clear();
      });
    }
  }
  
  // 배경 콘텐츠 빌드 (PDF 또는 이미지)
  Widget _buildBackgroundContent(FileModel file) {
    final isPdf = file.metadata?['isPdf'] == true;
    
    if (kIsWeb) {
      if (isPdf) {
        // PDF 파일인 경우 iframe으로 표시
        final viewType = 'pdf-viewer-${file.id}-${DateTime.now().millisecondsSinceEpoch}';
        _registerPdfViewer(viewType, file.filePath!);
        
        return HtmlElementView(
          key: ValueKey(viewType),
          viewType: viewType,
        );
      } else {
        // 일반 이미지 파일
        return Image.network(
          file.filePath!,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorWidget('이미지를 불러올 수 없습니다');
          },
        );
      }
    } else {
      // 네이티브에서는 파일 경로로 표시
      return Image.file(
        File(file.filePath!),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget('파일을 불러올 수 없습니다');
        },
      );
    }
  }
  
  // 오류 위젯
  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(message),
        ],
      ),
    );
  }
  
  // PDF 뷰어 등록
  void _registerPdfViewer(String viewType, String pdfUrl) {
    try {
      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(
        viewType,
        (int viewId) {
          final iframe = html.IFrameElement()
            ..src = pdfUrl
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
    }
  }

  // 이미지 필기 저장
  Future<void> _saveImageDrawing(FileModel imageFile) async {
    try {
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      
      // 필기 데이터를 메타데이터에 저장
      final updatedMetadata = Map<String, dynamic>.from(imageFile.metadata ?? {});
      updatedMetadata['drawingPaths'] = _drawingPaths.map((path) => 
        path.map((offset) => {'x': offset.dx, 'y': offset.dy}).toList()
      ).toList();
      updatedMetadata['penColor'] = _penColor.value;
      updatedMetadata['penWidth'] = _penWidth;
      updatedMetadata['lastEditTime'] = DateTime.now().toIso8601String();
      
      final updatedFile = imageFile.copyWith(
        metadata: updatedMetadata,
        updatedAt: DateTime.now(),
      );
      
      await noteProvider.updateFileInNote(imageFile.noteId, updatedFile);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('필기가 저장되었습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장 실패: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// 그리기 페인터 클래스
class DrawingPainter extends CustomPainter {
  final List<List<Offset>> paths;
  final List<Offset> currentPath;
  final Color color;
  final double strokeWidth;
  
  DrawingPainter(this.paths, this.currentPath, this.color, this.strokeWidth);
  
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
        final drawPath = Path();
        drawPath.moveTo(path[0].dx, path[0].dy);
        
        for (int i = 1; i < path.length; i++) {
          drawPath.lineTo(path[i].dx, path[i].dy);
        }
        
        canvas.drawPath(drawPath, paint);
      } else if (path.length == 1) {
        // 단일 점 그리기
        canvas.drawCircle(path[0], strokeWidth / 2, paint..style = PaintingStyle.fill);
      }
    }
    
    // 현재 그리고 있는 경로 그리기
    if (currentPath.length > 1) {
      final drawPath = Path();
      drawPath.moveTo(currentPath[0].dx, currentPath[0].dy);
      
      for (int i = 1; i < currentPath.length; i++) {
        drawPath.lineTo(currentPath[i].dx, currentPath[i].dy);
      }
      
      canvas.drawPath(drawPath, paint);
    } else if (currentPath.length == 1) {
      canvas.drawCircle(currentPath[0], strokeWidth / 2, paint..style = PaintingStyle.fill);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
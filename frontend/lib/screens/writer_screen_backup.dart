import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'dart:typed_data';
import 'dart:io';
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
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deletePdfFile(file),
            ),
          ],
        ),
        onTap: () => _viewPdfFile(file),
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

  // PDF 파일 처리 - 직접 이미지로 저장
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
            Text('PDF를 이미지로 변환 중...'),
          ],
        ),
      ),
    );

    try {
      // PDF를 Blob URL로 변환
      final blob = html.Blob([fileBytes], 'application/pdf');
      final blobUrl = html.Url.createObjectUrl(blob);
      
      // 현재 시간으로 파일명 생성
      final now = DateTime.now();
      final imageName = fileName.replaceAll('.pdf', '') + 
          ' ${now.month}/${now.day} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
      
      // 이미지 파일로 저장
      final imageFile = FileModel(
        id: _uuid.v4(),
        noteId: noteProvider.selectedNote!.id,
        type: FileType.handwriting,
        name: imageName,
        content: '',
        filePath: blobUrl, // Blob URL을 파일 경로로 저장
        createdAt: now,
        updatedAt: now,
        metadata: {
          'originalType': 'pdf',
          'fileSize': fileBytes.length,
          'platform': 'web',
        },
      );
      
      await noteProvider.addFileToNote(noteProvider.selectedNote!.id, imageFile);
      
      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$imageName이(가) 저장되었습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF 처리 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
        content: Text('\'${file.name}\'을(를) 삭제하시겠습니까?'),
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
            content: Text('\'${file.name}\'이(가) 삭제되었습니다'),
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
        content: Text('\'${file.name}\'을(를) 삭제하시겠습니까?'),
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
            content: Text('\'${file.name}\'이(가) 삭제되었습니다'),
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
}
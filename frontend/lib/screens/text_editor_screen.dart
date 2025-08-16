import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/note_provider.dart';
import '../models/note_model.dart';
import '../config/app_config.dart';

class TextEditorScreen extends StatefulWidget {
  final String noteId;
  final FileModel? existingFile;
  
  const TextEditorScreen({
    super.key,
    required this.noteId,
    this.existingFile,
  });

  @override
  State<TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<TextEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  final _uuid = const Uuid();
  
  @override
  void initState() {
    super.initState();
    
    // 기존 파일이 있으면 해당 내용으로 초기화, 없으면 빈 내용으로 시작
    _titleController = TextEditingController(
      text: widget.existingFile?.name ?? '새 텍스트 문서',
    );
    _contentController = TextEditingController(
      text: widget.existingFile?.content ?? '',
    );
    
    // 변경사항 감지
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
  
  void _onTextChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvoked: (bool didPop) async {
        if (!didPop && _hasUnsavedChanges) {
          final shouldPop = await _showExitConfirmDialog();
          if (shouldPop == true && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.existingFile != null ? '텍스트 편집' : '새 텍스트 문서',
            style: TextStyle(fontSize: 18),
          ),
          actions: [
            if (_hasUnsavedChanges)
              Container(
                margin: EdgeInsets.only(right: 8),
                child: Center(
                  child: Text(
                    '저장되지 않음',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            IconButton(
              onPressed: _isSaving ? null : _saveFile,
              icon: _isSaving 
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.save),
            ),
          ],
        ),
        body: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // 제목 입력
              TextField(
                controller: _titleController,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: '문서 제목을 입력하세요',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: Icon(Icons.title),
                ),
                maxLines: 1,
              ),
              SizedBox(height: 16),
              
              // 내용 입력
              Expanded(
                child: TextField(
                  controller: _contentController,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: '내용을 작성하세요...\n\n여기에 자유롭게 텍스트를 작성할 수 있습니다.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: EdgeInsets.all(16),
                  ),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                ),
              ),
              
              // 하단 정보
              SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Text(
                    '글자 수: ${_contentController.text.length}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  Spacer(),
                  if (widget.existingFile != null)
                    Text(
                      '마지막 저장: ${_formatDateTime(widget.existingFile!.updatedAt)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _isSaving ? null : _saveFile,
          icon: _isSaving 
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(Icons.save),
          label: Text(_isSaving ? '저장 중...' : '저장'),
          backgroundColor: _hasUnsavedChanges ? null : Colors.grey,
        ),
      ),
    );
  }
  
  // 파일 저장
  Future<void> _saveFile() async {
    if (_isSaving) return;
    
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('제목을 입력해주세요'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      final now = DateTime.now();
      
      if (widget.existingFile != null) {
        // 기존 파일 업데이트
        final updatedFile = widget.existingFile!.copyWith(
          name: title,
          content: content,
          updatedAt: now,
        );
        
        final success = await noteProvider.updateFileInNote(widget.noteId, updatedFile);
        
        if (success && mounted) {
          setState(() {
            _hasUnsavedChanges = false;
          });
          Navigator.of(context).pop(true);
        } else {
          throw Exception('파일 업데이트에 실패했습니다');
        }
      } else {
        // 새 파일 생성
        final newFile = FileModel(
          id: _uuid.v4(),
          noteId: widget.noteId,
          type: FileType.text,
          name: title,
          content: content,
          createdAt: now,
          updatedAt: now,
          metadata: {
            'wordCount': content.length,
            'platform': 'flutter',
          },
        );
        
        final success = await noteProvider.addFileToNote(widget.noteId, newFile);
        
        if (success && mounted) {
          setState(() {
            _hasUnsavedChanges = false;
          });
          Navigator.of(context).pop(true);
        } else {
          throw Exception('파일 생성에 실패했습니다');
        }
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
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
  
  // 나가기 확인 다이얼로그
  Future<bool?> _showExitConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('저장하지 않고 나가시겠습니까?'),
        content: Text('변경된 내용이 저장되지 않습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              // 저장하고 나가기
              await _saveFile();
              if (mounted) {
                Navigator.of(context).pop(true);
              }
            },
            child: Text('저장 후 나가기', style: TextStyle(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('저장 안 함', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  // 날짜 포맷팅
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/note_provider.dart';
import '../config/app_config.dart';

class NoteCreateDialog extends StatefulWidget {
  const NoteCreateDialog({super.key});

  @override
  State<NoteCreateDialog> createState() => _NoteCreateDialogState();
}

class _NoteCreateDialogState extends State<NoteCreateDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isLoading = false;
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<NoteProvider>(
      builder: (context, noteProvider, child) {
        return AlertDialog(
          title: const Text('새 리튼 생성'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 제한 안내 (무료 버전)
                if (noteProvider.noteCount >= AppConfig.maxNotesForFree)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '무료 버전에서는 최대 ${AppConfig.maxNotesForFree}개의 리튼만 생성할 수 있습니다.',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // 제목 입력
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '제목',
                    hintText: '리튼 제목을 입력하세요',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  autofocus: true,
                ),
                
                const SizedBox(height: 16),
                
                // 설명 입력
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: '설명 (선택사항)',
                    hintText: '간단한 설명을 입력하세요',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.done,
                  maxLines: 3,
                  onSubmitted: (_) => _createNote(noteProvider),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: _isLoading 
                  ? null
                  : noteProvider.noteCount >= AppConfig.maxNotesForFree
                      ? _showUpgradeDialog
                      : () => _createNote(noteProvider),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : noteProvider.noteCount >= AppConfig.maxNotesForFree
                      ? const Text('업그레이드')
                      : const Text('생성'),
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _createNote(NoteProvider noteProvider) async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('제목을 입력해주세요'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final note = await noteProvider.createNote(title, description: description);
      
      if (note != null && mounted) {
        // 생성된 리튼을 자동으로 선택
        noteProvider.selectNote(note.id);
        
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('\'${note.title}\' 생성 완료'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('리튼 생성 실패: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('스탠다드로 업그레이드'),
        content: const Text(
          '무료 버전에서는 최대 5개의 리튼만 생성할 수 있습니다.\n'
          '스탠다드 버전으로 업그레이드하면:\n\n'
          '• 무제한 리튼 생성\n'
          '• 무제한 파일 저장\n'
          '• 광고 제거\n'
          '• 클라우드 동기화',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('나중에'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(false);
              // TODO: 업그레이드 화면으로 이동
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('업그레이드 기능은 곧 제공될 예정입니다'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('업그레이드'),
          ),
        ],
      ),
    );
  }
}
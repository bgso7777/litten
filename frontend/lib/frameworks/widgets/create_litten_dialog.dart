import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../config/app_config.dart';
import '../providers/litten_provider.dart';

/// 리튼 생성 다이얼로그
class CreateLittenDialog extends StatefulWidget {
  const CreateLittenDialog({Key? key}) : super(key: key);

  @override
  State<CreateLittenDialog> createState() => _CreateLittenDialogState();
}

class _CreateLittenDialogState extends State<CreateLittenDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return AlertDialog(
      title: Text(l10n.createLitten),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 제목 입력
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '제목',
                hintText: '리튼 제목을 입력하세요',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '제목을 입력해주세요';
                }
                if (value.trim().length > 50) {
                  return '제목은 50자 이하로 입력해주세요';
                }
                return null;
              },
              autofocus: true,
              maxLength: 50,
            ),
            const SizedBox(height: 16),
            
            // 설명 입력 (선택사항)
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '설명 (선택사항)',
                hintText: '리튼에 대한 간단한 설명',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 200,
              validator: (value) {
                if (value != null && value.length > 200) {
                  return '설명은 200자 이하로 입력해주세요';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        Consumer<LittenProvider>(
          builder: (context, littenProvider, child) {
            return ElevatedButton(
              onPressed: _isCreating ? null : () => _createLitten(context, littenProvider),
              child: _isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.createLitten),
            );
          },
        ),
      ],
    );
  }

  /// 리튼 생성
  Future<void> _createLitten(BuildContext context, LittenProvider littenProvider) async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isCreating = true;
    });
    
    AppConfig.logDebug('CreateLittenDialog._createLitten - 리튼 생성 시작');
    
    try {
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();
      
      final newLitten = await littenProvider.createLitten(title, description: description);
      
      if (newLitten != null) {
        // 성공
        AppConfig.logInfo('CreateLittenDialog._createLitten - 리튼 생성 성공: $title');
        
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('리튼 "$title"이 생성되었습니다'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // 실패 (에러 메시지는 LittenProvider에서 설정됨)
        AppConfig.logWarning('CreateLittenDialog._createLitten - 리튼 생성 실패');
        
        if (context.mounted) {
          final errorMessage = littenProvider.errorMessage ?? '리튼 생성에 실패했습니다';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (error, stackTrace) {
      AppConfig.logError('CreateLittenDialog._createLitten - 리튼 생성 예외', error, stackTrace);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('리튼 생성 중 오류가 발생했습니다'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }
}
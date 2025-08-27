import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_localizations_temp.dart';

import '../services/app_state_provider.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/home/litten_item.dart';
import '../config/themes.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showCreateLittenDialog() {
    final l10n = AppLocalizations.of(context);
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    
    if (!appState.canCreateMoreLittens) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('무료 사용자는 최대 5개의 리튼만 생성할 수 있습니다. 업그레이드하여 무제한으로 생성하세요!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    _titleController.clear();
    _descriptionController.clear();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.createLitten ?? '리튼 생성'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '제목',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            AppSpacing.verticalSpaceM,
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '설명 (선택사항)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = _titleController.text.trim();
              if (title.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('제목을 입력해주세요.')),
                );
                return;
              }
              
              try {
                await appState.createLitten(
                  title,
                  description: _descriptionController.text.trim().isEmpty
                      ? null
                      : _descriptionController.text.trim(),
                );
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$title 리튼이 생성되었습니다.')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('오류: $e')),
                );
              }
            },
            child: const Text('생성'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return Scaffold(
          body: appState.littens.isEmpty
              ? EmptyState(
                  icon: Icons.note_add,
                  title: l10n?.emptyLittenTitle ?? '리튼을 생성하거나 선택하세요',
                  description: l10n?.emptyLittenDescription ?? '하단의 \'리튼 생성\' 버튼을 사용해서 첫 번째 노트를 시작하세요',
                  actionText: l10n?.createLitten ?? '리튼 생성',
                  onAction: _showCreateLittenDialog,
                )
              : RefreshIndicator(
                  onRefresh: appState.refreshLittens,
                  child: ListView.builder(
                    padding: AppSpacing.paddingL,
                    itemCount: appState.littens.length,
                    itemBuilder: (context, index) {
                      final litten = appState.littens[index];
                      return LittenItem(
                        litten: litten,
                        isSelected: appState.selectedLitten?.id == litten.id,
                        onTap: () => appState.selectLitten(litten),
                        onDelete: () => _showDeleteDialog(litten.id, litten.title),
                      );
                    },
                  ),
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: _showCreateLittenDialog,
            tooltip: l10n?.createLitten ?? '리튼 생성',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _showDeleteDialog(String littenId, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('리튼 삭제'),
        content: Text('\'$title\' 리튼을 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없으며, 관련된 모든 파일이 함께 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final appState = Provider.of<AppStateProvider>(context, listen: false);
              await appState.deleteLitten(littenId);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$title 리튼이 삭제되었습니다.')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
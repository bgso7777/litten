import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../config/app_config.dart';
import '../../providers/litten_provider.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/create_litten_dialog.dart';

/// 홈 화면 - 리튼 목록 표시
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    AppConfig.logDebug('HomeScreen.build - 홈 화면 빌드');
    
    return Scaffold(
      body: Consumer<LittenProvider>(
        builder: (context, littenProvider, child) {
          if (littenProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          
          if (littenProvider.errorMessage != null) {
            return _buildErrorState(context, l10n, littenProvider);
          }
          
          if (littenProvider.littens.isEmpty) {
            return _buildEmptyState(context, l10n);
          }
          
          return _buildLittenList(context, l10n, littenProvider);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateLittenDialog(context, l10n),
        tooltip: l10n.createLitten,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// 에러 상태 위젯
  Widget _buildErrorState(
    BuildContext context,
    AppLocalizations l10n,
    LittenProvider littenProvider,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.errorTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              littenProvider.errorMessage ?? l10n.errorGeneral,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              littenProvider.clearError();
              littenProvider.loadLittens();
            },
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  /// 빈 상태 위젯
  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return EmptyStateWidget(
      icon: Icons.sticky_note_2_outlined,
      title: l10n.noLittensMessage,
      subtitle: l10n.noLittensSubtitle,
      actionText: l10n.createLitten,
      onActionPressed: () => _showCreateLittenDialog(context, l10n),
    );
  }

  /// 리튼 목록 위젯
  Widget _buildLittenList(
    BuildContext context,
    AppLocalizations l10n,
    LittenProvider littenProvider,
  ) {
    return RefreshIndicator(
      onRefresh: () => littenProvider.loadLittens(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: littenProvider.littens.length,
        itemBuilder: (context, index) {
          final litten = littenProvider.littens[index];
          final isSelected = littenProvider.selectedLitten?.id == litten.id;
          
          return Card(
            elevation: isSelected ? 4 : 2,
            color: isSelected 
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Icon(
                Icons.folder,
                size: 32,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.primary,
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      litten.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : null,
                      ),
                    ),
                  ),
                  _buildFileCountBadges(litten),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (litten.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      litten.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8)
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _formatDateTime(litten.updatedAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7)
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) => _handleMenuAction(value, litten, littenProvider),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('편집'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('삭제', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
              onTap: () {
                AppConfig.logDebug('HomeScreen - 리튼 선택: ${litten.title}');
                littenProvider.selectLitten(litten);
              },
            ),
          );
        },
      ),
    );
  }

  /// 파일 수 배지들
  Widget _buildFileCountBadges(litten) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (litten.audioFileCount > 0) ...[
          _buildFileCountBadge(Icons.mic, litten.audioFileCount, Colors.red),
          const SizedBox(width: 4),
        ],
        if (litten.textFileCount + litten.drawingFileCount > 0) ...[
          _buildFileCountBadge(
            Icons.edit,
            litten.textFileCount + litten.drawingFileCount,
            Colors.green,
          ),
        ],
      ],
    );
  }

  Widget _buildFileCountBadge(IconData icon, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// 메뉴 액션 처리
  void _handleMenuAction(String action, litten, LittenProvider littenProvider) {
    switch (action) {
      case 'edit':
        _editLitten(litten, littenProvider);
        break;
      case 'delete':
        _deleteLitten(litten, littenProvider);
        break;
    }
  }

  /// 리튼 편집
  void _editLitten(litten, LittenProvider littenProvider) {
    // TODO: 리튼 편집 다이얼로그 구현
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('편집 기능은 곧 구현됩니다')),
    );
  }

  /// 리튼 삭제
  void _deleteLitten(litten, LittenProvider littenProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('리튼 삭제'),
        content: Text('정말로 "${litten.title}"을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              littenProvider.deleteLitten(litten.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  /// 리튼 생성 다이얼로그
  void _showCreateLittenDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => const CreateLittenDialog(),
    );
  }

  /// 날짜/시간 포맷
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      // 오늘
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      // 이번 주
      final weekdays = ['일', '월', '화', '수', '목', '금', '토'];
      return '${weekdays[dateTime.weekday % 7]} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      // 그 이전
      return '${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}
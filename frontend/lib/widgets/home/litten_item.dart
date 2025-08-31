import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/litten.dart';
import '../../config/themes.dart';
import '../../l10n/app_localizations.dart';

class LittenItem extends StatelessWidget {
  final Litten litten;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onLongPress;

  const LittenItem({
    super.key,
    required this.litten,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MM/dd HH:mm');
    final l10n = AppLocalizations.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: AppSpacing.paddingL,
          child: Row(
            children: [
              // Leading icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.folder_outlined,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
              ),
              AppSpacing.horizontalSpaceM,
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and badges row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            litten.title,
                            style: AppTextStyles.headline3,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        AppSpacing.horizontalSpaceS,
                        // File count badges (녹음, 텍스트, 필기 순서 - 항상 표시)
                        Row(
                          children: [
                            _buildFileBadge(
                              Icons.hearing,
                              litten.audioCount,
                              litten.audioCount > 0 
                                  ? AppColors.recordingColor 
                                  : AppColors.recordingColor.withValues(alpha: 0.3),
                              isActive: litten.audioCount > 0,
                            ),
                            AppSpacing.horizontalSpaceXS,
                            _buildFileBadge(
                              Icons.keyboard,
                              litten.textCount,
                              litten.textCount > 0 
                                  ? AppColors.writingColor 
                                  : AppColors.writingColor.withValues(alpha: 0.3),
                              isActive: litten.textCount > 0,
                            ),
                            AppSpacing.horizontalSpaceXS,
                            _buildFileBadge(
                              Icons.draw,
                              litten.handwritingCount,
                              litten.handwritingCount > 0 
                                  ? AppColors.writingColor.withValues(alpha: 0.8)
                                  : AppColors.writingColor.withValues(alpha: 0.2),
                              isActive: litten.handwritingCount > 0,
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Description
                    if (litten.description != null && litten.description!.isNotEmpty) ...[
                      AppSpacing.verticalSpaceXS,
                      Text(
                        litten.description!,
                        style: AppTextStyles.bodyText2.copyWith(
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    AppSpacing.verticalSpaceXS,
                    // Date
                    Text(
                      dateFormat.format(litten.updatedAt),
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.horizontalSpaceS,
              // Delete button
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                color: Colors.red.shade400,
                iconSize: 20,
                tooltip: l10n?.delete ?? '삭제',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileBadge(IconData icon, int count, Color color, {bool isActive = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 10,
            color: isActive ? Colors.white : Colors.white70,
          ),
          const SizedBox(width: 2),
          Text(
            count.toString(),
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
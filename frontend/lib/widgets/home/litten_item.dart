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
    final timeFormat = DateFormat('HH:mm');
    final l10n = AppLocalizations.of(context);
    
    return Draggable<String>(
      data: litten.id,
      feedback: Material(
        elevation: 8,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Icon(
            Icons.folder_outlined,
            color: Colors.white,
            size: 12,
          ),
        ),
      ),
      feedbackOffset: const Offset(-10, -10), // 아이콘 중앙이 터치 위치에 오도록 조정
      dragAnchorStrategy: pointerDragAnchorStrategy, // 터치한 위치에서 드래그 시작
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300, width: 1),
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
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.folder_outlined,
                      color: Colors.grey.shade400,
                      size: 24,
                    ),
                  ),
                  AppSpacing.horizontalSpaceM,
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title, time and badges row
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      litten.title,
                                      style: AppTextStyles.headline3.copyWith(
                                        color: Colors.grey.shade400,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  AppSpacing.horizontalSpaceS,
                                  // Time
                                  Text(
                                    timeFormat.format(litten.updatedAt),
                                    style: AppTextStyles.caption.copyWith(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AppSpacing.horizontalSpaceS,
                            // File count badges (greyed out)
                            Row(
                              children: [
                                _buildFileBadge(
                                  Icons.hearing,
                                  litten.audioCount,
                                  Colors.grey.shade300,
                                  isActive: false,
                                ),
                                AppSpacing.horizontalSpaceXS,
                                _buildFileBadge(
                                  Icons.keyboard,
                                  litten.textCount,
                                  Colors.grey.shade300,
                                  isActive: false,
                                ),
                                AppSpacing.horizontalSpaceXS,
                                _buildFileBadge(
                                  Icons.draw,
                                  litten.handwritingCount,
                                  Colors.grey.shade300,
                                  isActive: false,
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
                              color: Colors.grey.shade300,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  AppSpacing.horizontalSpaceS,
                  // Delete button (greyed out)
                  IconButton(
                    onPressed: null,
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.grey.shade300,
                    iconSize: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      child: Card(
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
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
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
                    // Title, time and badges row
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  litten.title,
                                  style: AppTextStyles.headline3,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              AppSpacing.horizontalSpaceS,
                              // Time
                              Text(
                                timeFormat.format(litten.updatedAt),
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
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
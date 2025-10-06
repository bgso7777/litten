import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/litten.dart';
import '../../config/themes.dart';
import '../../l10n/app_localizations.dart';
import '../../services/app_state_provider.dart';

class LittenItem extends StatefulWidget {
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
  State<LittenItem> createState() => _LittenItemState();
}

class _LittenItemState extends State<LittenItem> {
  bool _isHighlighted = false;

  @override
  void initState() {
    super.initState();
    // 알림이 있는지 확인하고 강조 표시 상태 설정
    _checkNotificationStatus();
  }

  void _checkNotificationStatus() {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final hasNotifications = appState.hasNotificationForLitten(widget.litten.id);

    if (hasNotifications && !_isHighlighted) {
      setState(() {
        _isHighlighted = true;
      });
    }
  }

  void _handleTap() {
    if (_isHighlighted) {
      // 강조 표시된 상태에서 터치하면 원래 색으로 복원
      setState(() {
        _isHighlighted = false;
      });

      // 해당 리튼의 발생한 알림만 제거 (대기 중인 알림은 유지)
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      final notificationsToRemove = appState.notificationService.firedNotifications
          .where((notification) => notification.littenId == widget.litten.id)
          .toList();

      for (final notification in notificationsToRemove) {
        appState.notificationService.dismissNotification(notification);
      }
    }

    // 원래 onTap 콜백 호출
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    final l10n = AppLocalizations.of(context);

    // 알림 상태 실시간 체크
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        final hasNotifications = appState.hasNotificationForLitten(widget.litten.id);

        // 새로운 알림이 발생했을 때 강조 표시 업데이트
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (hasNotifications && !_isHighlighted) {
            setState(() {
              _isHighlighted = true;
            });
          }
        });

        return _buildLittenItem(context, timeFormat, l10n);
      },
    );
  }

  Widget _buildLittenItem(BuildContext context, DateFormat timeFormat, l10n) {
    
    return Draggable<String>(
      data: widget.litten.id,
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
          margin: EdgeInsets.only(bottom: AppSpacing.s),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          child: InkWell(
            onTap: _handleTap,
            onLongPress: widget.onLongPress,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.m),
              child: Row(
                children: [
                  // Leading icon
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.folder_outlined,
                      color: Colors.grey.shade400,
                      size: 20,
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
                                      widget.litten.title,
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
                                    timeFormat.format(widget.litten.updatedAt),
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
                                  Icons.mic,
                                  widget.litten.audioCount,
                                  Colors.grey.shade300,
                                  isActive: false,
                                ),
                                AppSpacing.horizontalSpaceXS,
                                _buildFileBadge(
                                  Icons.keyboard,
                                  widget.litten.textCount,
                                  Colors.grey.shade300,
                                  isActive: false,
                                ),
                                AppSpacing.horizontalSpaceXS,
                                _buildFileBadge(
                                  Icons.draw,
                                  widget.litten.handwritingCount,
                                  Colors.grey.shade300,
                                  isActive: false,
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Schedule information
                        if (widget.litten.schedule != null) ...[
                          AppSpacing.verticalSpaceXS,
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Theme.of(context).primaryColor.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 16,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.litten.schedule!.startTime.format(context)} - ${widget.litten.schedule!.endTime.format(context)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (widget.litten.schedule!.notes != null && widget.litten.schedule!.notes!.isNotEmpty) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.note,
                                    size: 14,
                                    color: Theme.of(context).primaryColor.withOpacity(0.7),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        // Description
                        if (widget.litten.description != null && widget.litten.description!.isNotEmpty) ...[
                          AppSpacing.verticalSpaceXS,
                          Text(
                            widget.litten.description!,
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
        margin: EdgeInsets.only(bottom: AppSpacing.s),
        elevation: widget.isSelected ? 4 : (_isHighlighted ? 6 : 2),
        color: _isHighlighted ? Colors.orange.shade50 : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: widget.isSelected
              ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
              : _isHighlighted
                  ? BorderSide(color: Colors.orange, width: 2)
                  : BorderSide.none,
        ),
        child: InkWell(
          onTap: _handleTap,
          onLongPress: widget.onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.m),
            child: Row(
            children: [
              // Leading icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.folder_outlined,
                  color: Theme.of(context).primaryColor,
                  size: 20,
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
                                  widget.litten.title,
                                  style: AppTextStyles.headline3,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              AppSpacing.horizontalSpaceS,
                              // Time
                              Text(
                                timeFormat.format(widget.litten.updatedAt),
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
                              Icons.mic,
                              widget.litten.audioCount,
                              widget.litten.audioCount > 0
                                  ? Theme.of(context).primaryColor
                                  : Theme.of(context).primaryColor.withValues(alpha: 0.3),
                              isActive: widget.litten.audioCount > 0,
                            ),
                            AppSpacing.horizontalSpaceXS,
                            _buildFileBadge(
                              Icons.keyboard,
                              widget.litten.textCount,
                              widget.litten.textCount > 0
                                  ? Theme.of(context).primaryColor
                                  : Theme.of(context).primaryColor.withValues(alpha: 0.3),
                              isActive: widget.litten.textCount > 0,
                            ),
                            AppSpacing.horizontalSpaceXS,
                            _buildFileBadge(
                              Icons.draw,
                              widget.litten.handwritingCount,
                              widget.litten.handwritingCount > 0
                                  ? Theme.of(context).primaryColor
                                  : Theme.of(context).primaryColor.withValues(alpha: 0.3),
                              isActive: widget.litten.handwritingCount > 0,
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Description
                    if (widget.litten.description != null && widget.litten.description!.isNotEmpty) ...[
                      AppSpacing.verticalSpaceXS,
                      Text(
                        widget.litten.description!,
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
                onPressed: widget.onDelete,
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
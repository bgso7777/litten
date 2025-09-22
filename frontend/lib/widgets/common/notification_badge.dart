import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/app_state_provider.dart';
import '../../services/notification_service.dart';
import '../../l10n/app_localizations.dart';

class NotificationBadge extends StatelessWidget {
  const NotificationBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return AnimatedBuilder(
          animation: appState.notificationService,
          builder: (context, child) {
            final firedNotifications = appState.notificationService.firedNotifications;
            final pendingNotifications = appState.notificationService.pendingNotifications;

            // 디버깅을 위해 항상 표시 (알림이 있거나 대기 중인 알림이 있을 때)
            if (firedNotifications.isEmpty && pendingNotifications.isEmpty) {
              // 최소한 디버그용 배지는 표시
              return Positioned(
                top: 16,
                right: 16,
                child: GestureDetector(
                  onTap: () => _showNotificationPanel(context, appState.notificationService),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.notifications_none,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              );
            }

            return Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => _showNotificationPanel(context, appState.notificationService),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.notifications,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${firedNotifications.length}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showNotificationPanel(BuildContext context, NotificationService notificationService) {
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.blue),
            const SizedBox(width: 8),
            Text(l10n?.notifications ?? '알림'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 디버깅 정보
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '디버깅 정보:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('대기 중인 알림: ${notificationService.pendingNotifications.length}개'),
                    Text('발생한 알림: ${notificationService.firedNotifications.length}개'),
                    Text('현재 시간: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 알림 목록
              Expanded(
                child: notificationService.firedNotifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_off,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n?.noNotifications ?? '발생한 알림이 없습니다',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                            if (notificationService.pendingNotifications.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                '${notificationService.pendingNotifications.length}개의 알림이 대기 중입니다',
                                style: TextStyle(
                                  color: Colors.blue.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
              : ListView.builder(
                  itemCount: notificationService.firedNotifications.length,
                  itemBuilder: (context, index) {
                    final notification = notificationService.firedNotifications[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor,
                          child: const Icon(
                            Icons.schedule,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          notification.littenTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(notification.message),
                            const SizedBox(height: 4),
                            Text(
                              notification.timingDescription,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            notificationService.dismissNotification(notification);
                          },
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          // 디버깅 버튼들
          TextButton(
            onPressed: () {
              notificationService.manualCheckNotifications();
            },
            child: Text('수동 체크'),
          ),
          TextButton(
            onPressed: () {
              notificationService.createTestNotification('테스트 알림');
            },
            child: Text('테스트 알림'),
          ),
          if (notificationService.firedNotifications.isNotEmpty)
            TextButton(
              onPressed: () {
                notificationService.clearAllNotifications();
                Navigator.of(context).pop();
              },
              child: Text(l10n?.clearAll ?? '모두 지우기'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.close ?? '닫기'),
          ),
        ],
      ),
    );
  }
}
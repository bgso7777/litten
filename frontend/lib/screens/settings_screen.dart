import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/note_provider.dart';
import '../services/subscription_service.dart';
import '../l10n/app_localizations.dart';
import '../config/app_config.dart';
import '../services/preferences_service.dart';
import 'subscription_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _subscriptionType = 'free';
  
  @override
  void initState() {
    super.initState();
    _loadSubscriptionType();
  }
  
  Future<void> _loadSubscriptionType() async {
    final subscriptionType = PreferencesService.getSubscriptionType();
    setState(() {
      _subscriptionType = subscriptionType;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer3<LocaleProvider, ThemeProvider, SubscriptionService>(
      builder: (context, localeProvider, themeProvider, subscriptionService, child) {
        
        return Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 구독 정보 카드
              _buildSubscriptionCard(subscriptionService),
              const SizedBox(height: 16),
              
              // 앱 설정 섹션
              _buildSectionTitle('앱 설정'),
              _buildSettingsList([
                _buildLanguageSetting(localeProvider),
                _buildThemeSetting(themeProvider),
                _buildAutoSaveSetting(),
                _buildRecordingTimeSetting(),
              ]),
              const SizedBox(height: 16),
              
              // 데이터 관리 섹션
              _buildSectionTitle('데이터 관리'),
              _buildSettingsList([
                _buildBackupSetting(),
                _buildClearDataSetting(),
              ]),
              const SizedBox(height: 16),
              
              // 정보 섹션
              _buildSectionTitle('정보'),
              _buildSettingsList([
                _buildVersionSetting(),
                _buildHelpSetting(),
                _buildPrivacySetting(),
              ]),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildSubscriptionCard(SubscriptionService subscriptionService) {
    final currentType = subscriptionService.currentType;
    final subscription = subscriptionService.currentSubscription;
    
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () => _navigateToSubscription(),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getSubscriptionIcon(currentType),
                    size: 28,
                    color: _getSubscriptionColor(currentType),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentType.displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          currentType.description,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                ],
              ),
              
              if (subscription != null && !subscriptionService.isFreePlan) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '상태: ${subscription.isValid ? '활성' : '만료됨'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: subscription.isValid ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subscription.daysRemaining != null)
                      Text(
                        '${subscription.daysRemaining}일 남음',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ],
              
              if (subscriptionService.isFreePlan) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _navigateToSubscription(),
                    icon: const Icon(Icons.upgrade, size: 18),
                    label: const Text('업그레이드'),
                  ),
                ),
              ],
              
              if (subscriptionService.needsRenewalNotification) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '구독 갱신이 필요합니다',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
  
  Widget _buildSettingsList(List<Widget> items) {
    if (items.isEmpty) {
      return const Card(
        child: SizedBox.shrink(),
      );
    }
    
    return Card(
      child: Column(
        children: items
            .expand((item) => [item, const Divider(height: 1)])
            .take((items.length * 2 - 1).clamp(0, items.length * 2))
            .toList(),
      ),
    );
  }
  
  Widget _buildLanguageSetting(LocaleProvider localeProvider) {
    return ListTile(
      leading: const Icon(Icons.language),
      title: const Text('언어'),
      subtitle: Text(localeProvider.getLanguageDisplayName(localeProvider.locale.languageCode)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showLanguageDialog(localeProvider),
    );
  }
  
  Widget _buildThemeSetting(ThemeProvider themeProvider) {
    return ListTile(
      leading: const Icon(Icons.palette),
      title: const Text('테마'),
      subtitle: Text(themeProvider.getThemeDisplayName(themeProvider.currentThemeName)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showThemeDialog(themeProvider),
    );
  }
  
  Widget _buildAutoSaveSetting() {
    return ListTile(
      leading: const Icon(Icons.save),
      title: const Text('자동 저장'),
      subtitle: Text('${PreferencesService.getAutoSaveInterval()}초마다'),
      trailing: const Icon(Icons.chevron_right),
      onTap: _showAutoSaveDialog,
    );
  }
  
  Widget _buildRecordingTimeSetting() {
    return ListTile(
      leading: const Icon(Icons.timer),
      title: const Text('최대 녹음 시간'),
      subtitle: Text('${PreferencesService.getMaxRecordingDuration()}분'),
      trailing: const Icon(Icons.chevron_right),
      onTap: _showRecordingTimeDialog,
    );
  }
  
  Widget _buildBackupSetting() {
    return ListTile(
      leading: const Icon(Icons.backup),
      title: const Text('데이터 백업'),
      subtitle: const Text('로컬 데이터 백업/복원'),
      trailing: const Icon(Icons.chevron_right),
      onTap: _showBackupDialog,
    );
  }
  
  Widget _buildClearDataSetting() {
    return ListTile(
      leading: const Icon(Icons.delete_sweep, color: Colors.red),
      title: const Text('모든 데이터 삭제', style: TextStyle(color: Colors.red)),
      subtitle: const Text('앱의 모든 데이터를 삭제합니다'),
      onTap: _showClearDataDialog,
    );
  }
  
  Widget _buildVersionSetting() {
    return ListTile(
      leading: const Icon(Icons.info),
      title: const Text('앱 버전'),
      subtitle: Text('${AppConfig.appName} ${AppConfig.appVersion}'),
    );
  }
  
  Widget _buildHelpSetting() {
    return ListTile(
      leading: const Icon(Icons.help),
      title: const Text('도움말'),
      subtitle: const Text('사용법 및 FAQ'),
      trailing: const Icon(Icons.chevron_right),
      onTap: _showHelpDialog,
    );
  }
  
  Widget _buildPrivacySetting() {
    return ListTile(
      leading: const Icon(Icons.privacy_tip),
      title: const Text('개인정보 처리방침'),
      trailing: const Icon(Icons.chevron_right),
      onTap: _showPrivacyDialog,
    );
  }
  
  void _showLanguageDialog(LocaleProvider localeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('언어 선택'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: AppConfig.supportedLocales.length,
            itemBuilder: (context, index) {
              final locale = AppConfig.supportedLocales[index];
              final isSelected = locale.languageCode == localeProvider.locale.languageCode;
              
              return RadioListTile<String>(
                title: Text(localeProvider.getLanguageDisplayName(locale.languageCode)),
                value: locale.languageCode,
                groupValue: localeProvider.locale.languageCode,
                onChanged: (value) {
                  if (value != null) {
                    localeProvider.setLanguageByCode(value);
                    Navigator.of(context).pop();
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }
  
  void _showThemeDialog(ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('테마 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: themeProvider.availableThemes.map((themeName) {
            return RadioListTile<String>(
              title: Text(themeProvider.getThemeDisplayName(themeName)),
              value: themeName,
              groupValue: themeProvider.currentThemeName,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setTheme(value);
                  Navigator.of(context).pop();
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }
  
  void _showAutoSaveDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('자동 저장 간격'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppConfig.autoSaveIntervals.map((interval) {
            final current = PreferencesService.getAutoSaveInterval();
            return RadioListTile<int>(
              title: Text('${interval}초'),
              value: interval,
              groupValue: current,
              onChanged: (value) {
                if (value != null) {
                  PreferencesService.setAutoSaveInterval(value);
                  Navigator.of(context).pop();
                  setState(() {}); // UI 업데이트
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }
  
  void _showRecordingTimeDialog() {
    final options = [30, 60, 120, 180]; // 30분, 1시간, 2시간, 3시간
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('최대 녹음 시간'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((minutes) {
            final current = PreferencesService.getMaxRecordingDuration();
            return RadioListTile<int>(
              title: Text(minutes >= 60 ? '${minutes ~/ 60}시간' : '${minutes}분'),
              value: minutes,
              groupValue: current,
              onChanged: (value) {
                if (value != null) {
                  PreferencesService.setMaxRecordingDuration(value);
                  Navigator.of(context).pop();
                  setState(() {}); // UI 업데이트
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }
  
  void _navigateToSubscription() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SubscriptionScreen(),
      ),
    );
  }

  IconData _getSubscriptionIcon(dynamic type) {
    if (type.toString().contains('free')) return Icons.free_breakfast;
    if (type.toString().contains('standard')) return Icons.star;
    if (type.toString().contains('premium')) return Icons.diamond;
    return Icons.free_breakfast;
  }

  Color _getSubscriptionColor(dynamic type) {
    if (type.toString().contains('free')) return Colors.grey;
    if (type.toString().contains('standard')) return Colors.orange;
    if (type.toString().contains('premium')) return Colors.purple;
    return Colors.grey;
  }
  
  void _showBackupDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('백업 기능은 곧 구현될 예정입니다'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('모든 데이터 삭제'),
        content: const Text(
          '정말로 모든 데이터를 삭제하시겠습니까?\n'
          '이 작업은 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('데이터 삭제 기능은 곧 구현될 예정입니다'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
  
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('도움말'),
        content: const SingleChildScrollView(
          child: Text(
            '리튼 앱 사용법:\n\n'
            '1. 홈 탭에서 새 리튼을 생성하세요\n'
            '2. 듣기 탭에서 음성을 녹음하세요\n'
            '3. 쓰기 탭에서 텍스트나 필기를 추가하세요\n'
            '4. 설정에서 언어와 테마를 변경할 수 있습니다\n\n'
            '음성-쓰기 동기화:\n'
            '녹음 중 텍스트나 필기를 작성하면 자동으로 음성 위치와 연결됩니다.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
  
  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('개인정보 처리방침'),
        content: const SingleChildScrollView(
          child: Text(
            '리튼 앱은 사용자의 개인정보를 보호합니다.\n\n'
            '수집하는 정보:\n'
            '• 앱 사용 통계 (익명)\n'
            '• 오류 보고서 (익명)\n\n'
            '수집하지 않는 정보:\n'
            '• 개인 식별 정보\n'
            '• 녹음된 음성 내용\n'
            '• 작성된 텍스트 내용\n\n'
            '모든 노트와 파일은 사용자 기기에만 저장됩니다.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
  
  String _getSubscriptionName(String type) {
    switch (type) {
      case 'standard':
        return '스탠다드';
      case 'premium':
        return '프리미엄';
      default:
        return '무료';
    }
  }
  
  String _getSubscriptionDescription(String type) {
    switch (type) {
      case 'standard':
        return '광고 없음, 무제한 파일, 클라우드 동기화';
      case 'premium':
        return '모든 기능, 웹 접근, 고급 분석';
      default:
        return '기본 기능, 광고 포함, 파일 수 제한';
    }
  }
}
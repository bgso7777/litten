import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';

import '../services/app_state_provider.dart';
import '../services/background_notification_service.dart';
import '../config/themes.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return ListView(
          padding: AppSpacing.paddingL,
          children: [
            // 계정 및 구독 섹션
            _buildSettingsSection(
              l10n?.accountAndSubscription ?? '계정 및 구독',
              [
                _buildSettingsItem(
                  icon: Icons.person,
                  title: l10n?.userStatus ?? '사용자 상태',
                  subtitle: _getSubscriptionStatusText(appState.subscriptionType, l10n),
                  iconColor: _getSubscriptionColor(appState.subscriptionType),
                ),
                _buildSettingsItem(
                  icon: Icons.bar_chart,
                  title: l10n?.usageStatistics ?? '사용량 통계',
                  subtitle: '${appState.littens.length}${l10n?.littensCount ?? '개 리튼'}, ${_getTotalFileCount(appState)}${l10n?.filesCount ?? '개 파일'}',
                  iconColor: Colors.blue,
                  onTap: () => _showUsageDialog(context, appState),
                ),
                if (appState.subscriptionType == SubscriptionType.free) ...[
                  _buildSettingsItem(
                    icon: Icons.upgrade,
                    title: l10n?.upgrade ?? '프리미엄 업그레이드',
                    subtitle: l10n?.removeAdsAndUnlimited ?? '광고 제거 및 무제한 기능',
                    iconColor: Colors.orange,
                    onTap: () => _showUpgradeDialog(context, appState),
                  ),
                ],
              ],
            ),
            AppSpacing.verticalSpaceL,
            
            // 앱 설정 섹션
            _buildSettingsSection(
              l10n?.appSettings ?? '앱 설정',
              [
                _buildSettingsItem(
                  icon: Icons.palette,
                  title: l10n?.theme ?? '테마',
                  subtitle: _getThemeText(appState.themeType, l10n),
                  iconColor: Colors.purple,
                  onTap: () => _showThemeDialog(context, appState),
                ),
                _buildSettingsItem(
                  icon: Icons.language,
                  title: l10n?.language ?? '언어',
                  subtitle: _getLanguageText(appState.locale.languageCode),
                  iconColor: Colors.green,
                  onTap: () => _showLanguageDialog(context, appState),
                ),
                _buildSettingsItem(
                  icon: Icons.home,
                  title: l10n?.startScreen ?? '시작 화면',
                  subtitle: l10n?.homeTitle ?? '홈',
                  iconColor: Colors.blue,
                ),
              ],
            ),
            AppSpacing.verticalSpaceL,
            
            // 녹음 설정 섹션
            _buildSettingsSection(
              l10n?.recordingSettings ?? '듣기 설정',
              [
                _buildSettingsItem(
                  icon: Icons.timer,
                  title: l10n?.maxRecordingTime ?? '최대 녹음 시간',
                  subtitle: l10n?.maxRecordingTimeValue ?? '1시간',
                  iconColor: AppColors.recordingColor,
                ),
                _buildSettingsItem(
                  icon: Icons.headphones,
                  title: l10n?.audioQuality ?? '오디오 품질',
                  subtitle: l10n?.standardQuality ?? '표준',
                  iconColor: AppColors.recordingColor,
                ),
              ],
            ),
            AppSpacing.verticalSpaceL,
            
            // 쓰기 설정 섹션
            _buildSettingsSection(
              l10n?.writingSettings ?? '쓰기 설정',
              [
                _buildSettingsItem(
                  icon: Icons.save,
                  title: l10n?.autoSaveInterval ?? '자동 저장 간격',
                  subtitle: l10n?.autoSaveIntervalValue ?? '3분',
                  iconColor: AppColors.writingColor,
                ),
                _buildSettingsItem(
                  icon: Icons.font_download,
                  title: l10n?.defaultFont ?? '기본 폰트',
                  subtitle: l10n?.systemFont ?? '시스템 폰트',
                  iconColor: AppColors.writingColor,
                ),
              ],
            ),
            
            // 개발자 정보
            AppSpacing.verticalSpaceXL,
            Container(
              padding: AppSpacing.paddingL,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    l10n?.appVersion ?? 'Litten v1.0.0',
                    style: AppTextStyles.caption,
                  ),
                  AppSpacing.verticalSpaceXS,
                  Text(
                    l10n?.appDescription ?? '크로스 플랫폼 통합 노트 앱',
                    style: AppTextStyles.caption2,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              title,
              style: AppTextStyles.label.copyWith(
                color: Colors.grey.shade700,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Color iconColor = Colors.blue,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: AppTextStyles.bodyText2),
      subtitle: subtitle != null 
          ? Text(subtitle, style: AppTextStyles.caption) 
          : null,
      trailing: onTap != null 
          ? const Icon(Icons.arrow_forward_ios, size: 16) 
          : null,
      onTap: onTap,
    );
  }

  String _getSubscriptionStatusText(SubscriptionType type, AppLocalizations? l10n) {
    switch (type) {
      case SubscriptionType.free:
        return l10n?.freeWithAds ?? '무료 (광고 포함)';
      case SubscriptionType.standard:
        return l10n?.standardMonthly ?? '스탠다드 (\$4.99/월)';
      case SubscriptionType.premium:
        return l10n?.premiumMonthly ?? '프리미엄 (\$9.99/월)';
    }
  }

  Color _getSubscriptionColor(SubscriptionType type) {
    switch (type) {
      case SubscriptionType.free:
        return Colors.grey;
      case SubscriptionType.standard:
        return Colors.blue;
      case SubscriptionType.premium:
        return Colors.amber;
    }
  }

  int _getTotalFileCount(AppStateProvider appState) {
    return appState.littens.fold(0, (total, litten) => total + litten.totalFileCount);
  }

  String _getThemeText(AppThemeType themeType, AppLocalizations? l10n) {
    switch (themeType) {
      case AppThemeType.classicBlue:
        return l10n?.classicBlue ?? '클래식 블루';
      case AppThemeType.darkMode:
        return l10n?.darkMode ?? '다크 모드';
      case AppThemeType.natureGreen:
        return l10n?.natureGreen ?? '네이처 그린';
      case AppThemeType.sunsetOrange:
        return l10n?.sunsetOrange ?? '선셋 오렌지';
      case AppThemeType.monochromeGrey:
        return l10n?.monochromeGrey ?? '모노크롬 그레이';
    }
  }

  String _getLanguageText(String languageCode) {
    final languageMap = {
      'en': 'English',
      'zh': '中文',
      'hi': 'हिन्दी',
      'es': 'Español',
      'fr': 'Français',
      'ar': 'العربية',
      'bn': 'বাংলা',
      'ru': 'Русский',
      'pt': 'Português',
      'ur': 'اردو',
      'id': 'Bahasa Indonesia',
      'de': 'Deutsch',
      'ja': '日本語',
      'sw': 'Kiswahili',
      'mr': 'मराठी',
      'te': 'తెలుగు',
      'tr': 'Türkçe',
      'ta': 'தமிழ்',
      'fa': 'فارسی',
      'ko': '한국어',
      'uk': 'Українська',
      'it': 'Italiano',
      'tl': 'Filipino',
      'pl': 'Polski',
      'ps': 'پښتو',
      'ms': 'Bahasa Melayu',
      'ro': 'Română',
      'nl': 'Nederlands',
      'ha': 'Hausa',
      'th': 'ไทย',
    };
    return languageMap[languageCode] ?? languageCode.toUpperCase();
  }

  void _showUsageDialog(BuildContext context, AppStateProvider appState) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.usageStatistics ?? '사용량 통계'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUsageRow(l10n?.createLitten ?? '리튼 수', '${appState.littens.length}${l10n?.littensCount ?? '개'}', 
                appState.subscriptionType == SubscriptionType.free ? ' / ${l10n?.maxLittensLimit ?? '최대 5개'}' : ''),
            _buildUsageRow(l10n?.totalFiles ?? '총 파일 수', '${_getTotalFileCount(appState)}${l10n?.filesCount ?? '개'}', ''),
            if (appState.subscriptionType == SubscriptionType.free) ...[
              const Divider(),
              Text(
                l10n?.freeUserLimits ?? '무료 사용자 제한:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              _buildUsageRow(l10n?.maxLittens ?? '• 리튼', l10n?.maxLittensLimit ?? '최대 5개', ''),
              _buildUsageRow(l10n?.maxRecordingFiles ?? '• 녹음 파일', l10n?.maxRecordingFilesLimit ?? '최대 10개', ''),
              _buildUsageRow(l10n?.maxTextFiles ?? '• 텍스트 파일', l10n?.maxTextFilesLimit ?? '최대 5개', ''),
              _buildUsageRow(l10n?.maxHandwritingFiles ?? '• 필기 파일', l10n?.maxHandwritingFilesLimit ?? '최대 5개', ''),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.close ?? '닫기'),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageRow(String label, String value, String limit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text('$value$limit'),
        ],
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context, AppStateProvider appState) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.upgradeToStandard ?? '프리미엄 업그레이드'),
        content: Text(l10n?.upgradeBenefits ?? '스탠다드 플랜으로 업그레이드하시겠습니까?\n\n• 광고 제거\n• 무제한 리튼 및 파일\n• 월 \$4.99'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.cancel ?? '취소'),
          ),
          ElevatedButton(
            onPressed: () {
              appState.updateSubscriptionType(SubscriptionType.standard);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n?.upgradedToStandard ?? '스탠다드 플랜으로 업그레이드되었습니다! (시뮬레이션)'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text(l10n?.upgrade ?? '업그레이드'),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context, AppStateProvider appState) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.selectTheme ?? '테마 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppThemeType.values.map((theme) {
            return RadioListTile<AppThemeType>(
              title: Text(_getThemeText(theme, l10n)),
              value: theme,
              groupValue: appState.themeType,
              onChanged: (value) {
                if (value != null) {
                  appState.changeTheme(value);
                  Navigator.of(context).pop();
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.close ?? '닫기'),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, AppStateProvider appState) {
    final l10n = AppLocalizations.of(context);
    final languages = [
      {'code': 'en', 'name': 'English'},
      {'code': 'zh', 'name': '中文'},
      {'code': 'hi', 'name': 'हिन्दी'},
      {'code': 'es', 'name': 'Español'},
      {'code': 'fr', 'name': 'Français'},
      {'code': 'ar', 'name': 'العربية'},
      {'code': 'bn', 'name': 'বাংলা'},
      {'code': 'ru', 'name': 'Русский'},
      {'code': 'pt', 'name': 'Português'},
      {'code': 'ur', 'name': 'اردو'},
      {'code': 'id', 'name': 'Bahasa Indonesia'},
      {'code': 'de', 'name': 'Deutsch'},
      {'code': 'ja', 'name': '日本語'},
      {'code': 'sw', 'name': 'Kiswahili'},
      {'code': 'mr', 'name': 'मराठी'},
      {'code': 'te', 'name': 'తెలుగు'},
      {'code': 'tr', 'name': 'Türkçe'},
      {'code': 'ta', 'name': 'தமிழ்'},
      {'code': 'fa', 'name': 'فارسی'},
      {'code': 'ko', 'name': '한국어'},
      {'code': 'uk', 'name': 'Українська'},
      {'code': 'it', 'name': 'Italiano'},
      {'code': 'tl', 'name': 'Filipino'},
      {'code': 'pl', 'name': 'Polski'},
      {'code': 'ps', 'name': 'پښتو'},
      {'code': 'ms', 'name': 'Bahasa Melayu'},
      {'code': 'ro', 'name': 'Română'},
      {'code': 'nl', 'name': 'Nederlands'},
      {'code': 'ha', 'name': 'Hausa'},
      {'code': 'th', 'name': 'ไทย'},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.selectLanguage ?? '언어 선택'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: languages.length,
            itemBuilder: (context, index) {
              final language = languages[index];
              return RadioListTile<String>(
                title: Text(language['name']!),
                value: language['code']!,
                groupValue: appState.locale.languageCode,
                onChanged: (value) {
                  if (value != null) {
                    appState.changeLanguage(value);
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
            child: Text(l10n?.close ?? '닫기'),
          ),
        ],
      ),
    );
  }
}
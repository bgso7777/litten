import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';

import '../services/app_state_provider.dart';
import '../services/background_notification_service.dart';
import '../services/api_service.dart';
import '../config/themes.dart';
import 'login_screen.dart';
import 'change_password_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _registeredEmail; // signup 상태의 계정 이메일

  @override
  void initState() {
    super.initState();
    _loadRegisteredAccount();
  }

  /// UUID로 signup 상태 계정 조회
  Future<void> _loadRegisteredAccount() async {
    debugPrint('[SettingsScreen] _loadRegisteredAccount - 시작');

    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final apiService = ApiService();

    try {
      // UUID 가져오기
      final uuid = await appState.authService.getDeviceUuid();
      debugPrint('[SettingsScreen] UUID: $uuid');

      // UUID로 계정 조회
      final accountData = await apiService.findAccountByUuid(uuid: uuid);
      debugPrint('[SettingsScreen] 계정 조회 결과: $accountData');

      final prefs = await SharedPreferences.getInstance();

      if (accountData != null && mounted) {
        // Backend는 'noteMember' 필드로 반환
        final member = accountData['noteMember'] as Map<String, dynamic>?;
        if (member != null) {
          final state = member['state'] as String?;
          final email = member['id'] as String?;

          debugPrint('[SettingsScreen] state: $state, email: $email');

          // signup 상태인 경우 이메일 저장
          if (state == 'signup' && email != null) {
            setState(() {
              _registeredEmail = email;
            });

            // SharedPreferences에 저장
            await prefs.setString('registered_email', email);
            debugPrint('[SettingsScreen] 등록된 계정 저장: $email');
          } else {
            // signup 상태가 아니면 삭제
            setState(() {
              _registeredEmail = null;
            });
            await prefs.remove('registered_email');
            debugPrint('[SettingsScreen] signup 상태 아님 - 등록된 계정 삭제');
          }
        } else {
          // member가 null이면 삭제
          setState(() {
            _registeredEmail = null;
          });
          await prefs.remove('registered_email');
          debugPrint('[SettingsScreen] member null - 등록된 계정 삭제');
        }
      } else {
        // accountData가 null이면 계정 없음 -> 삭제
        if (mounted) {
          setState(() {
            _registeredEmail = null;
          });
        }
        await prefs.remove('registered_email');
        debugPrint('[SettingsScreen] 계정 없음 - 등록된 계정 삭제');
      }
    } catch (e) {
      debugPrint('[SettingsScreen] 계정 조회 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return ListView(
          padding: AppSpacing.paddingL,
          children: [
            // 구독 섹션
            _buildSettingsSection('구독', [
              _buildSettingsItem(
                icon: Icons.card_membership,
                title:
                    '구독 플랜 (${_getSubscriptionName(appState.subscriptionType, l10n)})',
                subtitle: _getSubscriptionStatusText(
                  appState.subscriptionType,
                  l10n,
                ),
                iconColor: _getSubscriptionColor(appState.subscriptionType),
                onTap: () => _showSubscriptionPlansDialog(context, appState),
              ),
              _buildSettingsItem(
                icon: Icons.bar_chart,
                title: l10n?.usageStatistics ?? '사용량 통계',
                subtitle:
                    '${appState.littens.length}${l10n?.littensCount ?? '개 리튼'}, ${_getTotalFileCount(appState)}${l10n?.filesCount ?? '개 파일'}',
                iconColor: Colors.blue,
                onTap: () => _showUsageDialog(context, appState),
              ),
            ]),
            AppSpacing.verticalSpaceL,

            // 앱 설정 섹션
            _buildSettingsSection(l10n?.appSettings ?? '앱 설정', [
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
            ]),
            AppSpacing.verticalSpaceL,

            // 녹음 설정 섹션
            _buildSettingsSection(l10n?.recordingSettings ?? '듣기 설정', [
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
            ]),
            AppSpacing.verticalSpaceL,

            // 쓰기 설정 섹션
            _buildSettingsSection(l10n?.writingSettings ?? '쓰기 설정', [
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
            ]),
            AppSpacing.verticalSpaceL,

            // 계정 섹션
            _buildSettingsSection('계정', [
              _buildSettingsItem(
                icon: Icons.person,
                title: '사용자 상태',
                subtitle: appState.isLoggedIn
                    ? '${appState.currentUser?.email ?? ''} (로그인)'
                    : _registeredEmail != null
                    ? '$_registeredEmail (로그아웃)'
                    : '로그아웃',
                iconColor: appState.isLoggedIn ? Colors.green : Colors.grey,
                onTap: null,
              ),
              // 로그인 상태일 때
              if (appState.isLoggedIn) ...[
                _buildSettingsItem(
                  icon: Icons.lock_reset,
                  title: l10n?.changePassword ?? '비밀번호 변경',
                  subtitle: '계정 비밀번호를 변경합니다',
                  iconColor: Colors.orange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChangePasswordScreen(),
                      ),
                    );
                  },
                ),
                _buildSettingsItem(
                  icon: Icons.logout,
                  title: '로그아웃',
                  subtitle: '현재 계정에서 로그아웃합니다',
                  iconColor: Colors.blue,
                  onTap: () => _showLogoutDialog(context, appState),
                ),
                _buildSettingsItem(
                  icon: Icons.person_remove,
                  title: '회원탈퇴',
                  subtitle: '계정을 영구적으로 삭제합니다',
                  iconColor: Colors.red,
                  onTap: () => _showDeleteAccountDialog(context, appState),
                ),
              ],
              // 로그아웃 상태일 때
              if (!appState.isLoggedIn) ...[
                _buildSettingsItem(
                  icon: Icons.login,
                  title: '로그인',
                  subtitle: '계정에 로그인합니다',
                  iconColor: Colors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                ),
              ],
            ]),

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
              style: AppTextStyles.label.copyWith(color: Colors.grey.shade700),
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

  String _getSubscriptionName(SubscriptionType type, AppLocalizations? l10n) {
    switch (type) {
      case SubscriptionType.free:
        return l10n?.freeVersion ?? '무료';
      case SubscriptionType.standard:
        return l10n?.standardVersion ?? '스탠다드';
      case SubscriptionType.premium:
        return l10n?.premiumVersion ?? '프리미엄';
    }
  }

  String _getSubscriptionStatusText(
    SubscriptionType type,
    AppLocalizations? l10n,
  ) {
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
    return appState.littens.fold(
      0,
      (total, litten) => total + litten.totalFileCount,
    );
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
            _buildUsageRow(
              l10n?.createLitten ?? '리튼 수',
              '${appState.littens.length}${l10n?.littensCount ?? '개'}',
              appState.subscriptionType == SubscriptionType.free
                  ? ' / ${l10n?.maxLittensLimit ?? '최대 5개'}'
                  : '',
            ),
            _buildUsageRow(
              l10n?.totalFiles ?? '총 파일 수',
              '${_getTotalFileCount(appState)}${l10n?.filesCount ?? '개'}',
              '',
            ),
            if (appState.subscriptionType == SubscriptionType.free) ...[
              const Divider(),
              Text(
                l10n?.freeUserLimits ?? '무료 사용자 제한:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              _buildUsageRow(
                l10n?.maxLittens ?? '• 리튼',
                l10n?.maxLittensLimit ?? '최대 5개',
                '',
              ),
              _buildUsageRow(
                l10n?.maxRecordingFiles ?? '• 녹음 파일',
                l10n?.maxRecordingFilesLimit ?? '최대 10개',
                '',
              ),
              _buildUsageRow(
                l10n?.maxTextFiles ?? '• 텍스트 파일',
                l10n?.maxTextFilesLimit ?? '최대 5개',
                '',
              ),
              _buildUsageRow(
                l10n?.maxHandwritingFiles ?? '• 필기 파일',
                l10n?.maxHandwritingFilesLimit ?? '최대 5개',
                '',
              ),
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
        children: [Text(label), Text('$value$limit')],
      ),
    );
  }

  void _showSubscriptionPlansDialog(
    BuildContext context,
    AppStateProvider appState,
  ) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('구독 플랜 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPlanOption(
              context,
              appState,
              SubscriptionType.free,
              '무료',
              '광고 포함, 리튼 5개 제한',
              l10n,
            ),
            SizedBox(height: 12),
            _buildPlanOption(
              context,
              appState,
              SubscriptionType.standard,
              '스탠다드',
              '\$4.99/월 - 광고 제거, 무제한',
              l10n,
            ),
            SizedBox(height: 12),
            _buildPlanOption(
              context,
              appState,
              SubscriptionType.premium,
              '프리미엄',
              appState.isLoggedIn
                ? '\$9.99/월 - 클라우드 동기화'
                : '\$9.99/월 - 클라우드 동기화 (로그인 필요)',
              l10n,
              isDisabled: !appState.isLoggedIn,
            ),
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

  Widget _buildPlanOption(
    BuildContext context,
    AppStateProvider appState,
    SubscriptionType type,
    String title,
    String description,
    AppLocalizations? l10n, {
    bool isDisabled = false,
  }) {
    final isSelected = appState.subscriptionType == type;
    return InkWell(
      onTap: isDisabled
          ? null
          : () {
              appState.changeSubscriptionType(type);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$title 플랜으로 변경되었습니다'),
                  backgroundColor: Colors.green,
                ),
              );
            },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.1)
              : isDisabled
              ? Colors.grey.withValues(alpha: 0.05)
              : Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Colors.blue
                : isDisabled
                ? Colors.grey.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isSelected
                        ? Colors.blue
                        : isDisabled
                        ? Colors.grey
                        : Colors.black87,
                  ),
                ),
                if (isSelected) ...[
                  SizedBox(width: 8),
                  Icon(Icons.check_circle, color: Colors.blue, size: 20),
                ],
                if (isDisabled) ...[
                  SizedBox(width: 8),
                  Icon(Icons.lock, color: Colors.grey, size: 16),
                ],
              ],
            ),
            SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: isDisabled ? Colors.grey : Colors.grey[600],
              ),
            ),
          ],
        ),
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

  void _showSubscriptionManagementDialog(
    BuildContext context,
    AppStateProvider appState,
  ) {
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.manageSubscription ?? '구독 관리'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 사용자 상태 섹션
            Text(
              '사용자 상태',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        appState.isLoggedIn
                            ? Icons.person
                            : Icons.person_outline,
                        size: 20,
                        color: appState.isLoggedIn ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        appState.isLoggedIn ? '로그인됨' : '로그아웃됨',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: appState.isLoggedIn
                              ? Colors.green
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  if (appState.isLoggedIn && appState.currentUser != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      appState.currentUser!.email,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        if (appState.isLoggedIn) {
                          // 로그아웃
                          _showLogoutDialog(context, appState);
                        } else {
                          // 로그인 화면으로 이동
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        }
                      },
                      icon: Icon(
                        appState.isLoggedIn ? Icons.logout : Icons.login,
                        size: 18,
                      ),
                      label: Text(
                        appState.isLoggedIn ? '로그아웃' : '로그인',
                        style: const TextStyle(fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appState.isLoggedIn
                            ? Colors.red
                            : Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n?.availablePlans ?? '사용 가능한 플랜',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            _buildSubscriptionCard(
              type: SubscriptionType.free,
              title: l10n?.freeVersion ?? 'Free',
              price: l10n?.freeWithAds ?? 'Free (with ads)',
              isCurrentPlan: appState.subscriptionType == SubscriptionType.free,
              onSelect: () {
                appState.changeSubscriptionType(SubscriptionType.free);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n?.subscriptionChanged ?? '구독이 변경되었습니다'),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildSubscriptionCard(
              type: SubscriptionType.standard,
              title: l10n?.standardVersion ?? 'Standard',
              price: l10n?.standardMonthly ?? 'Standard (\$4.99/month)',
              isCurrentPlan:
                  appState.subscriptionType == SubscriptionType.standard,
              onSelect: () {
                appState.changeSubscriptionType(SubscriptionType.standard);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n?.subscriptionChanged ?? '구독이 변경되었습니다'),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildSubscriptionCard(
              type: SubscriptionType.premium,
              title: l10n?.premiumVersion ?? 'Premium',
              price: l10n?.premiumMonthly ?? 'Premium (\$9.99/month)',
              isCurrentPlan:
                  appState.subscriptionType == SubscriptionType.premium,
              isDisabled: !appState.isLoggedIn, // 로그아웃 상태면 비활성화
              onSelect: () {
                if (appState.isLoggedIn) {
                  appState.changeSubscriptionType(SubscriptionType.premium);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n?.subscriptionChanged ?? '구독이 변경되었습니다'),
                    ),
                  );
                } else {
                  // 로그아웃 상태면 안내 메시지
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('프리미엄은 로그인 후 선택 가능합니다'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
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

  Widget _buildSubscriptionCard({
    required SubscriptionType type,
    required String title,
    required String price,
    required bool isCurrentPlan,
    bool isDisabled = false, // 비활성화 여부
    required VoidCallback onSelect,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentPlan
            ? Colors.blue.withValues(alpha: 0.1)
            : isDisabled
            ? Colors.grey.withValues(alpha: 0.03)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrentPlan
              ? Colors.blue
              : isDisabled
              ? Colors.grey.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.3),
          width: isCurrentPlan ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isCurrentPlan
                            ? Colors.blue
                            : isDisabled
                            ? Colors.grey.withValues(alpha: 0.5)
                            : Colors.black87,
                      ),
                    ),
                    if (isCurrentPlan) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Current',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    if (isDisabled && !isCurrentPlan) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.lock,
                        size: 14,
                        color: Colors.grey.withValues(alpha: 0.5),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDisabled
                        ? Colors.grey.withValues(alpha: 0.4)
                        : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (!isCurrentPlan)
            ElevatedButton(
              onPressed: isDisabled ? null : onSelect,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Select', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AppStateProvider appState) {
    final l10n = AppLocalizations.of(context);
    final isPremium = appState.subscriptionType == SubscriptionType.premium;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.blue),
            SizedBox(width: 8),
            Text('로그아웃'),
          ],
        ),
        content: Text(
          isPremium
              ? '프리미엄 상태에서 로그아웃 시 파일 공유를 할 수 없습니다.\n정말로 로그아웃 하시겠습니까?'
              : '정말로 로그아웃 하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.cancel ?? '취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              navigator.pop(); // 다이얼로그 닫기

              try {
                // 로그아웃 실행
                await appState.authService.signOut();

                // 성공 메시지
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('로그아웃되었습니다.'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              } catch (e) {
                // 에러 메시지
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('로그아웃 실패: $e'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text('로그아웃'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(
    BuildContext context,
    AppStateProvider appState,
  ) {
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('회원탈퇴'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '정말로 회원탈퇴를 진행하시겠습니까?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 16),
            Text('회원탈퇴 시 다음 사항에 유의해주세요:', style: TextStyle(fontSize: 14)),
            SizedBox(height: 12),
            _buildWarningItem('• 모든 데이터가 영구적으로 삭제됩니다'),
            _buildWarningItem('• 서버에 저장된 파일이 모두 삭제됩니다'),
            _buildWarningItem('• 계정 복구가 불가능합니다'),
            _buildWarningItem('• 구독이 자동으로 취소됩니다'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.cancel ?? '취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _confirmDeleteAccount(context, appState);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('탈퇴하기'),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: Colors.red.shade700),
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, AppStateProvider appState) {
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('최종 확인'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '정말로 탈퇴하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              '탈퇴하시려면 "삭제 확인" 버튼을 눌러주세요',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.cancel ?? '취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              navigator.pop();

              // 로딩 표시
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('계정 삭제 중...'),
                        ],
                      ),
                    ),
                  ),
                ),
              );

              try {
                // 회원탈퇴 실행 (로컬 파일 유지, 무료 플랜 전환)
                await appState.authService.deleteAccountAndAllData();

                // 설정 화면의 registered_email 상태 초기화
                if (mounted) {
                  setState(() {
                    _registeredEmail = null;
                  });
                }

                navigator.pop(); // 로딩 닫기

                // 성공 메시지
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('계정이 삭제되었습니다. 로컬 파일은 유지되며 무료 플랜으로 전환되었습니다.'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );

                // 무료 플랜으로 전환
                await appState.changeSubscriptionType(SubscriptionType.free);

                // 로그인 화면으로 이동
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              } catch (e) {
                navigator.pop(); // 로딩 닫기

                // 에러 메시지
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('계정 삭제 실패: $e'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('삭제 확인'),
          ),
        ],
      ),
    );
  }
}

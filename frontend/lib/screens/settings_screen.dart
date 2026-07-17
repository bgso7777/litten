import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';

import '../services/app_state_provider.dart';
import '../config/plan_limits.dart';
import '../widgets/common/tab_count_title.dart';
import '../widgets/common/quiz_bulb_icon.dart';
import '../widgets/common/record_memo_icon.dart';
import '../widgets/common/round_chat_bubble_icon.dart';
import '../services/background_notification_service.dart';
import '../services/api_service.dart';
import '../config/themes.dart';
import '../widgets/common/ad_banner.dart';
import 'login_screen.dart';
import 'change_password_screen.dart';
import 'device_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _registeredEmail; // signup 상태의 계정 이메일
  String? _nickname; // 현재 계정 닉네임 (note_member.name)
  String? _deviceUuid; // 기기 구분용 — 끝 5자리를 설정 하단에 표시

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

      // 기기 구분용 UUID 표시 (네트워크 조회 전에 먼저 반영)
      if (mounted) setState(() => _deviceUuid = uuid);

      // 로그인 상태면 서버(JWT)에서 내 정보(닉네임 포함)를 우선 반영 — 기기 무관(다기기 로그인 대응).
      final loginPrefs = await SharedPreferences.getInstance();
      final token = loginPrefs.getString('auth_token');
      if (appState.isLoggedIn && token != null && token.isNotEmpty) {
        final me = await apiService.getMyInfo(token: token);
        if (me != null && mounted) {
          final nick = (me['name'] as String?)?.trim();
          final email = (me['memberId'] as String?)?.trim();
          setState(() {
            if (email != null && email.isNotEmpty) _registeredEmail = email;
            _nickname = (nick != null && nick.isNotEmpty) ? nick : null;
          });
          appState.setMyNickname(_nickname);
          if (email != null && email.isNotEmpty) {
            await loginPrefs.setString('registered_email', email);
          }
          debugPrint('[SettingsScreen] 로그인 계정 정보 반영 - email: $email, 닉네임: $_nickname');
          return; // 로그인 계정으로 확정 — device-uuid 조회는 건너뜀
        }
      }

      // (비로그인) UUID로 계정 조회
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
            final nick = (member['name'] as String?)?.trim();
            setState(() {
              _registeredEmail = email;
              _nickname = (nick != null && nick.isNotEmpty) ? nick : null;
            });
            // 공용 상태에도 반영 → 설정 탭 제목란이 닉네임(아이디) 형식으로 표시
            appState.setMyNickname(_nickname);

            // SharedPreferences에 저장
            await prefs.setString('registered_email', email);
            debugPrint('[SettingsScreen] 등록된 계정 저장: $email, 닉네임: $nick');
          } else {
            // signup 상태가 아니면 삭제
            setState(() {
              _registeredEmail = null;
              _nickname = null;
            });
            appState.setMyNickname(null);
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
          padding: EdgeInsets.zero,
          children: [
            // 실제 설정 내용
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            // 구독 섹션
            _buildSettingsSection(l10n?.subscription ?? '구독', [
              _buildSettingsItem(
                icon: Icons.card_membership,
                title:
                    '${l10n?.subscriptionPlan ?? '구독 플랜'} (${_getSubscriptionName(appState.subscriptionType, l10n)})',
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
                    '${appState.littens.where((l) => l.title != 'undefined').length}${l10n?.littensCount ?? '개 일정'}, ${_getTotalFileCount(appState)}${l10n?.filesCount ?? '개 파일'}',
                iconColor: Theme.of(context).primaryColor,
                onTap: () => _showUsageDialog(context, appState),
              ),
            ]),
            AppSpacing.verticalSpaceM,

            // 계정 섹션 - 모든 플랜에서 로그인 가능 (로그인 자체는 플랜 무관; 클라우드 동기화만 프리미엄).
            _buildSettingsSection(l10n?.account ?? '계정', [
                _buildSettingsItem(
                  icon: Icons.person,
                  title: l10n?.userStatus ?? '사용자 상태',
                  subtitle: appState.isLoggedIn
                      ? '${appState.currentUser?.email ?? ''} (${l10n?.loggedIn ?? '로그인'})'
                      : l10n?.loggedOut ?? '로그아웃',
                  iconColor: Theme.of(context).primaryColor,
                  onTap: null,
                ),
                // 로그인 상태일 때
                if (appState.isLoggedIn) ...[
                  _buildSettingsItem(
                    icon: Icons.badge_outlined,
                    title: '닉네임 변경',
                    subtitle: (_nickname != null && _nickname!.isNotEmpty)
                        ? '현재 닉네임: $_nickname'
                        : '닉네임이 없습니다 · 다른 사용자에게 표시될 닉네임을 설정하세요',
                    iconColor: Theme.of(context).primaryColor,
                    onTap: () => _showChangeNicknameDialog(context, appState),
                  ),
                  _buildSettingsItem(
                    icon: Icons.lock_reset,
                    title: l10n?.changePassword ?? '비밀번호 변경',
                    subtitle: l10n?.changePasswordSubtitle ?? '계정 비밀번호를 변경합니다',
                    iconColor: Theme.of(context).primaryColor,
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
                    icon: Icons.devices,
                    // NOTE: 다국어(ARB) 키 추가는 후속 작업 — 우선 한국어 하드코딩
                    title: '기기 관리',
                    subtitle: '로그인된 기기를 확인하고 해제합니다 (최대 3대)',
                    iconColor: Theme.of(context).primaryColor,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DeviceManagementScreen(),
                        ),
                      );
                    },
                  ),
                  _buildSettingsItem(
                    icon: Icons.logout,
                    title: l10n?.logout ?? '로그아웃',
                    subtitle: l10n?.loginToAccount ?? '현재 계정에서 로그아웃합니다',
                    iconColor: Theme.of(context).primaryColor,
                    onTap: () => _showLogoutDialog(context, appState),
                  ),
                  _buildSettingsItem(
                    icon: Icons.person_remove,
                    title: l10n?.deleteAccount ?? '회원탈퇴',
                    subtitle: l10n?.deleteAccountSubtitle ?? '계정을 영구적으로 삭제합니다',
                    iconColor: Colors.red,
                    onTap: () => _showDeleteAccountDialog(context, appState),
                  ),
                ],
                // 미로그인 상태일 때 (프리미엄인데 로그인 안 된 경우)
                if (!appState.isLoggedIn)
                  _buildSettingsItem(
                    icon: Icons.login,
                    title: l10n?.login ?? '로그인',
                    subtitle: '로그인하면 공유 받기·동기화를 이용할 수 있습니다',
                    iconColor: Theme.of(context).primaryColor,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                  ),
            ]),
            AppSpacing.verticalSpaceM,

            // 앱 설정 섹션
            _buildSettingsSection(l10n?.appSettings ?? '앱 설정', [
              _buildSettingsItem(
                icon: Icons.palette,
                title: l10n?.theme ?? '테마',
                subtitle: _getThemeText(appState.themeType, l10n),
                iconColor: Theme.of(context).primaryColor,
                onTap: () => _showThemeDialog(context, appState),
              ),
              _buildSettingsItem(
                icon: Icons.language,
                title: l10n?.language ?? '언어',
                subtitle: _getLanguageText(appState.locale.languageCode),
                iconColor: Theme.of(context).primaryColor,
                onTap: () => _showLanguageDialog(context, appState),
              ),
              _buildSettingsItem(
                icon: Icons.home,
                title: l10n?.startScreen ?? '시작 화면',
                subtitle: appState.startScreen == 'calendar'
                    ? (l10n?.calendarTab ?? '캘린더')
                    : (l10n?.noteOption ?? '노트'),
                iconColor: Theme.of(context).primaryColor,
                onTap: () => _showStartScreenDialog(context, appState),
              ),
              _buildSettingsItem(
                icon: Icons.view_quilt,
                title: l10n?.visibleAreas ?? '영역 보기',
                subtitle: _getVisibleAreasText(appState.visibleAreas, l10n),
                iconColor: Theme.of(context).primaryColor,
                onTap: () => _showVisibleAreasDialog(context, appState),
              ),
              _buildSettingsItem(
                icon: Icons.tab,
                title: l10n?.noteTabView ?? '노트 탭 표시',
                subtitle: _getNoteTabVisibilityText(appState.noteTabVisibility, l10n),
                iconColor: Theme.of(context).primaryColor,
                onTap: () => _showNoteTabVisibilityDialog(context, appState),
              ),
              _buildSettingsItem(
                icon: Icons.add_circle_outline,
                title: l10n?.allTabFab ?? '전체탭 빠른 추가 표시',
                subtitle: _getAllTabFabText(appState.allTabFabVisibility, l10n),
                iconColor: Theme.of(context).primaryColor,
                onTap: () => _showAllTabFabVisibilityDialog(context, appState),
              ),
              _buildSettingsItem(
                icon: Icons.title,
                title: '전체탭 제목',
                subtitle: appState.allTabTitleMode == 'search' ? '검색' : '파일 통계',
                iconColor: Theme.of(context).primaryColor,
                onTap: () => _showAllTabTitleModeDialog(context, appState),
              ),
              _buildSettingsSwitchItem(
                icon: Icons.subscriptions_outlined,
                title: '전체탭 영상 구독 표시',
                subtitle: appState.showYoutubeInAllTab ? '전체탭에 구독 채널 표시' : '전체탭에 구독 채널 숨김',
                iconColor: Theme.of(context).primaryColor,
                value: appState.showYoutubeInAllTab,
                onChanged: (v) => appState.setShowYoutubeInAllTab(v),
              ),
              _buildSettingsSwitchItem(
                icon: Icons.campaign_outlined,
                title: l10n?.showAds ?? '광고 표시',
                subtitle: appState.adsEnabled ? '광고 표시 ON' : '광고 표시 OFF',
                iconColor: Theme.of(context).primaryColor,
                value: appState.adsEnabled,
                onChanged: (v) => appState.setAdsEnabled(v),
              ),
            ]),
            AppSpacing.verticalSpaceM,

            // 녹음 설정 섹션
            _buildSettingsSection(l10n?.recordingSettings ?? '듣기 설정', [
              _buildSettingsItem(
                icon: Icons.timer,
                title: l10n?.maxRecordingTime ?? '최대 녹음 시간',
                subtitle: l10n?.maxRecordingTimeValue ?? '무제한',
                iconColor: Theme.of(context).primaryColor,
              ),
              _buildSettingsItem(
                icon: Icons.headphones,
                title: l10n?.audioQuality ?? '오디오 품질',
                subtitle: l10n?.standardQuality ?? '표준',
                iconColor: Theme.of(context).primaryColor,
              ),
            ]),
            AppSpacing.verticalSpaceM,

            // 쓰기 설정 섹션
            _buildSettingsSection(l10n?.writingSettings ?? '쓰기 설정', [
              _buildSettingsItem(
                icon: Icons.save,
                title: l10n?.autoSaveInterval ?? '자동 저장 간격',
                subtitle: l10n?.autoSaveIntervalValue ?? '3분',
                iconColor: Theme.of(context).primaryColor,
              ),
              _buildSettingsItem(
                icon: Icons.font_download,
                title: l10n?.defaultFont ?? '기본 폰트',
                subtitle: l10n?.systemFont ?? '시스템 폰트',
                iconColor: Theme.of(context).primaryColor,
              ),
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
                  if (_deviceUuid != null && _deviceUuid!.length >= 5) ...[
                    AppSpacing.verticalSpaceXS,
                    Text(
                      '기기 ID: ${_deviceUuid!.substring(_deviceUuid!.length - 5)}',
                      style: AppTextStyles.caption2,
                    ),
                  ],
                ],
              ),
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
    final primaryColor = Theme.of(context).primaryColor;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              title,
              style: AppTextStyles.label.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingsSwitchItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Color iconColor = Colors.blue,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, color: iconColor, size: 16),
      ),
      title: Row(
        children: [
          Text(title, style: AppTextStyles.bodyText2),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                subtitle,
                style: AppTextStyles.caption.copyWith(color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: iconColor,
      ),
      onTap: onChanged == null ? null : () => onChanged(!value),
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
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, color: iconColor, size: 16),
      ),
      title: Row(
        children: [
          Text(title, style: AppTextStyles.bodyText2),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                subtitle,
                style: AppTextStyles.caption.copyWith(color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
      trailing: onTap != null
          ? const Icon(Icons.arrow_forward_ios, size: 16)
          : null,
      onTap: onTap,
    );
  }

  Widget _buildSettingsItemDisabled({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, color: Colors.grey.shade400, size: 16),
      ),
      title: Row(
        children: [
          Text(title, style: AppTextStyles.bodyText2.copyWith(color: Colors.grey.shade400)),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                subtitle,
                style: AppTextStyles.caption.copyWith(color: Colors.grey.shade400),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
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

  void _showAllTabTitleModeDialog(BuildContext context, AppStateProvider appState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('전체탭 제목'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              value: 'search',
              groupValue: appState.allTabTitleMode,
              title: const Text('검색'),
              subtitle: const Text('제목 자리에 파일명 검색바 표시'),
              onChanged: (v) {
                appState.setAllTabTitleMode(v!);
                Navigator.of(context).pop();
              },
            ),
            RadioListTile<String>(
              value: 'stats',
              groupValue: appState.allTabTitleMode,
              title: const Text('파일 통계'),
              subtitle: const Text('제목 자리에 종류별 아이콘 카운트 표시'),
              onChanged: (v) {
                appState.setAllTabTitleMode(v!);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  void _showUsageDialog(BuildContext context, AppStateProvider appState) {
    final l10n = AppLocalizations.of(context);
    final isFree = appState.subscriptionType == SubscriptionType.free;

    // 스터디룸(홈) — 전체(계정) 기준
    final chatN = appState.homeConversationCount;
    final inN = appState.sharesReceived.length;
    final outN = appState.sharesSent.length + appState.selfChatFileCount;

    // 노트 · 전체 합계 (모든 리튼 합산) — 전체탭 제목과 동일 9종
    final awMemo = appState.appWideMemoCount;
    final awCanvas = appState.appWideCanvasCount;
    final awPdf = appState.appWidePdfCount;
    final awRecording = appState.appWideRecordingCount;
    final awStt = appState.appWideSttCount;
    final awFile = appState.appWideFileCount;
    final awPhoto = appState.appWidePhotoCount;
    final awVideo = appState.appWideVideoCount;
    final awYt = appState.actualYoutubeChannelCount;

    // 노트 · 현재 선택 리튼 세부 (탭 제목과 동일 계산)
    final sel = appState.selectedLitten;
    final memo = (appState.actualTextCount - appState.actualSttTextCount).clamp(0, 1 << 31);
    final canvas = appState.actualCanvasCount;
    final pdf = appState.actualPdfCount;
    final recording = (appState.actualAudioCount - appState.actualSttMemoCount).clamp(0, 1 << 31);
    final stt = appState.actualSttTextCount + appState.actualSttMemoCount;
    final otherFiles = (appState.actualAttachmentCount - appState.actualPhotoCount - appState.actualVideoCount).clamp(0, 1 << 31);
    final ytCh = appState.actualYoutubeChannelCount;
    final photo = appState.actualPhotoCount;
    final video = appState.actualVideoCount;

    // 리마인드 — 탭 제목과 동일: '확인 안 한 것(미완료)'만
    final sumPending = appState.summaries.where((s) => !s.isDone).length;
    final quizPending = appState.quizTargets
        .where((g) => g.items.isNotEmpty && g.pendingCount > 0)
        .length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.usageStatistics ?? '사용량 통계'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUsageRow(
                  l10n?.createLitten ?? '일정 수',
                  '${appState.littens.where((l) => l.title != 'undefined').length}${l10n?.littensCount ?? '개'}',
                  isFree ? ' / ${l10n?.maxLittensLimit ?? '최대 5개'}' : '',
                ),
                _buildUsageRow(
                  l10n?.totalFiles ?? '총 파일 수',
                  '${_getTotalFileCount(appState)}${l10n?.filesCount ?? '개'}',
                  '',
                ),

                // 💬 스터디룸 (탭 제목과 동일: 대화·공유받음·공유함)
                _buildStatHeader(context, Icons.forum, '스터디룸'),
                _buildCountStrip([
                  TabCount(Icons.chat_bubble_outline, chatN,
                      iconWidget: const RoundChatBubbleIcon(filled: true, size: 20)),
                  TabCount(Icons.download, inN),
                  TabCount(Icons.upload, outN),
                ]),

                // 📝 노트 · 전체 합계 (전체탭 제목과 동일 9종, 모든 리튼 합산)
                _buildStatHeader(context, Icons.notes, '노트 · 전체 합계'),
                _buildCountStrip([
                  TabCount(Icons.notes, awMemo),
                  TabCount(Icons.draw, awCanvas),
                  TabCount(Icons.picture_as_pdf, awPdf),
                  TabCount(Icons.mic, awRecording),
                  TabCount(Icons.record_voice_over, awStt,
                      iconWidget: const RecordMemoIcon()),
                  TabCount(Icons.description, awFile),
                  TabCount(Icons.subscriptions, awYt),
                  TabCount(Icons.photo_camera, awPhoto),
                  TabCount(Icons.videocam, awVideo),
                ].where((c) => c.count > 0).toList()),

                // 📁 노트 · 현재 리튼 (탭 제목과 동일 9종, 0은 숨김)
                if (sel != null && sel.title != 'undefined') ...[
                  _buildStatHeader(context, Icons.folder_open, '노트 · 현재 리튼 (${sel.title})'),
                  _buildCountStrip([
                    TabCount(Icons.notes, memo),
                    TabCount(Icons.draw, canvas),
                    TabCount(Icons.picture_as_pdf, pdf),
                    TabCount(Icons.mic, recording),
                    TabCount(Icons.record_voice_over, stt,
                        iconWidget: const RecordMemoIcon()),
                    TabCount(Icons.description, otherFiles),
                    TabCount(Icons.subscriptions, ytCh),
                    TabCount(Icons.photo_camera, photo),
                    TabCount(Icons.videocam, video),
                  ].where((c) => c.count > 0).toList()),
                ],

                // 🔁 리마인드 (탭 제목과 동일: 요약·퀴즈, 미완료 기준)
                _buildStatHeader(context, Icons.auto_awesome, '리마인드'),
                _buildCountStrip([
                  TabCount(Icons.auto_awesome, sumPending),
                  TabCount(Icons.lightbulb_outline, quizPending,
                      iconWidget: const QuizBulbIcon(size: 20)),
                ]),

                if (isFree) ...[
                  const Divider(height: 24),
                  Text(
                    l10n?.freeUserLimits ?? '무료 사용자 제한:',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  _buildUsageRow('• 메모', '최대 ${PlanLimits.memos(SubscriptionType.free)}개', ''),
                  _buildUsageRow('• 녹음', '최대 ${PlanLimits.audios(SubscriptionType.free)}개', ''),
                  _buildUsageRow('• 녹음 메모', '최대 ${PlanLimits.sttMemos(SubscriptionType.free)}개', ''),
                  _buildUsageRow('• 필기', '최대 ${PlanLimits.handwritings(SubscriptionType.free)}개', ''),
                  _buildUsageRow('• 첨부파일', '최대 ${PlanLimits.attachments(SubscriptionType.free)}개', ''),
                  _buildUsageRow('• 영상 구독', '최대 ${PlanLimits.youtubeChannels(SubscriptionType.free)}개', ''),
                  _buildUsageRow('• 일정', '최대 ${PlanLimits.schedules(SubscriptionType.free)}개', ''),
                  _buildUsageRow('• 요약', '${PlanLimits.summaryPerMonth(SubscriptionType.free)}회 (누적)', ''),
                  _buildUsageRow('• 퀴즈', '${PlanLimits.quizPerMonth(SubscriptionType.free)}회 (누적)', ''),
                  _buildUsageRow('• 파일 변환', '${PlanLimits.fileConvertTotal(SubscriptionType.free)}회 (누적)', ''),
                ],
              ],
            ),
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

  // 사용량 통계 섹션 헤더 (아이콘 + 제목)
  Widget _buildStatHeader(BuildContext context, IconData icon, String title) {
    final color = Theme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
        ],
      ),
    );
  }

  // 탭 제목과 동일한 "아이콘 + 카운트" 가로 배열 (TabCountTitle 재사용)
  Widget _buildCountStrip(List<TabCount> counts) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4, bottom: 2),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: counts.isEmpty
            ? Text('0', style: TextStyle(color: Colors.grey[500], fontSize: 13))
            : IconTheme(
                data: IconThemeData(size: 20, color: Theme.of(context).colorScheme.onSurface),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(fontSize: 13),
                  child: TabCountTitle([counts]),
                ),
              ),
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
        title: Text(l10n?.selectPlan ?? '구독 플랜 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPlanOption(
              context,
              appState,
              SubscriptionType.free,
              l10n?.planFree ?? '무료',
              l10n?.planFreeDescription ?? '광고 포함, 리튼 5개 제한',
              l10n,
            ),
            SizedBox(height: 12),
            _buildPlanOption(
              context,
              appState,
              SubscriptionType.standard,
              l10n?.planStandard ?? '스탠다드',
              l10n?.planStandardDescription ?? '\$4.99/월 - 광고 제거, 무제한',
              l10n,
            ),
            SizedBox(height: 12),
            _buildPlanOption(
              context,
              appState,
              SubscriptionType.premium,
              l10n?.planPremium ?? '프리미엄',
              l10n?.planPremiumDescription ?? '\$9.99/월 - 클라우드 동기화',
              l10n,
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
          : () => _handlePlanSelection(context, appState, type, title, l10n),
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

  String _getNoteTabVisibilityText(Set<String> visibility, AppLocalizations? l10n) {
    final labels = <String>[];
    if (visibility.contains('all')) labels.add(l10n?.allFilesLabel ?? '전체');
    if (visibility.contains('handwriting')) labels.add(l10n?.handwritingTab ?? '필기');
    if (visibility.contains('text')) labels.add(l10n?.memoLabel ?? '메모');
    if (visibility.contains('pdf')) labels.add('PDF');
    if (visibility.contains('audio')) labels.add(l10n?.audioTab ?? '녹음');
    if (visibility.contains('files')) labels.add('파일');
    if (visibility.contains('browser')) labels.add(l10n?.browserTab ?? '검색');
    if (visibility.contains('youtube')) labels.add('영상');
    return labels.join(', ');
  }

  String _getAllTabFabText(Set<String> visibility, AppLocalizations? l10n) {
    if (visibility.isEmpty) return l10n?.noneLabel ?? '없음';
    final labels = {
      'text': l10n?.memoLabel ?? '메모',
      'canvas': l10n?.handwritingTab ?? '필기',
      'audio': l10n?.audioTab ?? '녹음',
      'stt': l10n?.voiceMemoLabel ?? '녹음 메모',
      'photo': '사진',
      'video': '비디오',
      'youtube': '영상 채널',
      'files': '파일',
    };
    final order = ['text', 'canvas', 'audio', 'stt', 'files', 'youtube', 'photo', 'video'];
    final result = order.where(visibility.contains).map((k) => labels[k]!).toList();
    return result.isEmpty ? (l10n?.noneLabel ?? '없음') : result.join(', ');
  }

  void _showAllTabFabVisibilityDialog(BuildContext context, AppStateProvider appState) {
    showDialog(
      context: context,
      builder: (context) => _AllTabFabVisibilityDialog(appState: appState),
    );
  }

  void _showStartScreenDialog(BuildContext context, AppStateProvider appState) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n?.startScreen ?? '시작 화면'),
        children: [
          RadioListTile<String>(
            value: 'note',
            groupValue: appState.startScreen,
            title: Text(l10n?.noteOption ?? '노트'),
            onChanged: (v) {
              appState.setStartScreen(v!);
              Navigator.pop(ctx);
            },
          ),
          RadioListTile<String>(
            value: 'calendar',
            groupValue: appState.startScreen,
            title: Text(l10n?.calendarTab ?? '캘린더'),
            onChanged: (v) {
              appState.setStartScreen(v!);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  String _getVisibleAreasText(Set<String> areas, AppLocalizations? l10n) {
    final labels = <String>[];
    if (areas.contains('topRight')) labels.add(l10n?.positionTopRight ?? '우상단');
    if (areas.contains('bottomLeft')) labels.add(l10n?.positionBottomLeft ?? '좌하단');
    if (areas.contains('bottomRight')) labels.add(l10n?.positionBottomRight ?? '우하단');
    if (labels.isEmpty) return l10n?.topLeftOnly ?? '좌상단만 표시';
    return l10n?.topLeftWith(labels.join(', ')) ?? '좌상단 + ${labels.join(', ')}';
  }

  void _showVisibleAreasDialog(BuildContext context, AppStateProvider appState) {
    showDialog(
      context: context,
      builder: (context) => _VisibleAreasDialog(appState: appState),
    );
  }

  void _showNoteTabVisibilityDialog(BuildContext context, AppStateProvider appState) {
    showDialog(
      context: context,
      builder: (context) => _NoteTabVisibilityDialog(appState: appState),
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
              l10n?.userStatus ?? '사용자 상태',
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
                        appState.isLoggedIn ? (l10n?.loggedIn ?? '로그인됨') : (l10n?.loggedOut ?? '로그아웃됨'),
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
                        appState.isLoggedIn ? (l10n?.logout ?? '로그아웃') : (l10n?.login ?? '로그인'),
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
                final planTitle = l10n?.standardVersion ?? '스탠다드';
                appState.changeSubscriptionType(SubscriptionType.standard);
                Navigator.of(context).pop();
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Row(
                      children: [
                        const Icon(Icons.cloud_outlined, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(l10n?.cloudSync ?? '클라우드 동기화'),
                      ],
                    ),
                    content: Text(
                      l10n?.cloudSyncPlanChanged(planTitle) ?? '$planTitle 플랜으로 변경되었습니다.\n\n클라우드 동기화 서비스를 이용하려면 설정 > 계정에서 로그인하세요.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(l10n?.confirm ?? '확인'),
                      ),
                    ],
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
              onSelect: () {
                final planTitle = l10n?.premiumVersion ?? '프리미엄';
                appState.changeSubscriptionType(SubscriptionType.premium);
                Navigator.of(context).pop();
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Row(
                      children: [
                        const Icon(Icons.cloud_outlined, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(l10n?.cloudSync ?? '클라우드 동기화'),
                      ],
                    ),
                    content: Text(
                      l10n?.cloudSyncPlanChanged(planTitle) ?? '$planTitle 플랜으로 변경되었습니다.\n\n클라우드 동기화 서비스를 이용하려면 설정 > 계정에서 로그인하세요.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(l10n?.confirm ?? '확인'),
                      ),
                    ],
                  ),
                );
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

  /// 플랜 선택 처리 — 현재 플랜 → 대상 플랜 전환에 맞는 안내/확인 다이얼로그를 띄운다.
  void _handlePlanSelection(
    BuildContext context,
    AppStateProvider appState,
    SubscriptionType target,
    String title,
    AppLocalizations? l10n,
  ) {
    final from = appState.subscriptionType;
    debugPrint('[SettingsScreen] 플랜 선택: $from → $target');
    Navigator.of(context).pop(); // 플랜 선택 다이얼로그 닫기

    if (from == target) return; // 동일 플랜 — 변경 없음

    // 프리미엄 → 하위(스탠다드/무료): 클라우드 동기화 해지 + 로그아웃 확인 후 전환
    if (from == SubscriptionType.premium && target != SubscriptionType.premium) {
      _showDowngradeFromPremiumDialog(context, appState, target, title, l10n);
      return;
    }

    // 그 외 전환(무료→스탠다드/프리미엄, 스탠다드→프리미엄/무료): 즉시 전환 + 안내
    appState.changeSubscriptionType(target);
    _showPlanChangeInfoDialog(context, target, _planChangeInfoMessage(from, target));
  }

  /// 업그레이드·스탠다드→무료 전환 시 보여줄 안내 문구 (전환별 차등)
  String _planChangeInfoMessage(SubscriptionType from, SubscriptionType to) {
    if (to == SubscriptionType.standard) {
      // 무료 → 스탠다드: 개수 제한 해제, 요약·퀴즈는 월별 제한
      return '스탠다드 플랜으로 변경되었습니다.\n\n'
          '• 리튼·파일 개수 제한이 모두 해제됩니다 (무제한).\n'
          '• 광고가 제거됩니다.\n'
          '• 영상 요약·퀴즈는 매월 10회로 제한됩니다.';
    }
    if (to == SubscriptionType.premium) {
      if (from == SubscriptionType.free) {
        // 무료 → 프리미엄: 개수 제한 해제 + 클라우드 동기화
        return '프리미엄 플랜으로 변경되었습니다.\n\n'
            '• 리튼·파일 개수 제한이 모두 해제됩니다 (무제한).\n'
            '• 광고가 제거됩니다.\n'
            '• 영상 요약·퀴즈가 무제한입니다.\n'
            '• 설정 > 계정에서 로그인하면 클라우드 파일 동기화가 제공됩니다.';
      }
      // 스탠다드 → 프리미엄: 클라우드 동기화 추가
      return '프리미엄 플랜으로 변경되었습니다.\n\n'
          '• 영상 요약·퀴즈가 무제한이 됩니다.\n'
          '• 설정 > 계정에서 로그인하면 클라우드 파일 동기화가 제공됩니다.';
    }
    // 스탠다드 → 무료: 개수 제한 재적용, 광고, 요약·퀴즈 월 2회
    return '무료 플랜으로 변경되었습니다.\n\n'
        '• 리튼·파일 개수 제한이 다시 적용됩니다.\n'
        '• 광고가 표시됩니다.\n'
        '• 영상 요약·퀴즈는 매월 2회로 제한됩니다.';
  }

  void _showPlanChangeInfoDialog(
    BuildContext context,
    SubscriptionType target,
    String message,
  ) {
    final isUpgrade = target != SubscriptionType.free;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(isUpgrade ? Icons.cloud_done_outlined : Icons.info_outline,
                color: isUpgrade ? Colors.blue : Colors.grey),
            const SizedBox(width: 8),
            const Text('플랜 변경'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  /// 프리미엄 → 하위 플랜 다운그레이드 시 보여줄 확인 문구 (대상별 차등)
  String _downgradeMessage(SubscriptionType target) {
    if (target == SubscriptionType.standard) {
      // 프리미엄 → 스탠다드: 로그아웃 + 동기화 해지 (개수 제한은 없음)
      return '프리미엄에서 스탠다드 플랜으로 변경합니다.\n\n'
          '• 클라우드 파일 동기화가 해지되고 자동으로 로그아웃됩니다.\n'
          '• 리튼·파일 개수 제한은 없습니다 (무제한 유지).\n'
          '• 영상 요약·퀴즈는 매월 10회로 제한됩니다.\n\n'
          '계속하시겠습니까?';
    }
    // 프리미엄 → 무료: 개수 제한 재적용 + 로그아웃 + 동기화 해지
    return '프리미엄에서 무료 플랜으로 변경합니다.\n\n'
        '• 클라우드 파일 동기화가 해지되고 자동으로 로그아웃됩니다.\n'
        '• 리튼·파일 개수 제한이 다시 적용됩니다.\n'
        '• 광고가 표시됩니다.\n'
        '• 영상 요약·퀴즈는 매월 2회로 제한됩니다.\n\n'
        '계속하시겠습니까?';
  }

  void _showDowngradeFromPremiumDialog(
    BuildContext context,
    AppStateProvider appState,
    SubscriptionType newType,
    String planTitle,
    AppLocalizations? l10n,
  ) {
    debugPrint('[SettingsScreen] 다운그레이드 확인 다이얼로그 - 목표 플랜: $newType');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            Text(l10n?.planChange ?? '플랜 변경'),
          ],
        ),
        content: Text(_downgradeMessage(newType)),
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
              debugPrint('[SettingsScreen] 다운그레이드 실행: $newType, 강제 로그아웃');
              await appState.changeSubscriptionType(newType);
              await appState.authService.signOut();
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text(l10n?.planChangedAndLoggedOut(planTitle) ?? '$planTitle 플랜으로 변경되었습니다. 로그아웃되었습니다.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n?.changeAndLogout ?? '변경 및 로그아웃'),
          ),
        ],
      ),
    );
  }

  /// 닉네임 변경 다이얼로그 — 입력 + 중복확인(필수) + 저장(서버 재검증).
  void _showChangeNicknameDialog(BuildContext context, AppStateProvider appState) {
    final current = _nickname ?? appState.currentUser?.displayName ?? '';
    final controller = TextEditingController(text: current);
    bool? available; // null=미확인, true=가능, false=중복
    bool checking = false;
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final color = Theme.of(ctx).primaryColor;
          return AlertDialog(
            title: const Text('닉네임 변경', style: TextStyle(fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    current.isEmpty ? '현재 닉네임: (없음)' : '현재 닉네임: $current',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: '닉네임',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixIcon: checking
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : TextButton(
                            onPressed: () async {
                              final nick = controller.text.trim();
                              if (nick.isEmpty) return;
                              setLocal(() => checking = true);
                              final ok = await appState.authService
                                  .checkNicknameAvailable(nick);
                              setLocal(() {
                                checking = false;
                                available = ok;
                              });
                            },
                            child: const Text('중복확인'),
                          ),
                  ),
                  onChanged: (_) {
                    if (available != null) setLocal(() => available = null);
                  },
                ),
                if (available == true)
                  const Padding(
                    padding: EdgeInsets.only(top: 4, left: 4),
                    child: Text('사용 가능한 닉네임입니다.',
                        style: TextStyle(fontSize: 12, color: Colors.green)),
                  ),
                if (available == false)
                  const Padding(
                    padding: EdgeInsets.only(top: 4, left: 4),
                    child: Text('이미 사용 중인 닉네임입니다.',
                        style: TextStyle(fontSize: 12, color: Colors.red)),
                  ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
              TextButton(
                onPressed: saving
                    ? null
                    : () async {
                        final nick = controller.text.trim();
                        if (nick.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('닉네임을 입력하세요.')));
                          return;
                        }
                        if (available != true) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('닉네임 중복확인을 해주세요.')));
                          return;
                        }
                        setLocal(() => saving = true);
                        final r =
                            await appState.authService.updateNickname(nick);
                        if (!ctx.mounted) return;
                        if (r.ok) {
                          Navigator.pop(ctx);
                          if (mounted) setState(() => _nickname = nick);
                          appState.setMyNickname(nick); // 탭 제목 즉시 반영
                          _loadRegisteredAccount(); // 서버 값 재동기화
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('닉네임을 변경했습니다.')));
                        } else {
                          setLocal(() => saving = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              content: Text(r.message ?? '닉네임 변경 실패')));
                        }
                      },
                style: TextButton.styleFrom(foregroundColor: color),
                child: const Text('저장'),
              ),
            ],
          );
        },
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
            Text(l10n?.logoutConfirmTitle ?? '로그아웃'),
          ],
        ),
        content: Text(
          isPremium
              ? (l10n?.logoutConfirmPremiumMessage ?? '프리미엄 상태에서 로그아웃 시 파일 공유를 할 수 없습니다.\n정말로 로그아웃 하시겠습니까?')
              : (l10n?.logoutConfirmMessage ?? '정말로 로그아웃 하시겠습니까?'),
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
                    content: Text(l10n?.logoutSuccess ?? '로그아웃되었습니다.'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              } catch (e) {
                // 에러 메시지
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(l10n?.logoutFailed(e.toString()) ?? '로그아웃 실패: $e'),
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
            child: Text(l10n?.logout ?? '로그아웃'),
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
            Text(l10n?.deleteAccountTitle ?? '회원탈퇴'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.deleteAccountConfirm ?? '정말로 회원탈퇴를 진행하시겠습니까?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(l10n?.deleteAccountWarningTitle ?? '회원탈퇴 시 다음 사항에 유의해주세요:', style: TextStyle(fontSize: 14)),
            SizedBox(height: 12),
            _buildWarningItem(l10n?.deleteAccountWarning1 ?? '• 모든 데이터가 영구적으로 삭제됩니다'),
            _buildWarningItem(l10n?.deleteAccountWarning2 ?? '• 서버에 저장된 파일이 모두 삭제됩니다'),
            _buildWarningItem(l10n?.deleteAccountWarning3 ?? '• 계정 복구가 불가능합니다'),
            _buildWarningItem(l10n?.deleteAccountWarning4 ?? '• 구독이 자동으로 취소됩니다'),
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
            child: Text(l10n?.deleteAccountButton ?? '탈퇴하기'),
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
        title: Text(l10n?.deleteAccountFinalConfirmTitle ?? '최종 확인'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n?.deleteAccountFinalConfirmMessage ?? '정말로 탈퇴하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              l10n?.deleteAccountFinalConfirmHint ?? '탈퇴하시려면 "삭제 확인" 버튼을 눌러주세요',
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
                          Text(l10n?.deleteAccountProgress ?? '계정 삭제 중...'),
                        ],
                      ),
                    ),
                  ),
                ),
              );

              try {
                // 회원탈퇴 실행 (서버 계정/데이터 삭제 + 로그아웃, 로컬 데이터는 유지)
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
                    content: Text(l10n?.deleteAccountSuccess ?? '계정이 삭제되었습니다. 로컬 파일은 유지되며 무료 플랜으로 전환되었습니다.'),
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
                    content: Text(l10n?.deleteAccountFailed(e.toString()) ?? '계정 삭제 실패: $e'),
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
            child: Text(l10n?.deleteAccountConfirmButton ?? '삭제 확인'),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── 영역 보기 설정 다이얼로그 ─────────────────────────────

class _VisibleAreasDialog extends StatefulWidget {
  final AppStateProvider appState;
  const _VisibleAreasDialog({required this.appState});

  @override
  State<_VisibleAreasDialog> createState() => _VisibleAreasDialogState();
}

class _VisibleAreasDialogState extends State<_VisibleAreasDialog> {
  late Set<String> _selected;

  List<Map<String, dynamic>> _buildAreas(AppLocalizations? l10n) => [
    {'id': 'topRight',    'label': l10n?.positionTopRight ?? '우상단',    'icon': Icons.north_east},
    {'id': 'bottomLeft',  'label': l10n?.positionBottomLeft ?? '좌하단',  'icon': Icons.south_west},
    {'id': 'bottomRight', 'label': l10n?.positionBottomRight ?? '우하단', 'icon': Icons.south_east},
  ];

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.appState.visibleAreas);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final themeColor = Theme.of(context).primaryColor;
    final areas = _buildAreas(l10n);
    return AlertDialog(
      title: Text(l10n?.visibleAreas ?? '영역 보기'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 좌상단 — 항상 활성 (고정)
          ListTile(
            dense: true,
            leading: Icon(Icons.north_west, size: 20, color: themeColor),
            title: Text(l10n?.positionTopLeft ?? '좌상단'),
            subtitle: Text(l10n?.allTabFixed ?? '전체탭 고정', style: const TextStyle(fontSize: 11)),
            trailing: Icon(Icons.lock, color: themeColor, size: 18),
          ),
          const Divider(height: 1),
          ...areas.map((area) {
            final id = area['id'] as String;
            final label = area['label'] as String;
            final icon = area['icon'] as IconData;
            final isChecked = _selected.contains(id);
            return CheckboxListTile(
              dense: true,
              secondary: Icon(icon, size: 20, color: isChecked ? themeColor : Colors.grey),
              title: Text(label),
              value: isChecked,
              activeColor: themeColor,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selected.add(id);
                  } else {
                    _selected.remove(id);
                  }
                });
              },
            );
          }),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.cancel ?? '취소'),
        ),
        TextButton(
          onPressed: () {
            widget.appState.setVisibleAreas(_selected);
            Navigator.of(context).pop();
          },
          child: Text(l10n?.confirm ?? '확인'),
        ),
      ],
    );
  }
}

// ───────────────────────────── 노트탭 보기 설정 다이얼로그 ─────────────────────────────

class _NoteTabVisibilityDialog extends StatefulWidget {
  final AppStateProvider appState;
  const _NoteTabVisibilityDialog({required this.appState});

  @override
  State<_NoteTabVisibilityDialog> createState() => _NoteTabVisibilityDialogState();
}

class _NoteTabVisibilityDialogState extends State<_NoteTabVisibilityDialog> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.appState.noteTabVisibility);
  }

  List<Map<String, dynamic>> _buildTabs(AppLocalizations? l10n) => [
    {'id': 'handwriting', 'label': l10n?.handwritingTab ?? '필기', 'icon': Icons.draw},
    {'id': 'text', 'label': l10n?.memoLabel ?? '메모', 'icon': Icons.notes},
    {'id': 'pdf', 'label': 'PDF', 'icon': Icons.picture_as_pdf},
    {'id': 'audio', 'label': l10n?.audioTab ?? '녹음', 'icon': Icons.mic},
    {'id': 'sttMemo', 'label': l10n?.sttMemoLabel ?? '녹음메모', 'icon': Icons.record_voice_over},
    {'id': 'files', 'label': '파일', 'icon': Icons.drive_folder_upload},
    {'id': 'youtube', 'label': '영상', 'icon': Icons.subscriptions_outlined},
    {'id': 'browser', 'label': l10n?.browserTab ?? '검색', 'icon': Icons.public},
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tabs = _buildTabs(l10n);
    final themeColor = Theme.of(context).primaryColor;
    return AlertDialog(
      title: Text(l10n?.noteTabView ?? '노트 탭 표시'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 전체는 항상 활성 (고정)
          ListTile(
            dense: true,
            leading: Icon(Icons.apps, size: 20, color: themeColor),
            title: Text(l10n?.allFilesLabel ?? '전체'),
            trailing: Icon(Icons.check_circle, color: themeColor, size: 20),
          ),
          const Divider(height: 1),
          ...tabs.map((tab) {
            final id = tab['id'] as String;
            final label = tab['label'] as String;
            final icon = tab['icon'] as IconData;
            final isChecked = _selected.contains(id);
            return CheckboxListTile(
              dense: true,
              // 녹음 메모(sttMemo)는 녹음+메모 합성 아이콘.
              secondary: id == 'sttMemo'
                  ? RecordMemoIcon(size: 20, color: isChecked ? themeColor : Colors.grey)
                  : Icon(icon, size: 20, color: isChecked ? themeColor : Colors.grey),
              title: Text(label),
              value: isChecked,
              activeColor: themeColor,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selected.add(id);
                  } else {
                    _selected.remove(id);
                  }
                });
              },
            );
          }),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.cancel ?? '취소'),
        ),
        TextButton(
          onPressed: () {
            widget.appState.setNoteTabVisibility(_selected); // ignore: discarded_futures
            Navigator.of(context).pop();
          },
          child: Text(l10n?.confirm ?? '확인'),
        ),
      ],
    );
  }
}

// ── 전체탭 FAB 버튼 가시성 다이얼로그 ────────────────────────────────────────
class _AllTabFabVisibilityDialog extends StatefulWidget {
  final AppStateProvider appState;
  const _AllTabFabVisibilityDialog({required this.appState});

  @override
  State<_AllTabFabVisibilityDialog> createState() => _AllTabFabVisibilityDialogState();
}

class _AllTabFabVisibilityDialogState extends State<_AllTabFabVisibilityDialog> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.appState.allTabFabVisibility);
  }

  List<Map<String, dynamic>> _buildButtons(AppLocalizations? l10n) => [
    // 순서: 메모 → 필기 → 녹음 → 녹음 메모 → 파일 → 영상 채널 → 사진 → 비디오
    {'id': 'text',   'label': l10n?.memoLabel ?? '메모',         'icon': Icons.notes},
    {'id': 'canvas', 'label': l10n?.handwritingTab ?? '필기',    'icon': Icons.draw},
    {'id': 'audio',  'label': l10n?.audioTab ?? '녹음',          'icon': Icons.mic},
    {'id': 'stt',    'label': l10n?.voiceMemoLabel ?? '녹음 메모', 'icon': Icons.record_voice_over},
    {'id': 'files',  'label': '파일',                            'icon': Icons.attach_file},
    {'id': 'youtube', 'label': '영상 채널',                       'icon': Icons.subscriptions_outlined},
    {'id': 'photo',  'label': '사진',                            'icon': Icons.photo_camera},
    {'id': 'video',  'label': '비디오',                          'icon': Icons.videocam},
  ];

  /// 녹음+메모 합성 아이콘 (단색 컨텍스트용) — 공용 [RecordMemoIcon]에 위임.
  Widget _recordMemoIcon(Color color) =>
      RecordMemoIcon(size: 20, color: color);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final buttons = _buildButtons(l10n);
    final color = Theme.of(context).primaryColor;
    return AlertDialog(
      title: Text(l10n?.allTabFab ?? '전체탭 빠른 추가 표시'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: buttons.map((btn) {
          final id = btn['id'] as String;
          final label = btn['label'] as String;
          final icon = btn['icon'] as IconData;
          final isChecked = _selected.contains(id);
          final iconColor = isChecked ? color : Colors.grey;
          return CheckboxListTile(
            dense: true,
            // 녹음 메모(stt)는 녹음+메모 합성 아이콘으로 표시 (노트 "+" 메뉴와 일치)
            secondary: id == 'stt'
                ? _recordMemoIcon(iconColor)
                : Icon(icon, size: 20, color: iconColor),
            title: Text(label),
            value: isChecked,
            activeColor: color,
            onChanged: (val) {
              setState(() {
                if (val == true) _selected.add(id);
                else _selected.remove(id);
              });
            },
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.cancel ?? '취소'),
        ),
        TextButton(
          onPressed: () {
            widget.appState.setAllTabFabVisibility(_selected);
            Navigator.of(context).pop();
          },
          child: Text(l10n?.confirm ?? '확인'),
        ),
      ],
    );
  }
}

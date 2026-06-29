import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/draggable_tab_layout.dart';
import '../services/app_state_provider.dart';
import 'settings_screen.dart';

/// 설정 영역 — 다른 탭(홈/리마인드)과 동일한 DraggableTabLayout으로 구성.
/// 제목란에 현재 닉네임(아이디)과 구독 플랜명을 표시한다.
///
/// ⭐ 개인화 확장 지점: [_tabs]에 TabItem을 추가하면 설정 영역에 탭이 늘어난다.
class SettingsTabScreen extends StatefulWidget {
  const SettingsTabScreen({super.key});

  @override
  State<SettingsTabScreen> createState() => _SettingsTabScreenState();
}

class _SettingsTabScreenState extends State<SettingsTabScreen> {
  late final List<TabItem> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      TabItem(
        id: 'settings',
        title: '설정',
        icon: Icons.settings,
        // 제목란: 닉네임(아이디) · 구독 플랜명
        customTabWidget: const _SettingsTabTitle(),
        content: const SettingsScreen(),
        position: TabPosition.topLeft,
        // 단일 탭이라 드래그가 무의미 — 제목란 우측 드래그 핸들 숨김
        isDraggable: false,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('⚙️ [SettingsTabScreen] build - 탭 ${_tabs.length}개');
    return DraggableTabLayout(
      tabs: _tabs,
      initialActiveTabId: 'settings',
      visibleAreas: const {'topLeft'},
      onTabPositionChanged: (tabId, newPosition) {
        setState(() {
          for (final t in _tabs) {
            if (t.id == tabId) {
              t.position = newPosition;
              break;
            }
          }
        });
        debugPrint('[SettingsTabScreen] 탭 위치 변경: $tabId -> $newPosition');
      },
      onTabChanged: (tabId) {
        debugPrint('[SettingsTabScreen] 탭 변경: $tabId');
      },
    );
  }
}

/// 설정 탭 제목란 — "닉네임(아이디) · 플랜명". 비로그인 시 "게스트 · 플랜명".
class _SettingsTabTitle extends StatelessWidget {
  const _SettingsTabTitle();

  String _planName(SubscriptionType type) {
    switch (type) {
      case SubscriptionType.free:
        return '무료';
      case SubscriptionType.standard:
        return '스탠다드';
      case SubscriptionType.premium:
        return '프리미엄';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Consumer<AppStateProvider>(
      builder: (context, appState, _) {
        final user = appState.currentUser;
        final email = (user?.email ?? '').trim();
        final nick = (user?.displayName ?? '').trim();
        final plan = _planName(appState.subscriptionType);

        // 닉네임(아이디) 조합: 닉네임이 있으면 '닉네임(아이디)', 없으면 아이디만, 비로그인은 게스트.
        final String who;
        if (!appState.isLoggedIn || email.isEmpty) {
          who = '게스트';
        } else if (nick.isNotEmpty) {
          who = '$nick($email)';
        } else {
          who = email;
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_circle, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '$who · $plan',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: color),
              ),
            ),
          ],
        );
      },
    );
  }
}

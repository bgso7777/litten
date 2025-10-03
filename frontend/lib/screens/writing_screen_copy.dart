import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state_provider.dart';
import '../widgets/draggable_tab_layout.dart';

// 실제 기능 탭들을 import
import '../widgets/recording_tab.dart';
import '../widgets/text_tab.dart';
import '../widgets/handwriting_tab.dart';
import '../widgets/browser_tab.dart';

class WritingScreen extends StatefulWidget {
  const WritingScreen({super.key});

  @override
  State<WritingScreen> createState() => _WritingScreenState();
}

class _WritingScreenState extends State<WritingScreen> {
  late List<TabItem> _tabs;

  @override
  void initState() {
    super.initState();

    // 탭 초기화 - 좌상단 영역에 텍스트, 필기, 듣기, Google 순서로 배치
    _tabs = [
      TabItem(
        id: 'text',
        title: '텍스트',
        icon: Icons.text_fields,
        content: const TextTab(),
        position: TabPosition.topLeft,
      ),
      TabItem(
        id: 'handwriting',
        title: '필기',
        icon: Icons.draw,
        content: const HandwritingTab(),
        position: TabPosition.topLeft,
      ),
      TabItem(
        id: 'audio',
        title: '듣기',
        icon: Icons.mic,
        content: const RecordingTab(),
        position: TabPosition.topLeft,
      ),
      TabItem(
        id: 'browser',
        title: 'Google',
        icon: Icons.public,
        content: const BrowserTab(),
        position: TabPosition.topLeft,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        // 리튼이 선택되지 않았을 때
        if (appState.selectedLitten == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.create_new_folder,
                  size: 64,
                  color: Theme.of(context).disabledColor,
                ),
                const SizedBox(height: 16),
                Text(
                  '먼저 리튼을 선택하거나 생성하세요',
                  style: TextStyle(
                    fontSize: 18,
                    color: Theme.of(context).disabledColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '홈 탭에서 리튼을 관리할 수 있습니다',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).disabledColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
        }

        // 드래그 가능한 탭 레이아웃
        return DraggableTabLayout(
          tabs: _tabs,
          onTabPositionChanged: (tabId, newPosition) {
            setState(() {
              for (final tab in _tabs) {
                if (tab.id == tabId) {
                  tab.position = newPosition;
                  break;
                }
              }
            });
          },
        );
      },
    );
  }
}
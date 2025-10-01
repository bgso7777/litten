import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state_provider.dart';
import '../widgets/draggable_tab_layout.dart';
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
    _initializeTabs();
  }

  void _initializeTabs() {
    _tabs = [
      TabItem(
        id: 'handwriting',
        title: '필기',
        icon: Icons.draw,
        content: const HandwritingTab(),
        position: TabPosition.topLeft,
      ),
      TabItem(
        id: 'text',
        title: '텍스트',
        icon: Icons.keyboard,
        content: const TextTab(),
        position: TabPosition.topRight,
      ),
      TabItem(
        id: 'audio',
        title: '녹음',
        icon: Icons.mic,
        content: const RecordingTab(),
        position: TabPosition.bottomLeft,
      ),
      TabItem(
        id: 'browser',
        title: '브라우저',
        icon: Icons.public,
        content: const BrowserTab(),
        position: TabPosition.bottomRight,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        // 리튼이 선택되지 않았을 때
        if (appState.selectedLitten == null) {
          return _buildEmptyState(context);
        }

        // 드래그 가능한 탭 레이아웃
        return DraggableTabLayout(tabs: _tabs);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
}
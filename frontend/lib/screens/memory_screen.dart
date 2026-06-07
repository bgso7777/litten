import 'package:flutter/material.dart';
import '../widgets/remind_panel.dart';

/// 기억 탭 — 노트 하단에 있던 리마인드 칩셋 내용을 독립 화면으로 이동.
/// 리마인드 내용 표시 + 기억 유도용 깜빡이 + 완료 체크.
class MemoryScreen extends StatelessWidget {
  const MemoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('🧠 [MemoryScreen] build');
    return const Material(
      child: SafeArea(
        top: false,
        child: RemindPanel(isFullScreen: true),
      ),
    );
  }
}

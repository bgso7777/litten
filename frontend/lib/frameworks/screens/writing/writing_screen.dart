import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../widgets/empty_state_widget.dart';

/// 쓰기 화면 - 텍스트 작성 및 필기
class WritingScreen extends StatefulWidget {
  const WritingScreen({Key? key}) : super(key: key);

  @override
  State<WritingScreen> createState() => _WritingScreenState();
}

class _WritingScreenState extends State<WritingScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    // TODO: 실제 텍스트/필기 기능 구현
    return EmptyStateWidget(
      icon: Icons.edit,
      title: '쓰기 기능 구현 예정',
      subtitle: '텍스트 작성 및 필기 기능이 곧 추가됩니다',
      actionText: '새 텍스트',
      onActionPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('쓰기 기능은 곧 구현됩니다')),
        );
      },
    );
  }
}
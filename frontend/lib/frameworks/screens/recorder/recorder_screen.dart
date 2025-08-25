import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../widgets/empty_state_widget.dart';

/// 듣기 화면 - 음성 녹음 및 재생
class RecorderScreen extends StatefulWidget {
  const RecorderScreen({Key? key}) : super(key: key);

  @override
  State<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    // TODO: 실제 음성 기능 구현
    return EmptyStateWidget(
      icon: Icons.mic,
      title: '음성 기능 구현 예정',
      subtitle: '음성 녹음 및 재생 기능이 곧 추가됩니다',
      actionText: '테스트 녹음',
      onActionPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('음성 기능은 곧 구현됩니다')),
        );
      },
    );
  }
}
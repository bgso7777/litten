import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_localizations_temp.dart';

import '../services/app_state_provider.dart';
import '../widgets/common/empty_state.dart';
import '../config/themes.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;

  void _toggleRecording() {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    
    if (appState.selectedLitten == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 리튼을 선택하거나 생성해주세요.')),
      );
      return;
    }
    
    setState(() {
      _isRecording = !_isRecording;
      if (!_isRecording) {
        _recordingDuration = Duration.zero;
      }
    });
    
    if (_isRecording) {
      _startRecordingTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('녹음이 시작되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('녹음이 중지되었습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startRecordingTimer() {
    if (_isRecording) {
      Future.delayed(const Duration(seconds: 1), () {
        if (_isRecording && mounted) {
          setState(() {
            _recordingDuration += const Duration(seconds: 1);
          });
          _startRecordingTimer();
        }
      });
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        if (appState.selectedLitten == null) {
          return EmptyState(
            icon: Icons.mic_none,
            title: '리튼을 선택해주세요',
            description: '녹음을 시작하려면 먼저 홈 탭에서 리튼을 선택하거나 생성해주세요.',
            actionText: '홈으로 이동',
            onAction: () => appState.changeTabIndex(0),
          );
        }

        return Column(
          children: [
            // 녹음 파일 목록 영역 (확장 예정)
            Expanded(
              child: Container(
                padding: AppSpacing.paddingL,
                child: const Center(
                  child: Text(
                    '녹음 파일 목록\n(구현 예정)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
            // 녹음 컨트롤 패널
            Container(
              padding: AppSpacing.paddingL,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Column(
                children: [
                  // 녹음 상태 표시
                  if (_isRecording) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        AppSpacing.horizontalSpaceS,
                        Text(
                          '녹음 중... ${_formatDuration(_recordingDuration)}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.verticalSpaceM,
                  ],
                  // 녹음 버튼
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _toggleRecording,
                        icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                        label: Text(
                          _isRecording 
                              ? (l10n?.stopRecording ?? '녹음 중지')
                              : (l10n?.startRecording ?? '녹음 시작'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isRecording 
                              ? Colors.red 
                              : AppColors.recordingColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24, 
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.verticalSpaceM,
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
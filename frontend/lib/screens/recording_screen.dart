import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';

import '../services/app_state_provider.dart';
import '../services/audio_service.dart';
import '../widgets/common/empty_state.dart';
import '../config/themes.dart';
import '../models/audio_file.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  final AudioService _audioService = AudioService();
  List<AudioFile> _audioFiles = [];

  @override
  void initState() {
    super.initState();
    _loadAudioFiles();
  }

  Future<void> _loadAudioFiles() async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    if (appState.selectedLitten != null) {
      final files = await _audioService.getAudioFiles(appState.selectedLitten!);
      if (mounted) {
        setState(() {
          _audioFiles = files;
        });
      }
    }
  }

  Future<void> _toggleRecording() async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context);
    
    if (appState.selectedLitten == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.selectLittenFirstMessage ?? '먼저 리튼을 선택하거나 생성해주세요.')),
      );
      return;
    }

    if (_audioService.isRecording) {
      // 듣기 중지 및 파일 저장
      final audioFile = await _audioService.stopRecording(appState.selectedLitten!);
      if (mounted && audioFile != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.recordingStoppedAndSaved ?? '듣기가 중지되고 파일이 저장되었습니다.'),
            backgroundColor: Colors.blue,
          ),
        );
        await _loadAudioFiles(); // 목록 새로고침
      }
    } else {
      // 듣기 시작
      final success = await _audioService.startRecording(appState.selectedLitten!);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n?.recordingStarted ?? '듣기가 시작되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n?.recordingFailed ?? '듣기 시작에 실패했습니다. 권한을 확인해주세요.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _playAudio(AudioFile audioFile) async {
    if (_audioService.currentPlayingFile?.id == audioFile.id && _audioService.isPlaying) {
      await _audioService.stopAudio();
    } else {
      final success = await _audioService.playAudio(audioFile);
      if (mounted && !success) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.playbackFailed ?? '재생에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAudio(AudioFile audioFile) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.deleteFile ?? '파일 삭제'),
        content: Text('${audioFile.fileName} 파일을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n?.cancel ?? '취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n?.delete ?? '삭제', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _audioService.deleteAudioFile(audioFile);
      if (mounted && success) {
        await _loadAudioFiles(); // 목록 새로고침
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.fileDeleted ?? '파일이 삭제되었습니다.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    }
  }

  Future<void> _changePlaybackSpeed() async {
    final l10n = AppLocalizations.of(context);
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final currentSpeed = _audioService.playbackSpeed;
    
    final newSpeed = await showDialog<double>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n?.selectPlaybackSpeed ?? '재생 속도 선택'),
        children: speeds.map((speed) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, speed),
          child: Row(
            children: [
              if (speed == currentSpeed) const Icon(Icons.check, color: Colors.blue),
              const SizedBox(width: 8),
              Text('${speed}x'),
            ],
          ),
        )).toList(),
      ),
    );

    if (newSpeed != null) {
      await _audioService.setPlaybackSpeed(newSpeed);
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // 음성-쓰기 동기화 상태 표시 위젯
  Widget _buildSyncStatusBar() {
    final l10n = AppLocalizations.of(context);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _audioService,
            builder: (context, child) {
              return Icon(
                _audioService.isRecording ? Icons.mic : Icons.sync, 
                color: Colors.black87, 
                size: 16
              );
            },
          ),
          const SizedBox(width: 8),
          AnimatedBuilder(
            animation: _audioService,
            builder: (context, child) {
              return Text(
                _audioService.isRecording 
                    ? (l10n?.recording ?? '듣기 중...')
                    : (l10n?.recordingTitle ?? '음성 동기화 준비됨'),
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              );
            },
          ),
          const Spacer(),
          AnimatedBuilder(
            animation: _audioService,
            builder: (context, child) {
              return Text(
                _audioService.isRecording 
                    ? _formatDuration(_audioService.recordingDuration)
                    : '00:00',
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        if (appState.selectedLitten == null) {
          return EmptyState(
            icon: Icons.mic_none,
            title: l10n?.noLittenSelected ?? '리튼을 선택해주세요',
            description: l10n?.selectLittenFirst ?? '듣기를 시작하려면 먼저 홈 탭에서 리튼을 선택하거나 생성해주세요.',
            actionText: l10n?.goToHome ?? '홈으로 이동',
            onAction: () => appState.changeTabIndex(0),
          );
        }

        return AnimatedBuilder(
          animation: _audioService,
          builder: (context, child) => Column(
            children: [
              // 음성-쓰기 동기화 상태 표시
              _buildSyncStatusBar(),
              // 듣기 파일 목록 영역
              Expanded(
                child: Container(
                  padding: AppSpacing.paddingL,
                  child: _audioFiles.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.headphones_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '${l10n?.noAudioFilesYet ?? '아직 듣기 파일이 없습니다'}\n${l10n?.startFirstRecording ?? '아래 버튼을 눌러 첫 번째 듣기를 시작하세요'}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _audioFiles.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final audioFile = _audioFiles[index];
                            final isCurrentPlaying = _audioService.currentPlayingFile?.id == audioFile.id;
                            
                            return ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isCurrentPlaying && _audioService.isPlaying 
                                      ? Colors.blue 
                                      : Colors.grey.shade300,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isCurrentPlaying && _audioService.isPlaying 
                                      ? Icons.pause 
                                      : Icons.play_arrow,
                                  color: isCurrentPlaying && _audioService.isPlaying 
                                      ? Colors.white 
                                      : Colors.grey.shade600,
                                ),
                              ),
                              title: Text(
                                audioFile.fileName,
                                style: TextStyle(
                                  fontWeight: isCurrentPlaying ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${l10n?.created ?? '생성'}: ${audioFile.createdAt.month}/${audioFile.createdAt.day} ${audioFile.createdAt.hour}:${audioFile.createdAt.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  if (isCurrentPlaying && _audioService.isPlaying) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          '${_formatDuration(_audioService.playbackDuration)} / ${_formatDuration(_audioService.totalDuration)}',
                                          style: const TextStyle(fontSize: 12, color: Colors.blue),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${_audioService.playbackSpeed}x',
                                          style: const TextStyle(fontSize: 12, color: Colors.blue),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isCurrentPlaying && _audioService.isPlaying) ...[
                                    IconButton(
                                      icon: const Icon(Icons.speed),
                                      onPressed: _changePlaybackSpeed,
                                      tooltip: l10n?.playbackSpeed ?? '재생 속도',
                                    ),
                                  ],
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _deleteAudio(audioFile),
                                    tooltip: l10n?.delete ?? '삭제',
                                  ),
                                ],
                              ),
                              onTap: () => _playAudio(audioFile),
                            );
                          },
                        ),
                ),
              ),
              // 듣기 컨트롤 패널
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
                    // 듣기 버튼
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _toggleRecording,
                          icon: Icon(_audioService.isRecording ? Icons.stop : Icons.mic),
                          label: Text(
                            _audioService.isRecording 
                                ? l10n?.stopRecording ?? '듣기 중지'
                                : l10n?.startRecording ?? '듣기 시작',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
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
                    // 하단 네비게이션 바와의 간격 확보
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
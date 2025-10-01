import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/app_state_provider.dart';
import '../services/audio_service.dart';
import '../models/audio_file.dart';
import '../models/litten.dart';
import '../config/app_spacing.dart';
import '../config/app_text_styles.dart';
import '../widgets/empty_state.dart';

class RecordingTab extends StatefulWidget {
  const RecordingTab({super.key});

  @override
  State<RecordingTab> createState() => _RecordingTabState();
}

class _RecordingTabState extends State<RecordingTab> {
  final AudioService _audioService = AudioService();
  List<AudioFile> _audioFiles = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAudioFiles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        if (appState.selectedLitten == null) {
          return const EmptyState(
            icon: Icons.edit_note,
            title: '리튼을 선택해주세요',
            subtitle: '녹음을 시작하려면 먼저 홈 탭에서 리튼을 선택하거나 생성해주세요.',
          );
        }

        return Container(
          color: Colors.orange.shade50,
          child: Stack(
            children: [
              Column(
                children: [
                  // 헤더
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      border: Border(
                        bottom: BorderSide(color: Colors.orange.shade200),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.hearing,
                          color: Colors.orange.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '듣기 (${_audioFiles.length})',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        const Spacer(),
                        AnimatedBuilder(
                          animation: _audioService,
                          builder: (context, child) {
                            if (_audioService.isRecording) {
                              return Row(
                                children: [
                                  Icon(
                                    Icons.fiber_manual_record,
                                    color: Colors.red,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDuration(_audioService.recordingDuration),
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                  ),
                  // 오디오 파일 목록
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(),
                          )
                        : _audioFiles.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.mic_off,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      '아직 녹음된 파일이 없습니다',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '하단의 녹음 버튼을 눌러 시작해보세요',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _audioFiles.length,
                                itemBuilder: (context, index) {
                                  return _buildAudioFileItem(_audioFiles[index]);
                                },
                              ),
                  ),
                ],
              ),
              // 녹음 버튼 (우하단 고정)
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton(
                  onPressed: _toggleRecording,
                  backgroundColor: _audioService.isRecording
                      ? Colors.red
                      : Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  child: AnimatedBuilder(
                    animation: _audioService,
                    builder: (context, child) {
                      return Icon(
                        _audioService.isRecording ? Icons.stop : Icons.mic,
                        size: 28,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadAudioFiles() async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final selectedLitten = appState.selectedLitten;

    if (selectedLitten == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final audioFiles = await _audioService.getAudioFiles(selectedLitten);
      setState(() {
        _audioFiles = audioFiles;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[RecordingTab] 오디오 파일 로드 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildAudioFileItem(AudioFile audioFile) {
    final timeFormat = DateFormat('HH:mm');

    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.paddingS),
      elevation: 2,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.hearing,
            color: Colors.orange.shade700,
            size: 24,
          ),
        ),
        title: Text(
          audioFile.fileName,
          style: AppTextStyles.headline3,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              timeFormat.format(audioFile.createdAt),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            const SizedBox(width: 12),
            Icon(Icons.timer, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              _formatDuration(audioFile.duration ?? Duration.zero),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 재생/정지 버튼
            AnimatedBuilder(
              animation: _audioService,
              builder: (context, child) {
                final isCurrentlyPlaying = _audioService.isPlaying &&
                    _audioService.currentPlayingFile?.id == audioFile.id;

                return IconButton(
                  onPressed: () => _playAudio(audioFile),
                  icon: Icon(
                    isCurrentlyPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.orange.shade700,
                  ),
                );
              },
            ),
            // 삭제 버튼
            IconButton(
              onPressed: () => _deleteAudioFile(audioFile),
              icon: const Icon(Icons.delete_outline),
              color: Colors.red.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleRecording() async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final selectedLitten = appState.selectedLitten;

    if (selectedLitten == null) return;

    if (_audioService.isRecording) {
      final audioFile = await _audioService.stopRecording(selectedLitten);
      if (audioFile != null) {
        await _loadAudioFiles();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('녹음이 저장되었습니다: ${audioFile.fileName}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } else {
      final success = await _audioService.startRecording(selectedLitten);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('녹음을 시작할 수 없습니다. 마이크 권한을 확인해주세요.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _playAudio(AudioFile audioFile) async {
    if (_audioService.isPlaying && _audioService.currentPlayingFile?.id == audioFile.id) {
      await _audioService.stopAudio();
    } else {
      await _audioService.playAudio(audioFile);
    }
  }

  Future<void> _deleteAudioFile(AudioFile audioFile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('파일 삭제'),
        content: Text('"${audioFile.fileName}" 파일을 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _audioService.deleteAudioFile(audioFile);
      if (success) {
        await _loadAudioFiles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${audioFile.fileName}" 파일이 삭제되었습니다.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
  }
}
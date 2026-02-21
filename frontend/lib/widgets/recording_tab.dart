import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';

import '../services/app_state_provider.dart';
import '../services/audio_service.dart';
import '../services/litten_service.dart';
import '../widgets/common/empty_state.dart';
import '../config/themes.dart';
import '../models/audio_file.dart';

class RecordingTab extends StatefulWidget {
  const RecordingTab({super.key});

  @override
  State<RecordingTab> createState() => _RecordingTabState();
}

class _RecordingTabState extends State<RecordingTab> {
  final AudioService _audioService = AudioService();
  List<AudioFile> _audioFiles = [];
  String? _lastActiveTabId; // 마지막으로 알고 있던 활성 탭 ID

  @override
  void initState() {
    super.initState();
    _loadAudioFiles();
  }

  // ⭐ 외부에서 호출 가능한 public 새로고침 메서드
  void refresh() {
    debugPrint('[RecordingTab] refresh() 외부 호출됨');
    _loadAudioFiles();
  }

  Future<void> _loadAudioFiles() async {
    debugPrint('[RecordingTab] _loadAudioFiles() 호출');
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    if (appState.selectedLitten != null) {
      final files = await _audioService.getAudioFiles(appState.selectedLitten!);
      debugPrint('[RecordingTab] 로드된 오디오 파일 수: ${files.length}');
      if (mounted) {
        setState(() {
          _audioFiles = files;
          // 최신순으로 정렬 (createdAt 기준 내림차순)
          _audioFiles.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });
        debugPrint('[RecordingTab] UI 업데이트 완료 - 표시 파일 수: ${_audioFiles.length}');
      }
    } else {
      debugPrint('[RecordingTab] 선택된 리튼 없음');
    }
  }

  Future<void> _toggleRecording() async {
    print('[RecordingTab] _toggleRecording 진입');
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context);

    if (appState.selectedLitten == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n?.selectLittenFirstMessage ?? '먼저 리튼을 선택하거나 생성해주세요.',
            ),
          ),
        );
      }
      return;
    }

    if (_audioService.isRecording) {
      print('[RecordingTab] 녹음 중지 시작');
      // 녹음 중지 및 파일 저장
      final audioFile = await _audioService.stopRecording(
        appState.selectedLitten!,
      );
      print('[RecordingTab] 녹음 중지 완료, mounted: $mounted, audioFile: ${audioFile?.id}');

      if (mounted && audioFile != null) {
        // 리튼의 오디오 파일 목록에 추가
        final littenService = LittenService();
        await littenService.addAudioFileToLitten(
          appState.selectedLitten!.id,
          audioFile.id,
        );

        // refreshLittens() 호출하지 않음 - Consumer rebuild 방지
        await _loadAudioFiles(); // 목록 새로고침

        // 파일 카운트 업데이트
        await appState.updateFileCount();
        print('[RecordingTab] 파일 카운트 업데이트 완료');

        print('[RecordingTab] 파일 목록 새로고침 완료, mounted: $mounted');

        if (mounted) {
          print('[RecordingTab] SnackBar 표시 시도');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n?.recordingStoppedAndSaved ?? '녹음이 중지되고 파일이 저장되었습니다.',
              ),
              backgroundColor: Colors.blue,
            ),
          );
          print('[RecordingTab] SnackBar 표시 완료');
        }
      }
      print('[RecordingTab] 녹음 중지 프로세스 종료');
    } else {
      print('[RecordingTab] 녹음 시작');
      // 녹음 시작
      final success = await _audioService.startRecording(
        appState.selectedLitten!,
      );
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n?.recordingStarted ?? '녹음이 시작되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n?.recordingFailed ?? '녹음 시작에 실패했습니다. 권한을 확인해주세요.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _playAudio(AudioFile audioFile) async {
    // 같은 파일이 재생 중이면 일시정지/재개
    if (_audioService.currentPlayingFile?.id == audioFile.id) {
      if (_audioService.isPlaying) {
        await _audioService.pauseAudio();
      } else {
        await _audioService.resumeAudio();
      }
    } else {
      // 다른 파일 재생
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
            child: Text(
              l10n?.delete ?? '삭제',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _audioService.deleteAudioFile(audioFile);
      if (mounted && success) {
        // 파일 카운트 업데이트
        final appState = Provider.of<AppStateProvider>(context, listen: false);
        await appState.updateFileCount();

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
        children: speeds
            .map(
              (speed) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, speed),
                child: Row(
                  children: [
                    if (speed == currentSpeed)
                      const Icon(Icons.check, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text('${speed}x'),
                  ],
                ),
              ),
            )
            .toList(),
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
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _audioService,
            builder: (context, child) {
              return Icon(
                _audioService.isRecording ? Icons.mic : Icons.sync,
                color: Colors.black87,
                size: 16,
              );
            },
          ),
          const SizedBox(width: 8),
          AnimatedBuilder(
            animation: _audioService,
            builder: (context, child) {
              return Text(
                _audioService.isRecording
                    ? (l10n?.recording ?? '녹음 중...')
                    : (l10n?.recordingTitle ?? '녹음 동기화 준비됨'),
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
        // 녹음 탭이 활성화되었을 때 파일 목록 새로고침
        if (appState.currentWritingTabId == 'audio' && _lastActiveTabId != 'audio') {
          _lastActiveTabId = 'audio';
          debugPrint('[RecordingTab] 녹음 탭 활성화됨 - 파일 목록 새로고침');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadAudioFiles();
          });
        } else if (appState.currentWritingTabId != 'audio') {
          _lastActiveTabId = appState.currentWritingTabId;
        }

        if (appState.selectedLitten == null) {
          return EmptyState(
            icon: Icons.mic_none,
            title: l10n?.noLittenSelected ?? '리튼을 선택해주세요',
            description:
                l10n?.selectLittenFirst ??
                '듣기를 시작하려면 먼저 홈 탭에서 리튼을 선택하거나 생성해주세요.',
            actionText: l10n?.goToHome ?? '홈으로 이동',
            onAction: () => appState.changeTabIndex(0),
          );
        }

        return AnimatedBuilder(
          animation: _audioService,
          builder: (context, child) => Stack(
            children: [
              Column(
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
                                    '${l10n?.noAudioFilesYet ?? '아직 녹음 파일이 없습니다'}\n${l10n?.startFirstRecording ?? '아래 버튼을 눌러 첫 번째 녹음을 시작하세요'}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _audioFiles.length,
                              itemBuilder: (context, index) {
                                final audioFile = _audioFiles[index];
                                final isCurrentPlaying =
                                    _audioService.currentPlayingFile?.id ==
                                    audioFile.id;

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 4),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isCurrentPlaying &&
                                              _audioService.isPlaying
                                          ? Colors.blue
                                          : Theme.of(context)
                                              .primaryColor
                                              .withValues(alpha: 0.1),
                                      child: Icon(
                                        isCurrentPlaying &&
                                                _audioService.isPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                        color: isCurrentPlaying &&
                                                _audioService.isPlaying
                                            ? Colors.white
                                            : Theme.of(context).primaryColor,
                                      ),
                                    ),
                                    title: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          audioFile.fileName,
                                          style: TextStyle(
                                            fontWeight: isCurrentPlaying
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${l10n?.created ?? '생성'}: ${audioFile.createdAt.month}/${audioFile.createdAt.day} ${audioFile.createdAt.hour}:${audioFile.createdAt.minute.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        if (isCurrentPlaying) ...[
                                          const SizedBox(height: 8),
                                          // 프로그레스바
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              SliderTheme(
                                                data: SliderTheme.of(context)
                                                    .copyWith(
                                                  trackHeight: 2.0,
                                                  thumbShape:
                                                      const RoundSliderThumbShape(
                                                    enabledThumbRadius: 6.0,
                                                  ),
                                                  overlayShape:
                                                      const RoundSliderOverlayShape(
                                                    overlayRadius: 12.0,
                                                  ),
                                                ),
                                                child: Slider(
                                                  value: _audioService
                                                          .totalDuration
                                                          .inMilliseconds >
                                                      0
                                                      ? _audioService
                                                          .playbackDuration
                                                          .inMilliseconds
                                                          .toDouble()
                                                      : 0.0,
                                                  min: 0.0,
                                                  max: _audioService
                                                      .totalDuration
                                                      .inMilliseconds
                                                      .toDouble(),
                                                  onChanged: (value) async {
                                                    await _audioService
                                                        .seekAudio(Duration(
                                                            milliseconds:
                                                                value.toInt()));
                                                  },
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets
                                                    .symmetric(horizontal: 8.0),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    // 재생시간
                                                    Text(
                                                      _formatDuration(
                                                          _audioService
                                                              .playbackDuration),
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.blue,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    // 배속
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue.withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Text(
                                                        '${_audioService.playbackSpeed}x',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.blue,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    // 전체 녹음시간
                                                    Text(
                                                      _formatDuration(
                                                          _audioService
                                                              .totalDuration),
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.blue,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isCurrentPlaying &&
                                            _audioService.isPlaying)
                                          IconButton(
                                            icon: const Icon(Icons.speed),
                                            onPressed: _changePlaybackSpeed,
                                            tooltip:
                                                l10n?.playbackSpeed ?? '재생 속도',
                                          ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.edit_outlined,
                                            color: Theme.of(context).primaryColor,
                                          ),
                                          onPressed: () => _showRenameAudioFileDialog(audioFile),
                                          tooltip: '이름 변경',
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete_outline,
                                            color: Theme.of(context).primaryColor,
                                          ),
                                          onPressed: () => _deleteAudio(audioFile),
                                          tooltip: l10n?.delete ?? '삭제',
                                        ),
                                      ],
                                    ),
                                    onTap: () => _playAudio(audioFile),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
              // 텍스트 탭과 동일한 FloatingActionButton 위치와 크기
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton(
                  onPressed: _toggleRecording,
                  mini: true,
                  tooltip: _audioService.isRecording
                      ? l10n?.stopRecording ?? '녹음 중지'
                      : l10n?.recordingTitle ?? '녹음 시작',
                  child: _audioService.isRecording
                      ? const Icon(Icons.stop)
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.mic, size: 16),
                            SizedBox(width: 2),
                            Icon(Icons.add, size: 16),
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 오디오 파일 이름 변경 다이얼로그
  void _showRenameAudioFileDialog(AudioFile audioFile) {
    final controller = TextEditingController(text: audioFile.displayName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('파일 이름 변경'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '새 파일 이름',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (_) {
            Navigator.pop(context);
            _renameAudioFile(audioFile, controller.text.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _renameAudioFile(audioFile, controller.text.trim());
            },
            child: const Text('변경'),
          ),
        ],
      ),
    );
  }

  // 오디오 파일 이름 변경
  Future<void> _renameAudioFile(AudioFile audioFile, String newName) async {
    if (newName.isEmpty || newName == audioFile.displayName) {
      return;
    }

    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      if (appState.selectedLitten == null) return;

      // AudioService를 통해 파일 이름 업데이트
      await _audioService.renameAudioFile(audioFile, newName);

      // 목록 새로고침
      await _loadAudioFiles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('파일 이름이 변경되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일 이름 변경 실패: $e')),
        );
      }
    }
  }
}

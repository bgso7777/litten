import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/note_provider.dart';
import '../services/audio_service.dart';
import '../models/note_model.dart';
import '../config/app_config.dart';
import '../l10n/app_localizations.dart';
import '../widgets/empty_state_widget.dart';

// 웹에서 페이지 새로고침을 위한 import
import 'dart:html' as html show window;

class RecorderScreen extends StatefulWidget {
  const RecorderScreen({super.key});

  @override
  State<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen> {
  final AudioService _audioService = AudioService();
  
  @override
  Widget build(BuildContext context) {
    debugPrint('RecorderScreen build() 호출됨');
    
    return Consumer<NoteProvider>(
      builder: (context, noteProvider, child) {
        final audioService = context.watch<AudioService>();
        
        return Scaffold(
          body: _buildBody(noteProvider, audioService),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _startRecording(audioService, noteProvider),
            icon: Icon(audioService.recordingState == RecordingState.recording 
                ? Icons.stop 
                : Icons.mic),
            label: Text(audioService.recordingState == RecordingState.recording 
                ? '녹음 정지' 
                : '+듣기'),
            backgroundColor: audioService.recordingState == RecordingState.recording 
                ? Colors.red 
                : null,
          ),
        );
      },
    );
  }

  // UI 본문 구성
  Widget _buildBody(NoteProvider noteProvider, AudioService audioService) {
    final selectedNote = noteProvider.selectedNote;
    
    // 선택된 노트가 없는 경우
    if (selectedNote == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic_outlined, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              '선택된 리튼이 없습니다\n+듣기 버튼을 눌러 녹음을 시작하면\n"기본리튼"이 자동으로 생성됩니다',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // 오디오 파일 목록 가져오기
    final audioFiles = selectedNote.files.where((file) => file.type == FileType.audio).toList();
    
    // 오디오 파일이 없는 경우
    if (audioFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic_outlined, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              '녹음된 오디오가 없습니다\n하단의 +듣기 버튼을 눌러\n첫 번째 녹음을 시작하세요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            if (kIsWeb) ...[
              SizedBox(height: 24),
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                        SizedBox(width: 8),
                        Text(
                          '웹에서 녹음하기',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• 마이크가 연결되어 있는지 확인\n'
                      '• 다른 앱(Teams, Zoom)에서 마이크 사용 중단\n'
                      '• 주소창 🔒 아이콘 클릭 → 마이크 허용\n'
                      '• WSL: Windows에서 마이크 권한 확인',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    // 오디오 파일 목록 표시
    return Column(
      children: [
        // 헤더
        Container(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.audiotrack, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                '녹음된 오디오 (${audioFiles.length}개)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        // 파일 목록
        Expanded(
          child: ListView.builder(
            itemCount: audioFiles.length,
            itemBuilder: (context, index) {
              final audioFile = audioFiles[index];
              return _buildAudioFileItem(audioFile, audioService);
            },
          ),
        ),
      ],
    );
  }

  // 오디오 파일 아이템 구성
  Widget _buildAudioFileItem(FileModel audioFile, AudioService audioService) {
    final isPlaying = audioService.currentPlayingFileId == audioFile.id && audioService.isPlaying;
    final duration = audioFile.audioDuration;
    final createdAt = audioFile.createdAt;
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPlaying ? Colors.red : Colors.blue,
          child: Icon(
            isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
          ),
        ),
        title: Text(
          audioFile.name,
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '길이: ${_formatDuration(Duration(seconds: duration.round()))}',
              style: TextStyle(fontSize: 12),
            ),
            Text(
              '생성: ${_formatDateTime(createdAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (kIsWeb && audioFile.metadata?['platform'] == 'web')
              Text(
                '웹 녹음',
                style: TextStyle(fontSize: 11, color: Colors.orange[700]),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPlaying)
              Text(
                '${_formatDuration(audioService.playbackPosition)} / ${_formatDuration(audioService.playbackDuration)}',
                style: TextStyle(fontSize: 12),
              ),
            SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _showDeleteConfirmDialog(audioFile),
            ),
          ],
        ),
        onTap: () => _playOrPauseAudio(audioFile, audioService),
      ),
    );
  }

  // 오디오 재생/일시정지
  Future<void> _playOrPauseAudio(FileModel audioFile, AudioService audioService) async {
    if (audioService.currentPlayingFileId == audioFile.id && audioService.isPlaying) {
      await audioService.pausePlayback();
    } else {
      await audioService.playAudio(audioFile);
    }
  }

  // 파일 삭제 확인 다이얼로그
  void _showDeleteConfirmDialog(FileModel audioFile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('파일 삭제'),
        content: Text('\'${audioFile.name}\'을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteAudioFile(audioFile);
            },
            child: Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // 오디오 파일 삭제
  Future<void> _deleteAudioFile(FileModel audioFile) async {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final audioService = Provider.of<AudioService>(context, listen: false);
    
    // 현재 재생 중인 파일이면 정지
    if (audioService.currentPlayingFileId == audioFile.id) {
      await audioService.stopPlayback();
    }
    
    // 파일 삭제
    if (audioFile.filePath != null) {
      await audioService.deleteAudioFile(audioFile.id, audioFile.filePath!);
    }
    
    // 노트에서 파일 제거
    final success = await noteProvider.removeFileFromNote(audioFile.noteId, audioFile.id);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('\'${audioFile.name}\'이(가) 삭제되었습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // 시간 포맷팅
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  // 날짜 포맷팅
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // 녹음 시작 메서드
  Future<void> _startRecording(AudioService audioService, NoteProvider noteProvider) async {
    debugPrint('_startRecording 호출됨');
    
    try {
      // 녹음 상태에 따라 동작 결정
      if (audioService.recordingState == RecordingState.idle) {
        // 새 녹음 시작
        final success = await audioService.startRecording();
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('녹음을 시작했습니다'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (mounted) {
          _showPermissionErrorDialog();
        }
      } else if (audioService.recordingState == RecordingState.recording) {
        debugPrint('=== 녹음 정지 및 저장 프로세스 시작 ===');
        debugPrint('현재 선택된 노트: ${noteProvider.selectedNote?.title ?? "없음"}');
        
        // 항상 "기본리튼" 생성하고 그곳에 저장
        debugPrint('강제로 "기본리튼" 생성하여 저장');
        final defaultNote = await noteProvider.createDefaultNoteIfNeeded();
        if (defaultNote == null) {
          debugPrint('리튼 자동 생성 실패');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('리튼 생성에 실패했습니다'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        } else {
          debugPrint('기본리튼 생성 성공: ${defaultNote.title}');
        }
        
        // 녹음 정지 및 저장
        final note = noteProvider.selectedNote!;
        debugPrint('파일을 저장할 노트: ${note.title} (${note.id})');
        final audioFile = await audioService.stopRecording(note.id);
        
        if (audioFile != null) {
          debugPrint('오디오 파일 생성됨: ${audioFile.name}');
          final success = await noteProvider.addFileToNote(note.id, audioFile);
          debugPrint('파일 저장 결과: $success');
          
          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('녹음이 저장되었습니다: ${audioFile.name}'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (mounted && !success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('녹음 저장에 실패했습니다'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          debugPrint('오디오 파일 생성 실패');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('녹음 파일 생성에 실패했습니다'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('녹음 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('녹음 중 오류가 발생했습니다: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 권한 오류 다이얼로그 표시
  void _showPermissionErrorDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.mic_off, color: Colors.red),
              SizedBox(width: 8),
              Text('마이크 권한 필요'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('녹음을 시작하려면 마이크 권한이 필요합니다.'),
              SizedBox(height: 16),
              if (kIsWeb) ...[
                Text('웹 브라우저에서:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('1. 주소창 왼쪽의 🔒 아이콘을 클릭하세요'),
                Text('2. 마이크 권한을 "허용"으로 변경하세요'),
                Text('3. 페이지를 새로고침하세요'),
                SizedBox(height: 12),
                Text('또는:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('• Chrome: 설정 > 개인정보 및 보안 > 사이트 설정 > 마이크'),
                Text('• Firefox: 설정 > 개인정보 및 보안 > 권한 > 마이크'),
                Text('• Safari: Safari > 환경설정 > 웹사이트 > 마이크'),
              ] else ...[
                Text('모바일 앱에서:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('1. 설정 앱을 여세요'),
                Text('2. 개인정보 보호 > 마이크를 선택하세요'),
                Text('3. 리튼 앱의 권한을 켜세요'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('확인'),
            ),
            if (kIsWeb)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // 웹에서는 페이지 새로고침 유도
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('마이크 권한을 변경한 후 페이지를 새로고침해주세요 (F5 또는 Ctrl+R)'),
                      duration: Duration(seconds: 5),
                      action: SnackBarAction(
                        label: '새로고침',
                        onPressed: () {
                          // 웹에서 페이지 새로고침
                          if (kIsWeb) {
                            html.window.location.reload();
                          }
                        },
                      ),
                    ),
                  );
                },
                child: Text('권한 설정하기'),
              ),
          ],
        );
      },
    );
  }
}
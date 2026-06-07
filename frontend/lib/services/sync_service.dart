import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audio_file.dart';
import '../models/text_file.dart';
import '../models/handwriting_file.dart';
import '../models/attachment_file.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'file_storage_service.dart';
import 'litten_service.dart';
import '../models/litten.dart';

class SyncService {
  static const String _keyLastSyncTime = 'sync_last_time';
  static const String _keyBackgroundTime = 'sync_background_time';
  static const String _keyOfflineQueue = 'sync_offline_queue';

  static SyncService? _instance;
  static SyncService get instance => _instance ??= SyncService._();
  SyncService._();

  final ApiService _api = ApiService();
  final LittenService _littenService = LittenService();
  AuthServiceImpl? _authService;
  VoidCallback? _onSyncStatusChanged;
  VoidCallback? _onLittenChanged; // 리튼 목록이 바뀌었을 때만 호출(무거운 리튼 리로드용)
  FileStorageService get _fileStorage => FileStorageService.instance;

  void init(AuthServiceImpl authService, {VoidCallback? onSyncStatusChanged, VoidCallback? onLittenChanged}) {
    _authService = authService;
    _onSyncStatusChanged = onSyncStatusChanged;
    _onLittenChanged = onLittenChanged;
    debugPrint('[SyncService] init 완료');
  }

  /// 동기화 비활성화(프리미엄 해제/로그아웃) — 진행 중 동기화는 _canSync 게이트로 자연 중단되고,
  /// 다음 활성화 시 전체 재동기화하도록 마지막 동기화 시각만 초기화한다. (로컬 데이터는 보존)
  Future<void> onSyncDisabled() async {
    debugPrint('[SyncService] onSyncDisabled - 동기화 비활성화');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLastSyncTime);
    _onSyncStatusChanged?.call();
  }

  /// 동기화 계정이 바뀌었을 때 로컬 파일의 클라우드 상태(cloudId/cloudUpdatedAt/syncStatus)를 초기화한다.
  /// 서버는 (memberId, localId)로 멱등 업서트하므로, 초기화 후 재업로드하면 새 계정에 정상 등록된다.
  /// 수정 시각(updatedAt)은 보존하여 파일 목록 정렬이 흐트러지지 않게 한다.
  Future<void> resetLocalCloudState(List<String> littenIds) async {
    debugPrint('[SyncService] resetLocalCloudState - ${littenIds.length}개 리튼');
    for (final littenId in littenIds) {
      final texts = await _fileStorage.loadTextFiles(littenId);
      if (texts.any((f) => f.cloudId != null || f.syncStatus != SyncStatus.none)) {
        await _fileStorage.saveTextFiles(littenId,
            texts.map((f) => f.copyWith(clearCloud: true, updatedAt: f.updatedAt)).toList());
      }
      final audios = await _fileStorage.loadAudioFiles(littenId);
      if (audios.any((f) => f.cloudId != null || f.syncStatus != SyncStatus.none)) {
        await _fileStorage.saveAudioFiles(littenId,
            audios.map((f) => f.copyWith(clearCloud: true, updatedAt: f.updatedAt)).toList());
      }
      final hws = await _fileStorage.loadHandwritingFiles(littenId);
      if (hws.any((f) => f.cloudId != null || f.syncStatus != SyncStatus.none)) {
        await _fileStorage.saveHandwritingFiles(littenId,
            hws.map((f) => f.copyWith(clearCloud: true, updatedAt: f.updatedAt)).toList());
      }
    }
    _onSyncStatusChanged?.call();
  }

  bool get _canSync {
    final auth = _authService;
    if (auth == null) return false;
    final user = auth.currentUser;
    return auth.authStatus == AuthStatus.authenticated &&
        user != null &&
        user.isPremium;
  }

  Future<String?> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // ① 로그인 시 전체 양방향 동기화
  Future<void> syncOnLogin() async {
    debugPrint('[SyncService] syncOnLogin 진입');
    if (!_canSync) {
      debugPrint('[SyncService] syncOnLogin - 프리미엄 아님 또는 미로그인, 스킵');
      return;
    }
    final token = await _loadToken();
    if (token == null) return;

    try {
      await _bidirectionalSync(token);
      await _saveLastSyncTime(DateTime.now());
      debugPrint('[SyncService] syncOnLogin 완료');
    } catch (e) {
      debugPrint('[SyncService] syncOnLogin 오류: $e');
    }
  }

  // ② 앱 시작 시 전체 양방향 동기화 (누락된 클라우드 파일 포함)
  Future<void> syncOnAppStart() async {
    debugPrint('[SyncService] syncOnAppStart 진입');
    if (!_canSync) {
      debugPrint('[SyncService] syncOnAppStart - 프리미엄 아님 또는 미로그인, 스킵');
      return;
    }
    final token = await _loadToken();
    if (token == null) return;

    try {
      await _bidirectionalSync(token);
      await _saveLastSyncTime(DateTime.now());
      debugPrint('[SyncService] syncOnAppStart 완료');
    } catch (e) {
      debugPrint('[SyncService] syncOnAppStart 오류: $e');
    }
  }

  // ③ 포그라운드 전환 시 (5분 이상 백그라운드였을 때만)
  Future<void> syncOnForeground() async {
    debugPrint('[SyncService] syncOnForeground 진입');
    if (!_canSync) return;

    final backgroundDuration = await _getBackgroundDuration();
    if (backgroundDuration < const Duration(minutes: 5)) {
      debugPrint('[SyncService] syncOnForeground - 백그라운드 ${backgroundDuration.inSeconds}초, 스킵');
      return;
    }
    debugPrint('[SyncService] syncOnForeground - 백그라운드 ${backgroundDuration.inMinutes}분, 동기화');
    final token = await _loadToken();
    if (token == null) return;
    try {
      final lastSync = await _getLastSyncTime();
      if (lastSync != null) {
        await _incrementalSync(token, lastSync);
      } else {
        await _bidirectionalSync(token);
      }
      await _saveLastSyncTime(DateTime.now());
    } catch (e) {
      debugPrint('[SyncService] syncOnForeground 오류: $e');
    }
  }

  void recordBackgroundTime() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_keyBackgroundTime, DateTime.now().toIso8601String());
    });
  }

  // ④ 노트탭 진입 시: 마지막 동기화 이후 클라우드 변경분 비교 + 로컬 미동기화 파일 업로드
  Future<void> syncOnNoteTab(List<String> littenIds) async {
    debugPrint('[SyncService] syncOnNoteTab 진입 - ${littenIds.length}개 리튼');
    if (!_canSync) {
      debugPrint('[SyncService] syncOnNoteTab - 프리미엄 아님 또는 미로그인, 스킵');
      return;
    }
    final token = await _loadToken();
    if (token == null) return;

    try {
      // 리튼 메타 동기화(업서트/수신/삭제 전파) — 노트탭 진입 시에도 리튼이 양방향 동기화되도록.
      // (증분 파일 경로에는 리튼 동기화가 없어, 노트탭 진입만으로는 리튼이 서버에 안 올라가던 문제 수정)
      await _syncLittens(token);

      final lastSync = await _getLastSyncTime();

      if (lastSync != null) {
        // 마지막 동기화 이후 클라우드 변경분 가져오기
        final changedFiles = await _api.getCloudFiles(token: token, since: lastSync.toIso8601String());
        debugPrint('[SyncService] syncOnNoteTab - 클라우드 변경 파일: ${changedFiles.length}개');

        for (final cloudMeta in changedFiles) {
          final littenId = cloudMeta['littenId'] as String;
          if (!littenIds.contains(littenId)) continue;

          final localId = cloudMeta['localId'] as String;
          final fileType = cloudMeta['fileType'] as String;
          final cloudId = cloudMeta['cloudId'].toString();
          final cloudUpdatedAt = DateTime.parse(cloudMeta['localUpdatedAt'].toString());
          final cloudFileName = cloudMeta['fileName'] as String? ?? '';

          // 삭제 tombstone 처리 (다른 기기에서 삭제됨)
          if (cloudMeta['isDeleted'] == true) {
            await _handleCloudDeletion(token, littenId, localId, fileType, cloudId, _parseDeletedAt(cloudMeta));
            continue;
          }

          final localFile = await _findLocalFile(littenId, localId, fileType);

          if (localFile == null) {
            // 로컬에 없음 → 클라우드에서 다운로드
            await _downloadAndApply(token, cloudId, littenId, localId, fileType, cloudUpdatedAt, cloudFileName);
          } else {
            final localUpdatedAt = _getFileUpdatedAt(localFile);
            if (cloudUpdatedAt.isAfter(localUpdatedAt)) {
              // 클라우드가 더 최신 → 다운로드
              await _downloadAndApply(token, cloudId, littenId, localId, fileType, cloudUpdatedAt, cloudFileName);
            } else if (localUpdatedAt.isAfter(cloudUpdatedAt)) {
              // 로컬이 더 최신 → 업로드
              await _uploadLocalFile(token, littenId, localId, cloudId, fileType, localFile);
            }
          }
        }
      } else {
        // 동기화 기록 없음 → 전체 양방향 동기화
        await _bidirectionalSync(token);
      }

      // 미동기화 로컬 파일 업로드
      for (final littenId in littenIds) {
        await _uploadUnsyncedFilesForLitten(token, littenId);
      }

      // 오프라인 큐 재시도
      await processOfflineQueue();

      await _saveLastSyncTime(DateTime.now());
      debugPrint('[SyncService] syncOnNoteTab 완료');
    } catch (e) {
      debugPrint('[SyncService] syncOnNoteTab 오류: $e');
    }
  }

  // 로컬 전체 미동기화 파일 일괄 업로드 (첫 프리미엄 전환 또는 로그인 시)
  Future<void> uploadAllLocalFiles(List<String> littenIds) async {
    debugPrint('[SyncService] uploadAllLocalFiles 시작 - ${littenIds.length}개 리튼');
    if (!_canSync) return;
    final token = await _loadToken();
    if (token == null) return;

    for (final littenId in littenIds) {
      await _uploadUnsyncedFilesForLitten(token, littenId);
    }
    // 업로드 완료 후 lastSync 갱신 (이후 syncOnNoteTab에서 중복 조회 방지)
    await _saveLastSyncTime(DateTime.now());
    debugPrint('[SyncService] uploadAllLocalFiles 완료');
  }

  Future<void> _uploadUnsyncedFilesForLitten(String token, String littenId) async {
    debugPrint('[SyncService] _uploadUnsyncedFilesForLitten - littenId: $littenId');
    final appDir = await getApplicationDocumentsDirectory();

    // 텍스트 파일
    final textFiles = await _fileStorage.loadTextFiles(littenId);
    for (final file in textFiles) {
      final filePath = '${appDir.path}/littens/$littenId/text/${file.id}.html';
      if (file.cloudId == null) {
        // 신규: 클라우드에 없는 파일 업로드
        if (await File(filePath).exists()) {
          await uploadFile(
            littenId: littenId, localId: file.id, fileType: 'text',
            fileName: '${file.id}.html', filePath: filePath, localUpdatedAt: file.updatedAt,
          );
        }
      } else if (_isModifiedLocally(file.updatedAt, file.cloudUpdatedAt)) {
        // 수정: 로컬이 클라우드보다 최신이면 업데이트
        debugPrint('[SyncService] 텍스트 수정 감지 - localId: ${file.id}');
        if (await File(filePath).exists()) {
          await updateFile(
            littenId: littenId, localId: file.id, cloudId: file.cloudId!,
            fileType: 'text', filePath: filePath, localUpdatedAt: file.updatedAt,
          );
        }
      }
    }

    // 필기 파일
    final hwFiles = await _fileStorage.loadHandwritingFiles(littenId);
    for (final file in hwFiles) {
      final filePath = file.isMultiPage
          ? file.imagePath
          : '${appDir.path}/littens/$littenId/handwriting/${file.id}_drawing.png';
      if (file.cloudId == null) {
        // 신규: 클라우드에 없는 파일 업로드
        await uploadFile(
          littenId: littenId, localId: file.id, fileType: 'handwriting',
          fileName: '${file.displayTitle}_drawing.png', filePath: filePath, localUpdatedAt: file.updatedAt,
        );
      } else if (_isModifiedLocally(file.updatedAt, file.cloudUpdatedAt)) {
        // 수정: 로컬이 클라우드보다 최신이면 업데이트
        debugPrint('[SyncService] 필기 수정 감지 - localId: ${file.id}');
        if (await File(filePath).exists()) {
          await updateFile(
            littenId: littenId, localId: file.id, cloudId: file.cloudId!,
            fileType: 'handwriting', filePath: filePath, localUpdatedAt: file.updatedAt,
          );
        }
      }
    }

    // 오디오 파일 (오디오는 수정 없이 생성/삭제만)
    final audioFiles = await _fileStorage.loadAudioFiles(littenId);
    for (final file in audioFiles) {
      if (file.cloudId == null) {
        await uploadFile(
          littenId: littenId, localId: file.id, fileType: 'audio',
          fileName: '${file.fileName}.m4a', filePath: file.filePath, localUpdatedAt: file.updatedAt,
        );
      }
    }

    // 첨부 파일 (zip/docx/xlsx 등 — 수정 없이 생성/삭제만, fileName에 확장자 포함)
    final attachmentFiles = await _fileStorage.loadAttachmentFiles(littenId);
    for (final file in attachmentFiles) {
      if (file.cloudId == null) {
        await uploadFile(
          littenId: littenId, localId: file.id, fileType: 'attachment',
          fileName: file.fileName, filePath: file.filePath, localUpdatedAt: file.updatedAt,
        );
      }
    }
  }

  // 로컬 파일이 클라우드보다 수정됐는지 판단 (2초 여유 허용)
  bool _isModifiedLocally(DateTime localUpdatedAt, DateTime? cloudUpdatedAt) {
    if (cloudUpdatedAt == null) return false;
    return localUpdatedAt.isAfter(cloudUpdatedAt.add(const Duration(seconds: 2)));
  }

  // 파일 이벤트: 생성
  Future<void> uploadFile({
    required String littenId,
    required String localId,
    required String fileType,
    required String fileName,
    required String filePath,
    required DateTime localUpdatedAt,
  }) async {
    debugPrint('[SyncService] uploadFile - localId: $localId');
    if (!_canSync) return;
    final token = await _loadToken();
    if (token == null) return;

    final file = File(filePath);
    if (!await file.exists()) {
      await _addToOfflineQueue({
        'action': 'upload', 'littenId': littenId, 'localId': localId,
        'fileType': fileType, 'fileName': fileName, 'filePath': filePath,
        'localUpdatedAt': localUpdatedAt.toIso8601String()
      });
      return;
    }

    try {
      final result = await _api.uploadFile(
        token: token, littenId: littenId, localId: localId,
        fileType: fileType, fileName: fileName,
        localUpdatedAt: localUpdatedAt.toIso8601String(),
        file: file, contentType: _getContentType(fileType),
      );
      if (result != null) {
        await _updateLocalSyncStatus(littenId, localId, fileType, result['cloudId'].toString(), SyncStatus.synced);
        debugPrint('[SyncService] uploadFile 성공 - cloudId: ${result['cloudId']}');
      } else {
        await _addToOfflineQueue({
          'action': 'upload', 'littenId': littenId, 'localId': localId,
          'fileType': fileType, 'fileName': fileName, 'filePath': filePath,
          'localUpdatedAt': localUpdatedAt.toIso8601String()
        });
      }
    } catch (e) {
      debugPrint('[SyncService] uploadFile 오류: $e');
      await _addToOfflineQueue({
        'action': 'upload', 'littenId': littenId, 'localId': localId,
        'fileType': fileType, 'fileName': fileName, 'filePath': filePath,
        'localUpdatedAt': localUpdatedAt.toIso8601String()
      });
    }
  }

  // 파일 이벤트: 수정
  Future<void> updateFile({
    required String littenId,
    required String localId,
    required String cloudId,
    required String fileType,
    required String filePath,
    required DateTime localUpdatedAt,
  }) async {
    debugPrint('[SyncService] updateFile - cloudId: $cloudId');
    if (!_canSync) return;
    final token = await _loadToken();
    if (token == null) return;

    final file = File(filePath);
    if (!await file.exists()) {
      await _addToOfflineQueue({
        'action': 'update', 'littenId': littenId, 'localId': localId,
        'cloudId': cloudId, 'fileType': fileType, 'filePath': filePath,
        'localUpdatedAt': localUpdatedAt.toIso8601String()
      });
      return;
    }

    try {
      final result = await _api.updateFile(
        token: token, cloudId: cloudId,
        localUpdatedAt: localUpdatedAt.toIso8601String(),
        file: file, contentType: _getContentType(fileType),
      );
      if (result != null) {
        await _updateLocalSyncStatus(littenId, localId, fileType, cloudId, SyncStatus.synced);
        debugPrint('[SyncService] updateFile 성공');
      } else {
        await _addToOfflineQueue({
          'action': 'update', 'littenId': littenId, 'localId': localId,
          'cloudId': cloudId, 'fileType': fileType, 'filePath': filePath,
          'localUpdatedAt': localUpdatedAt.toIso8601String()
        });
      }
    } catch (e) {
      debugPrint('[SyncService] updateFile 오류: $e');
    }
  }

  // 파일 이벤트: 삭제
  Future<void> deleteFile({
    required String littenId, required String localId,
    required String cloudId, required String fileType,
  }) async {
    debugPrint('[SyncService] deleteFile 진입 - cloudId: $cloudId, fileType: $fileType');

    if (!_canSync) {
      // 비프리미엄/미로그인이어도 나중에 처리할 수 있도록 큐에 보관
      debugPrint('[SyncService] deleteFile - _canSync=false, 오프라인 큐에 보관');
      await _addToOfflineQueue({
        'action': 'delete', 'littenId': littenId, 'localId': localId,
        'cloudId': cloudId, 'fileType': fileType
      });
      return;
    }

    final token = await _loadToken();
    if (token == null) {
      debugPrint('[SyncService] deleteFile - 토큰 없음, 오프라인 큐에 보관');
      await _addToOfflineQueue({
        'action': 'delete', 'littenId': littenId, 'localId': localId,
        'cloudId': cloudId, 'fileType': fileType
      });
      return;
    }

    try {
      final success = await _api.deleteCloudFile(token: token, cloudId: cloudId);
      if (success) {
        debugPrint('[SyncService] deleteFile 성공 - cloudId: $cloudId');
      } else {
        debugPrint('[SyncService] deleteFile 실패 (result≠1) - cloudId: $cloudId, 오프라인 큐 추가');
        await _addToOfflineQueue({
          'action': 'delete', 'littenId': littenId, 'localId': localId,
          'cloudId': cloudId, 'fileType': fileType
        });
      }
    } catch (e) {
      debugPrint('[SyncService] deleteFile 오류: $e, 오프라인 큐 추가');
      await _addToOfflineQueue({
        'action': 'delete', 'littenId': littenId, 'localId': localId,
        'cloudId': cloudId, 'fileType': fileType
      });
    }
  }

  // 리튼(공간) 원격 삭제 — 사용자 삭제 액션 경로에서 호출. 서버에도 삭제를 전파해
  // 다음 동기화 때 부활하지 않도록 한다. 실패 시 오프라인 큐에 보관 후 재시도.
  Future<void> deleteLittenRemote(String littenId) async {
    debugPrint('[SyncService] deleteLittenRemote 진입 - littenId: $littenId');
    if (!_canSync) {
      await _addToOfflineQueue({'action': 'deleteLitten', 'littenId': littenId});
      return;
    }
    final token = await _loadToken();
    if (token == null) {
      await _addToOfflineQueue({'action': 'deleteLitten', 'littenId': littenId});
      return;
    }
    try {
      final ok = await _api.deleteLittenRemote(token: token, littenId: littenId);
      if (!ok) {
        await _addToOfflineQueue({'action': 'deleteLitten', 'littenId': littenId});
      }
    } catch (e) {
      debugPrint('[SyncService] deleteLittenRemote 오류: $e, 큐 추가');
      await _addToOfflineQueue({'action': 'deleteLitten', 'littenId': littenId});
    }
  }

  // 오프라인 큐 처리
  Future<void> processOfflineQueue() async {
    if (!_canSync) return;
    final token = await _loadToken();
    if (token == null) return;

    final queue = await _loadOfflineQueue();
    if (queue.isEmpty) return;

    debugPrint('[SyncService] processOfflineQueue - ${queue.length}개');
    final remaining = <Map<String, dynamic>>[];

    for (final item in queue) {
      try {
        final action = item['action'] as String;
        bool success = false;

        if (action == 'upload') {
          final file = File(item['filePath'] as String);
          if (await file.exists()) {
            final result = await _api.uploadFile(
              token: token, littenId: item['littenId'], localId: item['localId'],
              fileType: item['fileType'], fileName: item['fileName'],
              localUpdatedAt: item['localUpdatedAt'], file: file,
              contentType: _getContentType(item['fileType']),
            );
            success = result != null;
          }
        } else if (action == 'update') {
          final file = File(item['filePath'] as String);
          if (await file.exists()) {
            final result = await _api.updateFile(
              token: token, cloudId: item['cloudId'],
              localUpdatedAt: item['localUpdatedAt'], file: file,
              contentType: _getContentType(item['fileType']),
            );
            success = result != null;
          }
        } else if (action == 'delete') {
          success = await _api.deleteCloudFile(token: token, cloudId: item['cloudId']);
        } else if (action == 'deleteLitten') {
          success = await _api.deleteLittenRemote(token: token, littenId: item['littenId']);
        }

        if (!success) remaining.add(item);
      } catch (e) {
        debugPrint('[SyncService] 큐 항목 처리 오류: $e');
        remaining.add(item);
      }
    }

    await _saveOfflineQueue(remaining);
    debugPrint('[SyncService] processOfflineQueue 완료 - 남은: ${remaining.length}개');
  }

  // 양방향 전체 동기화
  /// 리튼(노트 공간) 메타 양방향 동기화. 파일보다 먼저 호출해 파일이 담길 공간을 확보한다.
  /// LWW: updatedAt 최신 우선. 삭제 동기화는 tombstone 부재로 보류(추가/수정만).
  Future<void> _syncLittens(String token) async {
    try {
      final serverList = await _api.getLittens(token: token);
      final localList = await _littenService.getAllLittens();
      final localById = {for (final l in localList) l.id: l};
      final serverIds = <String>{};
      var localChanged = false; // 로컬 리튼 목록이 바뀌면 UI 리로드 트리거

      // 서버 → 로컬: 로컬에 없거나 서버가 더 최신이면 로컬 반영, 로컬이 더 최신이면 서버로 push
      for (final sj in serverList) {
        // 삭제 tombstone 처리 (다른 기기에서 리튼 삭제됨)
        if (sj['_deleted'] == true) {
          final deletedId = sj['id'] as String?;
          if (deletedId == null) continue;
          serverIds.add(deletedId);
          final local = localById[deletedId];
          if (local == null) continue; // 이미 로컬에 없음
          final deletedAt = sj['deletedAt'] != null ? DateTime.tryParse(sj['deletedAt'].toString()) : null;
          if (deletedAt != null && local.updatedAt.isAfter(deletedAt)) {
            // 수정 우선: 로컬이 더 최신 → 서버 재활성화(upsert)
            debugPrint('[SyncService] 리튼 삭제 취소(수정 우선) - id: $deletedId');
            await _api.upsertLitten(token: token, littenJson: local.toJson());
          } else {
            // 삭제 전파: 로컬 리튼 삭제 (로컬 전용 — 원격 재호출 방지)
            debugPrint('[SyncService] 리튼 삭제 전파 - id: $deletedId 로컬 삭제');
            await _littenService.deleteLitten(deletedId);
            localChanged = true;
          }
          continue;
        }
        Litten serverLitten;
        try {
          serverLitten = Litten.fromJson(sj);
        } catch (e) {
          debugPrint('[SyncService] 리튼 파싱 실패, 스킵: $e');
          continue;
        }
        serverIds.add(serverLitten.id);
        final local = localById[serverLitten.id];
        if (local == null || serverLitten.updatedAt.isAfter(local.updatedAt)) {
          await _littenService.saveLitten(serverLitten);
          localChanged = true;
        } else if (local.updatedAt.isAfter(serverLitten.updatedAt)) {
          await _api.upsertLitten(token: token, littenJson: local.toJson());
        }
      }
      // 서버에 없는 로컬 리튼 → 서버로 push
      for (final local in localList) {
        if (!serverIds.contains(local.id)) {
          await _api.upsertLitten(token: token, littenJson: local.toJson());
        }
      }
      debugPrint('[SyncService] _syncLittens 완료 - 서버 ${serverList.length} / 로컬 ${localList.length}, localChanged=$localChanged');
      if (localChanged) _onLittenChanged?.call(); // 새로 받은 리튼이 있으면 UI 목록 리로드
    } catch (e) {
      debugPrint('[SyncService] _syncLittens 오류: $e');
    }
  }

  Future<void> _bidirectionalSync(String token) async {
    debugPrint('[SyncService] _bidirectionalSync 시작');
    // 오프라인 큐 먼저 처리: 보류 중인 삭제가 클라우드에 반영된 후 파일 목록을 조회해야
    // 삭제된 파일이 다시 다운로드되는 현상을 방지
    await processOfflineQueue();
    await _syncLittens(token); // 리튼 메타 먼저 동기화 (파일이 담길 공간 확보)
    final cloudFiles = await _api.getCloudFiles(token: token);
    debugPrint('[SyncService] 클라우드 파일 ${cloudFiles.length}개');

    for (final cloudMeta in cloudFiles) {
      final localId = cloudMeta['localId'] as String;
      final littenId = cloudMeta['littenId'] as String;
      final fileType = cloudMeta['fileType'] as String;
      final cloudId = cloudMeta['cloudId'].toString();
      final cloudUpdatedAt = DateTime.parse(cloudMeta['localUpdatedAt'].toString());
      final cloudFileName = cloudMeta['fileName'] as String? ?? '';

      // 삭제 tombstone 처리 (다른 기기에서 삭제됨)
      if (cloudMeta['isDeleted'] == true) {
        await _handleCloudDeletion(token, littenId, localId, fileType, cloudId, _parseDeletedAt(cloudMeta));
        continue;
      }

      final localFile = await _findLocalFile(littenId, localId, fileType);

      if (localFile == null) {
        // 클라우드에만 존재 → 다운로드
        debugPrint('[SyncService] 클라우드 전용 파일 다운로드: $localId ($fileType) fileName=$cloudFileName');
        await _downloadAndApply(token, cloudId, littenId, localId, fileType, cloudUpdatedAt, cloudFileName);
      } else {
        final localUpdatedAt = _getFileUpdatedAt(localFile);
        if (cloudUpdatedAt.isAfter(localUpdatedAt)) {
          await _downloadAndApply(token, cloudId, littenId, localId, fileType, cloudUpdatedAt, cloudFileName);
        } else if (localUpdatedAt.isAfter(cloudUpdatedAt)) {
          await _uploadLocalFile(token, littenId, localId, cloudId, fileType, localFile);
        }
      }
    }
  }

  // 증분 동기화
  Future<void> _incrementalSync(String token, DateTime since) async {
    debugPrint('[SyncService] _incrementalSync - since: $since');
    final changedFiles = await _api.getCloudFiles(token: token, since: since.toIso8601String());
    debugPrint('[SyncService] 변경 파일 ${changedFiles.length}개');

    for (final cloudMeta in changedFiles) {
      final localId = cloudMeta['localId'] as String;
      final littenId = cloudMeta['littenId'] as String;
      final fileType = cloudMeta['fileType'] as String;
      final cloudId = cloudMeta['cloudId'].toString();
      final cloudUpdatedAt = DateTime.parse(cloudMeta['localUpdatedAt'].toString());
      final cloudFileName = cloudMeta['fileName'] as String? ?? '';

      // 삭제 tombstone 처리 (다른 기기에서 삭제됨)
      if (cloudMeta['isDeleted'] == true) {
        await _handleCloudDeletion(token, littenId, localId, fileType, cloudId, _parseDeletedAt(cloudMeta));
        continue;
      }

      final localFile = await _findLocalFile(littenId, localId, fileType);
      if (localFile == null || cloudUpdatedAt.isAfter(_getFileUpdatedAt(localFile))) {
        await _downloadAndApply(token, cloudId, littenId, localId, fileType, cloudUpdatedAt, cloudFileName);
      }
    }
    await processOfflineQueue();
  }

  Future<void> _downloadAndApply(String token, String cloudId, String littenId,
      String localId, String fileType, DateTime cloudUpdatedAt, [String cloudFileName = '']) async {
    try {
      final bytes = await _api.downloadFile(token: token, cloudId: cloudId);
      if (bytes == null) return;
      final localPath = await _saveDownloadedFile(littenId, localId, fileType, bytes, cloudFileName);
      if (localPath == null) return;
      await _updateLocalFileFromDownload(littenId, localId, fileType, cloudId, localPath, cloudUpdatedAt, cloudFileName);
      debugPrint('[SyncService] 다운로드 완료 - localId: $localId, fileName: $cloudFileName');
    } catch (e) {
      debugPrint('[SyncService] _downloadAndApply 오류: $e');
    }
  }

  Future<void> _uploadLocalFile(String token, String littenId, String localId,
      String cloudId, String fileType, dynamic localFile) async {
    final filePath = await _getFilePath(localFile, littenId);
    if (filePath == null) return;
    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint('[SyncService] _uploadLocalFile - 파일 없음: $filePath');
      return;
    }
    final result = await _api.updateFile(
      token: token, cloudId: cloudId,
      localUpdatedAt: _getFileUpdatedAt(localFile).toIso8601String(),
      file: file, contentType: _getContentType(fileType),
    );
    if (result != null) {
      await _updateLocalSyncStatus(littenId, localId, fileType, cloudId, SyncStatus.synced);
    }
  }

  // 서버 삭제 tombstone(deletedAt) 파싱
  DateTime? _parseDeletedAt(Map<String, dynamic> cloudMeta) {
    final v = cloudMeta['deletedAt'];
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  /// 서버에서 삭제된 파일(tombstone)을 로컬에 반영.
  /// 수정 우선(삭제 취소): 로컬 수정시각이 서버 삭제시각보다 최신이면 재업로드해 서버를 재활성화하고,
  /// 그렇지 않으면 로컬 파일(메타+실파일)을 삭제한다.
  Future<void> _handleCloudDeletion(String token, String littenId, String localId,
      String fileType, String cloudId, DateTime? deletedAt) async {
    final localFile = await _findLocalFile(littenId, localId, fileType);
    if (localFile == null) return; // 이미 로컬에 없음
    final localUpdatedAt = _getFileUpdatedAt(localFile);
    if (deletedAt != null && localUpdatedAt.isAfter(deletedAt)) {
      debugPrint('[SyncService] 삭제 취소(수정 우선) - localId: $localId, local: $localUpdatedAt > deleted: $deletedAt');
      await _uploadLocalFile(token, littenId, localId, cloudId, fileType, localFile);
    } else {
      debugPrint('[SyncService] 삭제 전파 - localId: $localId 로컬 삭제');
      await _deleteLocalFile(littenId, localId, fileType, localFile);
    }
  }

  /// 로컬 파일의 실제 파일 + 메타데이터를 제거 (다른 기기 삭제 전파용).
  Future<void> _deleteLocalFile(String littenId, String localId, String fileType, dynamic localFile) async {
    final path = await _getFilePath(localFile, littenId);
    if (path != null) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (e) {
        debugPrint('[SyncService] _deleteLocalFile 실파일 삭제 오류: $e');
      }
    }
    if (fileType == 'text') {
      final files = await _fileStorage.loadTextFiles(littenId);
      files.removeWhere((f) => f.id == localId);
      await _fileStorage.saveTextFiles(littenId, files);
    } else if (fileType == 'handwriting') {
      final files = await _fileStorage.loadHandwritingFiles(littenId);
      files.removeWhere((f) => f.id == localId);
      await _fileStorage.saveHandwritingFiles(littenId, files);
    } else if (fileType == 'audio') {
      final files = await _fileStorage.loadAudioFiles(littenId);
      files.removeWhere((f) => f.id == localId);
      await _fileStorage.saveAudioFiles(littenId, files);
    } else if (fileType == 'attachment') {
      final files = await _fileStorage.loadAttachmentFiles(littenId);
      files.removeWhere((f) => f.id == localId);
      await _fileStorage.saveAttachmentFiles(littenId, files);
    }
    _onSyncStatusChanged?.call();
  }

  Future<dynamic> _findLocalFile(String littenId, String localId, String fileType) async {
    if (fileType == 'text') {
      final files = await _fileStorage.loadTextFiles(littenId);
      try { return files.firstWhere((f) => f.id == localId); } catch (_) { return null; }
    } else if (fileType == 'handwriting') {
      final files = await _fileStorage.loadHandwritingFiles(littenId);
      try { return files.firstWhere((f) => f.id == localId); } catch (_) { return null; }
    } else if (fileType == 'audio') {
      final files = await _fileStorage.loadAudioFiles(littenId);
      try { return files.firstWhere((f) => f.id == localId); } catch (_) { return null; }
    } else if (fileType == 'attachment') {
      final files = await _fileStorage.loadAttachmentFiles(littenId);
      try { return files.firstWhere((f) => f.id == localId); } catch (_) { return null; }
    }
    return null;
  }

  DateTime _getFileUpdatedAt(dynamic file) {
    if (file is TextFile) return file.updatedAt;
    if (file is HandwritingFile) return file.updatedAt;
    if (file is AudioFile) return file.updatedAt;
    if (file is AttachmentFile) return file.updatedAt;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<String?> _getFilePath(dynamic file, String littenId) async {
    if (file is TextFile) {
      final appDir = await getApplicationDocumentsDirectory();
      return '${appDir.path}/littens/$littenId/text/${file.id}.html';
    }
    if (file is HandwritingFile) return file.imagePath;
    if (file is AudioFile) return file.filePath;
    if (file is AttachmentFile) return file.filePath;
    return null;
  }

  Future<String?> _saveDownloadedFile(String littenId, String localId, String fileType, Uint8List bytes,
      [String cloudFileName = '']) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      // 첨부파일은 'attachments' 폴더에 원본 확장자로 저장 (확장자 가변)
      final dirName = fileType == 'attachment' ? 'attachments' : fileType;
      final dir = Directory('${appDir.path}/littens/$littenId/$dirName');
      await dir.create(recursive: true);
      String ext;
      if (fileType == 'attachment') {
        final dot = cloudFileName.lastIndexOf('.');
        ext = dot >= 0 ? cloudFileName.substring(dot) : '';
      } else {
        ext = _getFileExtension(fileType);
      }
      final file = File('${dir.path}/$localId$ext');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      debugPrint('[SyncService] _saveDownloadedFile 오류: $e');
      return null;
    }
  }

  Future<void> _updateLocalFileFromDownload(String littenId, String localId, String fileType,
      String cloudId, String localPath, DateTime cloudUpdatedAt, [String cloudFileName = '']) async {
    if (fileType == 'text') {
      final files = await _fileStorage.loadTextFiles(littenId);
      final idx = files.indexWhere((f) => f.id == localId);
      if (idx >= 0) {
        files[idx] = files[idx].copyWith(cloudId: cloudId, cloudUpdatedAt: cloudUpdatedAt, syncStatus: SyncStatus.synced);
      } else {
        // 클라우드에만 있던 신규 파일 → 메타데이터 생성 (title은 HTML content에서 재생성)
        final content = await File(localPath).readAsString().catchError((_) => '');
        files.add(TextFile(
          id: localId,
          littenId: littenId,
          content: content,
          cloudId: cloudId,
          cloudUpdatedAt: cloudUpdatedAt,
          syncStatus: SyncStatus.synced,
          createdAt: cloudUpdatedAt,
          updatedAt: cloudUpdatedAt,
        ));
        debugPrint('[SyncService] 텍스트 신규 파일 생성 - localId: $localId');
      }
      await _fileStorage.saveTextFiles(littenId, files);
      _onSyncStatusChanged?.call();
    } else if (fileType == 'handwriting') {
      // 클라우드 fileName에서 표시 제목 추출
      final displayTitle = _extractHandwritingTitle(cloudFileName, cloudUpdatedAt);
      final files = await _fileStorage.loadHandwritingFiles(littenId);
      final idx = files.indexWhere((f) => f.id == localId);
      if (idx >= 0) {
        files[idx] = files[idx].copyWith(cloudId: cloudId, cloudUpdatedAt: cloudUpdatedAt, syncStatus: SyncStatus.synced);
      } else {
        // 클라우드에만 있던 신규 파일 → 중복 이름 방지 후 메타데이터 생성
        final uniqueTitle = _uniqueName(displayTitle, files.map((f) => f.title).toSet());
        files.add(HandwritingFile(
          id: localId,
          littenId: littenId,
          title: uniqueTitle,
          imagePath: localPath,
          cloudId: cloudId,
          cloudUpdatedAt: cloudUpdatedAt,
          syncStatus: SyncStatus.synced,
          createdAt: cloudUpdatedAt,
          updatedAt: cloudUpdatedAt,
        ));
        debugPrint('[SyncService] 필기 신규 파일 생성 - localId: $localId, title: $uniqueTitle');
      }
      await _fileStorage.saveHandwritingFiles(littenId, files);
      _onSyncStatusChanged?.call();
    } else if (fileType == 'audio') {
      // 클라우드 fileName에서 표시 이름 추출: "원본이름.m4a" → "원본이름"
      final displayName = _extractAudioDisplayName(cloudFileName, cloudUpdatedAt);
      final files = await _fileStorage.loadAudioFiles(littenId);
      final idx = files.indexWhere((f) => f.id == localId);
      if (idx >= 0) {
        files[idx] = files[idx].copyWith(cloudId: cloudId, cloudUpdatedAt: cloudUpdatedAt, syncStatus: SyncStatus.synced);
      } else {
        // 클라우드에만 있던 신규 파일 → 중복 이름 방지 후 메타데이터 생성
        final uniqueName = _uniqueName(displayName, files.map((f) => f.fileName).toSet());
        files.add(AudioFile(
          id: localId,
          littenId: littenId,
          fileName: uniqueName,
          filePath: localPath,
          cloudId: cloudId,
          cloudUpdatedAt: cloudUpdatedAt,
          syncStatus: SyncStatus.synced,
          createdAt: cloudUpdatedAt,
          updatedAt: cloudUpdatedAt,
        ));
        debugPrint('[SyncService] 오디오 신규 파일 생성 - localId: $localId, displayName: $uniqueName');
      }
      await _fileStorage.saveAudioFiles(littenId, files);
      _onSyncStatusChanged?.call();
    } else if (fileType == 'attachment') {
      final files = await _fileStorage.loadAttachmentFiles(littenId);
      final idx = files.indexWhere((f) => f.id == localId);
      if (idx >= 0) {
        files[idx] = files[idx].copyWith(cloudId: cloudId, cloudUpdatedAt: cloudUpdatedAt, syncStatus: SyncStatus.synced);
      } else {
        // 클라우드에만 있던 신규 첨부 → 메타 생성 (fileName은 원본 cloudFileName, 크기는 저장된 파일에서)
        int size = 0;
        try { size = await File(localPath).length(); } catch (_) {}
        final fname = cloudFileName.isNotEmpty ? cloudFileName : localId;
        files.add(AttachmentFile(
          id: localId,
          littenId: littenId,
          fileName: fname,
          filePath: localPath,
          sizeBytes: size,
          cloudId: cloudId,
          cloudUpdatedAt: cloudUpdatedAt,
          syncStatus: SyncStatus.synced,
          createdAt: cloudUpdatedAt,
          updatedAt: cloudUpdatedAt,
        ));
        debugPrint('[SyncService] 첨부 신규 파일 생성 - localId: $localId, fileName: $fname');
      }
      await _fileStorage.saveAttachmentFiles(littenId, files);
      _onSyncStatusChanged?.call();
    }
  }

  Future<void> _updateLocalSyncStatus(String littenId, String localId, String fileType, String cloudId, SyncStatus status) async {
    if (fileType == 'text') {
      final files = await _fileStorage.loadTextFiles(littenId);
      final idx = files.indexWhere((f) => f.id == localId);
      if (idx >= 0) {
        files[idx] = files[idx].copyWith(cloudId: cloudId, syncStatus: status);
        await _fileStorage.saveTextFiles(littenId, files);
        _onSyncStatusChanged?.call();
      }
    } else if (fileType == 'handwriting') {
      final files = await _fileStorage.loadHandwritingFiles(littenId);
      final idx = files.indexWhere((f) => f.id == localId);
      if (idx >= 0) {
        files[idx] = files[idx].copyWith(cloudId: cloudId, syncStatus: status);
        await _fileStorage.saveHandwritingFiles(littenId, files);
        _onSyncStatusChanged?.call();
      }
    } else if (fileType == 'audio') {
      final files = await _fileStorage.loadAudioFiles(littenId);
      final idx = files.indexWhere((f) => f.id == localId);
      if (idx >= 0) {
        files[idx] = files[idx].copyWith(cloudId: cloudId, syncStatus: status);
        await _fileStorage.saveAudioFiles(littenId, files);
        _onSyncStatusChanged?.call();
      }
    } else if (fileType == 'attachment') {
      final files = await _fileStorage.loadAttachmentFiles(littenId);
      final idx = files.indexWhere((f) => f.id == localId);
      if (idx >= 0) {
        files[idx] = files[idx].copyWith(cloudId: cloudId, syncStatus: status);
        await _fileStorage.saveAttachmentFiles(littenId, files);
        _onSyncStatusChanged?.call();
      }
    }
  }

  String _getContentType(String fileType) {
    switch (fileType) {
      case 'audio': return 'audio/m4a';
      case 'text': return 'text/plain';
      case 'handwriting': return 'image/png';
      default: return 'application/octet-stream'; // attachment 등
    }
  }

  String _getFileExtension(String fileType) {
    switch (fileType) {
      case 'audio': return '.m4a';
      case 'text': return '.html';
      case 'handwriting': return '.png';
      default: return '.bin';
    }
  }

  Future<void> _saveLastSyncTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastSyncTime, time.toIso8601String());
  }

  Future<DateTime?> _getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyLastSyncTime);
    return str != null ? DateTime.tryParse(str) : null;
  }

  Future<Duration> _getBackgroundDuration() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyBackgroundTime);
    if (str == null) return Duration.zero;
    final bgTime = DateTime.tryParse(str);
    if (bgTime == null) return Duration.zero;
    return DateTime.now().difference(bgTime);
  }

  Future<void> _addToOfflineQueue(Map<String, dynamic> item) async {
    final queue = await _loadOfflineQueue();
    queue.add(item);
    await _saveOfflineQueue(queue);
    debugPrint('[SyncService] 오프라인 큐 추가 - action: ${item['action']}');
  }

  Future<List<Map<String, dynamic>>> _loadOfflineQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyOfflineQueue);
    if (str == null) return [];
    try {
      return List<Map<String, dynamic>>.from(
          (jsonDecode(str) as List).map((e) => Map<String, dynamic>.from(e)));
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveOfflineQueue(List<Map<String, dynamic>> queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOfflineQueue, jsonEncode(queue));
  }

  // UUID 패턴 감지: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  static final _uuidRegExp = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  // 이름 중복 방지: "이름" → "이름 (2)" → "이름 (3)"
  String _uniqueName(String name, Set<String> existingNames) {
    if (!existingNames.contains(name)) return name;
    int suffix = 2;
    while (existingNames.contains('$name ($suffix)')) {
      suffix++;
    }
    return '$name ($suffix)';
  }

  // 날짜 기반 기본 파일명 생성 (앱 규칙: YYMMDDHHmmss)
  String _dateBasedName(String prefix, DateTime dt) {
    final y = dt.year.toString().substring(2);
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$prefix $y$mo$d$h$mi$s';
  }

  // 필기 파일 표시 제목 추출
  // - 신규 업로드: "제목_drawing.png" → "제목"
  // - 구버전 업로드: "UUID_drawing.png" → UUID → 날짜 기반 대체
  String _extractHandwritingTitle(String cloudFileName, DateTime cloudUpdatedAt) {
    if (cloudFileName.isEmpty) return _dateBasedName('필기', cloudUpdatedAt);
    final name = cloudFileName
        .replaceAll(RegExp(r'\.(png|jpg|jpeg)$', caseSensitive: false), '')
        .replaceAll('_drawing', '');
    // UUID면 날짜 기반 제목으로 대체
    if (_uuidRegExp.hasMatch(name)) return _dateBasedName('필기', cloudUpdatedAt);
    return name;
  }

  // 오디오 파일 표시 이름 추출
  // - "원본이름.m4a" → "원본이름"
  // - UUID 기반이면 날짜 기반 대체
  String _extractAudioDisplayName(String cloudFileName, DateTime cloudUpdatedAt) {
    if (cloudFileName.isEmpty) return _dateBasedName('녹음', cloudUpdatedAt);
    final name = cloudFileName.replaceAll(RegExp(r'\.m4a$', caseSensitive: false), '');
    if (_uuidRegExp.hasMatch(name)) return _dateBasedName('녹음', cloudUpdatedAt);
    return name;
  }
}

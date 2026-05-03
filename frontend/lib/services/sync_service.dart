import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audio_file.dart';
import '../models/text_file.dart';
import '../models/handwriting_file.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'file_storage_service.dart';

class SyncService {
  static const String _keyLastSyncTime = 'sync_last_time';
  static const String _keyBackgroundTime = 'sync_background_time';
  static const String _keyOfflineQueue = 'sync_offline_queue';

  static SyncService? _instance;
  static SyncService get instance => _instance ??= SyncService._();
  SyncService._();

  final ApiService _api = ApiService();
  AuthServiceImpl? _authService;
  VoidCallback? _onSyncStatusChanged;
  FileStorageService get _fileStorage => FileStorageService.instance;

  void init(AuthServiceImpl authService, {VoidCallback? onSyncStatusChanged}) {
    _authService = authService;
    _onSyncStatusChanged = onSyncStatusChanged;
    debugPrint('[SyncService] init 완료');
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

  // ② 앱 시작 시 변경분만 동기화
  Future<void> syncOnAppStart() async {
    debugPrint('[SyncService] syncOnAppStart 진입');
    if (!_canSync) return;
    final token = await _loadToken();
    if (token == null) return;

    final lastSync = await _getLastSyncTime();
    if (lastSync == null) {
      debugPrint('[SyncService] syncOnAppStart - 최초, 전체 동기화');
      await syncOnLogin();
      return;
    }

    try {
      await _incrementalSync(token, lastSync);
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
    await syncOnAppStart();
  }

  void recordBackgroundTime() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_keyBackgroundTime, DateTime.now().toIso8601String());
    });
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
    debugPrint('[SyncService] deleteFile - cloudId: $cloudId');
    if (!_canSync) return;
    final token = await _loadToken();
    if (token == null) return;

    try {
      final success = await _api.deleteCloudFile(token: token, cloudId: cloudId);
      if (!success) {
        await _addToOfflineQueue({
          'action': 'delete', 'littenId': littenId, 'localId': localId,
          'cloudId': cloudId, 'fileType': fileType
        });
      }
    } catch (e) {
      debugPrint('[SyncService] deleteFile 오류: $e');
      await _addToOfflineQueue({
        'action': 'delete', 'littenId': littenId, 'localId': localId,
        'cloudId': cloudId, 'fileType': fileType
      });
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
  Future<void> _bidirectionalSync(String token) async {
    debugPrint('[SyncService] _bidirectionalSync 시작');
    final cloudFiles = await _api.getCloudFiles(token: token);
    debugPrint('[SyncService] 클라우드 파일 ${cloudFiles.length}개');

    for (final cloudMeta in cloudFiles) {
      final localId = cloudMeta['localId'] as String;
      final littenId = cloudMeta['littenId'] as String;
      final fileType = cloudMeta['fileType'] as String;
      final cloudId = cloudMeta['cloudId'].toString();
      final cloudUpdatedAt = DateTime.parse(cloudMeta['localUpdatedAt'].toString());

      final localFile = await _findLocalFile(littenId, localId, fileType);

      if (localFile == null) {
        // 클라우드에만 존재 → lazy 다운로드 마킹
        debugPrint('[SyncService] 클라우드 전용 파일 (lazy): $localId');
      } else {
        final localUpdatedAt = _getFileUpdatedAt(localFile);
        if (cloudUpdatedAt.isAfter(localUpdatedAt)) {
          await _downloadAndApply(token, cloudId, littenId, localId, fileType, cloudUpdatedAt);
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

      final localFile = await _findLocalFile(littenId, localId, fileType);
      if (localFile == null || cloudUpdatedAt.isAfter(_getFileUpdatedAt(localFile))) {
        await _downloadAndApply(token, cloudId, littenId, localId, fileType, cloudUpdatedAt);
      }
    }
    await processOfflineQueue();
  }

  Future<void> _downloadAndApply(String token, String cloudId, String littenId,
      String localId, String fileType, DateTime cloudUpdatedAt) async {
    try {
      final bytes = await _api.downloadFile(token: token, cloudId: cloudId);
      if (bytes == null) return;
      final localPath = await _saveDownloadedFile(littenId, localId, fileType, bytes);
      if (localPath == null) return;
      await _updateLocalFileFromDownload(littenId, localId, fileType, cloudId, localPath, cloudUpdatedAt);
      debugPrint('[SyncService] 다운로드 완료 - localId: $localId');
    } catch (e) {
      debugPrint('[SyncService] _downloadAndApply 오류: $e');
    }
  }

  Future<void> _uploadLocalFile(String token, String littenId, String localId,
      String cloudId, String fileType, dynamic localFile) async {
    final filePath = _getFilePath(localFile);
    if (filePath == null) return;
    final result = await _api.updateFile(
      token: token, cloudId: cloudId,
      localUpdatedAt: _getFileUpdatedAt(localFile).toIso8601String(),
      file: File(filePath), contentType: _getContentType(fileType),
    );
    if (result != null) {
      await _updateLocalSyncStatus(littenId, localId, fileType, cloudId, SyncStatus.synced);
    }
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
    }
    return null;
  }

  DateTime _getFileUpdatedAt(dynamic file) {
    if (file is TextFile) return file.updatedAt;
    if (file is HandwritingFile) return file.updatedAt;
    if (file is AudioFile) return file.updatedAt;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String? _getFilePath(dynamic file) {
    if (file is HandwritingFile) return file.imagePath;
    if (file is AudioFile) return file.filePath;
    return null;
  }

  Future<String?> _saveDownloadedFile(String littenId, String localId, String fileType, Uint8List bytes) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${appDir.path}/litten/$littenId/$fileType');
      await dir.create(recursive: true);
      final file = File('${dir.path}/$localId${_getFileExtension(fileType)}');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      debugPrint('[SyncService] _saveDownloadedFile 오류: $e');
      return null;
    }
  }

  Future<void> _updateLocalFileFromDownload(String littenId, String localId, String fileType,
      String cloudId, String localPath, DateTime cloudUpdatedAt) async {
    if (fileType == 'text') {
      final files = await _fileStorage.loadTextFiles(littenId);
      final idx = files.indexWhere((f) => f.id == localId);
      if (idx >= 0) {
        files[idx] = files[idx].copyWith(cloudId: cloudId, cloudUpdatedAt: cloudUpdatedAt, syncStatus: SyncStatus.synced);
        await _fileStorage.saveTextFiles(littenId, files);
        _onSyncStatusChanged?.call();
      }
    } else if (fileType == 'handwriting') {
      final files = await _fileStorage.loadHandwritingFiles(littenId);
      final idx = files.indexWhere((f) => f.id == localId);
      if (idx >= 0) {
        files[idx] = files[idx].copyWith(cloudId: cloudId, cloudUpdatedAt: cloudUpdatedAt, syncStatus: SyncStatus.synced);
        await _fileStorage.saveHandwritingFiles(littenId, files);
        _onSyncStatusChanged?.call();
      }
    } else if (fileType == 'audio') {
      final files = await _fileStorage.loadAudioFiles(littenId);
      final idx = files.indexWhere((f) => f.id == localId);
      if (idx >= 0) {
        files[idx] = files[idx].copyWith(cloudId: cloudId, cloudUpdatedAt: cloudUpdatedAt, syncStatus: SyncStatus.synced);
        await _fileStorage.saveAudioFiles(littenId, files);
        _onSyncStatusChanged?.call();
      }
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
    }
  }

  String _getContentType(String fileType) {
    switch (fileType) {
      case 'audio': return 'audio/m4a';
      case 'text': return 'text/plain';
      case 'handwriting': return 'image/png';
      default: return 'application/octet-stream';
    }
  }

  String _getFileExtension(String fileType) {
    switch (fileType) {
      case 'audio': return '.m4a';
      case 'text': return '.txt';
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
}

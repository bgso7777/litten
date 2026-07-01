import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 채팅으로 공유(보냄/받음)한 파일을 '공유 시점 내용 그대로' 기기 로컬에 복사해 보관한 한 건.
/// littens 저장소·공유 취소(회수) 로직과 완전히 분리되어, 원본 수정/삭제나
/// 발신자의 공유 취소가 있어도 보존된다.
class SharedSnapshot {
  final String key;         // 고유 키 (sent:{shareId} / recv:{deliveryId})
  final String direction;   // 'sent' | 'received'
  final int? shareId;       // 서버 공유 id
  final int? deliveryId;    // 받은 공유의 전달 id
  final String fileName;    // 원본 표시 파일명(확장자 포함)
  final String fileType;    // text/stt_text/audio/stt_audio/handwriting/attachment
  final String? contentType;
  final String path;        // 복사본의 절대 경로
  final String sharedAt;    // 공유 시각(ISO8601)
  final String peer;        // 상대(이메일/그룹) 표시용
  final String? message;    // 함께 보낸 메시지

  SharedSnapshot({
    required this.key,
    required this.direction,
    this.shareId,
    this.deliveryId,
    required this.fileName,
    required this.fileType,
    this.contentType,
    required this.path,
    required this.sharedAt,
    required this.peer,
    this.message,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'direction': direction,
        'shareId': shareId,
        'deliveryId': deliveryId,
        'fileName': fileName,
        'fileType': fileType,
        'contentType': contentType,
        'path': path,
        'sharedAt': sharedAt,
        'peer': peer,
        'message': message,
      };

  factory SharedSnapshot.fromJson(Map<String, dynamic> j) => SharedSnapshot(
        key: j['key']?.toString() ?? '',
        direction: j['direction']?.toString() ?? 'sent',
        shareId: (j['shareId'] as num?)?.toInt(),
        deliveryId: (j['deliveryId'] as num?)?.toInt(),
        fileName: j['fileName']?.toString() ?? 'shared',
        fileType: j['fileType']?.toString() ?? 'attachment',
        contentType: j['contentType']?.toString(),
        path: j['path']?.toString() ?? '',
        sharedAt: j['sharedAt']?.toString() ?? '',
        peer: j['peer']?.toString() ?? '',
        message: j['message']?.toString(),
      );
}

/// 공유 파일 스냅샷(복사본)을 저장/조회하는 서비스.
/// - 파일 실체: `{appDoc}/shared_snapshots/{key}{ext}`
/// - 인덱스: SharedPreferences 키 `shared_snapshots_index` (JSON 배열)
class SharedSnapshotService {
  SharedSnapshotService._();
  static final SharedSnapshotService instance = SharedSnapshotService._();

  static const String _indexKey = 'shared_snapshots_index';
  static const String _dirName = 'shared_snapshots';

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_dirName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<List<SharedSnapshot>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_indexKey);
      if (raw == null || raw.isEmpty) return [];
      final list = (jsonDecode(raw) as List)
          .map((e) => SharedSnapshot.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return list;
    } catch (e) {
      debugPrint('[SharedSnapshotService] loadAll 오류: $e');
      return [];
    }
  }

  Future<void> _saveIndex(List<SharedSnapshot> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _indexKey, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  /// 보낸 공유의 원본 파일을 복사해 스냅샷으로 보관. shareId 기준 중복이면 기존 것을 반환.
  Future<SharedSnapshot?> saveSent({
    required int shareId,
    required String fileName,
    required String fileType,
    String? contentType,
    required String sourcePath,
    String? sharedAt,
    String peer = '',
    String? message,
  }) async {
    try {
      final key = 'sent:$shareId';
      final existing = await findByKey(key);
      if (existing != null) return existing;
      final src = File(sourcePath);
      if (!await src.exists()) {
        debugPrint('[SharedSnapshotService] saveSent - 원본 없음: $sourcePath');
        return null;
      }
      final bytes = await src.readAsBytes();
      return _persist(
        key: key,
        direction: 'sent',
        shareId: shareId,
        deliveryId: null,
        fileName: fileName,
        fileType: fileType,
        contentType: contentType,
        bytes: bytes,
        sharedAt: sharedAt,
        peer: peer,
        message: message,
      );
    } catch (e) {
      debugPrint('[SharedSnapshotService] saveSent 오류: $e');
      return null;
    }
  }

  /// 받은 공유의 다운로드 바이트를 스냅샷으로 보관. deliveryId 기준 중복이면 기존 것을 반환.
  Future<SharedSnapshot?> saveReceived({
    required int deliveryId,
    int? shareId,
    required String fileName,
    required String fileType,
    String? contentType,
    required List<int> bytes,
    String? sharedAt,
    String peer = '',
    String? message,
  }) async {
    try {
      final key = 'recv:$deliveryId';
      final existing = await findByKey(key);
      if (existing != null) return existing;
      return _persist(
        key: key,
        direction: 'received',
        shareId: shareId,
        deliveryId: deliveryId,
        fileName: fileName,
        fileType: fileType,
        contentType: contentType,
        bytes: bytes,
        sharedAt: sharedAt,
        peer: peer,
        message: message,
      );
    } catch (e) {
      debugPrint('[SharedSnapshotService] saveReceived 오류: $e');
      return null;
    }
  }

  Future<SharedSnapshot> _persist({
    required String key,
    required String direction,
    int? shareId,
    int? deliveryId,
    required String fileName,
    required String fileType,
    String? contentType,
    required List<int> bytes,
    String? sharedAt,
    required String peer,
    String? message,
  }) async {
    final dir = await _dir();
    final ext = _extFor(fileName, fileType);
    final safeKey = key.replaceAll(':', '_');
    final path = '${dir.path}/$safeKey$ext';
    await File(path).writeAsBytes(bytes, flush: true);

    final snap = SharedSnapshot(
      key: key,
      direction: direction,
      shareId: shareId,
      deliveryId: deliveryId,
      fileName: fileName,
      fileType: fileType,
      contentType: contentType,
      path: path,
      sharedAt: sharedAt ?? DateTime.now().toIso8601String(),
      peer: peer,
      message: message,
    );

    final list = await loadAll();
    list.removeWhere((e) => e.key == key); // 혹시 모를 중복 제거
    list.add(snap);
    await _saveIndex(list);
    debugPrint('[SharedSnapshotService] 스냅샷 보관 - $key ($fileType) → $path');
    return snap;
  }

  /// 주어진 키들의 스냅샷(파일 + 인덱스)을 삭제한다. 대화방 나가기/삭제 시 파일 정리용.
  Future<void> deleteByKeys(Iterable<String> keys) async {
    final target = keys.toSet();
    if (target.isEmpty) return;
    final list = await loadAll();
    final remain = <SharedSnapshot>[];
    for (final s in list) {
      if (target.contains(s.key)) {
        try {
          final f = File(s.path);
          if (await f.exists()) await f.delete();
        } catch (e) {
          debugPrint('[SharedSnapshotService] 파일 삭제 실패(무시): ${s.path} - $e');
        }
      } else {
        remain.add(s);
      }
    }
    await _saveIndex(remain);
    debugPrint('[SharedSnapshotService] 스냅샷 삭제 ${list.length - remain.length}건: $target');
  }

  Future<SharedSnapshot?> findByKey(String key) async {
    final list = await loadAll();
    for (final s in list) {
      if (s.key == key) return s;
    }
    return null;
  }

  Future<SharedSnapshot?> findSent(int shareId) => findByKey('sent:$shareId');
  Future<SharedSnapshot?> findReceived(int deliveryId) =>
      findByKey('recv:$deliveryId');

  /// shareId가 일치하는 스냅샷을 방향 무관하게 찾는다(키 조회 실패 시 폴백).
  Future<SharedSnapshot?> findByShareId(int shareId) async {
    final list = await loadAll();
    for (final s in list) {
      if (s.shareId == shareId) return s;
    }
    return null;
  }

  /// 파일명 확장자 우선, 없으면 파일 타입으로 확장자 추정.
  String _extFor(String fileName, String fileType) {
    final dot = fileName.lastIndexOf('.');
    if (dot > 0 && dot < fileName.length - 1) {
      return fileName.substring(dot).toLowerCase();
    }
    switch (fileType) {
      case 'text':
      case 'stt_text':
        return '.html';
      case 'audio':
      case 'stt_audio':
        return '.m4a';
      case 'handwriting':
        return '.png';
      default:
        return '';
    }
  }
}

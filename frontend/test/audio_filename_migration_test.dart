import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:litten/models/audio_file.dart';
import 'package:litten/services/audio_service.dart';
import 'package:litten/services/file_storage_service.dart';

/// 회귀 방지: "같은 녹음은 어떤 동기화 경로에서도 물리 파일/메타 단 1개"
///
/// 과거 버그 — 녹음 원본은 표시명({litten명} {날짜}.m4a)으로, 동기화 다운로드본은
/// localId({id}.m4a)로 저장돼 디렉토리에 물리 파일 2개가 생기고, getAudioFiles의
/// 디렉토리 스캔이 이를 2개 항목으로 잡아 중복되었다. 수정으로 녹음 파일명을 {id}.m4a로
/// 통일했고, 기존 데이터는 마이그레이션이 정규화한다. 그 마이그레이션 불변식을 검증한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('오디오 파일명 마이그레이션 (중복 제거 + 경로 정규화)', () {
    test('표시명 파일과 id 파일이 모두 있으면 id 파일 1개로 합치고 메타 경로를 정규화한다', () async {
      final tmp = await Directory.systemTemp.createTemp('litten_audio_mig');
      const littenId = 'L1';
      const id = '1781325074512';
      final audioDir = Directory('${tmp.path}/littens/$littenId/audio')
        ..createSync(recursive: true);
      // 원본(표시명) + 동기화 다운로드본(id) — 같은 녹음의 물리 파일 2개
      final displayFile = File('${audioDir.path}/녹음 260613133106.m4a')..writeAsBytesSync([1, 2, 3]);
      final idFile = File('${audioDir.path}/$id.m4a')..writeAsBytesSync([1, 2, 3]);

      await FileStorageService.instance.saveAudioFiles(littenId, [
        AudioFile(
          id: id,
          littenId: littenId,
          fileName: '녹음 260613133106',
          filePath: displayFile.path,
          createdAt: DateTime(2026, 6, 13),
          updatedAt: DateTime(2026, 6, 13),
        ),
      ]);

      await AudioService.migrateLittenAudioForTest(littenId, tmp);

      expect(idFile.existsSync(), isTrue, reason: 'id 파일은 유지');
      expect(displayFile.existsSync(), isFalse, reason: '표시명 중복 파일은 삭제');
      final meta = await FileStorageService.instance.loadAudioFiles(littenId);
      expect(meta.length, 1, reason: '메타는 1개');
      expect(meta.first.filePath, idFile.path, reason: '메타 경로가 id 파일로 정규화');
      expect(meta.first.fileName, '녹음 260613133106', reason: '표시명(fileName) 보존');
      expect(meta.first.updatedAt, DateTime(2026, 6, 13), reason: '수정 시각 보존(재업로드 핑퐁 방지)');

      tmp.deleteSync(recursive: true);
    });

    test('표시명 파일만 있으면 id 파일로 rename한다', () async {
      final tmp = await Directory.systemTemp.createTemp('litten_audio_mig');
      const littenId = 'L1';
      const id = '1781325074513';
      final audioDir = Directory('${tmp.path}/littens/$littenId/audio')
        ..createSync(recursive: true);
      final displayFile = File('${audioDir.path}/녹음 abc.m4a')..writeAsBytesSync([9, 9]);

      await FileStorageService.instance.saveAudioFiles(littenId, [
        AudioFile(
          id: id,
          littenId: littenId,
          fileName: '녹음 abc',
          filePath: displayFile.path,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ]);

      await AudioService.migrateLittenAudioForTest(littenId, tmp);

      expect(displayFile.existsSync(), isFalse, reason: '표시명 파일은 rename되어 사라짐');
      expect(File('${audioDir.path}/$id.m4a').existsSync(), isTrue, reason: 'id 파일로 이동');
      final meta = await FileStorageService.instance.loadAudioFiles(littenId);
      expect(meta.length, 1);
      expect(meta.first.filePath, '${audioDir.path}/$id.m4a');

      tmp.deleteSync(recursive: true);
    });

    test('이미 id 파일이면 변경 없이 그대로 둔다(멱등)', () async {
      final tmp = await Directory.systemTemp.createTemp('litten_audio_mig');
      const littenId = 'L1';
      const id = '1781325074514';
      final audioDir = Directory('${tmp.path}/littens/$littenId/audio')
        ..createSync(recursive: true);
      final idFile = File('${audioDir.path}/$id.m4a')..writeAsBytesSync([7]);

      await FileStorageService.instance.saveAudioFiles(littenId, [
        AudioFile(
          id: id,
          littenId: littenId,
          fileName: '녹음 xyz',
          filePath: idFile.path,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ]);

      await AudioService.migrateLittenAudioForTest(littenId, tmp);

      expect(idFile.existsSync(), isTrue);
      final meta = await FileStorageService.instance.loadAudioFiles(littenId);
      expect(meta.length, 1);
      expect(meta.first.filePath, idFile.path);
      expect(meta.first.fileName, '녹음 xyz');
    });
  });
}

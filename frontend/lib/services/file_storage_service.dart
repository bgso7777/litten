import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/text_file.dart';
import '../models/handwriting_file.dart';
import 'litten_service.dart';

class FileStorageService {
  static const String _textFilesKey = 'text_files';
  static const String _handwritingFilesKey = 'handwriting_files';
  
  static FileStorageService? _instance;
  static FileStorageService get instance => _instance ??= FileStorageService._();
  FileStorageService._();

  /// 텍스트 파일들을 SharedPreferences에서 로드
  Future<List<TextFile>> loadTextFiles(String littenId) async {
    try {
      print('디버그: 텍스트 파일 로드 시작 - littenId: $littenId');
      
      final prefs = await SharedPreferences.getInstance();
      final filesJsonString = prefs.getString('${_textFilesKey}_$littenId');
      
      if (filesJsonString == null) {
        print('디버그: 저장된 텍스트 파일이 없음');
        return [];
      }
      
      final filesList = jsonDecode(filesJsonString) as List;
      final textFiles = filesList
          .map((fileJson) => TextFile.fromJson(fileJson))
          .toList();

      // 최신순으로 정렬 (최신이 맨 위로)
      textFiles.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      print('디버그: 텍스트 파일 ${textFiles.length}개 로드 완료 (최신순 정렬)');
      return textFiles;
    } catch (e) {
      print('에러: 텍스트 파일 로드 실패 - $e');
      return [];
    }
  }

  /// 텍스트 파일들을 SharedPreferences에 저장
  Future<bool> saveTextFiles(String littenId, List<TextFile> textFiles) async {
    try {
      print('디버그: 텍스트 파일 저장 시작 - littenId: $littenId, 파일 수: ${textFiles.length}');
      
      final prefs = await SharedPreferences.getInstance();
      final filesJson = textFiles.map((file) => file.toJson()).toList();
      final filesJsonString = jsonEncode(filesJson);
      
      final success = await prefs.setString('${_textFilesKey}_$littenId', filesJsonString);
      
      print('디버그: 텍스트 파일 저장 완료 - 성공: $success');
      return success;
    } catch (e) {
      print('에러: 텍스트 파일 저장 실패 - $e');
      return false;
    }
  }

  /// 필기 파일들을 SharedPreferences에서 로드
  Future<List<HandwritingFile>> loadHandwritingFiles(String littenId) async {
    try {
      print('디버그: 필기 파일 로드 시작 - littenId: $littenId');

      final prefs = await SharedPreferences.getInstance();
      final filesJsonString = prefs.getString('${_handwritingFilesKey}_$littenId');

      // SharedPreferences에 저장된 파일이 있고 비어있지 않으면 그것을 사용
      if (filesJsonString != null) {
        final filesList = jsonDecode(filesJsonString) as List;

        // 빈 배열이면 파일 시스템을 다시 스캔
        if (filesList.isEmpty) {
          print('디버그: SharedPreferences에 빈 배열 저장됨, 파일 시스템 스캔 시작');
        } else {
          final handwritingFiles = filesList
              .map((fileJson) => HandwritingFile.fromJson(fileJson))
              .toList();

          // 최신순으로 정렬 (최신이 맨 위로)
          handwritingFiles.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          print('디버그: 필기 파일 ${handwritingFiles.length}개 로드 완료 (최신순 정렬)');
          return handwritingFiles;
        }
      } else {
        print('디버그: SharedPreferences에 없음, 파일 시스템 스캔 시작');
      }

      // 파일 시스템에서 스캔
      if (kIsWeb) {
        print('디버그: 웹 환경에서는 파일 시스템 스캔 불가');
        return [];
      }

      final dir = await getApplicationDocumentsDirectory();
      final handwritingDir = Directory('${dir.path}/littens/$littenId/handwriting');

      if (!await handwritingDir.exists()) {
        print('디버그: 필기 디렉토리가 존재하지 않음');
        return [];
      }

      final files = <HandwritingFile>[];
      await for (final entity in handwritingDir.list()) {
        if (entity is File) {
          final fileName = entity.path.split('/').last;
          // metadata.json 파일 찾기
          if (fileName.endsWith('_metadata.json')) {
            try {
              final metadataStr = await entity.readAsString();
              final metadata = jsonDecode(metadataStr);
              final handwritingFile = HandwritingFile.fromJson(metadata);
              files.add(handwritingFile);
              print('디버그: 메타데이터 파일 발견: $fileName -> ${handwritingFile.title}');
            } catch (e) {
              print('에러: 메타데이터 파일 읽기 실패 - $fileName: $e');
            }
          }
        }
      }

      // 최신순으로 정렬
      files.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // SharedPreferences에 저장
      if (files.isNotEmpty) {
        await saveHandwritingFiles(littenId, files);
      }

      print('디버그: 파일 시스템에서 필기 파일 ${files.length}개 발견 및 로드 완료');
      return files;
    } catch (e) {
      print('에러: 필기 파일 로드 실패 - $e');
      return [];
    }
  }

  /// 필기 파일들을 SharedPreferences에 저장
  Future<bool> saveHandwritingFiles(String littenId, List<HandwritingFile> handwritingFiles) async {
    try {
      print('디버그: 필기 파일 저장 시작 - littenId: $littenId, 파일 수: ${handwritingFiles.length}');
      
      final prefs = await SharedPreferences.getInstance();
      final filesJson = handwritingFiles.map((file) => file.toJson()).toList();
      final filesJsonString = jsonEncode(filesJson);
      
      final success = await prefs.setString('${_handwritingFilesKey}_$littenId', filesJsonString);
      
      print('디버그: 필기 파일 저장 완료 - 성공: $success');
      return success;
    } catch (e) {
      print('에러: 필기 파일 저장 실패 - $e');
      return false;
    }
  }

  /// 텍스트 파일 하나를 저장 (HTML 콘텐츠를 파일로 저장)
  Future<String?> saveTextFileContent(TextFile textFile) async {
    try {
      print('디버그: 텍스트 파일 콘텐츠 저장 시작 - ${textFile.displayTitle}');

      if (kIsWeb) {
        // 웹에서는 SharedPreferences에 직접 저장
        final prefs = await SharedPreferences.getInstance();
        final key = 'text_content_${textFile.id}';
        await prefs.setString(key, textFile.content);
        print('디버그: 웹에서 텍스트 파일 콘텐츠 저장 완료 - 키: $key');
        return key; // 웹에서는 키를 반환
      } else {
        // 모바일에서는 기존 파일 시스템 사용
        final directory = await getApplicationDocumentsDirectory();
        final littenDir = Directory('${directory.path}/littens/${textFile.littenId}/text');

        if (!await littenDir.exists()) {
          await littenDir.create(recursive: true);
        }

        final fileName = '${textFile.id}.html';
        final file = File('${littenDir.path}/$fileName');

        await file.writeAsString(textFile.content);

        print('디버그: 텍스트 파일 콘텐츠 저장 완료 - 경로: ${file.path}');
        return file.path;
      }
    } catch (e) {
      print('에러: 텍스트 파일 콘텐츠 저장 실패 - $e');
      return null;
    }
  }

  /// 텍스트 파일 콘텐츠 로드
  Future<String?> loadTextFileContent(String filePath) async {
    try {
      if (kIsWeb) {
        // 웹에서는 SharedPreferences에서 로드
        final prefs = await SharedPreferences.getInstance();
        final content = prefs.getString(filePath); // filePath는 실제로는 키
        if (content != null) {
          print('디버그: 웹에서 텍스트 파일 콘텐츠 로드 완료 - 길이: ${content.length}자');
        } else {
          print('에러: 웹에서 텍스트 파일을 찾을 수 없음 - 키: $filePath');
        }
        return content;
      } else {
        // 모바일에서는 기존 파일 시스템 사용
        final file = File(filePath);

        if (await file.exists()) {
          final content = await file.readAsString();
          print('디버그: 텍스트 파일 콘텐츠 로드 완료 - 길이: ${content.length}자');
          return content;
        } else {
          print('에러: 텍스트 파일이 존재하지 않음 - 경로: $filePath');
          return null;
        }
      }
    } catch (e) {
      print('에러: 텍스트 파일 콘텐츠 로드 실패 - $e');
      return null;
    }
  }

  /// 필기 파일 이미지 저장
  Future<String?> saveHandwritingImage(HandwritingFile handwritingFile, Uint8List imageBytes) async {
    try {
      print('디버그: 필기 파일 이미지 저장 시작 - ${handwritingFile.displayTitle}');

      if (kIsWeb) {
        // 웹에서는 SharedPreferences에 base64로 저장
        final key = '${handwritingFile.id}.png';
        final success = await saveImageBytesToWeb(key, imageBytes);
        if (success) {
          print('디버그: 웹에서 필기 파일 이미지 저장 완료 - 키: $key');
          return key; // 웹에서는 키를 반환
        } else {
          return null;
        }
      } else {
        // 모바일에서는 기존 파일 시스템 사용
        final directory = await getApplicationDocumentsDirectory();
        final littenDir = Directory('${directory.path}/littens/${handwritingFile.littenId}/handwriting');

        if (!await littenDir.exists()) {
          await littenDir.create(recursive: true);
        }

        final fileName = '${handwritingFile.id}.png';
        final file = File('${littenDir.path}/$fileName');

        await file.writeAsBytes(imageBytes);

        print('디버그: 필기 파일 이미지 저장 완료 - 경로: ${file.path}');
        return file.path;
      }
    } catch (e) {
      print('에러: 필기 파일 이미지 저장 실패 - $e');
      return null;
    }
  }

  /// 필기 파일 이미지 로드
  Future<Uint8List?> loadHandwritingImage(String filePath) async {
    try {
      if (kIsWeb) {
        // 웹에서는 SharedPreferences에서 base64로 로드
        return await getImageBytesFromWeb(filePath); // filePath는 실제로는 키
      } else {
        // 모바일에서는 기존 파일 시스템 사용
        final file = File(filePath);

        if (await file.exists()) {
          final imageBytes = await file.readAsBytes();
          print('디버그: 필기 파일 이미지 로드 완료 - 크기: ${imageBytes.length} bytes');
          return imageBytes;
        } else {
          print('에러: 필기 파일이 존재하지 않음 - 경로: $filePath');
          return null;
        }
      }
    } catch (e) {
      print('에러: 필기 파일 이미지 로드 실패 - $e');
      return null;
    }
  }

  /// 특정 리튼의 모든 파일 삭제
  Future<bool> deleteAllFilesForLitten(String littenId) async {
    try {
      print('디버그: 리튼 파일 전체 삭제 시작 - littenId: $littenId');
      
      // SharedPreferences에서 삭제
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_textFilesKey}_$littenId');
      await prefs.remove('${_handwritingFilesKey}_$littenId');
      
      // 파일 시스템에서 디렉토리 삭제
      final directory = await getApplicationDocumentsDirectory();
      final littenDir = Directory('${directory.path}/littens/$littenId');
      
      if (await littenDir.exists()) {
        await littenDir.delete(recursive: true);
      }
      
      print('디버그: 리튼 파일 전체 삭제 완료 - littenId: $littenId');
      return true;
    } catch (e) {
      print('에러: 리튼 파일 전체 삭제 실패 - $e');
      return false;
    }
  }

  /// 특정 텍스트 파일 삭제
  Future<bool> deleteTextFile(TextFile textFile) async {
    try {
      print('디버그: 텍스트 파일 삭제 시작 - ${textFile.displayTitle}');
      
      // 파일 시스템에서 삭제
      final directory = await getApplicationDocumentsDirectory();
      final littenDir = Directory('${directory.path}/littens/${textFile.littenId}/text');
      final file = File('${littenDir.path}/${textFile.id}.html');
      
      if (await file.exists()) {
        await file.delete();
      }
      
      print('디버그: 텍스트 파일 삭제 완료 - ${textFile.displayTitle}');
      return true;
    } catch (e) {
      print('에러: 텍스트 파일 삭제 실패 - $e');
      return false;
    }
  }

  /// 특정 필기 파일 삭제
  Future<bool> deleteHandwritingFile(HandwritingFile handwritingFile) async {
    try {
      print('디버그: 필기 파일 삭제 시작 - ${handwritingFile.displayTitle}');
      
      // 파일 시스템에서 삭제
      final directory = await getApplicationDocumentsDirectory();
      final littenDir = Directory('${directory.path}/littens/${handwritingFile.littenId}/handwriting');
      final file = File('${littenDir.path}/${handwritingFile.id}.png');
      
      if (await file.exists()) {
        await file.delete();
      }
      
      print('디버그: 필기 파일 삭제 완료 - ${handwritingFile.displayTitle}');
      return true;
    } catch (e) {
      print('에러: 필기 파일 삭제 실패 - $e');
      return false;
    }
  }

  /// 웹 전용: 이미지 바이트를 SharedPreferences에 base64로 저장
  Future<bool> saveImageBytesToWeb(String key, Uint8List imageBytes) async {
    try {
      print('디버그: 웹 이미지 저장 시작 - 키: $key, 크기: ${imageBytes.length} bytes');

      final prefs = await SharedPreferences.getInstance();
      final base64String = base64Encode(imageBytes);

      final success = await prefs.setString('image_$key', base64String);

      print('디버그: 웹 이미지 저장 완료 - 성공: $success');
      return success;
    } catch (e) {
      print('에러: 웹 이미지 저장 실패 - $e');
      return false;
    }
  }

  /// 웹 전용: SharedPreferences에서 base64 이미지를 로드
  Future<Uint8List?> getImageBytesFromWeb(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final base64String = prefs.getString('image_$key');

      if (base64String == null) {
        print('에러: 웹 이미지를 찾을 수 없음 - 키: $key');
        return null;
      }

      final imageBytes = base64Decode(base64String);
      print('디버그: 웹 이미지 로드 완료 - 키: $key, 크기: ${imageBytes.length} bytes');
      return imageBytes;
    } catch (e) {
      print('에러: 웹 이미지 로드 실패 - $e');
      return null;
    }
  }

  /// 웹 전용: 특정 키의 이미지 삭제
  Future<bool> removeImageFromWeb(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.remove('image_$key');
      print('디버그: 웹 이미지 삭제 완료 - 키: $key, 성공: $success');
      return success;
    } catch (e) {
      print('에러: 웹 이미지 삭제 실패 - $e');
      return false;
    }
  }
}
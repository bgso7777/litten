import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      
      print('디버그: 텍스트 파일 ${textFiles.length}개 로드 완료');
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
      
      if (filesJsonString == null) {
        print('디버그: 저장된 필기 파일이 없음');
        return [];
      }
      
      final filesList = jsonDecode(filesJsonString) as List;
      final handwritingFiles = filesList
          .map((fileJson) => HandwritingFile.fromJson(fileJson))
          .toList();
      
      print('디버그: 필기 파일 ${handwritingFiles.length}개 로드 완료');
      return handwritingFiles;
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
      
      final directory = await getApplicationDocumentsDirectory();
      final littenDir = Directory('${directory.path}/litten_${textFile.littenId}');
      
      if (!await littenDir.exists()) {
        await littenDir.create(recursive: true);
      }
      
      final fileName = '${textFile.id}.html';
      final file = File('${littenDir.path}/$fileName');
      
      await file.writeAsString(textFile.content);
      
      print('디버그: 텍스트 파일 콘텐츠 저장 완료 - 경로: ${file.path}');
      return file.path;
    } catch (e) {
      print('에러: 텍스트 파일 콘텐츠 저장 실패 - $e');
      return null;
    }
  }

  /// 텍스트 파일 콘텐츠 로드
  Future<String?> loadTextFileContent(String filePath) async {
    try {
      final file = File(filePath);
      
      if (await file.exists()) {
        final content = await file.readAsString();
        print('디버그: 텍스트 파일 콘텐츠 로드 완료 - 길이: ${content.length}자');
        return content;
      } else {
        print('에러: 텍스트 파일이 존재하지 않음 - 경로: $filePath');
        return null;
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
      
      final directory = await getApplicationDocumentsDirectory();
      final littenDir = Directory('${directory.path}/litten_${handwritingFile.littenId}');
      
      if (!await littenDir.exists()) {
        await littenDir.create(recursive: true);
      }
      
      final fileName = '${handwritingFile.id}.png';
      final file = File('${littenDir.path}/$fileName');
      
      await file.writeAsBytes(imageBytes);
      
      print('디버그: 필기 파일 이미지 저장 완료 - 경로: ${file.path}');
      return file.path;
    } catch (e) {
      print('에러: 필기 파일 이미지 저장 실패 - $e');
      return null;
    }
  }

  /// 필기 파일 이미지 로드
  Future<Uint8List?> loadHandwritingImage(String filePath) async {
    try {
      final file = File(filePath);
      
      if (await file.exists()) {
        final imageBytes = await file.readAsBytes();
        print('디버그: 필기 파일 이미지 로드 완료 - 크기: ${imageBytes.length} bytes');
        return imageBytes;
      } else {
        print('에러: 필기 파일이 존재하지 않음 - 경로: $filePath');
        return null;
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
      final littenDir = Directory('${directory.path}/litten_$littenId');
      
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
      final littenDir = Directory('${directory.path}/litten_${textFile.littenId}');
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
      final littenDir = Directory('${directory.path}/litten_${handwritingFile.littenId}');
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
}
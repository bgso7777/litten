import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/note_model.dart';

class LocalStorageService {
  static Database? _database;
  static const String _databaseName = 'litten.db';
  static const int _databaseVersion = 1;
  
  // 테이블 이름
  static const String _tableNotes = 'notes';
  static const String _tableFiles = 'files';
  
  // 데이터베이스 인스턴스 가져오기
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }
  
  // 데이터베이스 초기화
  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }
  
  // 데이터베이스 테이블 생성
  Future<void> _onCreate(Database db, int version) async {
    // 노트 테이블
    await db.execute('''
      CREATE TABLE $_tableNotes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    
    // 파일 테이블
    await db.execute('''
      CREATE TABLE $_tableFiles (
        id TEXT PRIMARY KEY,
        noteId TEXT NOT NULL,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        content TEXT,
        filePath TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        metadata TEXT,
        FOREIGN KEY (noteId) REFERENCES $_tableNotes (id) ON DELETE CASCADE
      )
    ''');
    
    // 인덱스 생성
    await db.execute('CREATE INDEX idx_files_noteId ON $_tableFiles (noteId)');
    await db.execute('CREATE INDEX idx_notes_updatedAt ON $_tableNotes (updatedAt)');
  }
  
  // 데이터베이스 업그레이드
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 향후 스키마 업그레이드 시 구현
  }
  
  // 노트 저장
  Future<void> saveNote(NoteModel note) async {
    final db = await database;
    
    await db.transaction((txn) async {
      // 노트 저장
      await txn.insert(
        _tableNotes,
        {
          'id': note.id,
          'title': note.title,
          'description': note.description,
          'createdAt': note.createdAt.toIso8601String(),
          'updatedAt': note.updatedAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      // 기존 파일들 삭제 후 다시 저장
      await txn.delete(_tableFiles, where: 'noteId = ?', whereArgs: [note.id]);
      
      // 새 파일들 저장
      for (final file in note.files) {
        await txn.insert(
          _tableFiles,
          {
            'id': file.id,
            'noteId': file.noteId,
            'type': file.type.name,
            'name': file.name,
            'content': file.content,
            'filePath': file.filePath,
            'createdAt': file.createdAt.toIso8601String(),
            'updatedAt': file.updatedAt.toIso8601String(),
            'metadata': jsonEncode(file.metadata),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
  
  // 노트 목록 로드
  Future<List<NoteModel>> loadNotes() async {
    final db = await database;
    
    final noteResults = await db.query(
      _tableNotes,
      orderBy: 'updatedAt DESC',
    );
    
    final notes = <NoteModel>[];
    
    for (final noteRow in noteResults) {
      final fileResults = await db.query(
        _tableFiles,
        where: 'noteId = ?',
        whereArgs: [noteRow['id']],
        orderBy: 'createdAt ASC',
      );
      
      final files = fileResults.map((fileRow) {
        return FileModel.fromJson({
          'id': fileRow['id'],
          'noteId': fileRow['noteId'],
          'type': fileRow['type'],
          'name': fileRow['name'],
          'content': fileRow['content'] ?? '',
          'filePath': fileRow['filePath'],
          'createdAt': fileRow['createdAt'],
          'updatedAt': fileRow['updatedAt'],
          'metadata': fileRow['metadata'] != null 
              ? jsonDecode(fileRow['metadata'] as String)
              : <String, dynamic>{},
        });
      }).toList();
      
      notes.add(NoteModel.fromJson({
        'id': noteRow['id'],
        'title': noteRow['title'],
        'description': noteRow['description'] ?? '',
        'createdAt': noteRow['createdAt'],
        'updatedAt': noteRow['updatedAt'],
        'files': files.map((file) => file.toJson()).toList(),
      }));
    }
    
    return notes;
  }
  
  // 노트 삭제
  Future<void> deleteNote(String noteId) async {
    final db = await database;
    
    await db.transaction((txn) async {
      // 관련 파일들의 로컬 파일 삭제
      final fileResults = await txn.query(
        _tableFiles,
        columns: ['filePath'],
        where: 'noteId = ? AND filePath IS NOT NULL',
        whereArgs: [noteId],
      );
      
      for (final fileRow in fileResults) {
        final filePath = fileRow['filePath'] as String?;
        if (filePath != null) {
          try {
            final file = File(filePath);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {
            print('파일 삭제 실패: $filePath, 에러: $e');
          }
        }
      }
      
      // 데이터베이스에서 파일 삭제
      await txn.delete(_tableFiles, where: 'noteId = ?', whereArgs: [noteId]);
      
      // 노트 삭제
      await txn.delete(_tableNotes, where: 'id = ?', whereArgs: [noteId]);
    });
  }
  
  // 파일 삭제
  Future<void> deleteFile(String fileId) async {
    final db = await database;
    
    // 파일 경로 조회
    final results = await db.query(
      _tableFiles,
      columns: ['filePath'],
      where: 'id = ?',
      whereArgs: [fileId],
    );
    
    if (results.isNotEmpty) {
      final filePath = results.first['filePath'] as String?;
      
      // 로컬 파일 삭제
      if (filePath != null) {
        try {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          print('파일 삭제 실패: $filePath, 에러: $e');
        }
      }
      
      // 데이터베이스에서 삭제
      await db.delete(_tableFiles, where: 'id = ?', whereArgs: [fileId]);
    }
  }
  
  // 앱 데이터 디렉토리 가져오기
  Future<Directory> getAppDataDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final appDir = Directory('${directory.path}/litten_data');
    
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    
    return appDir;
  }
  
  // 오디오 파일 디렉토리
  Future<Directory> getAudioDirectory() async {
    final appDir = await getAppDataDirectory();
    final audioDir = Directory('${appDir.path}/audio');
    
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    
    return audioDir;
  }
  
  // 이미지 파일 디렉토리
  Future<Directory> getImageDirectory() async {
    final appDir = await getAppDataDirectory();
    final imageDir = Directory('${appDir.path}/images');
    
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    
    return imageDir;
  }
  
  // 변환된 파일 디렉토리
  Future<Directory> getConvertedDirectory() async {
    final appDir = await getAppDataDirectory();
    final convertedDir = Directory('${appDir.path}/converted');
    
    if (!await convertedDir.exists()) {
      await convertedDir.create(recursive: true);
    }
    
    return convertedDir;
  }
  
  // 데이터베이스 초기화 (모든 데이터 삭제)
  Future<void> clearAllData() async {
    final db = await database;
    
    await db.transaction((txn) async {
      await txn.delete(_tableFiles);
      await txn.delete(_tableNotes);
    });
    
    // 앱 데이터 디렉토리의 모든 파일 삭제
    try {
      final appDir = await getAppDataDirectory();
      if (await appDir.exists()) {
        await appDir.delete(recursive: true);
      }
    } catch (e) {
      print('앱 데이터 디렉토리 삭제 실패: $e');
    }
  }
  
  // 데이터베이스 크기 확인
  Future<int> getDatabaseSize() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (e) {
      print('데이터베이스 크기 확인 실패: $e');
    }
    
    return 0;
  }
}
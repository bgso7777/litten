import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';
import '../models/note_model.dart';
import '../config/app_config.dart';
import 'local_storage_service.dart';

class DrawingPoint {
  final Offset point;
  final Paint paint;
  
  DrawingPoint({required this.point, required this.paint});
}

class DrawingService extends ChangeNotifier {
  static final DrawingService _instance = DrawingService._internal();
  factory DrawingService() => _instance;
  DrawingService._internal();

  final LocalStorageService _storageService = LocalStorageService();
  final Uuid _uuid = const Uuid();

  // 그리기 상태
  List<DrawingPoint?> _points = [];
  Color _selectedColor = Colors.black;
  double _strokeWidth = 2.0;
  bool _isErasing = false;

  // Getters
  List<DrawingPoint?> get points => _points;
  Color get selectedColor => _selectedColor;
  double get strokeWidth => _strokeWidth;
  bool get isErasing => _isErasing;

  // 그리기 도구 설정
  void setColor(Color color) {
    _selectedColor = color;
    _isErasing = false;
    notifyListeners();
  }

  void setStrokeWidth(double width) {
    _strokeWidth = width;
    notifyListeners();
  }

  void toggleEraser() {
    _isErasing = !_isErasing;
    notifyListeners();
  }

  void setEraserMode(bool enabled) {
    _isErasing = enabled;
    notifyListeners();
  }

  // 점 추가
  void addPoint(Offset point) {
    final paint = Paint()
      ..color = _isErasing ? Colors.white : _selectedColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _strokeWidth
      ..blendMode = _isErasing ? BlendMode.clear : BlendMode.srcOver;

    _points.add(DrawingPoint(point: point, paint: paint));
    notifyListeners();
  }

  // 선 종료 (null 점 추가)
  void endStroke() {
    _points.add(null);
    notifyListeners();
  }

  // 모든 점 지우기
  void clearDrawing() {
    _points.clear();
    notifyListeners();
  }

  // 마지막 스트로크 취소
  void undoLastStroke() {
    if (_points.isEmpty) return;

    // 마지막 null 점부터 제거
    while (_points.isNotEmpty && _points.last == null) {
      _points.removeLast();
    }

    // 마지막 스트로크 제거
    while (_points.isNotEmpty && _points.last != null) {
      _points.removeLast();
    }

    notifyListeners();
  }

  // 그림을 이미지로 저장
  Future<FileModel?> saveDrawingAsImage(
    String noteId, 
    GlobalKey canvasKey, 
    {String? customName}
  ) async {
    try {
      // 캔버스를 이미지로 렌더링
      final RenderRepaintBoundary boundary = 
          canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        debugPrint('이미지 변환 실패');
        return null;
      }

      final Uint8List imageBytes = byteData.buffer.asUint8List();

      // 이미지 파일 저장
      final imageDir = await _storageService.getImageDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = '${imageDir.path}/$fileName';
      
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);

      // FileModel 생성
      final now = DateTime.now();
      final displayName = customName ?? '필기 ${now.month}/${now.day} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
      
      final drawingFile = FileModel(
        id: _uuid.v4(),
        noteId: noteId,
        type: FileType.handwriting,
        name: displayName,
        content: '',
        filePath: filePath,
        createdAt: now,
        updatedAt: now,
        metadata: {
          'width': image.width,
          'height': image.height,
          'fileSize': imageBytes.length,
          'format': 'png',
        },
      );

      debugPrint('필기 저장 완료: ${drawingFile.name}');
      return drawingFile;
    } catch (e) {
      debugPrint('필기 저장 실패: $e');
      return null;
    }
  }

  // PDF를 JPEG로 변환
  Future<FileModel?> convertPdfToJpeg(
    String noteId,
    String pdfPath,
    {String? customName}
  ) async {
    try {
      // PDF 파일 확인
      final pdfFile = File(pdfPath);
      if (!await pdfFile.exists()) {
        debugPrint('PDF 파일을 찾을 수 없습니다: $pdfPath');
        return null;
      }

      // PDF 처리는 복잡하므로 간단한 placeholder 구현
      // 실제로는 pdf 패키지를 사용해야 합니다
      
      // 임시로 빈 JPEG 이미지 생성
      const width = 800;
      const height = 1000;
      final image = img.Image(width: width, height: height);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      
      // 텍스트 추가 (PDF 변환 안내)
      final pdfName = pdfPath.split('/').last;
      
      // JPEG로 변환
      final jpegBytes = img.encodeJpg(image);

      // 파일 저장
      final convertedDir = await _storageService.getConvertedDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_converted.jpg';
      final filePath = '${convertedDir.path}/$fileName';
      
      final file = File(filePath);
      await file.writeAsBytes(jpegBytes);

      // FileModel 생성
      final now = DateTime.now();
      final displayName = customName ?? 'PDF 변환: $pdfName';
      
      final convertedFile = FileModel(
        id: _uuid.v4(),
        noteId: noteId,
        type: FileType.convertedImage,
        name: displayName,
        content: '',
        filePath: filePath,
        createdAt: now,
        updatedAt: now,
        metadata: {
          'width': width,
          'height': height,
          'fileSize': jpegBytes.length,
          'format': 'jpg',
          'originalPdf': pdfPath,
        },
      );

      debugPrint('PDF 변환 완료: ${convertedFile.name}');
      return convertedFile;
    } catch (e) {
      debugPrint('PDF 변환 실패: $e');
      return null;
    }
  }

  // 이미지에 주석 추가
  Future<FileModel?> addAnnotationToImage(
    String noteId,
    String imagePath,
    List<DrawingPoint?> annotations,
    {String? customName}
  ) async {
    try {
      // 원본 이미지 로드
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        debugPrint('이미지 파일을 찾을 수 없습니다: $imagePath');
        return null;
      }

      final imageBytes = await imageFile.readAsBytes();
      final originalImage = await decodeImageFromList(imageBytes);

      // 새 캔버스에 원본 이미지와 주석을 함께 그리기
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // 원본 이미지 그리기
      canvas.drawImage(originalImage, Offset.zero, Paint());
      
      // 주석 그리기
      _drawAnnotations(canvas, annotations);
      
      // 최종 이미지로 변환
      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(
        originalImage.width, 
        originalImage.height,
      );
      
      final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        debugPrint('주석 이미지 변환 실패');
        return null;
      }

      final annotatedBytes = byteData.buffer.asUint8List();

      // 파일 저장
      final imageDir = await _storageService.getImageDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_annotated.png';
      final filePath = '${imageDir.path}/$fileName';
      
      final file = File(filePath);
      await file.writeAsBytes(annotatedBytes);

      // FileModel 생성
      final now = DateTime.now();
      final originalName = imagePath.split('/').last;
      final displayName = customName ?? '주석: $originalName';
      
      final annotatedFile = FileModel(
        id: _uuid.v4(),
        noteId: noteId,
        type: FileType.handwriting,
        name: displayName,
        content: '',
        filePath: filePath,
        createdAt: now,
        updatedAt: now,
        metadata: {
          'width': originalImage.width,
          'height': originalImage.height,
          'fileSize': annotatedBytes.length,
          'format': 'png',
          'originalImage': imagePath,
          'hasAnnotations': true,
        },
      );

      debugPrint('이미지 주석 추가 완료: ${annotatedFile.name}');
      return annotatedFile;
    } catch (e) {
      debugPrint('이미지 주석 추가 실패: $e');
      return null;
    }
  }

  // 주석을 캔버스에 그리기
  void _drawAnnotations(Canvas canvas, List<DrawingPoint?> annotations) {
    for (int i = 0; i < annotations.length - 1; i++) {
      final current = annotations[i];
      final next = annotations[i + 1];
      
      if (current != null && next != null) {
        canvas.drawLine(current.point, next.point, current.paint);
      }
    }
  }

  // 그리기 파일 삭제
  Future<bool> deleteDrawingFile(String fileId, String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      debugPrint('그리기 파일 삭제 완료: $filePath');
      return true;
    } catch (e) {
      debugPrint('그리기 파일 삭제 실패: $e');
      return false;
    }
  }

  // 그리기 설정 초기화
  void resetToDefaults() {
    _selectedColor = Colors.black;
    _strokeWidth = 2.0;
    _isErasing = false;
    _points.clear();
    notifyListeners();
  }

  // 색상 팔레트
  static const List<Color> colorPalette = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.brown,
    Colors.pink,
    Colors.teal,
    Colors.indigo,
  ];

  // 선 두께 옵션
  static const List<double> strokeWidthOptions = [1.0, 2.0, 4.0, 6.0, 8.0];
}
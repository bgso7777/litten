import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:html' show AnchorElement, document;
import 'dart:convert';
import '../providers/note_provider.dart';
import '../models/note_model.dart';
import '../config/app_config.dart';

class ImageViewerScreen extends StatefulWidget {
  final String? imageUrl;      // 웹에서 사용 (Blob URL)
  final String? imagePath;     // 네이티브에서 사용 (파일 경로)
  final String fileName;
  final bool isWeb;
  final FileModel? fileModel;  // 필기 기능을 위한 파일 모델
  
  const ImageViewerScreen({
    super.key,
    this.imageUrl,
    this.imagePath,
    required this.fileName,
    required this.isWeb,
    this.fileModel,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  
  // 필기 관련 상태
  bool _isEditMode = false;
  List<List<Offset>> _drawingPaths = [];
  List<Offset> _currentPath = [];
  Color _penColor = Colors.red;
  double _penWidth = 3.0;
  
  @override
  void initState() {
    super.initState();
    _validateImage();
    _loadExistingDrawing();
  }
  
  // 기존 필기 데이터 로드
  void _loadExistingDrawing() {
    if (widget.fileModel?.metadata?['drawingPaths'] != null) {
      try {
        final pathsData = widget.fileModel!.metadata!['drawingPaths'] as List;
        _drawingPaths = pathsData.map((pathData) {
          final path = (pathData as List).map((point) {
            return Offset(point['x'].toDouble(), point['y'].toDouble());
          }).toList();
          return path;
        }).toList();
        
        if (widget.fileModel!.metadata!['penColor'] != null) {
          _penColor = Color(widget.fileModel!.metadata!['penColor']);
        }
        if (widget.fileModel!.metadata!['penWidth'] != null) {
          _penWidth = widget.fileModel!.metadata!['penWidth'].toDouble();
        }
      } catch (e) {
        debugPrint('필기 데이터 로드 실패: $e');
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.fileName,
          style: TextStyle(fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // 편집 모드 토글 버튼 (변환된 이미지만)
          if (widget.fileModel?.type == FileType.convertedImage)
            IconButton(
              onPressed: () {
                setState(() {
                  _isEditMode = !_isEditMode;
                });
              },
              icon: Icon(_isEditMode ? Icons.pan_tool : Icons.edit),
              tooltip: _isEditMode ? '보기 모드' : '편집 모드',
            ),
          // 저장 버튼 (편집 모드일 때만)
          if (_isEditMode)
            IconButton(
              onPressed: _saveDrawing,
              icon: Icon(Icons.save),
              tooltip: '필기 저장',
            ),
          IconButton(
            onPressed: _shareImage,
            icon: Icon(Icons.share),
            tooltip: '공유',
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: 8),
                    Text('정보'),
                  ],
                ),
              ),
              if (widget.isWeb)
                PopupMenuItem(
                  value: 'download',
                  child: Row(
                    children: [
                      Icon(Icons.download),
                      SizedBox(width: 8),
                      Text('다운로드'),
                    ],
                  ),
                ),
              if (_isEditMode && _drawingPaths.isNotEmpty)
                PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.clear_all, color: Colors.red),
                      SizedBox(width: 8),
                      Text('필기 지우기'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
      backgroundColor: Colors.black,
    );
  }
  
  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              '이미지 로딩 중...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              '이미지를 불러올 수 없습니다',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('돌아가기'),
            ),
          ],
        ),
      );
    }
    
    if (_isEditMode) {
      // 편집 모드: 필기 가능
      return Stack(
        children: [
          // 배경 이미지
          InteractiveViewer(
            panEnabled: false, // 편집 모드에서는 팬 비활성화
            scaleEnabled: false, // 편집 모드에서는 줌 비활성화
            child: Center(
              child: _buildImage(),
            ),
          ),
          
          // 필기 레이어
          Positioned.fill(
            child: GestureDetector(
              onPanStart: _startDrawing,
              onPanUpdate: _updateDrawing,
              onPanEnd: _endDrawing,
              child: CustomPaint(
                painter: DrawingPainter(_drawingPaths, _currentPath, _penColor, _penWidth),
                size: Size.infinite,
              ),
            ),
          ),
          
          // 편집 모드 안내
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    '편집 모드',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      // 보기 모드: 확대/축소 가능
      return InteractiveViewer(
        panEnabled: true,
        scaleEnabled: true,
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: Stack(
            children: [
              _buildImage(),
              // 기존 필기가 있으면 표시
              if (_drawingPaths.isNotEmpty)
                Positioned.fill(
                  child: CustomPaint(
                    painter: DrawingPainter(_drawingPaths, [], _penColor, _penWidth),
                  ),
                ),
            ],
          ),
        ),
      );
    }
  }
  
  Widget _buildImage() {
    if (widget.isWeb && widget.imageUrl != null) {
      // 웹에서는 Blob URL 사용
      return Image.network(
        widget.imageUrl!,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _errorMessage = '웹 이미지 로드 실패: $error';
              _isLoading = false;
            });
          });
          return SizedBox.shrink();
        },
      );
    } else if (!widget.isWeb && widget.imagePath != null) {
      // 네이티브에서는 파일 경로 사용
      return Image.file(
        File(widget.imagePath!),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _errorMessage = '파일 이미지 로드 실패: $error';
              _isLoading = false;
            });
          });
          return SizedBox.shrink();
        },
      );
    } else {
      return Container(
        width: 200,
        height: 200,
        color: Colors.grey[800],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported,
                size: 48,
                color: Colors.grey[400],
              ),
              SizedBox(height: 8),
              Text(
                '이미지 경로가 없습니다',
                style: TextStyle(color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      );
    }
  }
  
  // 이미지 유효성 검사
  Future<void> _validateImage() async {
    try {
      print('이미지 유효성 검사 시작');
      if (widget.isWeb) {
        print('웹 모드 - 이미지 URL: ${widget.imageUrl?.substring(0, 50)}...');
        if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
          throw Exception('웹 이미지 URL이 제공되지 않았습니다');
        }
        if (!widget.imageUrl!.startsWith('blob:') && !widget.imageUrl!.startsWith('http') && !widget.imageUrl!.startsWith('data:')) {
          throw Exception('유효하지 않은 이미지 URL입니다: ${widget.imageUrl!.substring(0, 20)}');
        }
      } else {
        if (widget.imagePath == null || widget.imagePath!.isEmpty) {
          throw Exception('이미지 파일 경로가 제공되지 않았습니다');
        }
        final file = File(widget.imagePath!);
        if (!await file.exists()) {
          throw Exception('이미지 파일이 존재하지 않습니다: ${widget.imagePath}');
        }
      }
      
      // 유효성 검사 통과
      print('이미지 유효성 검사 통과');
      setState(() {
        _isLoading = false;
      });
      
    } catch (e) {
      print('이미지 유효성 검사 실패: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
  
  // 메뉴 액션 처리
  void _handleMenuAction(String action) {
    switch (action) {
      case 'info':
        _showImageInfo();
        break;
      case 'download':
        _downloadImage();
        break;
      case 'clear':
        _clearDrawing();
        break;
    }
  }
  
  // 이미지 정보 다이얼로그
  void _showImageInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('이미지 정보'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('파일명', widget.fileName),
            _buildInfoRow('타입', widget.isWeb ? '웹 이미지' : '로컬 이미지'),
            if (widget.isWeb && widget.imageUrl != null)
              _buildInfoRow('URL', widget.imageUrl!.length > 50 
                  ? '${widget.imageUrl!.substring(0, 50)}...' 
                  : widget.imageUrl!),
            if (!widget.isWeb && widget.imagePath != null)
              _buildInfoRow('경로', widget.imagePath!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('확인'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
  
  // 이미지 공유
  void _shareImage() {
    // TODO: 실제 공유 기능 구현
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('공유 기능은 추후 구현 예정입니다'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  // 이미지 다운로드 (웹 전용)
  void _downloadImage() {
    if (!widget.isWeb || widget.imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('다운로드할 수 없습니다'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      // 웹에서 다운로드 트리거
      if (kIsWeb) {
        final anchor = document.createElement('a') as AnchorElement;
        anchor.href = widget.imageUrl!;
        anchor.download = widget.fileName;
        anchor.click();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('다운로드가 시작되었습니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('다운로드 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // 필기 시작
  void _startDrawing(DragStartDetails details) {
    setState(() {
      _currentPath = [details.localPosition];
    });
  }
  
  // 필기 업데이트
  void _updateDrawing(DragUpdateDetails details) {
    setState(() {
      _currentPath.add(details.localPosition);
    });
  }
  
  // 필기 종료
  void _endDrawing(DragEndDetails details) {
    if (_currentPath.isNotEmpty) {
      setState(() {
        _drawingPaths.add(List.from(_currentPath));
        _currentPath.clear();
      });
    }
  }
  
  // 필기 지우기
  void _clearDrawing() {
    setState(() {
      _drawingPaths.clear();
      _currentPath.clear();
    });
  }
  
  // 필기 저장
  Future<void> _saveDrawing() async {
    if (widget.fileModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('파일 정보가 없어 저장할 수 없습니다'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      
      // 필기 데이터를 메타데이터에 저장
      final updatedMetadata = Map<String, dynamic>.from(widget.fileModel!.metadata ?? {});
      updatedMetadata['drawingPaths'] = _drawingPaths.map((path) => 
        path.map((offset) => {'x': offset.dx, 'y': offset.dy}).toList()
      ).toList();
      updatedMetadata['penColor'] = _penColor.value;
      updatedMetadata['penWidth'] = _penWidth;
      updatedMetadata['lastEditTime'] = DateTime.now().toIso8601String();
      
      final updatedFile = widget.fileModel!.copyWith(
        metadata: updatedMetadata,
        updatedAt: DateTime.now(),
      );
      
      await noteProvider.updateFileInNote(widget.fileModel!.noteId, updatedFile);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('필기가 저장되었습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장 실패: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// 필기용 CustomPainter
class DrawingPainter extends CustomPainter {
  final List<List<Offset>> paths;
  final List<Offset> currentPath;
  final Color color;
  final double strokeWidth;
  
  DrawingPainter(this.paths, this.currentPath, this.color, this.strokeWidth);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    
    // 완성된 경로들 그리기
    for (final path in paths) {
      if (path.length > 1) {
        final drawPath = Path();
        drawPath.moveTo(path[0].dx, path[0].dy);
        
        for (int i = 1; i < path.length; i++) {
          drawPath.lineTo(path[i].dx, path[i].dy);
        }
        
        canvas.drawPath(drawPath, paint);
      } else if (path.length == 1) {
        // 단일 점 그리기
        canvas.drawCircle(path[0], strokeWidth / 2, paint..style = PaintingStyle.fill);
      }
    }
    
    // 현재 그리고 있는 경로 그리기
    if (currentPath.length > 1) {
      final drawPath = Path();
      drawPath.moveTo(currentPath[0].dx, currentPath[0].dy);
      
      for (int i = 1; i < currentPath.length; i++) {
        drawPath.lineTo(currentPath[i].dx, currentPath[i].dy);
      }
      
      canvas.drawPath(drawPath, paint);
    } else if (currentPath.length == 1) {
      canvas.drawCircle(currentPath[0], strokeWidth / 2, paint..style = PaintingStyle.fill);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
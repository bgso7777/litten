import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/drawing_service.dart';
import '../models/note_model.dart';

class DrawingCanvas extends StatefulWidget {
  final GlobalKey canvasKey;
  final VoidCallback? onDrawingChanged;
  
  const DrawingCanvas({
    super.key, 
    required this.canvasKey,
    this.onDrawingChanged,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  @override
  Widget build(BuildContext context) {
    return Consumer<DrawingService>(
      builder: (context, drawingService, child) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: RepaintBoundary(
            key: widget.canvasKey,
            child: GestureDetector(
              onPanStart: (details) {
                final RenderBox renderBox = context.findRenderObject() as RenderBox;
                final localPosition = renderBox.globalToLocal(details.globalPosition);
                drawingService.addPoint(localPosition);
                widget.onDrawingChanged?.call();
              },
              onPanUpdate: (details) {
                final RenderBox renderBox = context.findRenderObject() as RenderBox;
                final localPosition = renderBox.globalToLocal(details.globalPosition);
                drawingService.addPoint(localPosition);
                widget.onDrawingChanged?.call();
              },
              onPanEnd: (details) {
                drawingService.endStroke();
              },
              child: CustomPaint(
                painter: DrawingPainter(drawingService.points),
                size: Size.infinite,
              ),
            ),
          ),
        );
      },
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPoint?> points;

  DrawingPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      
      if (current != null && next != null) {
        canvas.drawLine(current.point, next.point, current.paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class DrawingToolbar extends StatelessWidget {
  final VoidCallback? onSave;
  final VoidCallback? onClear;
  final VoidCallback? onUndo;
  
  const DrawingToolbar({
    super.key,
    this.onSave,
    this.onClear,
    this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DrawingService>(
      builder: (context, drawingService, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 색상 팔레트
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: DrawingService.colorPalette.length,
                  itemBuilder: (context, index) {
                    final color = DrawingService.colorPalette[index];
                    final isSelected = drawingService.selectedColor == color && !drawingService.isErasing;
                    
                    return GestureDetector(
                      onTap: () => drawingService.setColor(color),
                      child: Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected 
                            ? Border.all(color: Colors.blue, width: 3)
                            : Border.all(color: Colors.grey[400]!, width: 1),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 선 두께 선택
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: DrawingService.strokeWidthOptions.map((width) {
                  final isSelected = drawingService.strokeWidth == width;
                  
                  return GestureDetector(
                    onTap: () => drawingService.setStrokeWidth(width),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.blue : Colors.grey[400]!,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: width * 2,
                          height: width * 2,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 16),
              
              // 도구 버튼들
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 지우개
                  IconButton(
                    onPressed: () => drawingService.toggleEraser(),
                    icon: const Icon(Icons.cleaning_services),
                    style: IconButton.styleFrom(
                      backgroundColor: drawingService.isErasing 
                        ? Colors.orange 
                        : Colors.grey[200],
                      foregroundColor: drawingService.isErasing 
                        ? Colors.white 
                        : Colors.black,
                    ),
                    tooltip: '지우개',
                  ),
                  
                  // 실행 취소
                  IconButton(
                    onPressed: drawingService.points.isNotEmpty ? onUndo : null,
                    icon: const Icon(Icons.undo),
                    tooltip: '실행 취소',
                  ),
                  
                  // 모두 지우기
                  IconButton(
                    onPressed: drawingService.points.isNotEmpty ? onClear : null,
                    icon: const Icon(Icons.clear_all),
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    tooltip: '모두 지우기',
                  ),
                  
                  // 저장
                  IconButton(
                    onPressed: drawingService.points.isNotEmpty ? onSave : null,
                    icon: const Icon(Icons.save),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    tooltip: '저장',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class DrawingScreen extends StatefulWidget {
  final String noteId;
  final String? existingImagePath; // 기존 이미지에 주석을 추가하는 경우
  
  const DrawingScreen({
    super.key,
    required this.noteId,
    this.existingImagePath,
  });

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    // 새 그리기 세션 시작시 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DrawingService>(context, listen: false).resetToDefaults();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingImagePath != null ? '이미지 주석' : '새 필기'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _onBackPressed,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DrawingCanvas(
                canvasKey: _canvasKey,
                onDrawingChanged: () {
                  setState(() {
                    _hasChanges = true;
                  });
                },
              ),
            ),
          ),
          DrawingToolbar(
            onSave: _saveDrawing,
            onClear: _clearDrawing,
            onUndo: _undoLastStroke,
          ),
        ],
      ),
    );
  }

  void _onBackPressed() {
    if (_hasChanges) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('변경사항이 있습니다'),
          content: const Text('저장하지 않은 변경사항이 있습니다. 정말 나가시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('나가기'),
            ),
          ],
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _saveDrawing() async {
    final drawingService = Provider.of<DrawingService>(context, listen: false);
    
    if (drawingService.points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('그림을 그려주세요'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      FileModel? savedFile;
      
      if (widget.existingImagePath != null) {
        // 기존 이미지에 주석 추가
        savedFile = await drawingService.addAnnotationToImage(
          widget.noteId,
          widget.existingImagePath!,
          drawingService.points,
        );
      } else {
        // 새 그림 저장
        savedFile = await drawingService.saveDrawingAsImage(
          widget.noteId,
          _canvasKey,
        );
      }

      if (savedFile != null && mounted) {
        Navigator.of(context).pop(savedFile);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('저장에 실패했습니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 중 오류가 발생했습니다: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _clearDrawing() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('모두 지우기'),
        content: const Text('모든 그림을 지우시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<DrawingService>(context, listen: false).clearDrawing();
              Navigator.of(context).pop();
              setState(() {
                _hasChanges = true;
              });
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('지우기'),
          ),
        ],
      ),
    );
  }

  void _undoLastStroke() {
    Provider.of<DrawingService>(context, listen: false).undoLastStroke();
    setState(() {
      _hasChanges = true;
    });
  }
}
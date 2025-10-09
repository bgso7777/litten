import 'package:flutter/material.dart';

/// 테마색에 맞게 색상이 변경되는 노트 아이콘 위젯
///
/// CustomPaint를 사용하여 노트 아이콘을 그립니다.
class ThemedNoteIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const ThemedNoteIcon({
    super.key,
    this.size = 24.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    // IconTheme에서 색상 가져오기 (BottomNavigationBar가 설정한 색상)
    final iconTheme = IconTheme.of(context);
    final iconColor = color ?? iconTheme.color ?? Theme.of(context).primaryColor;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _NoteIconPainter(color: iconColor),
      ),
    );
  }
}

class _NoteIconPainter extends CustomPainter {
  final Color color;

  _NoteIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();

    // 노트 본체 (상단 왼쪽부터 시계방향)
    // 왼쪽 상단 시작 (탭 시작 전)
    path.moveTo(size.width * 0.15, size.height * 0.30);

    // 왼쪽 아래로 내려감
    path.lineTo(size.width * 0.15, size.height * 0.80);

    // 하단 오른쪽으로 이동 (둥근 모서리)
    path.arcToPoint(
      Offset(size.width * 0.85, size.height * 0.80),
      radius: Radius.circular(size.width * 0.05),
    );

    // 오른쪽 위로 올라감
    path.lineTo(size.width * 0.85, size.height * 0.30);

    // 상단 왼쪽으로 이동하되 탭 부분은 비워둠
    path.lineTo(size.width * 0.60, size.height * 0.30);

    // 탭 부분 (위로 올라갔다 다시 내려옴)
    path.lineTo(size.width * 0.60, size.height * 0.20);
    path.lineTo(size.width * 0.40, size.height * 0.20);
    path.lineTo(size.width * 0.40, size.height * 0.30);

    // 시작점으로 돌아옴
    path.lineTo(size.width * 0.15, size.height * 0.30);

    canvas.drawPath(path, paint);

    // 연필 아이콘 (우측 하단 대각선)
    final pencilPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round;

    // 연필 몸통
    canvas.drawLine(
      Offset(size.width * 0.48, size.height * 0.62),
      Offset(size.width * 0.62, size.height * 0.48),
      pencilPaint,
    );

    // 연필 끝부분 (삼각형)
    final pencilTipPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final tipPath = Path();
    tipPath.moveTo(size.width * 0.45, size.height * 0.65);
    tipPath.lineTo(size.width * 0.48, size.height * 0.62);
    tipPath.lineTo(size.width * 0.51, size.height * 0.65);
    tipPath.close();

    canvas.drawPath(tipPath, pencilTipPaint);
  }

  @override
  bool shouldRepaint(_NoteIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

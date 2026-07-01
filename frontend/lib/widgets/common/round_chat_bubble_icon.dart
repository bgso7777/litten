import 'dart:ui';
import 'package:flutter/material.dart';

/// 원형(동그란) 채팅 말풍선 아이콘 — Material 기본 채팅 아이콘이 모두 각진 사각형이라
/// 직접 그린다. 원 + 좌하단 꼬리를 Path.combine(union)으로 합쳐 외곽선이 하나로 이어지게 한다.
/// [filled] 가 true면 채움, false면 외곽선. 색은 상위 IconTheme 색을 따른다.
/// 하단 네비게이션(홈 탭)과 채팅 목록 제목의 채팅 아이콘에서 공통 사용한다.
class RoundChatBubbleIcon extends StatelessWidget {
  const RoundChatBubbleIcon({super.key, this.filled = false, this.size});
  final bool filled;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final color = iconTheme.color ?? Colors.black;
    final s = size ?? iconTheme.size ?? 24.0;
    return SizedBox(
      width: s,
      height: s,
      child: CustomPaint(
        painter: _RoundChatBubblePainter(color: color, filled: filled),
      ),
    );
  }
}

class _RoundChatBubblePainter extends CustomPainter {
  _RoundChatBubblePainter({required this.color, required this.filled});
  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;
    final cy = h * 0.44;
    final r = w * 0.40;

    // 원
    final circle = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    // 좌하단 꼬리(삼각형)
    final tail = Path()
      ..moveTo(cx - r * 0.62, cy + r * 0.50)
      ..lineTo(cx - r * 0.98, cy + r * 1.32)
      ..lineTo(cx - r * 0.02, cy + r * 0.86)
      ..close();
    // 외곽선이 하나로 이어지도록 합집합
    final bubble = Path.combine(PathOperation.union, circle, tail);

    final paint = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = w * 0.085
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(bubble, paint);
  }

  @override
  bool shouldRepaint(_RoundChatBubblePainter old) =>
      old.color != color || old.filled != filled;
}

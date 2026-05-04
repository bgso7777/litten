import 'package:flutter/material.dart';

/// 노트탭 하단 — 요약 리마인드 칩 (캘린더 힌트 칩과 동일한 디자인)
class SummaryReminderChip extends StatelessWidget {
  final VoidCallback? onTap;

  const SummaryReminderChip({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    final bgColor = Theme.of(context).cardColor;

    // TODO: 실제 리마인드 데이터 연결 — 요약이 있는 파일 중 remind 플래그가 있는 것
    final String? reminderText = _getReminderText(context);
    final String label = reminderText ?? '요약 리마인드';

    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _ConcaveChipTopPainter(
          fillColor: color.withValues(alpha: 0.08),
          borderColor: color.withValues(alpha: 0.25),
          backgroundColor: bgColor,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (reminderText != null) ...[
                Text(
                  reminderText,
                  style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_up, size: 24, color: color),
            ],
          ),
        ),
      ),
    );
  }

  /// 리마인드 텍스트 반환 — 추후 TextFile.summary + remind 플래그로 연결 예정
  String? _getReminderText(BuildContext context) {
    // TODO: AppStateProvider에서 요약 리마인드 데이터 읽기
    return null;
  }
}

/// 상단이 오목한 칩 Painter (노트탭 하단 배치용 — 캘린더 힌트 칩과 동일)
class _ConcaveChipTopPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final Color backgroundColor;

  const _ConcaveChipTopPainter({
    required this.fillColor,
    required this.borderColor,
    required this.backgroundColor,
  });

  Path _buildChipPath(Size size) {
    const r = 16.0;
    final path = Path();
    path.moveTo(r, 0);
    path.quadraticBezierTo(0, 0, 0, r);      // 좌상단 오목 곡선
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, r);
    path.quadraticBezierTo(size.width, 0, size.width - r, 0); // 우상단 오목 곡선
    path.lineTo(r, 0);
    path.close();
    return path;
  }

  Path _buildLeftTopCornerPath(Size size) {
    const r = 16.0;
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(r, 0);
    path.quadraticBezierTo(0, 0, 0, r);
    path.close();
    return path;
  }

  Path _buildRightTopCornerPath(Size size) {
    const r = 16.0;
    final path = Path();
    path.moveTo(size.width, 0);
    path.lineTo(size.width - r, 0);
    path.quadraticBezierTo(size.width, 0, size.width, r);
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      _buildChipPath(size),
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(_buildLeftTopCornerPath(size), bgPaint);
    canvas.drawPath(_buildRightTopCornerPath(size), bgPaint);
    canvas.drawPath(
      _buildChipPath(size),
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(_ConcaveChipTopPainter old) =>
      old.fillColor != fillColor ||
      old.borderColor != borderColor ||
      old.backgroundColor != backgroundColor;
}

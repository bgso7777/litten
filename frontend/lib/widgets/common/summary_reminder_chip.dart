import 'package:flutter/material.dart';

/// 노트탭 상단 — 요약 리마인드 칩
/// 요약된 내용의 리마인드가 있을 때 내용을 표시한다 (현재는 플레이스홀더).
class SummaryReminderChip extends StatelessWidget {
  final VoidCallback? onTap;

  const SummaryReminderChip({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    final bgColor = Theme.of(context).cardColor;

    // TODO: 실제 리마인드 데이터 연결 — 요약이 있는 파일 중 remind 플래그가 있는 것
    final String? reminderText = _getReminderText(context);
    final bool hasReminder = reminderText != null;

    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _ConcaveChipBottomPainter(
          fillColor: hasReminder
              ? color.withValues(alpha: 0.12)
              : color.withValues(alpha: 0.06),
          borderColor: color.withValues(alpha: 0.25),
          backgroundColor: bgColor,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasReminder ? Icons.notifications_active : Icons.notifications_none,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  reminderText ?? '요약 리마인드',
                  style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: hasReminder ? FontWeight.bold : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasReminder) ...[
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_right, size: 18, color: color),
              ],
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

/// 하단이 오목한 칩 Painter (노트탭 상단 배치용)
/// 상단은 직선, 하단 좌우 모서리를 오목(concave)으로 처리
class _ConcaveChipBottomPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final Color backgroundColor;

  const _ConcaveChipBottomPainter({
    required this.fillColor,
    required this.borderColor,
    required this.backgroundColor,
  });

  Path _buildChipPath(Size size) {
    const r = 16.0;
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height - r);
    path.quadraticBezierTo(size.width, size.height, size.width - r, size.height);
    path.lineTo(r, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - r);
    path.close();
    return path;
  }

  Path _buildLeftBottomCornerPath(Size size) {
    const r = 16.0;
    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(r, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - r);
    path.close();
    return path;
  }

  Path _buildRightBottomCornerPath(Size size) {
    const r = 16.0;
    final path = Path();
    path.moveTo(size.width, size.height);
    path.lineTo(size.width - r, size.height);
    path.quadraticBezierTo(size.width, size.height, size.width, size.height - r);
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
    canvas.drawPath(_buildLeftBottomCornerPath(size), bgPaint);
    canvas.drawPath(_buildRightBottomCornerPath(size), bgPaint);
    canvas.drawPath(
      _buildChipPath(size),
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(_ConcaveChipBottomPainter old) =>
      old.fillColor != fillColor ||
      old.borderColor != borderColor ||
      old.backgroundColor != backgroundColor;
}

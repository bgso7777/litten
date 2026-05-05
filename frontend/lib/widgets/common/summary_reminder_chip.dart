import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_state_provider.dart';

/// 노트탭 하단 — 요약 리마인드 칩
/// [panelLevel]: 0=닫힘, 1=절반, 2=전체
class SummaryReminderChip extends StatelessWidget {
  final VoidCallback? onTap;
  final VoidCallback? onScrollUp;
  final int panelLevel;

  const SummaryReminderChip({
    super.key,
    this.onTap,
    this.onScrollUp,
    this.panelLevel = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    final bgColor = Theme.of(context).cardColor;

    return Consumer<AppStateProvider>(
      builder: (context, appState, _) {
        final pendingCount = appState.remindItems.where((i) => !i.isDone).length;
        final label = pendingCount > 0 ? '리마인드 $pendingCount개' : '리마인드';

        return GestureDetector(
          onTap: () {
            debugPrint('[SummaryReminderChip] 탭');
            onTap?.call();
          },
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! < -200) {
              debugPrint('[SummaryReminderChip] 스크롤업 감지 velocity=${details.primaryVelocity}');
              onScrollUp?.call();
            }
          },
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
                  Icon(Icons.auto_awesome, size: 15, color: color),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 16),
                  // 레이아웃 높이를 단일 아이콘과 동일하게 고정
                  SizedBox(
                    width: 18,
                    height: 22,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        Positioned(
                          top: 0,
                          child: Icon(
                            panelLevel < 2 ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            size: 16,
                            color: color,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          child: Icon(
                            panelLevel == 0 ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            size: 16,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 상단이 오목한 칩 Painter
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
    path.quadraticBezierTo(0, 0, 0, r);
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, r);
    path.quadraticBezierTo(size.width, 0, size.width - r, 0);
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

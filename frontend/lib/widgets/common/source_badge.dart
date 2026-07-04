import 'package:flutter/material.dart';

/// 요약/퀴즈를 담은 메모의 '출처 배지' 아이콘.
/// 앱의 리마인드/네비 아이콘과 동일 계열로 통일한다:
///   - 요약(summary): 별셋(Icons.auto_awesome)
///   - 퀴즈(quiz)   : 전구 + 소문자 q(Icons.lightbulb + 'q')
/// [color]는 배지 원 배경색(테마색). 퀴즈의 q는 흰 전구 위에 이 색으로 찍어 대비를 준다.
Widget sourceKindBadgeChild(String sourceKind, Color color, {double size = 11}) {
  if (sourceKind == 'summary') {
    return Icon(Icons.auto_awesome, size: size * 0.9, color: Colors.white);
  }
  // quiz — 전구 안에 q (색은 반전: 흰 전구 + 배지색 q → 배지 원 위에서도 잘 보임)
  return SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.lightbulb, size: size, color: Colors.white),
        Positioned(
          top: size * 0.12,
          child: Text(
            'q',
            style: TextStyle(
              fontSize: size * 0.55,
              height: 1.0,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}

/// 공유/스냅샷 등 단일 아이콘만 쓰는 곳의 요약/퀴즈 아이콘.
IconData sourceKindBadgeIcon(String sourceKind) =>
    sourceKind == 'summary' ? Icons.auto_awesome : Icons.lightbulb;

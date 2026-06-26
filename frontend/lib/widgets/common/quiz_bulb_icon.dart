import 'package:flutter/material.dart';

/// 꽉 찬 전구(lightbulb) 안에 흰색 소문자 'q'를 올린 퀴즈 아이콘.
///
/// 파일 리스트·하단 네비(리마인드)·퀴즈 패널 등 "퀴즈"를 가리키는 모든 곳에서
/// 동일한 모양을 쓰기 위한 공통 위젯이다.
/// (외곽선 전구 위에 글자를 겹치면 전구선과 섞여 깨져 보여, 채운 전구 + 흰 q로 또렷하게)
///
/// [size]/[color]를 지정하지 않으면 주변 [IconTheme]을 상속한다.
/// → [BottomNavigationBar]·탭 제목란처럼 활성/비활성 색을 자동 적용하는 곳에서 그대로 사용 가능.
class QuizBulbIcon extends StatelessWidget {
  final double? size;
  final Color? color;

  const QuizBulbIcon({super.key, this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final double s = size ?? iconTheme.size ?? 24;
    final Color c = color ?? iconTheme.color ?? Colors.grey;

    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.lightbulb, size: s, color: c),
          // 전구 유리(위쪽 둥근 부분) 중앙에 흰 q — 살짝 위로 올려 또렷하게
          Positioned(
            top: s * 0.07,
            child: Text(
              'q',
              style: TextStyle(
                fontSize: s * 0.5,
                height: 1.0,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

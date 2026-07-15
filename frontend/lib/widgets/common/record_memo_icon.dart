import 'package:flutter/material.dart';

/// 녹음(마이크) + 메모(≡)가 한 아이콘에 함께 있는 "녹음 메모" 합성 아이콘.
///
/// 기존의 사람 말하기(Icons.record_voice_over) 아이콘 대신, 녹음과 메모가
/// 동시에 추가됨을 시각적으로 나타내기 위해 "녹음 메모"를 가리키는 모든 곳
/// (생성 칩·탭 제목·카운트·필터 칩·설정·다이얼로그 등)에서 공통으로 쓴다.
///
/// [size]/[color]를 지정하지 않으면 주변 [IconTheme]을 상속한다.
/// → 탭 제목란·BottomNavigationBar처럼 활성/비활성 색을 자동 적용하는 곳에서
///    그대로 사용 가능(퀴즈 아이콘 [QuizBulbIcon]과 동일한 사용법).
///
/// 마이크(좌상단, 약간 크게)와 메모(우하단)를 겹쳐 두되, 겹치는 부분의 메모는
/// [BlendMode.clear]로 잘라내(구멍) 두 글리프가 배경색과 무관하게 또렷이 분리된다.
class RecordMemoIcon extends StatelessWidget {
  final double? size;
  final Color? color;

  const RecordMemoIcon({super.key, this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final double s = size ?? iconTheme.size ?? 24;
    final Color c = color ?? iconTheme.color ?? Colors.grey;

    return SizedBox(
      width: s,
      height: s,
      child: CustomPaint(
        painter: _RecordMemoPainter(
          color: c,
          // 마이크는 조금 크게, 메모는 그보다 작게.
          micSize: s * 0.82,
          memoSize: s * 0.64,
        ),
      ),
    );
  }
}

class _RecordMemoPainter extends CustomPainter {
  final Color color;
  final double micSize;
  final double memoSize;

  _RecordMemoPainter({
    required this.color,
    required this.micSize,
    required this.memoSize,
  });

  TextPainter _glyph(IconData icon, double fontSize, Color c) {
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: fontSize,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: c,
        ),
      ),
    );
    tp.layout();
    return tp;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;

    final mic = _glyph(Icons.mic, micSize, color);
    final memo = _glyph(Icons.notes, memoSize, color);
    // 겹침 제거용 마이크 마스크 — 실제 마이크와 거의 같은 크기(아주 얇은 간격만).
    // 마이크에 '가려진' 메모 부분만 잘라내고, 나머지 메모는 그대로 보이게 한다.
    final micMask = _glyph(Icons.mic, micSize * 1.1, color);

    // 마이크: 좌상단. 메모: 우하단.
    final micOffset = Offset(0, 0);
    final memoOffset = Offset(size.width - memo.width, size.height - memo.height);
    final micMaskOffset = Offset(
      micOffset.dx - (micMask.width - mic.width) / 2,
      micOffset.dy - (micMask.height - mic.height) / 2,
    );

    // 1) 메모를 그리고, 마이크(+여백) 모양만큼만 구멍을 뚫는다.
    //    dstOut: 마스크(마이크)가 '그려진 부분만' 메모에서 제거(메모 전체가 아님).
    canvas.saveLayer(bounds, Paint());
    memo.paint(canvas, memoOffset);
    final erase = Paint()..blendMode = BlendMode.dstOut;
    canvas.saveLayer(bounds, erase);
    micMask.paint(canvas, micMaskOffset);
    canvas.restore();
    canvas.restore();

    // 2) 실제 마이크를 그 위에 그린다.
    mic.paint(canvas, micOffset);
  }

  @override
  bool shouldRepaint(_RecordMemoPainter old) =>
      old.color != color ||
      old.micSize != micSize ||
      old.memoSize != memoSize;
}

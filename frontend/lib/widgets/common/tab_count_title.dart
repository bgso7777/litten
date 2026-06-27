import 'package:flutter/material.dart';

/// 탭 제목란에 표시할 카운트 요소 하나 (아이콘 + 숫자).
class TabCount {
  final IconData icon;
  final int count;

  /// 지정하지 않으면 부모 [IconTheme]/[DefaultTextStyle] 색을 상속한다.
  /// (DraggableTabLayout의 customTabWidget은 활성/비활성 색을 자동 적용)
  final Color? color;

  /// 지정하면 [icon] 대신 이 위젯을 아이콘으로 사용한다.
  /// (예: 전구+q 합성 퀴즈 아이콘처럼 단일 [IconData]로 표현 불가한 경우)
  final Widget? iconWidget;

  /// 지정하면 이 요소(아이콘+숫자)를 탭할 수 있다(필터 토글 등).
  final VoidCallback? onTap;

  /// false면 비활성(필터 꺼짐)으로 흐리게 표시한다.
  final bool active;

  const TabCount(this.icon, this.count,
      {this.color, this.iconWidget, this.onTap, this.active = true});
}

/// 탭 제목란용 "아이콘+카운트" 가로 배열 위젯.
///
/// DraggableTabLayout의 [TabItem.customTabWidget]으로 사용한다.
/// 부모가 IconTheme/DefaultTextStyle을 적용하므로 색을 지정하지 않으면
/// 활성/비활성 색을 그대로 상속한다.
///
/// [groups]의 각 그룹 내부 요소는 좁은 간격으로 나열되고,
/// 그룹과 그룹 사이에는 [separator](기본 '/')가 들어간다.
///   - 홈:       groups = [[일정, 퀴즈, 공유한것, 공유받은것]]            (구분자 없음)
///   - 퀴즈: groups = [[신규, 확인], [전체]]                              (… / 전체)
///   - 캘린더:   groups = [[도래할], [전체]]                                  (도래할 / 전체)
class TabCountTitle extends StatelessWidget {
  final List<List<TabCount>> groups;
  final String separator;

  const TabCountTitle(this.groups, {super.key, this.separator = '/'});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    for (var g = 0; g < groups.length; g++) {
      if (g > 0) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            separator,
            style: const TextStyle(fontWeight: FontWeight.w400),
          ),
        ));
      }
      final group = groups[g];
      for (var i = 0; i < group.length; i++) {
        if (i > 0) children.add(const SizedBox(width: 11));
        children.add(_buildItem(context, group[i]));
      }
    }

    // 폭이 좁은 기기(폰)에서 넘치지 않도록 자동 축소.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _buildItem(BuildContext context, TabCount c) {
    // 전체탭 제목과 동일하게: 카운트 숫자를 아이콘보다 약간 작게(상속 폰트의 0.8배),
    // 아이콘 하단에 맞추고 아이콘에 바짝 붙인다.
    final countFontSize = (DefaultTextStyle.of(context).style.fontSize ?? 13) * 0.8;
    Widget item = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        c.iconWidget ?? Icon(c.icon, color: c.color),
        const SizedBox(width: 2),
        Text('${c.count}', style: TextStyle(fontSize: countFontSize)),
      ],
    );
    // 비활성(필터 꺼짐)이면 흐리게.
    if (!c.active) {
      item = Opacity(opacity: 0.35, child: item);
    }
    if (c.onTap != null) {
      item = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: c.onTap,
        child: item,
      );
    }
    return item;
  }
}

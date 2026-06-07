import 'package:flutter/material.dart';

/// 탭 제목란에 표시할 카운트 요소 하나 (아이콘 + 숫자).
class TabCount {
  final IconData icon;
  final int count;

  /// 지정하지 않으면 부모 [IconTheme]/[DefaultTextStyle] 색을 상속한다.
  /// (DraggableTabLayout의 customTabWidget은 활성/비활성 색을 자동 적용)
  final Color? color;

  const TabCount(this.icon, this.count, {this.color});
}

/// 탭 제목란용 "아이콘+카운트" 가로 배열 위젯.
///
/// DraggableTabLayout의 [TabItem.customTabWidget]으로 사용한다.
/// 부모가 IconTheme/DefaultTextStyle을 적용하므로 색을 지정하지 않으면
/// 활성/비활성 색을 그대로 상속한다.
///
/// [groups]의 각 그룹 내부 요소는 좁은 간격으로 나열되고,
/// 그룹과 그룹 사이에는 [separator](기본 '/')가 들어간다.
///   - 홈:       groups = [[일정, 리마인드, 공유한것, 공유받은것]]            (구분자 없음)
///   - 리마인드: groups = [[신규, 확인], [전체]]                              (… / 전체)
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
        children.add(_buildItem(group[i]));
      }
    }

    // 폭이 좁은 기기(폰)에서 넘치지 않도록 자동 축소.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _buildItem(TabCount c) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(c.icon, color: c.color),
        const SizedBox(width: 4),
        Text('${c.count}'),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

/// 탭 제목란용 compact 검색 필드.
/// 전체탭 제목 검색바(_AllTabTitleSearch)와 동일한 크기·스타일을 공유해
/// 셀·리마인드 등 다른 탭제목에서도 재사용한다.
///
/// 상태(검색어)는 상위(Provider 등)가 소유하고, 이 위젯은 [initialValue]로 초기값을
/// 받아 [onChanged]로만 통지한다(단일 출처 유지).
class TabTitleSearchField extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;
  final double width;

  const TabTitleSearchField({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.width = 180,
  });

  @override
  State<TabTitleSearchField> createState() => _TabTitleSearchFieldState();
}

class _TabTitleSearchFieldState extends State<TabTitleSearchField> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final l10n = AppLocalizations.of(context);
    // 하단 생성 칩 알약과 동일한 크기·스타일(radius 20, 테두리 alpha0.2, 바탕 alpha0.15, 아이콘16, 폰트13, 세로패딩3).
    return SizedBox(
      width: widget.width,
      height: 28,
      child: TextField(
        controller: _c,
        onChanged: (v) {
          widget.onChanged(v);
          setState(() {}); // 지우기 버튼 갱신
        },
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          isDense: true,
          hintText: l10n?.enterSearchTerm ?? '검색어를 입력하세요...',
          hintStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
          prefixIcon: Icon(Icons.search, size: 16, color: primary),
          prefixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 24),
          suffixIcon: _c.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _c.clear();
                    widget.onChanged('');
                    FocusScope.of(context).unfocus();
                    setState(() {});
                  },
                  child: const Icon(Icons.close, size: 14),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          contentPadding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
          filled: true,
          fillColor: primary.withValues(alpha: 0.15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: primary.withValues(alpha: 0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: primary.withValues(alpha: 0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: primary, width: 1),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/remind_item.dart';

/// AI 요약 텍스트에서 "─── 📌 리마인드 ───" 섹션을 파싱해 RemindItem 목록으로 변환
class RemindParser {
  static const _sectionMarker = '─── 📌 리마인드 ───';

  /// 요약 응답 첫 줄의 "콘텐츠 유형: [기타]" 패턴에서 유형 추출
  static String? _extractContentType(String summaryText) {
    final regex = RegExp(r'콘텐츠\s*유형\s*:\s*\[?([^\]\n]+)\]?');
    final match = regex.firstMatch(summaryText);
    if (match != null) {
      final type = match.group(1)?.trim();
      if (type != null && type.isNotEmpty) {
        // "(자동 감지)" 같은 부가 텍스트 제거
        return type.replaceAll(RegExp(r'\s*\([^)]*\)\s*'), '').trim();
      }
    }
    return null;
  }

  /// 라인 시작의 [유형] prefix 제거 (예: "[액션] 작업명" → "작업명")
  static String _stripCategoryPrefix(String text) {
    return text.replaceFirst(RegExp(r'^\s*\[[^\]]+\]\s*'), '').trim();
  }

  static List<RemindItem> parse({
    required String summaryText,
    required String fileId,
    required String fileName,
    required String littenId,
    RemindFileType fileType = RemindFileType.text,
    int? summaryLevel,
    String? summaryGroupId, // 호출자가 미지정 시 자동 생성 (요약 단위 그룹)
  }) {
    final startIdx = summaryText.indexOf(_sectionMarker);
    if (startIdx == -1) {
      return [];
    }

    final groupId = summaryGroupId ?? const Uuid().v4();
    final contentType = _extractContentType(summaryText);
    // ⭐ 변수명 충돌 회피: 함수 매개변수와 RemindItem 필드 이름이 동일하므로 별도 변수로 분리
    final String fullSummaryText = summaryText;
    debugPrint('[RemindParser] parse 시작 - groupId: $groupId, summaryText length: ${fullSummaryText.length}');

    final section = summaryText.substring(startIdx + _sectionMarker.length);
    final lines = section.split('\n');

    final items = <RemindItem>[];
    String? pendingTitle;
    final detailBuf = StringBuffer();

    void flush() {
      if (pendingTitle == null) return;
      // [유형] prefix는 제거하고 순수 제목만 사용
      final cleanTitle = _stripCategoryPrefix(pendingTitle!);
      // 첫 번째 항목에만 전체 요약 텍스트 저장 (그룹 대표)
      final isFirst = items.isEmpty;
      final stored = isFirst ? fullSummaryText : null;
      debugPrint('[RemindParser] flush - title: $cleanTitle, isFirst: $isFirst, summaryText stored: ${stored != null}');
      items.add(RemindItem(
        fileId: fileId,
        fileType: fileType,
        fileName: fileName,
        littenId: littenId,
        title: cleanTitle,
        content: detailBuf.toString().trim(),
        summaryGroupId: groupId,
        summaryLevel: summaryLevel,
        contentType: contentType,
        summaryText: stored,
      ));
      pendingTitle = null;
      detailBuf.clear();
    }

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('리마인드 총') || line.startsWith('없음')) break;

      if (line.startsWith('📂')) {
        flush();
        // 📂 라인은 항목 그룹 표시일 뿐, 새 구조에서는 무시 (요약 단위 그룹화 사용)
      } else if (line.startsWith('▸')) {
        flush();
        pendingTitle = line.replaceFirst('▸', '').trim();
      } else if (line.startsWith('└')) {
        final detail = line.replaceFirst('└', '').trim();
        if (detailBuf.isNotEmpty) detailBuf.write('\n');
        detailBuf.write(detail);
      }
    }
    flush();

    return items;
  }
}

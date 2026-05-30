/// 백엔드 `/note/v1/summary/process` 응답 모델 (요약 + 리마인드 계층)
class SummaryResult {
  final bool success;
  final String summary;        // 전체 텍스트 (기존 호환)
  final String summaryOnly;    // 리마인드 제거된 순수 요약
  final List<SummarySection> sections;
  final List<RemindGroup> reminds;
  final int totalRemindCount;
  final int? summaryLevel; // 저장/적용된 요약 수준 1~5 (응답에 있으면)
  final String? error;

  const SummaryResult({
    required this.success,
    required this.summary,
    required this.summaryOnly,
    required this.sections,
    required this.reminds,
    required this.totalRemindCount,
    this.summaryLevel,
    this.error,
  });

  /// 표시용 요약 텍스트 — 순수 요약 우선, 없으면 전체
  String get displaySummary => summaryOnly.isNotEmpty ? summaryOnly : summary;

  factory SummaryResult.fromJson(Map<String, dynamic> json) => SummaryResult(
        success: json['success'] as bool? ?? false,
        summary: json['summary'] as String? ?? '',
        summaryOnly: json['summaryOnly'] as String? ?? '',
        sections: ((json['summarySections'] as List?) ?? [])
            .map((e) => SummarySection.fromJson(e as Map<String, dynamic>))
            .toList(),
        reminds: ((json['reminds'] as List?) ?? [])
            .map((e) => RemindGroup.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalRemindCount: (json['totalRemindCount'] as num?)?.toInt() ?? 0,
        summaryLevel: (json['summaryLevel'] as num?)?.toInt(),
        error: json['error'] as String?,
      );
}

class SummarySection {
  final String sectionTitle;
  final String sectionContent;
  const SummarySection({required this.sectionTitle, required this.sectionContent});

  factory SummarySection.fromJson(Map<String, dynamic> json) => SummarySection(
        sectionTitle: json['sectionTitle'] as String? ?? '',
        sectionContent: json['sectionContent'] as String? ?? '',
      );
}

/// 리마인드 1단(그룹)
class RemindGroup {
  final String groupName;
  final List<RemindItem> items;
  const RemindGroup({required this.groupName, required this.items});

  factory RemindGroup.fromJson(Map<String, dynamic> json) => RemindGroup(
        groupName: json['groupName'] as String? ?? '',
        items: ((json['items'] as List?) ?? [])
            .map((e) => RemindItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// 리마인드 2~3단(세부 항목 + 부가설명)
class RemindItem {
  final String type;       // 일정|액션|핵심개념|적용포인트|학습할것|외부대기|리스크|기타
  final String content;
  final String? assignee;
  final String? deadline;
  final List<String> details;
  const RemindItem({
    required this.type,
    required this.content,
    this.assignee,
    this.deadline,
    required this.details,
  });

  factory RemindItem.fromJson(Map<String, dynamic> json) => RemindItem(
        type: json['type'] as String? ?? '기타',
        content: json['content'] as String? ?? '',
        assignee: json['assignee'] as String?,
        deadline: json['deadline'] as String?,
        details: ((json['details'] as List?) ?? []).map((e) => e.toString()).toList(),
      );
}

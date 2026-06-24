/// 백엔드 `/note/v1/summary/process` 응답 모델 (요약 + 퀴즈 계층)
class SummaryResult {
  final bool success;
  final String summary;        // 전체 텍스트 (기존 호환)
  final String summaryOnly;    // 퀴즈 제거된 순수 요약
  final List<SummarySection> sections;
  final List<QuizGroup> quizzes;
  final int totalQuizCount;
  final int? summaryLevel; // 저장/적용된 요약 수준 1~5 (응답에 있으면)
  final String? error;

  const SummaryResult({
    required this.success,
    required this.summary,
    required this.summaryOnly,
    required this.sections,
    required this.quizzes,
    required this.totalQuizCount,
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
        quizzes: ((json['quizzes'] as List?) ?? [])
            .map((e) => QuizGroup.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalQuizCount: (json['totalQuizCount'] as num?)?.toInt() ?? 0,
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

/// 퀴즈 1단(그룹)
class QuizGroup {
  final String groupName;
  final List<QuizItem> items;
  const QuizGroup({required this.groupName, required this.items});

  factory QuizGroup.fromJson(Map<String, dynamic> json) => QuizGroup(
        groupName: json['groupName'] as String? ?? '',
        items: ((json['items'] as List?) ?? [])
            .map((e) => QuizItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// 퀴즈 2~3단(세부 항목 + 부가설명)
class QuizItem {
  final String type;       // 일정|액션|핵심개념|적용포인트|학습할것|외부대기|리스크|기타
  final String content;
  final String? assignee;
  final String? deadline;
  final List<String> details;
  const QuizItem({
    required this.type,
    required this.content,
    this.assignee,
    this.deadline,
    required this.details,
  });

  factory QuizItem.fromJson(Map<String, dynamic> json) => QuizItem(
        type: json['type'] as String? ?? '기타',
        content: json['content'] as String? ?? '',
        assignee: json['assignee'] as String?,
        deadline: json['deadline'] as String?,
        details: ((json['details'] as List?) ?? []).map((e) => e.toString()).toList(),
      );
}

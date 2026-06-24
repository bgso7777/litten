package com.litten.note.summary;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * AI 요약 결과의 각 섹션 (QuizItem과 대응되는 요약 구조체).
 *
 * AI 출력 예:
 *   ## 전체 목적 / 주제
 *   내용...
 *
 *   ## 주요 내용
 *   내용...
 */
@Getter
@Setter
@NoArgsConstructor
public class SummarySection {
    private String sectionTitle;    // 섹션 제목 (## 뒤의 텍스트)
    private String sectionContent;  // 섹션 내용
}

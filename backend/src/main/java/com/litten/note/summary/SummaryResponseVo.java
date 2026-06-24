package com.litten.note.summary;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
public class SummaryResponseVo {
    private boolean success;

    /** note_summary_result PK — 클라이언트가 퀴즈 요청(POST /note/v1/quiz/process)에 사용 */
    private Long summaryResultId;

    /** 실제 적용된 요약 수준 1~5 */
    private int summaryLevel;

    /** AI 응답 전체 텍스트 (요약 + 퀴즈 섹션 포함) - 기존 호환 유지 */
    private String summary;

    /** 퀴즈 구분선 이전의 순수 요약 텍스트만 */
    private String summaryOnly;

    /** 파싱된 요약 섹션 목록 (## 헤더 기준 구조화) */
    private List<SummarySection> summarySections;

    /** 파싱된 퀴즈 그룹 목록 (1단→2단→3단 계층) */
    private List<QuizGroup> quizzes;

    /** 전체 퀴즈 세부항목 수 */
    private int totalQuizCount;

    private String error;

    /**
     * 성공 응답 생성. AI 응답 텍스트를 파싱하여 퀴즈를 구조화한다.
     */
    public static SummaryResponseVo ok(String fullText) {
        return ok(fullText, 0);
    }

    public static SummaryResponseVo ok(String fullText, int summaryLevel) {
        QuizParser.ParseResult result = QuizParser.parse(fullText);

        SummaryResponseVo vo = new SummaryResponseVo();
        vo.success          = true;
        vo.summaryLevel     = summaryLevel;
        vo.summary          = fullText;                  // 원본 전체 텍스트 (기존 호환)
        vo.summaryOnly      = result.getSummaryText();   // 퀴즈 제거된 순수 요약
        vo.summarySections  = result.getSections();      // 요약 섹션 구조화
        vo.quizzes          = result.getGroups();
        vo.totalQuizCount = result.getTotalCount();
        return vo;
    }

    public static SummaryResponseVo fail(String error) {
        SummaryResponseVo vo = new SummaryResponseVo();
        vo.success = false;
        vo.error   = error;
        return vo;
    }
}

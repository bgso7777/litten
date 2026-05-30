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

    /** AI 응답 전체 텍스트 (요약 + 리마인드 섹션 포함) - 기존 호환 유지 */
    private String summary;

    /** 리마인드 구분선 이전의 순수 요약 텍스트만 */
    private String summaryOnly;

    /** 파싱된 요약 섹션 목록 (## 헤더 기준 구조화) */
    private List<SummarySection> summarySections;

    /** 파싱된 리마인드 그룹 목록 (1단→2단→3단 계층) */
    private List<RemindGroup> reminds;

    /** 전체 리마인드 세부항목 수 */
    private int totalRemindCount;

    private String error;

    /**
     * 성공 응답 생성. AI 응답 텍스트를 파싱하여 리마인드를 구조화한다.
     */
    public static SummaryResponseVo ok(String fullText) {
        RemindParser.ParseResult result = RemindParser.parse(fullText);

        SummaryResponseVo vo = new SummaryResponseVo();
        vo.success          = true;
        vo.summary          = fullText;                  // 원본 전체 텍스트 (기존 호환)
        vo.summaryOnly      = result.getSummaryText();   // 리마인드 제거된 순수 요약
        vo.summarySections  = result.getSections();      // 요약 섹션 구조화
        vo.reminds          = result.getGroups();
        vo.totalRemindCount = result.getTotalCount();
        return vo;
    }

    public static SummaryResponseVo fail(String error) {
        SummaryResponseVo vo = new SummaryResponseVo();
        vo.success = false;
        vo.error   = error;
        return vo;
    }
}

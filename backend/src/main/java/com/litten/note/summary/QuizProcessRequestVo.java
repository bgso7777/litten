package com.litten.note.summary;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * 리마인드 생성 요청 VO.
 *
 * remindType → remindLevel 변환은 클라이언트 책임:
 *   ONE=1, THREE=2, FIVE=3, TEN=4, TWENTY=5
 *   CUSTOM → remindLevel=3(기본) + remindCustomCount 를 remindMaxCount override로 전달
 */
@Getter
@Setter
@NoArgsConstructor
public class RemindProcessRequestVo {

    /** 필수 — note_summary_result PK. 원본 텍스트(sourceText) 조회에 사용 */
    private Long summaryResultId;

    /**
     * 리마인드 수준 1~5 (0이면 note_remind_config 기본값=3 사용).
     *   1=핵심 1개, 2=간단 3개, 3=일반 5개, 4=상세 10개, 5=전체 20개
     */
    private int remindLevel;

    /**
     * CUSTOM remindType 대응 — remindMaxCount 직접 지정.
     * null이면 note_remind_config.remind_max_count 사용.
     */
    private Integer remindCustomCount;

    /** 선택 — 리마인드 출력 언어 (null=요약 결과의 언어 사용) */
    private String summaryLanguage;

    /** 선택 — true면 기존 remind 삭제 후 재생성 */
    private boolean forceRegenerate;
}

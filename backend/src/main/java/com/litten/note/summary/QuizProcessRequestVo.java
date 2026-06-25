package com.litten.note.summary;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * 퀴즈 생성 요청 VO.
 *
 * quizType → quizLevel 변환은 클라이언트 책임:
 *   ONE=1, THREE=2, FIVE=3, TEN=4, TWENTY=5
 *   CUSTOM → quizLevel=3(기본) + quizCustomCount 를 quizMaxCount override로 전달
 */
@Getter
@Setter
@NoArgsConstructor
public class QuizProcessRequestVo {

    /**
     * note_summary_result PK. 원본 텍스트(sourceText) 조회에 사용.
     * null이면 요약 없이 퀴즈 생성 모드 — youtubeVideoId + sourceText 로 레코드를 확보한다.
     */
    private Long summaryResultId;

    /** 요약 없이 퀴즈 생성 시 — 유튜브 영상 ID (summaryResultId 없을 때 사용) */
    private String youtubeVideoId;

    /** 요약 없이 퀴즈 생성 시 — 원본 자막/텍스트 (summaryResultId 없을 때 사용) */
    private String sourceText;

    /** 요약 없이 퀴즈 생성 시 — 파일 유형 (기본 youtube) */
    private String fileType;

    /**
     * 퀴즈 수준 1~5 (0이면 note_quiz_config 기본값=3 사용).
     *   1=핵심 1개, 2=간단 3개, 3=일반 5개, 4=상세 10개, 5=전체 20개
     */
    private int quizLevel;

    /**
     * CUSTOM quizType 대응 — quizMaxCount 직접 지정.
     * null이면 note_quiz_config.quiz_max_count 사용.
     */
    private Integer quizCustomCount;

    /** 선택 — 퀴즈 출력 언어 (null=요약 결과의 언어 사용) */
    private String summaryLanguage;

    /** 선택 — true면 기존 quiz 삭제 후 재생성 */
    private boolean forceRegenerate;
}

package com.litten.note.summary;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import lombok.Getter;
import lombok.Setter;

/**
 * 프론트엔드 → 백엔드 요약/리마인드 처리 요청 VO.
 *
 * 필수: fileType
 * YouTube  : fileType="youtube", youtubeVideoId 필수
 * 개인 파일: fileType="text"|"pdf"|"xls"|..., fileUuid + memberUuid 필수
 *
 * summaryLevel, textLanguage, summaryLanguage 는 생략 시
 * note_summary_config 의 기본값을 사용.
 */
@Getter
@Setter
@JsonIgnoreProperties(ignoreUnknown = true)
public class SummaryProcessRequestVo {

    /** 파일 유형 (youtube|text|pdf|xls|doc|ppt|audio|handwriting) - 필수 */
    private String fileType;

    /** 파일 UUID — 개인 파일용 (text/pdf/audio/handwriting) */
    private String fileUuid;

    /** 유튜브 영상 ID — YouTube용 */
    private String youtubeVideoId;

    /** 회원 UUID — 개인 파일용 */
    private String memberUuid;

    /** 요약할 원본 텍스트 (HTML 포함 가능) */
    private String text;

    /** 요약 수준 1~5 (0이면 config 기본값 사용) */
    private int summaryLevel;

    /** 입력 텍스트 언어 (null/blank → config 기본값) */
    private String textLanguage;

    /** 출력 요약 언어 (null/blank → config 기본값) */
    private String summaryLanguage;

    /** 강제 재생성 여부 (true면 DB 캐시 무시하고 AI 재호출) */
    private boolean forceRegenerate;
}

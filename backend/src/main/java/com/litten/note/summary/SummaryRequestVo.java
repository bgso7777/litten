package com.litten.note.summary;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@JsonIgnoreProperties(ignoreUnknown = true)
public class SummaryRequestVo {
    private String text;             // 요약할 텍스트 (HTML 포함 가능)
    private String textLanguage;     // 입력 텍스트의 언어 (기본값: ko)
    private String summaryLanguage;  // 요약 결과 언어 (기본값: ko)
    private int summaryLevel;        // 요약 수준 1~5 (1=한줄요약, 2=간단요약, 3=일반요약, 4=상세요약, 5=거의전체, 기본값: 3)
    private String fileId;           // Flutter 측 TextFile ID (로깅용)

    /**
     * DB에서 조합된 최종 시스템 프롬프트.
     * note_summary_config.system_prompt + note_remind_config.system_prompt
     * NULL이면 OpenAiSummaryService 내 하드코딩 fallback 사용.
     */
    private String systemPrompt;
}

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
    private int summaryRatio;        // 요약 비율 10~90, 10단위 (낮을수록 짧게, 높을수록 상세하게, 기본값: 50)
    private String fileId;           // Flutter 측 TextFile ID (로깅용)
}

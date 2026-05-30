package com.litten.note.summary;

import com.litten.common.dynamic.BaseEntity;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;

/**
 * 요약/리마인드 처리 파라미터 설정 엔티티.
 * 파일 유형(youtube, text, pdf 등)별 AI 모델, 요약 수준, 언어 설정 보관.
 * SummaryController가 file_type으로 이 테이블을 조회하여 처리한다.
 */
@Getter
@Setter
@NoArgsConstructor
@Entity(name = "SummaryConfig")
@Table(name = "note_summary_config",
    uniqueConstraints = @UniqueConstraint(
        name = "unique_file_type_level",
        columnNames = {"file_type", "summary_level"}
    ),
    indexes = {
        @Index(name = "idx_is_active", columnList = "is_active")
    }
)
public class SummaryConfig extends BaseEntity implements Serializable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "sequence", columnDefinition = "BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '설정 PK'")
    private Long sequence;

    @Column(name = "file_type", nullable = false,
            columnDefinition = "VARCHAR(50) NOT NULL COMMENT '파일 유형 (youtube|text|pdf|xls|doc|ppt|audio|handwriting)'")
    private String fileType;

    @Column(name = "config_name", nullable = false,
            columnDefinition = "VARCHAR(100) NOT NULL COMMENT '설정 이름'")
    private String configName;

    @Column(name = "ai_provider", nullable = false,
            columnDefinition = "VARCHAR(20) NOT NULL DEFAULT 'openai' COMMENT 'AI 제공자 (openai|claude)'")
    private String aiProvider = "openai";

    @Column(name = "ai_model",
            columnDefinition = "VARCHAR(100) NULL COMMENT 'AI 모델명 (NULL=서버 기본값)'")
    private String aiModel;

    // ── 요약 파라미터 ────────────────────────────────────────────────────────
    @Column(name = "summary_enabled", nullable = false,
            columnDefinition = "TINYINT(1) NOT NULL DEFAULT 1 COMMENT '요약 활성 여부'")
    private Boolean summaryEnabled = true;

    @Column(name = "summary_level", nullable = false,
            columnDefinition = "TINYINT NOT NULL DEFAULT 3 COMMENT '요약 수준 1~5 (1=한줄/2=간단/3=일반/4=상세/5=전체)'")
    private Integer summaryLevel = 3;

    /** 소스 buildSystemPrompt levelDetail 값 (VERY_SHORT|SHORT|MEDIUM|LONG|FULL) */
    @Column(name = "level_name",
            columnDefinition = "VARCHAR(20) NULL COMMENT '수준 코드명 (VERY_SHORT|SHORT|MEDIUM|LONG|FULL)'")
    private String levelName;

    /** 소스 buildSystemPrompt levelDetail 설명 문자열 */
    @Column(name = "level_description",
            columnDefinition = "VARCHAR(300) NULL COMMENT '수준 설명 (소스 buildSystemPrompt levelDetail)'")
    private String levelDescription;

    /** 소스 computeMaxTokens ratio 값 (0.15|0.30|0.55|0.80|1.10) */
    @Column(name = "level_ratio",
            columnDefinition = "DECIMAL(4,2) NULL COMMENT '토큰 계산 비율 (소스 computeMaxTokens ratio)'")
    private Double levelRatio;

    @Column(name = "text_language", nullable = false,
            columnDefinition = "VARCHAR(10) NOT NULL DEFAULT 'ko' COMMENT '입력 텍스트 언어'")
    private String textLanguage = "ko";

    @Column(name = "summary_language", nullable = false,
            columnDefinition = "VARCHAR(10) NOT NULL DEFAULT 'ko' COMMENT '출력 요약 언어'")
    private String summaryLanguage = "ko";

    @Column(name = "max_tokens",
            columnDefinition = "INT NULL COMMENT '최대 토큰 수 (NULL=서버 기본값)'")
    private Integer maxTokens;

    // ── 공통 ─────────────────────────────────────────────────────────────────
    @Column(name = "is_active", nullable = false,
            columnDefinition = "TINYINT(1) NOT NULL DEFAULT 1 COMMENT '설정 활성 여부'")
    private Boolean isActive = true;

    @Column(name = "description",
            columnDefinition = "VARCHAR(500) NULL COMMENT '설정 설명'")
    private String description;
}

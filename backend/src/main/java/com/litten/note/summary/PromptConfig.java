package com.litten.note.summary;

import com.litten.common.dynamic.BaseEntity;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.*;
import java.io.Serializable;

/**
 * 요약/리마인드 통합 설정 테이블 (note_prompt_config).
 *
 * note_summary_config + note_remind_config + 프롬프트 텍스트를 하나로 통합.
 * type + file_type + level 조합으로 유일하게 식별.
 *
 * type=summary 행: ai_provider, ai_model, max_tokens 사용
 * type=remind  행: remind_max_count, remind_max_group, remind_type_filter 사용
 *
 * 레벨(1~5):
 *   summary: 1=한줄 / 2=간단 / 3=일반 / 4=상세 / 5=전체
 *   remind : 1=핵심1개 / 2=간단3개 / 3=일반5개 / 4=상세10개 / 5=전체20개
 */
@Getter
@Setter
@NoArgsConstructor
@Entity(name = "PromptConfig")
@Table(name = "note_prompt_config",
    uniqueConstraints = @UniqueConstraint(
        name = "unique_type_file_level",
        columnNames = {"type", "file_type", "summary_level"}
    ),
    indexes = {
        @Index(name = "idx_prompt_type_file",  columnList = "type, file_type"),
        @Index(name = "idx_prompt_active",      columnList = "is_active")
    }
)
public class PromptConfig extends BaseEntity implements Serializable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "sequence",
            columnDefinition = "BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '설정 PK'")
    private Long sequence;

    // ── 식별 키 ──────────────────────────────────────────────────────────────
    @Column(name = "type", nullable = false,
            columnDefinition = "VARCHAR(20) NOT NULL COMMENT '유형 (summary|remind)'")
    private String type;

    @Column(name = "file_type", nullable = false,
            columnDefinition = "VARCHAR(50) NOT NULL COMMENT '파일 유형 (text|youtube|audio|pdf 등)'")
    private String fileType;

    /** summary_level 컬럼을 summary/remind 공통 level로 재사용 */
    @Column(name = "summary_level", nullable = false,
            columnDefinition = "TINYINT NOT NULL DEFAULT 3 COMMENT '수준 1~5'")
    private Integer level = 3;

    @Column(name = "level_name",
            columnDefinition = "VARCHAR(20) NULL COMMENT '수준 코드명 (VERY_SHORT|SHORT|MEDIUM|LONG|FULL / ONE|THREE|FIVE|TEN|TWENTY)'")
    private String levelName;

    // ── 프롬프트 ─────────────────────────────────────────────────────────────
    @Column(name = "prompt_name", nullable = false,
            columnDefinition = "VARCHAR(100) NOT NULL COMMENT '설정 이름'")
    private String promptName;

    /**
     * 실제 프롬프트 내용.
     * 사용 가능한 플레이스홀더:
     *   공통  : {{OUTPUT_LANG}}
     *   remind: {{MAX_COUNT}}, {{MAX_GROUP}}, {{TYPE_FILTER}}
     */
    @Lob
    @Column(name = "prompt",
            columnDefinition = "TEXT NULL COMMENT '실제 프롬프트 내용'")
    private String prompt;

    // ── summary 전용 파라미터 ─────────────────────────────────────────────────
    @Column(name = "ai_provider",
            columnDefinition = "VARCHAR(20) NULL DEFAULT 'openai' COMMENT 'AI 제공자 (openai|claude) — summary 전용'")
    private String aiProvider = "openai";

    @Column(name = "ai_model",
            columnDefinition = "VARCHAR(100) NULL COMMENT 'AI 모델명 (NULL=서버 기본값) — summary 전용'")
    private String aiModel;

    @Column(name = "max_tokens",
            columnDefinition = "INT NULL COMMENT '최대 토큰 수 (NULL=서버 기본값) — summary 전용'")
    private Integer maxTokens;

    // ── remind 전용 파라미터 ──────────────────────────────────────────────────
    @Column(name = "remind_max_count",
            columnDefinition = "INT NULL COMMENT '최대 세부항목 수 (NULL=무제한) — remind 전용'")
    private Integer remindMaxCount;

    @Column(name = "remind_max_group",
            columnDefinition = "INT NULL COMMENT '최대 그룹 수 (NULL=무제한) — remind 전용'")
    private Integer remindMaxGroup;

    @Column(name = "remind_type_filter",
            columnDefinition = "VARCHAR(500) NULL COMMENT '유형 필터, 콤마 구분 (NULL=전체) — remind 전용'")
    private String remindTypeFilter;

    // ── 공통 ─────────────────────────────────────────────────────────────────
    @Column(name = "is_active", nullable = false,
            columnDefinition = "TINYINT(1) NOT NULL DEFAULT 1 COMMENT '활성 여부'")
    private Boolean isActive = true;

    @Column(name = "description",
            columnDefinition = "VARCHAR(500) NULL COMMENT '설명'")
    private String description;
}

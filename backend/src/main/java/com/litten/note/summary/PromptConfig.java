package com.litten.note.summary;

import com.litten.common.dynamic.BaseEntity;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.*;
import java.io.Serializable;

/**
 * 프롬프트 관리 테이블 (note_prompt_config).
 *
 * type        : summary | remind
 * prompt_role : system  | user
 * file_type   : youtube | text | pdf | xls | doc | ppt | audio | handwriting
 * summary_level: 1~5 (summary용; remind는 NULL)
 *
 * 예시:
 *   summary / system / youtube / 3  → 유튜브 일반요약 시스템 프롬프트
 *   summary / user   / youtube / 3  → 유튜브 일반요약 유저 프롬프트
 *   remind  / system / youtube / NULL → 유튜브 리마인드 시스템 프롬프트
 *   remind  / user   / youtube / NULL → 유튜브 리마인드 유저 프롬프트
 */
@Getter
@Setter
@NoArgsConstructor
@Entity(name = "PromptConfig")
@Table(name = "note_prompt_config",
    uniqueConstraints = @UniqueConstraint(
        name = "unique_type_role_file_level",
        columnNames = {"type", "prompt_role", "file_type", "summary_level"}
    ),
    indexes = {
        @Index(name = "idx_prompt_type_role_file", columnList = "type, prompt_role, file_type"),
        @Index(name = "idx_prompt_active",         columnList = "is_active")
    }
)
public class PromptConfig extends BaseEntity implements Serializable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "sequence",
            columnDefinition = "BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '설정 PK'")
    private Long sequence;

    @Column(name = "type", nullable = false,
            columnDefinition = "VARCHAR(20) NOT NULL COMMENT '유형 (summary|remind)'")
    private String type;

    @Column(name = "prompt_role", nullable = false,
            columnDefinition = "VARCHAR(20) NOT NULL COMMENT '역할 (system|user)'")
    private String promptRole;

    @Column(name = "file_type", nullable = false,
            columnDefinition = "VARCHAR(50) NOT NULL COMMENT '파일 유형 (youtube|text|pdf|xls|doc|ppt|audio|handwriting)'")
    private String fileType;

    @Column(name = "summary_level",
            columnDefinition = "TINYINT NULL COMMENT '요약 수준 1~5 (summary용; remind는 NULL)'")
    private Integer summaryLevel;

    @Column(name = "prompt_name", nullable = false,
            columnDefinition = "VARCHAR(100) NOT NULL COMMENT '프롬프트 이름'")
    private String promptName;

    /**
     * 실제 프롬프트 내용.
     * system summary: {{LEVEL_DETAIL}}, {{SOURCE_LANG}}, {{OUTPUT_LANG}} 플레이스홀더 사용 가능.
     * NULL이면 소스 코드 hardcoded fallback 사용.
     */
    @Lob
    @Column(name = "prompt",
            columnDefinition = "TEXT NULL COMMENT '실제 프롬프트 내용. 플레이스홀더: {{LEVEL_DETAIL}} {{SOURCE_LANG}} {{OUTPUT_LANG}}'")
    private String prompt;

    @Column(name = "is_active", nullable = false,
            columnDefinition = "TINYINT(1) NOT NULL DEFAULT 1 COMMENT '활성 여부'")
    private Boolean isActive = true;

    @Column(name = "description",
            columnDefinition = "VARCHAR(500) NULL COMMENT '설명'")
    private String description;
}

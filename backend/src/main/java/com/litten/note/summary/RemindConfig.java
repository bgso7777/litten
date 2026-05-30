package com.litten.note.summary;

import com.litten.common.dynamic.BaseEntity;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.*;
import java.io.Serializable;

/**
 * 리마인드 처리 파라미터 설정 엔티티 (note_remind_config).
 * note_summary_config 와 file_type 으로 1:1 대응.
 *
 * 리마인드 관련 파라미터만 별도 관리:
 *   - 활성 여부
 *   - 최대 추출 항목 수
 *   - 추출 유형 필터
 *   - 최대 그룹 수
 */
@Getter
@Setter
@NoArgsConstructor
@Entity(name = "RemindConfig")
@Table(name = "note_remind_config", indexes = {
    @Index(name = "idx_remind_cfg_active", columnList = "is_active")
})
public class RemindConfig extends BaseEntity implements Serializable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "sequence",
            columnDefinition = "BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '설정 PK'")
    private Long sequence;

    @Column(name = "file_type", nullable = false, unique = true,
            columnDefinition = "VARCHAR(50) NOT NULL COMMENT '파일 유형 (note_summary_config.file_type 과 동일)'")
    private String fileType;

    @Column(name = "config_name", nullable = false,
            columnDefinition = "VARCHAR(100) NOT NULL COMMENT '설정 이름'")
    private String configName;

    // ── 리마인드 파라미터 ────────────────────────────────────────────────────
    @Column(name = "remind_enabled", nullable = false,
            columnDefinition = "TINYINT(1) NOT NULL DEFAULT 1 COMMENT '리마인드 추출 활성 여부'")
    private Boolean remindEnabled = true;

    @Column(name = "remind_max_count",
            columnDefinition = "INT NULL COMMENT '최대 리마인드 세부항목 수 (NULL=무제한)'")
    private Integer remindMaxCount;

    @Column(name = "remind_max_group",
            columnDefinition = "INT NULL COMMENT '최대 그룹(1단) 수 (NULL=무제한, 기본 AI 권장 2~5개)'")
    private Integer remindMaxGroup;

    @Column(name = "remind_type_filter",
            columnDefinition = "VARCHAR(500) NULL COMMENT '추출 유형 필터, 콤마 구분 (NULL=전체). 예: 일정,액션,핵심개념,적용포인트,학습할것,외부대기,리스크,기타'")
    private String remindTypeFilter;

    // ── 공통 ─────────────────────────────────────────────────────────────────
    @Column(name = "is_active", nullable = false,
            columnDefinition = "TINYINT(1) NOT NULL DEFAULT 1 COMMENT '설정 활성 여부'")
    private Boolean isActive = true;

    @Column(name = "description",
            columnDefinition = "VARCHAR(500) NULL COMMENT '설정 설명'")
    private String description;
}

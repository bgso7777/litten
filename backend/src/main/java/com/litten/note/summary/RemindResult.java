package com.litten.note.summary;

import com.litten.common.dynamic.BaseEntity;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.*;
import java.io.Serializable;

/**
 * 리마인드 결과 엔티티 — 1 RemindItem = 1 행.
 *
 * 계층 구조:
 *   1단 group_name  → 여러 RemindResult 를 group_order 로 묶음
 *   2단 item_*      → 세부항목 (유형/내용/담당자/기한)
 *   3단 detail_text → 부가 설명 (여러 줄은 \n 구분)
 *
 * summary_result_id 로 note_summary_result 와 연결.
 */
@Getter
@Setter
@NoArgsConstructor
@Entity(name = "RemindResult")
@Table(name = "note_remind_result", indexes = {
    @Index(name = "idx_remind_result_summary", columnList = "summary_result_id"),
    @Index(name = "idx_remind_result_group",   columnList = "summary_result_id, group_order, sort_order")
})
public class RemindResult extends BaseEntity implements Serializable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "sequence",
            columnDefinition = "BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '결과 PK'")
    private Long sequence;

    // ── 상위 요약 연결 ────────────────────────────────────────────────────────
    @Column(name = "summary_result_id", nullable = false,
            columnDefinition = "BIGINT(20) NOT NULL COMMENT 'note_summary_result FK'")
    private Long summaryResultId;

    // ── 1단: 그룹 ─────────────────────────────────────────────────────────────
    @Column(name = "group_name", nullable = false,
            columnDefinition = "VARCHAR(200) NOT NULL COMMENT '1단 그룹명'")
    private String groupName;

    @Column(name = "group_order", nullable = false,
            columnDefinition = "INT NOT NULL DEFAULT 0 COMMENT '그룹 정렬 순서'")
    private Integer groupOrder = 0;

    // ── 2단: 세부항목 ─────────────────────────────────────────────────────────
    @Column(name = "item_type", nullable = false,
            columnDefinition = "VARCHAR(50) NOT NULL COMMENT '2단 유형 (일정|액션|핵심개념|적용포인트|학습할것|외부대기|리스크|기타)'")
    private String itemType;

    @Lob
    @Column(name = "item_content", nullable = false,
            columnDefinition = "TEXT NOT NULL COMMENT '2단 세부항목 내용'")
    private String itemContent;

    @Column(name = "assignee",
            columnDefinition = "VARCHAR(100) NULL COMMENT '담당자 (없으면 -)'")
    private String assignee;

    @Column(name = "deadline",
            columnDefinition = "VARCHAR(100) NULL COMMENT '기한 (없으면 -)'")
    private String deadline;

    // ── 3단: 부가 설명 ────────────────────────────────────────────────────────
    @Lob
    @Column(name = "detail_text",
            columnDefinition = "TEXT NULL COMMENT '3단 부가 설명 (여러 줄은 \\n 구분)'")
    private String detailText;

    // ── 정렬/삭제 ─────────────────────────────────────────────────────────────
    @Column(name = "sort_order", nullable = false,
            columnDefinition = "INT NOT NULL DEFAULT 0 COMMENT '그룹 내 항목 정렬 순서'")
    private Integer sortOrder = 0;

    @Column(name = "is_deleted", nullable = false,
            columnDefinition = "TINYINT(1) NOT NULL DEFAULT 0 COMMENT '삭제 여부'")
    private Boolean isDeleted = false;
}

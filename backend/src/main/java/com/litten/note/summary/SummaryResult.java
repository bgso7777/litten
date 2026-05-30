package com.litten.note.summary;

import com.litten.common.dynamic.BaseEntity;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.*;
import java.io.Serializable;
import java.time.LocalDateTime;

/**
 * 파일별 요약/리마인드 처리 결과 엔티티.
 *
 * YouTube : is_shared=true, youtube_video_id 기준 1건 → 공통 사용
 * 개인 파일: is_shared=false, fileUuid + memberUuid 기준
 *
 * 처리 흐름:
 *   1) note_summary_config 에서 file_type 기준 파라미터 조회
 *   2) AI 요약/리마인드 생성
 *   3) 이 테이블에 결과 저장
 *   4) YouTube 는 다음 요청부터 DB 조회로 반환 (재생성 없음)
 */
@Getter
@Setter
@NoArgsConstructor
@Entity(name = "SummaryResult")
@Table(name = "note_summary_result", indexes = {
    @Index(name = "idx_file_type_status", columnList = "file_type, status"),
    @Index(name = "idx_member_uuid",      columnList = "member_uuid"),
    @Index(name = "idx_is_shared",        columnList = "is_shared"),
    @Index(name = "idx_config_id",        columnList = "config_id")
})
public class SummaryResult extends BaseEntity implements Serializable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "sequence", columnDefinition = "BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '결과 PK'")
    private Long sequence;

    // ── 파라미터 연결 ───────────────────────────────────────────────
    @Column(name = "config_id", nullable = false,
            columnDefinition = "BIGINT(20) NOT NULL COMMENT 'note_summary_config FK'")
    private Long configId;

    // ── 파일 식별 ───────────────────────────────────────────────────
    @Column(name = "file_type", nullable = false,
            columnDefinition = "VARCHAR(50) NOT NULL COMMENT '파일 유형'")
    private String fileType;

    @Column(name = "file_uuid",
            columnDefinition = "VARCHAR(64) NULL COMMENT '파일 UUID (text/handwriting/audio용)'")
    private String fileUuid;

    @Column(name = "youtube_video_id", unique = true,
            columnDefinition = "VARCHAR(50) NULL COMMENT '유튜브 영상 ID'")
    private String youtubeVideoId;

    @Column(name = "member_uuid",
            columnDefinition = "VARCHAR(64) NULL COMMENT '회원 UUID (개인 파일; 공유=NULL)'")
    private String memberUuid;

    @Column(name = "is_shared", nullable = false,
            columnDefinition = "TINYINT(1) NOT NULL DEFAULT 0 COMMENT '공유 여부 (1=공통/유튜브, 0=개인)'")
    private Boolean isShared = false;

    // ── 원본 텍스트 ─────────────────────────────────────────────────
    @Lob
    @Column(name = "source_text",
            columnDefinition = "LONGTEXT NULL COMMENT '원본 텍스트 (자막/OCR/STT 결과)'")
    private String sourceText;

    // ── 요약 결과 ───────────────────────────────────────────────────
    @Lob
    @Column(name = "summary_full",
            columnDefinition = "LONGTEXT NULL COMMENT 'AI 응답 전체 텍스트 (요약+리마인드)'")
    private String summaryFull;

    @Lob
    @Column(name = "summary_only",
            columnDefinition = "LONGTEXT NULL COMMENT '순수 요약 텍스트 (리마인드 구분선 이전)'")
    private String summaryOnly;

    // ── 리마인드 집계 (상세는 note_remind_result 별도 테이블) ───────
    @Column(name = "total_remind_count", nullable = false,
            columnDefinition = "INT NOT NULL DEFAULT 0 COMMENT '리마인드 총 세부항목 수 (빠른 조회용)'")
    private Integer totalRemindCount = 0;

    // ── 처리 상태 ───────────────────────────────────────────────────
    @Column(name = "status", nullable = false,
            columnDefinition = "VARCHAR(20) NOT NULL DEFAULT 'pending' COMMENT '처리 상태 (pending|done|error)'")
    private String status = "pending";

    @Column(name = "error_message",
            columnDefinition = "VARCHAR(1024) NULL COMMENT '오류 메시지'")
    private String errorMessage;

    @Column(name = "processed_at",
            columnDefinition = "TIMESTAMP NULL COMMENT '처리 완료일시'")
    private LocalDateTime processedAt;

    // ── 삭제 ────────────────────────────────────────────────────────
    @Column(name = "is_deleted", nullable = false,
            columnDefinition = "TINYINT(1) NOT NULL DEFAULT 0 COMMENT '삭제 여부'")
    private Boolean isDeleted = false;

    @Column(name = "deleted_date_time",
            columnDefinition = "TIMESTAMP NULL COMMENT '삭제 일시'")
    private LocalDateTime deletedDateTime;
}

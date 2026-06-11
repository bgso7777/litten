package com.litten.note.sync;

import com.litten.common.dynamic.BaseEntity;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.*;
import java.io.Serializable;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;

/**
 * 캘린더 일정 엔티티 (note_schedule).
 *
 * 캘린더를 "로그인 기준 독립 기능"으로 분리하기 위한 일정 전용 테이블.
 *   - 비로그인: 프론트 로컬에만 저장 (서버 미반영)
 *   - 로그인: 이 테이블에 회원 단위로 저장/동기화 (프리미엄 파일 동기화와 분리)
 *
 * 일정은 리튼당 0..1개 → (member_id, litten_id) UNIQUE.
 * 충돌 해결은 client_updated_at 기준 LWW, 삭제는 is_deleted/deleted_at tombstone
 * (note_litten 과 동일 규칙). title 은 캘린더 표시용 비정규화 컬럼.
 */
@Getter
@Setter
@NoArgsConstructor
@Entity(name = "NoteSchedule")
@Table(name = "note_schedule",
    uniqueConstraints = @UniqueConstraint(
        name = "uk_schedule_member_litten",
        columnNames = {"member_id", "litten_id"}
    ),
    indexes = {
        @Index(name = "idx_schedule_member", columnList = "member_id, is_deleted"),
        @Index(name = "idx_schedule_date", columnList = "member_id, schedule_date")
    }
)
public class NoteSchedule extends BaseEntity implements Serializable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id", columnDefinition = "BIGINT NOT NULL AUTO_INCREMENT COMMENT 'PK'")
    private Long id;

    @Column(name = "member_id", nullable = false,
            columnDefinition = "VARCHAR(128) NOT NULL COMMENT '회원 ID'")
    private String memberId;

    @Column(name = "litten_id", nullable = false,
            columnDefinition = "VARCHAR(64) NOT NULL COMMENT '일정이 속한 리튼 UUID'")
    private String littenId;

    @Column(name = "title",
            columnDefinition = "VARCHAR(512) NULL COMMENT '표시용 리튼 제목(비정규화)'")
    private String title;

    @Column(name = "schedule_date", nullable = false,
            columnDefinition = "DATE NOT NULL COMMENT '시작 날짜 (벽시계 기준)'")
    private LocalDate scheduleDate;

    @Column(name = "end_date",
            columnDefinition = "DATE NULL COMMENT '종료 날짜 (null이면 당일)'")
    private LocalDate endDate;

    @Column(name = "start_time", nullable = false,
            columnDefinition = "TIME NOT NULL COMMENT '시작 시각'")
    private LocalTime startTime;

    @Column(name = "end_time", nullable = false,
            columnDefinition = "TIME NOT NULL COMMENT '종료 시각'")
    private LocalTime endTime;

    @Lob
    @Column(name = "notes",
            columnDefinition = "TEXT NULL COMMENT '일정 메모'")
    private String notes;

    /** 알림 규칙 배열(NotificationRule[])을 JSON 문자열로 보관 */
    @Lob
    @Column(name = "notification_rules",
            columnDefinition = "LONGTEXT NULL COMMENT '알림 규칙 JSON 배열'")
    private String notificationRules;

    @Column(name = "notification_start_time",
            columnDefinition = "TIME NULL COMMENT '알림 허용 시작 시각'")
    private LocalTime notificationStartTime;

    @Column(name = "notification_end_time",
            columnDefinition = "TIME NULL COMMENT '알림 허용 종료 시각'")
    private LocalTime notificationEndTime;

    @Column(name = "notification_count", nullable = false,
            columnDefinition = "INT NOT NULL DEFAULT 0 COMMENT '알림 발생 횟수'")
    private Integer notificationCount = 0;

    @Column(name = "schema_version", nullable = false,
            columnDefinition = "INT NOT NULL DEFAULT 2 COMMENT '일정 스키마 버전'")
    private Integer schemaVersion = 2;

    @Column(name = "is_deleted", nullable = false,
            columnDefinition = "TINYINT(1) NOT NULL DEFAULT 0 COMMENT '삭제 여부'")
    private Boolean isDeleted = false;

    @Column(name = "deleted_at",
            columnDefinition = "TIMESTAMP NULL COMMENT '삭제 일시'")
    private LocalDateTime deletedAt;

    @Column(name = "client_updated_at", nullable = false,
            columnDefinition = "TIMESTAMP NOT NULL COMMENT '클라이언트 수정일시 (LWW 기준)'")
    private LocalDateTime clientUpdatedAt;
}

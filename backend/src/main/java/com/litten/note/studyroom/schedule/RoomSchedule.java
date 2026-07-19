package com.litten.note.studyroom.schedule;

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
 * 셀(스터디룸) 일정 엔티티 (note_room_schedule).
 *
 * 개인 일정(note_schedule)과 의도적으로 분리한다.
 *   - note_schedule : 회원 개인 일정. 리튼당 0..1개, (member_id, litten_id) UNIQUE.
 *   - note_room_schedule : 셀에 속한 공유 일정. 셀 하나에 여러 개 가능.
 *
 * 멤버별로 행을 복제하지 않는다. 셀 멤버 자격으로 조회하므로
 *   - 멤버가 셀에서 나가면 그 일정은 자동으로 보이지 않고
 *   - 방장이 수정하면 전원에게 즉시 반영되며
 *   - 멤버의 개인 일정/리튼 무료 할당량을 잠식하지 않는다.
 *
 * 시각 필드는 개인 일정과 동일한 형식(LocalDate/LocalTime)을 써서
 * 프론트가 두 소스를 같은 모델로 합쳐 표시할 수 있게 한다.
 */
@Getter
@Setter
@NoArgsConstructor
@Entity(name = "RoomSchedule")
@Table(name = "note_room_schedule",
    indexes = {
        @Index(name = "idx_room_schedule_room", columnList = "room_id, is_deleted"),
        @Index(name = "idx_room_schedule_date", columnList = "room_id, schedule_date")
    }
)
public class RoomSchedule extends BaseEntity implements Serializable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id", columnDefinition = "BIGINT NOT NULL AUTO_INCREMENT COMMENT 'PK'")
    private Long id;

    /**
     * 일정이 걸린 셀의 종류. 셀 종류마다 실체가 다른 테이블이라 키를 따로 둔다.
     *   group : roomId       (note_study_room)      — 방장/멤버 전원의 캘린더
     *   self  : selfRoomId   (note_self_study_room) — 본인만
     *   user  : peerMemberId (1:1 — 전용 테이블 없음) — 작성자와 상대 둘 다
     */
    @Column(name = "target_type", columnDefinition = "VARCHAR(16) NOT NULL DEFAULT 'group' COMMENT '셀 종류(group/self/user)'")
    private String targetType = "group";

    @Column(name = "room_id", columnDefinition = "BIGINT NULL DEFAULT NULL COMMENT '그룹 셀(룸) ID'")
    private Long roomId;

    @Column(name = "self_room_id", columnDefinition = "BIGINT NULL DEFAULT NULL COMMENT '나만의 셀 ID'")
    private Long selfRoomId;

    @Column(name = "peer_member_id", columnDefinition = "VARCHAR(128) NULL DEFAULT NULL COMMENT '1:1 상대 회원 ID'")
    private String peerMemberId;

    /** 일정을 만든 회원. 방장이 아닌 멤버가 만들 수도 있어 별도 보관한다. */
    @Column(name = "creator_member_id", columnDefinition = "VARCHAR(128) NOT NULL COMMENT '작성자 회원 ID'")
    private String creatorMemberId;

    /** 작성자 표시용 비정규화 컬럼(회원 탈퇴 후에도 캘린더에 이름이 남도록). */
    @Column(name = "creator_name", columnDefinition = "VARCHAR(128) NULL DEFAULT NULL COMMENT '작성자 표시 이름'")
    private String creatorName;

    @Column(name = "title", columnDefinition = "VARCHAR(512) NOT NULL COMMENT '일정 제목'")
    private String title;

    @Column(name = "schedule_date", columnDefinition = "DATE NOT NULL COMMENT '시작일'")
    private LocalDate scheduleDate;

    @Column(name = "end_date", columnDefinition = "DATE NULL DEFAULT NULL COMMENT '종료일'")
    private LocalDate endDate;

    @Column(name = "start_time", columnDefinition = "TIME NOT NULL COMMENT '시작 시각'")
    private LocalTime startTime;

    @Column(name = "end_time", columnDefinition = "TIME NOT NULL COMMENT '종료 시각'")
    private LocalTime endTime;

    @Column(name = "notes", columnDefinition = "TEXT NULL DEFAULT NULL COMMENT '메모'")
    private String notes;

    /** 알림 규칙 JSON 배열 문자열. note_schedule.notification_rules 와 같은 형식(프론트 NotificationRule). */
    @Column(name = "notification_rules", columnDefinition = "LONGTEXT NULL DEFAULT NULL COMMENT '알림 규칙(JSON 배열)'")
    private String notificationRules;

    @Column(name = "notification_start_time", columnDefinition = "TIME NULL DEFAULT NULL COMMENT '알림 허용 시작 시각'")
    private LocalTime notificationStartTime;

    @Column(name = "notification_end_time", columnDefinition = "TIME NULL DEFAULT NULL COMMENT '알림 허용 종료 시각'")
    private LocalTime notificationEndTime;

    /** 캘린더 일정 바 색상 인덱스(AppColors.scheduleColors). 개인 일정과 같은 팔레트를 쓴다. */
    @Column(name = "color_index", columnDefinition = "INT NOT NULL DEFAULT 0 COMMENT '일정 색상 인덱스'")
    private Integer colorIndex = 0;

    @Column(name = "is_deleted", columnDefinition = "TINYINT(1) NOT NULL DEFAULT 0 COMMENT '삭제 여부'")
    private Boolean isDeleted = false;

    @Column(name = "deleted_at", columnDefinition = "TIMESTAMP NULL DEFAULT NULL COMMENT '삭제 일시'")
    private LocalDateTime deletedAt;
}

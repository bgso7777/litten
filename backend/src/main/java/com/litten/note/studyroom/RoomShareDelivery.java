package com.litten.note.studyroom;

import com.litten.common.dynamic.BaseEntity;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.*;
import java.io.Serializable;
import java.time.LocalDateTime;

/** 공유의 수신자별 전달/응답. 공유 1건당 1~N개(룸이면 멤버 수). */
@Getter
@Setter
@Entity(name = "RoomShareDelivery")
@Table(name = "note_room_share_delivery")
@NoArgsConstructor
public class RoomShareDelivery extends BaseEntity implements Serializable {

    public static final String STATUS_PENDING = "pending";
    public static final String STATUS_ACCEPTED = "accepted";
    public static final String STATUS_REJECTED = "rejected";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id", columnDefinition = "BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '전달 ID'")
    private Long id;

    @Column(name = "share_id", columnDefinition = "BIGINT(20) NOT NULL COMMENT '공유 ID'")
    private Long shareId;

    @Column(name = "recipient_member_id", columnDefinition = "VARCHAR(128) NOT NULL COMMENT '수신자 회원 ID'")
    private String recipientMemberId;

    @Column(name = "status", columnDefinition = "VARCHAR(10) NOT NULL DEFAULT 'pending' COMMENT '상태 (pending/accepted/rejected)'")
    private String status = STATUS_PENDING;

    @Column(name = "responded_at", columnDefinition = "TIMESTAMP NULL DEFAULT NULL COMMENT '응답 일시'")
    private LocalDateTime respondedAt;

    @Column(name = "is_deleted", columnDefinition = "TINYINT(1) NOT NULL DEFAULT 0 COMMENT '삭제/취소 여부'")
    private Boolean isDeleted = false;
}

package com.litten.note.studyroom.message;

import com.litten.common.dynamic.BaseEntity;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.*;
import java.io.Serializable;

/** 스터디룸 메시지 1건 — 발신자 + 대상(개인/룸) + 본문. 실제 전달은 RoomMessageDelivery. */
@Getter
@Setter
@Entity(name = "RoomMessage")
@Table(name = "note_room_message")
@NoArgsConstructor
public class RoomMessage extends BaseEntity implements Serializable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id", columnDefinition = "BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '메시지 ID'")
    private Long id;

    @Column(name = "sender_member_id", columnDefinition = "VARCHAR(128) NOT NULL COMMENT '발신자 회원 ID'")
    private String senderMemberId;

    @Column(name = "sender_name", columnDefinition = "VARCHAR(100) NULL DEFAULT NULL COMMENT '발신자 표시 이름(스냅샷)'")
    private String senderName;

    @Column(name = "target_type", columnDefinition = "VARCHAR(10) NOT NULL COMMENT '대상 유형 (user/group)'")
    private String targetType;

    @Column(name = "room_id", columnDefinition = "BIGINT(20) NULL DEFAULT NULL COMMENT '룸 ID(group일 때)'")
    private Long roomId;

    @Column(name = "group_name", columnDefinition = "VARCHAR(100) NULL DEFAULT NULL COMMENT '룸 이름(스냅샷)'")
    private String groupName;

    @Column(name = "content", columnDefinition = "VARCHAR(2000) NOT NULL COMMENT '메시지 내용'")
    private String content;

    @Column(name = "is_deleted", columnDefinition = "TINYINT(1) NOT NULL DEFAULT 0 COMMENT '삭제 여부'")
    private Boolean isDeleted = false;
}

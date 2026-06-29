package com.litten.note.message;

import com.litten.common.dynamic.BaseEntity;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.*;
import java.io.Serializable;

/** 메시지의 수신자별 전달. 메시지 1건당 1~N개(그룹이면 멤버 수). */
@Getter
@Setter
@Entity(name = "NoteMessageDelivery")
@Table(name = "note_message_delivery")
@NoArgsConstructor
public class NoteMessageDelivery extends BaseEntity implements Serializable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id", columnDefinition = "BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '전달 ID'")
    private Long id;

    @Column(name = "message_id", columnDefinition = "BIGINT(20) NOT NULL COMMENT '메시지 ID'")
    private Long messageId;

    @Column(name = "recipient_member_id", columnDefinition = "VARCHAR(128) NOT NULL COMMENT '수신자 회원 ID'")
    private String recipientMemberId;

    @Column(name = "is_deleted", columnDefinition = "TINYINT(1) NOT NULL DEFAULT 0 COMMENT '삭제 여부'")
    private Boolean isDeleted = false;
}

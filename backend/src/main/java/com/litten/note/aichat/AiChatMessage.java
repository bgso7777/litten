package com.litten.note.aichat;

import com.litten.common.dynamic.BaseEntity;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.*;
import java.io.Serializable;

/** 'AI 셀' 대화 메시지 1건. role = 'user'(사용자) 또는 'assistant'(AI). id 오름차순 = 대화 순서. */
@Getter
@Setter
@Entity(name = "AiChatMessage")
@Table(name = "note_ai_chat_message")
@NoArgsConstructor
public class AiChatMessage extends BaseEntity implements Serializable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id", columnDefinition = "BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '메시지 ID'")
    private Long id;

    @Column(name = "chat_id", columnDefinition = "BIGINT(20) NOT NULL COMMENT 'AI 셀 ID'")
    private Long chatId;

    @Column(name = "member_id", columnDefinition = "VARCHAR(128) NOT NULL COMMENT '회원 ID(소유자, 빠른 권한확인용)'")
    private String memberId;

    @Column(name = "role", columnDefinition = "VARCHAR(16) NOT NULL COMMENT 'user 또는 assistant'")
    private String role;

    @Column(name = "content", columnDefinition = "MEDIUMTEXT NOT NULL COMMENT '메시지 내용'")
    private String content;

    @Column(name = "is_deleted", columnDefinition = "TINYINT(1) NOT NULL DEFAULT 0 COMMENT '삭제 여부'")
    private Boolean isDeleted = false;
}

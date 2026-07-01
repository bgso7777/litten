package com.litten.note.selfchat;

import com.litten.common.dynamic.BaseEntity;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.*;
import java.io.Serializable;

/** 셀프 채팅방 항목 — 텍스트 메시지 또는 파일. */
@Getter
@Setter
@Entity(name = "SelfChatItem")
@Table(name = "note_self_chat_item")
@NoArgsConstructor
public class SelfChatItem extends BaseEntity implements Serializable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id", columnDefinition = "BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '항목 ID'")
    private Long id;

    @Column(name = "self_chat_id", columnDefinition = "BIGINT(20) NOT NULL COMMENT '셀프챗 방 ID'")
    private Long selfChatId;

    @Column(name = "member_id", columnDefinition = "VARCHAR(128) NOT NULL COMMENT '회원 ID'")
    private String memberId;

    @Column(name = "item_type", columnDefinition = "VARCHAR(10) NOT NULL COMMENT 'text | file'")
    private String itemType;

    @Column(name = "content", columnDefinition = "VARCHAR(2000) NULL DEFAULT NULL COMMENT '텍스트 내용'")
    private String content;

    @Column(name = "file_name", columnDefinition = "VARCHAR(255) NULL DEFAULT NULL COMMENT '파일명'")
    private String fileName;

    @Column(name = "file_type", columnDefinition = "VARCHAR(20) NULL DEFAULT NULL COMMENT '파일 종류(text/audio/handwriting/attachment 등)'")
    private String fileType;

    @Column(name = "content_type", columnDefinition = "VARCHAR(100) NULL DEFAULT NULL COMMENT 'MIME 타입'")
    private String contentType;

    @Column(name = "file_size", columnDefinition = "BIGINT(20) NULL DEFAULT NULL COMMENT '파일 크기(bytes)'")
    private Long fileSize;

    @Column(name = "stored_path", columnDefinition = "VARCHAR(512) NULL DEFAULT NULL COMMENT '서버 저장 경로'")
    private String storedPath;

    @Column(name = "is_deleted", columnDefinition = "TINYINT(1) NOT NULL DEFAULT 0 COMMENT '삭제 여부'")
    private Boolean isDeleted = false;
}

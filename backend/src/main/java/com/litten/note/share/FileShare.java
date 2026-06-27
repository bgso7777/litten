package com.litten.note.share;

import com.litten.common.dynamic.BaseEntity;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.*;
import java.io.Serializable;
import java.time.LocalDateTime;

/** 파일 공유 1건 — 발신자 + 대상(개인/그룹) + 파일 본문 메타. 실제 전달은 FileShareDelivery. */
@Getter
@Setter
@Entity(name = "FileShare")
@Table(name = "note_file_share")
@NoArgsConstructor
public class FileShare extends BaseEntity implements Serializable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id", columnDefinition = "BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '공유 ID'")
    private Long id;

    @Column(name = "sender_member_id", columnDefinition = "VARCHAR(128) NOT NULL COMMENT '발신자 회원 ID'")
    private String senderMemberId;

    @Column(name = "sender_name", columnDefinition = "VARCHAR(100) NULL DEFAULT NULL COMMENT '발신자 표시 이름(스냅샷)'")
    private String senderName;

    @Column(name = "target_type", columnDefinition = "VARCHAR(10) NOT NULL COMMENT '대상 유형 (user/group)'")
    private String targetType;

    @Column(name = "group_id", columnDefinition = "BIGINT(20) NULL DEFAULT NULL COMMENT '그룹 ID(group일 때)'")
    private Long groupId;

    @Column(name = "group_name", columnDefinition = "VARCHAR(100) NULL DEFAULT NULL COMMENT '그룹 이름(스냅샷)'")
    private String groupName;

    @Column(name = "litten_title", columnDefinition = "VARCHAR(255) NULL DEFAULT NULL COMMENT '원본 리튼 이름(표시용)'")
    private String littenTitle;

    @Column(name = "file_type", columnDefinition = "VARCHAR(20) NOT NULL COMMENT '파일 유형 (text/audio/handwriting/attachment)'")
    private String fileType;

    @Column(name = "file_name", columnDefinition = "VARCHAR(255) NOT NULL COMMENT '파일명'")
    private String fileName;

    @Column(name = "content_type", columnDefinition = "VARCHAR(100) NULL DEFAULT NULL COMMENT 'MIME 타입'")
    private String contentType;

    @Column(name = "file_size", columnDefinition = "BIGINT(20) NULL DEFAULT 0 COMMENT '파일 크기(bytes)'")
    private Long fileSize = 0L;

    @Column(name = "stored_path", columnDefinition = "VARCHAR(512) NULL DEFAULT NULL COMMENT '공유 저장소 경로'")
    private String storedPath;

    @Column(name = "message", columnDefinition = "VARCHAR(500) NULL DEFAULT NULL COMMENT '보낸 메시지'")
    private String message;

    @Column(name = "is_deleted", columnDefinition = "TINYINT(1) NOT NULL DEFAULT 0 COMMENT '삭제/취소 여부'")
    private Boolean isDeleted = false;

    @Column(name = "deleted_at", columnDefinition = "TIMESTAMP NULL DEFAULT NULL COMMENT '삭제/취소 일시'")
    private LocalDateTime deletedAt;
}

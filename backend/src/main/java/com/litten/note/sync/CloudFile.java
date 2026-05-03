package com.litten.note.sync;

import com.litten.common.dynamic.BaseEntity;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.*;
import java.io.Serializable;
import java.time.LocalDateTime;

@Getter
@Setter
@Entity(name = "CloudFile")
@Table(name = "cloud_file")
@NoArgsConstructor
public class CloudFile extends BaseEntity implements Serializable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id", columnDefinition = "BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '파일 ID'")
    private Long id;

    @Column(name = "member_id", columnDefinition = "VARCHAR(128) NOT NULL COMMENT '회원 ID'")
    private String memberId;

    @Column(name = "litten_id", columnDefinition = "VARCHAR(128) NOT NULL COMMENT '리튼 ID'")
    private String littenId;

    @Column(name = "local_id", columnDefinition = "VARCHAR(128) NOT NULL COMMENT '로컬 파일 ID'")
    private String localId;

    @Column(name = "file_type", columnDefinition = "VARCHAR(20) NOT NULL COMMENT '파일 유형 (audio/text/handwriting)'")
    private String fileType;

    @Column(name = "file_name", columnDefinition = "VARCHAR(255) NOT NULL COMMENT '파일명'")
    private String fileName;

    @Column(name = "file_path", columnDefinition = "VARCHAR(512) NULL DEFAULT NULL COMMENT '서버 저장 경로'")
    private String filePath;

    @Column(name = "file_size", columnDefinition = "BIGINT(20) NULL DEFAULT 0 COMMENT '파일 크기(bytes)'")
    private Long fileSize = 0L;

    @Column(name = "content_type", columnDefinition = "VARCHAR(100) NULL DEFAULT NULL COMMENT 'MIME 타입'")
    private String contentType;

    @Column(name = "is_deleted", columnDefinition = "BOOLEAN NOT NULL DEFAULT false COMMENT '삭제 여부'")
    private Boolean isDeleted = false;

    @Column(name = "deleted_at", columnDefinition = "TIMESTAMP NULL DEFAULT NULL COMMENT '삭제 일시'")
    private LocalDateTime deletedAt;

    @Column(name = "local_updated_at", columnDefinition = "TIMESTAMP NOT NULL COMMENT '로컬 파일 수정일시 (동기화 비교용)'")
    private LocalDateTime localUpdatedAt;
}

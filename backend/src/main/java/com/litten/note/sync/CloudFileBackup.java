package com.litten.note.sync;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.*;
import java.io.Serializable;
import java.time.LocalDateTime;

@Getter
@Setter
@Entity(name = "CloudFileBackup")
@Table(name = "cloud_file_backup")
@NoArgsConstructor
public class CloudFileBackup implements Serializable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id", columnDefinition = "BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '백업 ID'")
    private Long id;

    @Column(name = "cloud_file_id", columnDefinition = "BIGINT(20) NOT NULL COMMENT '원본 cloud_file ID'")
    private Long cloudFileId;

    @Column(name = "backup_path", columnDefinition = "VARCHAR(512) NOT NULL COMMENT '백업 파일 경로'")
    private String backupPath;

    @Column(name = "file_size", columnDefinition = "BIGINT(20) NULL DEFAULT 0 COMMENT '백업 파일 크기(bytes)'")
    private Long fileSize = 0L;

    @Column(name = "backed_up_at", columnDefinition = "TIMESTAMP NOT NULL COMMENT '백업 일시'")
    private LocalDateTime backedUpAt;
}

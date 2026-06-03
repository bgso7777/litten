package com.litten.note.sync;

import com.litten.common.dynamic.BaseEntity;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.*;
import java.io.Serializable;
import java.time.LocalDateTime;

/**
 * 리튼(노트 공간) 메타 엔티티 (note_litten).
 *
 * 프리미엄 다기기 동기화용. 파일 바이트는 cloud_file 이 담당하고,
 * 이 테이블은 리튼 컨테이너 메타(제목/설명/일정/파일ID 목록)만 회원 단위로 보관한다.
 *
 * schedule, *FileIds 는 프론트 Litten.toJson 구조 그대로 extra_json(blob)에 보관 →
 * 서버는 파싱하지 않고 통째로 저장/반환한다.
 */
@Getter
@Setter
@NoArgsConstructor
@Entity(name = "Litten")
@Table(name = "note_litten",
    uniqueConstraints = @UniqueConstraint(
        name = "unique_member_litten",
        columnNames = {"member_id", "litten_id"}
    ),
    indexes = {
        @Index(name = "idx_litten_member", columnList = "member_id, is_deleted")
    }
)
public class Litten extends BaseEntity implements Serializable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id", columnDefinition = "BIGINT NOT NULL AUTO_INCREMENT COMMENT 'PK'")
    private Long id;

    @Column(name = "member_id", nullable = false,
            columnDefinition = "VARCHAR(128) NOT NULL COMMENT '회원 ID'")
    private String memberId;

    @Column(name = "litten_id", nullable = false,
            columnDefinition = "VARCHAR(64) NOT NULL COMMENT '클라이언트 생성 리튼 UUID (PK 역할)'")
    private String littenId;

    @Column(name = "title", nullable = false,
            columnDefinition = "VARCHAR(512) NOT NULL COMMENT '리튼 제목'")
    private String title;

    @Lob
    @Column(name = "description",
            columnDefinition = "TEXT NULL COMMENT '리튼 설명'")
    private String description;

    /** 프론트 Litten.toJson 전체를 보관 (schedule, *FileIds, notificationCount 포함) */
    @Lob
    @Column(name = "extra_json",
            columnDefinition = "LONGTEXT NULL COMMENT '리튼 전체 JSON blob (프론트 Litten.toJson)'")
    private String extraJson;

    @Column(name = "client_created_at",
            columnDefinition = "TIMESTAMP NULL COMMENT '클라이언트 생성일시 (createdAt)'")
    private LocalDateTime clientCreatedAt;

    @Column(name = "client_updated_at", nullable = false,
            columnDefinition = "TIMESTAMP NOT NULL COMMENT '클라이언트 수정일시 (updatedAt — 충돌 해결 기준)'")
    private LocalDateTime clientUpdatedAt;

    @Column(name = "is_deleted", nullable = false,
            columnDefinition = "TINYINT(1) NOT NULL DEFAULT 0 COMMENT '삭제 여부'")
    private Boolean isDeleted = false;

    @Column(name = "deleted_at",
            columnDefinition = "TIMESTAMP NULL COMMENT '삭제 일시'")
    private LocalDateTime deletedAt;
}

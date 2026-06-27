package com.litten.note.share;

import com.litten.common.dynamic.BaseEntity;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.*;
import java.io.Serializable;
import java.time.LocalDateTime;

/** 공유 그룹 (소유자 단위). 그룹에 멤버를 넣고 파일을 그룹 전체에 공유한다. */
@Getter
@Setter
@Entity(name = "ShareGroup")
@Table(name = "note_share_group")
@NoArgsConstructor
public class ShareGroup extends BaseEntity implements Serializable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id", columnDefinition = "BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '그룹 ID'")
    private Long id;

    @Column(name = "owner_member_id", columnDefinition = "VARCHAR(128) NOT NULL COMMENT '그룹 소유자 회원 ID'")
    private String ownerMemberId;

    @Column(name = "name", columnDefinition = "VARCHAR(100) NOT NULL COMMENT '그룹 이름'")
    private String name;

    @Column(name = "password", columnDefinition = "VARCHAR(128) NULL DEFAULT NULL COMMENT '그룹 비밀번호'")
    private String password;

    @Column(name = "is_deleted", columnDefinition = "TINYINT(1) NOT NULL DEFAULT 0 COMMENT '삭제 여부'")
    private Boolean isDeleted = false;

    @Column(name = "deleted_at", columnDefinition = "TIMESTAMP NULL DEFAULT NULL COMMENT '삭제 일시'")
    private LocalDateTime deletedAt;
}

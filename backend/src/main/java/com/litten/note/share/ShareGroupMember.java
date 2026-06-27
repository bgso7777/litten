package com.litten.note.share;

import com.litten.common.dynamic.BaseEntity;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.*;
import java.io.Serializable;

/** 공유 그룹 멤버 (수신 대상 회원). */
@Getter
@Setter
@Entity(name = "ShareGroupMember")
@Table(name = "note_share_group_member")
@NoArgsConstructor
public class ShareGroupMember extends BaseEntity implements Serializable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id", columnDefinition = "BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '그룹 멤버 ID'")
    private Long id;

    @Column(name = "group_id", columnDefinition = "BIGINT(20) NOT NULL COMMENT '그룹 ID'")
    private Long groupId;

    @Column(name = "member_id", columnDefinition = "VARCHAR(128) NOT NULL COMMENT '멤버 회원 ID(수신 대상)'")
    private String memberId;

    @Column(name = "member_name", columnDefinition = "VARCHAR(100) NULL DEFAULT NULL COMMENT '표시 이름(스냅샷)'")
    private String memberName;

    @Column(name = "is_deleted", columnDefinition = "TINYINT(1) NOT NULL DEFAULT 0 COMMENT '삭제 여부'")
    private Boolean isDeleted = false;
}

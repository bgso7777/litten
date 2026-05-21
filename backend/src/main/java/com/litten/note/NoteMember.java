package com.litten.note;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.*;
import java.io.Serializable;

@Getter
@Setter
@Entity(name="NoteMember")
@Table(name = "note_member")
@NoArgsConstructor
public class NoteMember extends NoteMemberCommon implements Serializable {

    @Column(name="sequence", columnDefinition="BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '회원sequence'", insertable=false, updatable=false)
    private Long sequence;

    @Id
    @Column(name="id", columnDefinition="VARCHAR(128) NULL DEFAULT NULL COMMENT '계정 id' COLLATE 'utf8mb4_unicode_ci'")
    private String id;

    // 다중 디바이스 로그인 지원 — 최대 3대까지 (uuid는 가입 디바이스 기록용, 로그인 검증은 uuid1/uuid2/uuid3 슬롯으로)
    @Column(name="uuid1", columnDefinition="VARCHAR(64) NULL DEFAULT NULL COMMENT '로그인 디바이스 UUID 1'")
    private String uuid1;

    @Column(name="uuid2", columnDefinition="VARCHAR(64) NULL DEFAULT NULL COMMENT '로그인 디바이스 UUID 2'")
    private String uuid2;

    @Column(name="uuid3", columnDefinition="VARCHAR(64) NULL DEFAULT NULL COMMENT '로그인 디바이스 UUID 3'")
    private String uuid3;
}

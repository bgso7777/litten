package com.litten.common.domain;

import lombok.*;

import javax.persistence.*;
import java.io.Serializable;

@Getter
@Setter
@Entity(name="AdminUser")
@Table(name = "tbl_admin_user")
@NoArgsConstructor
public class AdminUser extends Domain implements Serializable {

    @Id
    @Column(name="pk_admin_user", columnDefinition="BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT 'admin pk'")
    @GeneratedValue(strategy=GenerationType.IDENTITY)
    private Long adminUserId;

    @Column(name="user_id", columnDefinition="VARCHAR(128) NOT NULL COMMENT '로그인id' COLLATE 'utf8mb4_general_ci'")
    private String loginId;

    @Column(name="user_pw", columnDefinition="VARCHAR(128) NOT NULL COMMENT '로그인pw' COLLATE 'utf8mb4_general_ci'")
    private String password;

    @Column(name="role", columnDefinition="VARCHAR(64) NULL DEFAULT NULL COMMENT '권한' COLLATE 'utf8mb4_general_ci'")
    private String role;

    @Column(name="user_name", columnDefinition="VARCHAR(64) NULL DEFAULT NULL COMMENT '표시 이름' COLLATE 'utf8mb4_general_ci'")
    private String name;

    @Column(name="user_level", columnDefinition="INT(11) NOT NULL DEFAULT '11' COMMENT '권한(큰값일수록 더 높은 권한,최대:2,100,000,000)'")
    private Integer level;

    @Column(name="use_yn", columnDefinition="CHAR(1) NULL DEFAULT 'Y' COMMENT '사용 여부 YN' COLLATE 'utf8mb4_unicode_ci'")
    private String useYn;

    @Column(name="user_email", columnDefinition="VARCHAR(200) NULL DEFAULT NULL COMMENT '이메일' COLLATE 'utf8mb4_general_ci'")
    private String email;

    @Column(name="user_mobile", columnDefinition="VARCHAR(20) NULL DEFAULT NULL COMMENT '핸드폰' COLLATE 'utf8mb4_general_ci'")
    private String mobile;

    @Column(name="memo", columnDefinition="VARCHAR(200) NULL DEFAULT NULL COMMENT '메모' COLLATE 'utf8mb4_general_ci'")
    private String memo;

    @Column(name="fk_writer", columnDefinition="BIGINT(20) NULL DEFAULT NULL COMMENT '[직원]등록자 fk'")
    private Long fk_writer; // [직원] 등록자 fk

    @Column(name="fk_modifier", columnDefinition="BIGINT(20) NULL DEFAULT NULL COMMENT '[직원]수정자 fk'")
    private Long fk_modifier; // [직원] 수정자 fk

    @Column(name="uuid", columnDefinition="VARCHAR(64) NULL DEFAULT NULL COMMENT '계정UUDI'")
    private String uuid;
}

package com.litten.note;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.databind.annotation.JsonDeserialize;
import com.fasterxml.jackson.databind.annotation.JsonSerialize;
import com.fasterxml.jackson.datatype.jsr310.deser.LocalDateTimeDeserializer;
import com.fasterxml.jackson.datatype.jsr310.ser.LocalDateTimeSerializer;
import com.litten.common.dynamic.BaseEntity;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import javax.persistence.*;
import java.time.LocalDateTime;

@Getter
@Setter
@Entity(name="NoteMember")
@Table(name="note_member")
@AllArgsConstructor
@NoArgsConstructor
public class NoteMember extends BaseEntity {

    @GeneratedValue(strategy=GenerationType.IDENTITY)
    @Column(name="sequence", columnDefinition="BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '회원sequence'")
    private Integer sequence;

    @Column(name="uuid", columnDefinition="VARCHAR(64) NULL DEFAULT NULL COMMENT '계정UUDI'")
    private String uuid;

    @Id
    @Column(name="id", columnDefinition="VARCHAR(128) NULL DEFAULT NULL COMMENT '계정 id' COLLATE 'utf8mb4_unicode_ci'")
    private String id;

    @Column(name="id_insert_date_time", columnDefinition="TIMESTAMP NULL DEFAULT NULL COMMENT 'ID 등록일시'")
    private LocalDateTime idInsertDateTime;


    @Column(name="password", columnDefinition="VARCHAR(512) NULL DEFAULT NULL COMMENT '직원 pw[단방향]' ")
    private String password;


    @Column(name="is_change_password", columnDefinition="BOOLEAN NOT NULL default 0 COMMENT '패스워드 변경 여부'")
    private Boolean isChangePassword=false;


    @Column(name="change_password_date_time", columnDefinition="TIMESTAMP NULL DEFAULT NULL COMMENT '패스워드 변경 일시'")
    private LocalDateTime changePasswordDateTime;

    @Column(name="name", columnDefinition="VARCHAR(64) NULL DEFAULT NULL COMMENT '이름' ")
    private String name;

    @Column(name="name_english", columnDefinition="VARCHAR(64) NULL DEFAULT NULL COMMENT '이름 영어' ")
    private String nameEnglish;

    @Column(name="mobile", columnDefinition="VARCHAR(64) NULL DEFAULT NULL COMMENT '핸드폰' ")
    private String mobile;

    @Column(name="mobile_type", columnDefinition="VARCHAR(64) NULL DEFAULT NULL COMMENT '핸드폰 통신사' ")
    private String mobileType;

    @Column(name="mobile_verify_date_time", columnDefinition="TIMESTAMP NULL DEFAULT NULL COMMENT '본인인증일시'")
    private LocalDateTime mobileVerifyDateTime;

    @Column(name="email", columnDefinition="VARCHAR(128) NULL DEFAULT NULL COMMENT '이메일' ")
    private String email;

    @Column(name="state_code", columnDefinition="VARCHAR(64) NULL DEFAULT NULL COMMENT '활성화 상태' ")
    private String stateCode;

}

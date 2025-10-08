package com.litten.common.domain;

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
@Entity(name="SampleMemberDomain")
@Table(name="TBL_COMPANY_STAFF")
@AllArgsConstructor
@NoArgsConstructor
public class Member extends BaseEntity {

    @GeneratedValue(strategy=GenerationType.IDENTITY)
    @Column(name="pk_company_staff", columnDefinition="BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '직원 pk'")
    private Integer memberSeq;

    @Column(name="fk_company", columnDefinition="BIGINT(20) NULL DEFAULT NULL COMMENT '회사 fk'")
    private Integer companySeq;

////	@ManyToOne(fetch=FetchType.LAZY)
//    @JsonIgnore
//    @ManyToOne(fetch=FetchType.EAGER)
//    @JoinColumn(name="fk_company", insertable=false, updatable=false, nullable=true, columnDefinition="")
//    private Company company;

    @Id
    @Column(name="fd_staff_id", columnDefinition="VARCHAR(128) NULL DEFAULT NULL COMMENT '직원 id' COLLATE 'utf8mb4_unicode_ci'")
    private String id;

    @JsonIgnore
    @Column(name="fd_staff_pw", columnDefinition="VARCHAR(512) NULL DEFAULT NULL COMMENT '직원 pw[단방향]' COLLATE 'utf8mb4_unicode_ci'")
    private String password;

    @Column(name="fd_staff_email", columnDefinition="VARCHAR(128) NULL DEFAULT NULL COMMENT '직원 이메일' COLLATE 'utf8mb4_unicode_ci'")
    private String email;

//	@Column(name="fk_company")
//	private Long companySeq;
//
////	@ManyToOne(fetch=FetchType.LAZY)
//	@ManyToOne(fetch=FetchType.EAGER)
//	@JoinColumn(name="fk_company" , insertable=false, updatable=false, nullable=true)
//	private Company company;

    @Column(name="fd_staff_name", columnDefinition="VARCHAR(64) NULL DEFAULT NULL COMMENT '직원 이름' COLLATE 'utf8mb4_unicode_ci'")
    private String name;

    @Column(name="fd_staff_name_en", columnDefinition="VARCHAR(64) NULL DEFAULT NULL COMMENT '직원 이름 영어' COLLATE 'utf8mb4_unicode_ci'")
    private String nameEnglish;

    @JsonIgnore
    @Column(name="fd_dnis", columnDefinition="VARCHAR(128) NULL DEFAULT NULL COMMENT '할당번호' COLLATE 'utf8mb4_unicode_ci'")
    private String dnis;

    @JsonIgnore
    @Column(name="fd_staff_mobile", columnDefinition="VARCHAR(64) NULL DEFAULT NULL COMMENT '직원 휴대전화' COLLATE 'utf8mb4_unicode_ci'")
    private String mobile;

    @JsonIgnore
    @Column(name="fd_staff_mobile_type", columnDefinition="VARCHAR(64) NULL DEFAULT NULL COMMENT '직원 휴대전화 통신사' COLLATE 'utf8mb4_unicode_ci'")
    private String mobileType;

    @JsonIgnore
    @Column(name="fd_staff_phone", columnDefinition="VARCHAR(64) NULL DEFAULT NULL COMMENT '직원 일반전화' COLLATE 'utf8mb4_unicode_ci'")
    private String phone;

    @JsonIgnore
    @Column(name="fd_staff_duty", columnDefinition="VARCHAR(64) NULL DEFAULT NULL COMMENT '임무' COLLATE 'utf8mb4_unicode_ci'")
    private String duty;

    @JsonIgnore
    @Column(name="fd_staff_birth", columnDefinition="VARCHAR(16) NULL DEFAULT NULL COMMENT '직원 생년월일' COLLATE 'utf8mb4_unicode_ci'")
    private String birth;

    @JsonIgnore
    @Column(name="fd_staff_gender_mf", columnDefinition="CHAR(1) NULL DEFAULT NULL COMMENT '직원 성별 MF' COLLATE 'utf8mb4_unicode_ci'")
    private String gender;

    @JsonIgnore
    @Column(name="fd_staff_national_yn", columnDefinition="CHAR(1) NULL DEFAULT NULL COMMENT '내국인 여부YN' COLLATE 'utf8mb4_unicode_ci'")
    private String national;

    @JsonIgnore
    @Column(name="fd_address_zipcode", columnDefinition="VARCHAR(64) NULL DEFAULT NULL COMMENT '주소 우편번호' COLLATE 'utf8mb4_unicode_ci'")
    private String zipcode;

    @JsonIgnore
    @Column(name="fd_address_common", columnDefinition="VARCHAR(128) NULL DEFAULT NULL COMMENT '주소 기본' COLLATE 'utf8mb4_unicode_ci'")
    private String addressCommon;

    @JsonIgnore
    @Column(name="fd_address_detail", columnDefinition="VARCHAR(128) NULL DEFAULT NULL COMMENT '주소 상세' COLLATE 'utf8mb4_unicode_ci'")
    private String addressDetail;

    @JsonIgnore
    @Column(name="fd_logo_file_path", columnDefinition="VARCHAR(128) NULL DEFAULT NULL COMMENT '개인심볼(aws path)' COLLATE 'utf8mb4_unicode_ci'")
    private String logoFilePath;

    @Column(name="solution_type", columnDefinition="VARCHAR(10) NOT NULL DEFAULT 'B11' COMMENT '솔루션타입' COLLATE 'utf8mb4_unicode_ci'")
    private String solutionType;

    @Column(name="user_type", columnDefinition="VARCHAR(10) NOT NULL DEFAULT 'B2001' COMMENT '사용자타입' COLLATE 'utf8mb4_unicode_ci'")
    private String userType;

    @Column(name="fd_staff_ai_yn", columnDefinition="CHAR(1) NULL DEFAULT 'N' COMMENT 'AI직원 여부YN' COLLATE 'utf8mb4_unicode_ci'")
    private String ai;

    @Column(name="fd_staff_level_code", columnDefinition="VARCHAR(64) NULL DEFAULT NULL COMMENT '직원 구분 코드' COLLATE 'utf8mb4_unicode_ci'")
    private String levelCode;

    @Column(name="fd_staff_status_code", columnDefinition="VARCHAR(64) NULL DEFAULT NULL COMMENT '직원 계정 상태 코드' COLLATE 'utf8mb4_unicode_ci'")
    private String statusCode;

    @Column(name="fd_staff_response_status_code", columnDefinition="VARCHAR(64) NULL DEFAULT 'A1201' COMMENT '직원 응답 상태 코드' COLLATE 'utf8mb4_unicode_ci'")
    private String responseStatusCode;

    @Column(name="fk_staff_work", columnDefinition="BIGINT(20) NULL DEFAULT NULL COMMENT '담당 직무 fk'")
    private String work;

    @Column(name="fd_company_master_yn", columnDefinition="CHAR(1) NULL DEFAULT 'N' COMMENT '회사 대표직원 여부YN' COLLATE 'utf8mb4_unicode_ci'")
    private String companyMaster;

    @Column(name="fd_default_ai", columnDefinition="CHAR(1) NULL DEFAULT 'N' COMMENT '디폴트 AI직원 (대표 AI직원)' COLLATE 'utf8mb4_unicode_ci'")
    private String defaultAi;

    @Column(name="fd_staff_ai_uid", columnDefinition="VARCHAR(128) NULL DEFAULT NULL COMMENT 'AI직원 uid' COLLATE 'utf8mb4_unicode_ci'")
    private String aiUid;

    @JsonIgnore
    @Column(name="fd_signup_keycode", columnDefinition="VARCHAR(256) NULL DEFAULT NULL COMMENT '직원 가입 초대코드' COLLATE 'utf8mb4_unicode_ci'")
    private String signupKeycode;

    @JsonIgnore
    @Column(name="fd_signup_keycode_ok_yn", columnDefinition="CHAR(1) NULL DEFAULT NULL COMMENT '초대코드 컨펌 여부YN' COLLATE 'utf8mb4_unicode_ci'")
    private String signupKeycodeOk;

    @Column(name="fk_staff_work_code", columnDefinition="VARCHAR(64) NULL DEFAULT NULL COMMENT 'ai직원 담당업무 코드' COLLATE 'utf8mb4_unicode_ci'")
    private String workCode;

    @Column(name="fd_state_code", columnDefinition="VARCHAR(64) NULL DEFAULT NULL COMMENT '직원 활성화 상태' COLLATE 'utf8mb4_unicode_ci'")
    private String stateCode;

    @JsonIgnore
    @Column(name="fd_staff_di", columnDefinition="VARCHAR(128) NULL DEFAULT NULL COMMENT '직원 DI' COLLATE 'utf8mb4_unicode_ci'")
    private String di;

    @JsonIgnore
    @Column(name="fd_staff_ci", columnDefinition="VARCHAR(128) NULL DEFAULT NULL COMMENT '직원 CI' COLLATE 'utf8mb4_unicode_ci'")
    private String ci;

    @JsonIgnore
    @Column(name="fd_staff_persona", columnDefinition="VARCHAR(64) NULL DEFAULT NULL COMMENT 'AI직원 목소리 설정' COLLATE 'utf8mb4_unicode_ci'")
    private String persona;

    @JsonIgnore
    @Column(name="fd_push_noti_yn", columnDefinition="CHAR(1) NULL DEFAULT NULL COMMENT 'push' COLLATE 'utf8mb4_unicode_ci'")
    private String noti;

    @JsonIgnore
    @Column(name="fd_push_token", columnDefinition="VARCHAR(256) NULL DEFAULT NULL COMMENT 'push token' COLLATE 'utf8mb4_unicode_ci'")
    private String pushToken;

    @JsonIgnore
    @JsonSerialize(using= LocalDateTimeSerializer.class)
    @JsonDeserialize(using= LocalDateTimeDeserializer.class)
    @Column(name="fd_signup_keycode_date", columnDefinition="TIMESTAMP NULL DEFAULT NULL COMMENT '직원 가입 초대코드 생성일시'")
    private LocalDateTime signupKeycodeDate;

    @JsonIgnore
    @Column(name="fd_staff_mobile_verify_dt", columnDefinition="DATETIME NULL DEFAULT NULL COMMENT '본인인증일시'")
    private LocalDateTime mobileVerifyDate;

    @JsonIgnore
    @Column(name="fd_login_date", columnDefinition="TIMESTAMP NULL DEFAULT NULL COMMENT '로그인 일시'")
    private LocalDateTime loginDate;

    @JsonIgnore
    @Column(name="fd_sign_up_path_code", columnDefinition="VARCHAR(64) NULL DEFAULT NULL COMMENT '회원 가입 경로'")
    private String signUpPathCode;

    @JsonIgnore
    @Column(name="is_change_password", columnDefinition="BOOLEAN NOT NULL default 0 COMMENT '패스워드 변경 여부'")
    private Boolean isChangePassword=false;

    @JsonIgnore
    @Column(name="change_password_date", columnDefinition="TIMESTAMP NULL DEFAULT NULL COMMENT '패스워드 변경 일시'")
    private LocalDateTime changePasswordDate;

    @Column(name="uuid", columnDefinition="VARCHAR(64) NULL DEFAULT NULL COMMENT '계정UUDI'")
    private String uuid;

}

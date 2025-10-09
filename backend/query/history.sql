CREATE DATABASE litten;


grant all privileges on *.* to 'litten'@'localhost' identified by 'litten1234';

DROP TABLE IF EXISTS `note_member`;
CREATE TABLE `note_member` (
  `sequence` BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '회원pk',
  `uuid` VARCHAR(64) NULL COMMENT '계정UUID',
  `id` VARCHAR(128) NULL COMMENT '회원아이디',
  `password` VARCHAR(512) NULL COMMENT '직원 pw[단방향]',
  `id_insert_date_time` TIMESTAMP NULL DEFAULT NULL COMMENT 'ID 등록일시',
  `is_change_password` TINYINT(1) NOT NULL DEFAULT '0' COMMENT '패스워드 변경 여부',
  `change_password_date_time` TIMESTAMP NULL COMMENT '패스워드 변경 일시',
  `name` VARCHAR(64) NULL COMMENT '직원 이름',
  `name_english` VARCHAR(64) NULL COMMENT '직원 이름 영어',
  `mobile` VARCHAR(64) NULL COMMENT '직원 휴대전화',
  `mobile_type` VARCHAR(64) NULL COMMENT '직원 휴대전화 통신사',
  `mobile_verify_date_time` DATETIME NULL COMMENT '본인인증일시',
  `email` VARCHAR(64) NULL COMMENT '이메일',
  `state_code` VARCHAR(64) NULL COMMENT '활성화 상태',
  `insert_date_time` TIMESTAMP NULL DEFAULT current_timestamp() COMMENT '[직원]등록일시',
  `update_pk` BIGINT(20) NULL COMMENT '[직원]수정자 fk',
  `update_date_time` TIMESTAMP NULL COMMENT '[직원]수정일시',
  `insert_pk` BIGINT(20) NULL COMMENT '[직원]등록자 fk',
	PRIMARY KEY (`sequence`) USING BTREE,
	INDEX `index_of_id` (`id`) USING BTREE,
	INDEX `index_of_uuid` (`uuid`) USING BTREE,  
   INDEX `index_of_mobile` (`mobile`),
   INDEX `index_of_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='회원';



CREATE TABLE `tbl_company_staff` (
	`pk_company_staff` BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '직원 pk',
	`solution_type` VARCHAR(10) NOT NULL DEFAULT B11 COMMENT '솔루션타입' COLLATE 'utf8mb4_general_ci',
	`user_type` VARCHAR(10) NOT NULL DEFAULT B2001 COMMENT '사용자타입' COLLATE 'utf8mb4_general_ci',
	`fd_staff_id` VARCHAR(128) NULL COMMENT '직원 id' COLLATE 'utf8mb4_general_ci',
	`fd_staff_ai_yn` CHAR(1) NULL DEFAULT N COMMENT 'AI직원 여부YN' COLLATE 'utf8mb4_general_ci',
	`fd_staff_level_code` VARCHAR(64) NULL COMMENT '직원 구분 코드' COLLATE 'utf8mb4_general_ci',
	`fd_staff_status_code` VARCHAR(64) NULL COMMENT '직원 계정 상태 코드' COLLATE 'utf8mb4_general_ci',
	`fd_staff_response_status_code` VARCHAR(64) NULL DEFAULT A1201 COMMENT '직원 응답 상태 코드' COLLATE 'utf8mb4_general_ci',
	`auto_response_yn` VARCHAR(1) NULL DEFAULT N COMMENT '손비서 자동 자리비움' COLLATE 'utf8mb4_general_ci',
	`fk_company` BIGINT(20) NULL COMMENT '회사 fk',
	`fk_staff_work` BIGINT(20) NULL COMMENT '담당 직무 fk',
	`fd_company_master_yn` CHAR(1) NULL DEFAULT N COMMENT '회사 대표직원 여부YN' COLLATE 'utf8mb4_general_ci',
	`fd_default_ai` CHAR(1) NULL DEFAULT N COMMENT '디폴트 AI직원 (대표 AI직원)' COLLATE 'utf8mb4_general_ci',
	`fd_staff_pw` VARCHAR(512) NULL COMMENT '직원 pw[단방향]' COLLATE 'utf8mb4_general_ci',
	`fd_signup_keycode` VARCHAR(256) NULL COMMENT '직원 가입 초대코드' COLLATE 'utf8mb4_general_ci',
	`fd_signup_keycode_date` TIMESTAMP NULL COMMENT '직원 가입 초대코드 생성일시',
	`fd_signup_keycode_ok_yn` CHAR(1) NULL COMMENT '초대코드 컨펌 여부YN' COLLATE 'utf8mb4_general_ci',
	`fd_staff_ai_uid` VARCHAR(128) NULL COMMENT 'AI직원 uid' COLLATE 'utf8mb4_general_ci',
	`fd_dnis` VARCHAR(128) NULL COMMENT '할당번호' COLLATE 'utf8mb4_general_ci',
	`fd_staff_name` VARCHAR(64) NULL COMMENT '직원 이름' COLLATE 'utf8mb4_general_ci',
	`staff_nick_name` VARCHAR(128) NULL COLLATE 'utf8mb4_general_ci',
	`fd_staff_name_en` VARCHAR(64) NULL COMMENT '직원 이름 영어' COLLATE 'utf8mb4_general_ci',
	`fd_staff_mobile` VARCHAR(64) NULL COMMENT '직원 휴대전화' COLLATE 'utf8mb4_general_ci',
	`dnis_hand` VARCHAR(32) NULL COMMENT '손비서 내선번호' COLLATE 'utf8mb4_general_ci',
	`fd_staff_mobile_type` VARCHAR(64) NULL COMMENT '직원 휴대전화 통신사' COLLATE 'utf8mb4_general_ci',
	`fd_staff_mobile_verify_dt` DATETIME NULL COMMENT '본인인증일시',
	`fd_staff_phone` VARCHAR(64) NULL COMMENT '직원 일반전화' COLLATE 'utf8mb4_general_ci',
	`fd_staff_email` VARCHAR(128) NULL COMMENT '직원 이메일' COLLATE 'utf8mb4_general_ci',
	`fd_staff_duty` VARCHAR(64) NULL COMMENT '임무' COLLATE 'utf8mb4_general_ci',
	`fd_staff_birth` VARCHAR(16) NULL COMMENT '직원 생년월일' COLLATE 'utf8mb4_general_ci',
	`fd_staff_gender_mf` CHAR(1) NULL COMMENT '직원 성별 MF' COLLATE 'utf8mb4_general_ci',
	`fd_staff_national_yn` CHAR(1) NULL COMMENT '내국인 여부YN' COLLATE 'utf8mb4_general_ci',
	`fd_address_zipcode` VARCHAR(64) NULL COMMENT '주소 우편번호' COLLATE 'utf8mb4_general_ci',
	`fd_address_common` VARCHAR(128) NULL COMMENT '주소 기본' COLLATE 'utf8mb4_general_ci',
	`fd_address_detail` VARCHAR(128) NULL COMMENT '주소 상세' COLLATE 'utf8mb4_general_ci',
	`fd_logo_file_path` VARCHAR(128) NULL COMMENT '개인심볼(aws path)' COLLATE 'utf8mb4_general_ci',
	`fd_staff_di` VARCHAR(128) NULL COMMENT '직원 DI' COLLATE 'utf8mb4_general_ci',
	`fd_staff_ci` VARCHAR(128) NULL COMMENT '직원 CI' COLLATE 'utf8mb4_general_ci',
	`fd_staff_persona` VARCHAR(64) NULL DEFAULT '20' COMMENT 'AI직원 목소리 설정' COLLATE 'utf8mb4_general_ci',
	`interj_yn` VARCHAR(1) NULL DEFAULT N COMMENT '간투사 사용 여부' COLLATE 'utf8mb4_general_ci',
	`call_fwd_yn` VARCHAR(1) NULL DEFAULT N COMMENT '착신설정 여부' COLLATE 'utf8mb4_general_ci',
	`fd_push_noti_yn` CHAR(1) NULL COMMENT 'push' COLLATE 'utf8mb4_general_ci',
	`fd_push_token` VARCHAR(256) NULL COMMENT 'push token' COLLATE 'utf8mb4_general_ci',
	`fd_login_date` TIMESTAMP NULL COMMENT '로그인 일시',
	`dept_disp_name` VARCHAR(254) NULL COMMENT '부서명' COLLATE 'utf8mb4_general_ci',
	`ad_agree_sms_yn` VARCHAR(1) NULL DEFAULT Y COLLATE 'utf8mb4_general_ci',
	`ad_agree_email_yn` VARCHAR(1) NULL DEFAULT Y COLLATE 'utf8mb4_general_ci',
	`leave_reason` VARCHAR(254) NULL COMMENT '탈퇴사유' COLLATE 'utf8mb4_general_ci',
	`fk_writer` BIGINT(20) NULL COMMENT '[직원]등록자 fk',
	`fd_regdate` TIMESTAMP NULL COMMENT '[직원]등록일시',
	`fk_modifier` BIGINT(20) NULL COMMENT '[직원]수정자 fk',
	`fd_moddate` TIMESTAMP NULL DEFAULT current_timestamp() COMMENT '[직원]수정일시',
	`fk_staff_work_code` VARCHAR(64) NULL COMMENT 'ai직원 담당업무 코드' COLLATE 'utf8mb4_general_ci',
	`fd_state_code` VARCHAR(64) NULL COMMENT '직원 활성화 상태' COLLATE 'utf8mb4_general_ci',
	`fd_sign_up_path_code` VARCHAR(64) NULL COMMENT '회원 가입 경로' COLLATE 'utf8mb4_general_ci',
	`is_change_password` TINYINT(1) NOT NULL DEFAULT '0' COMMENT '패스워드 변경 여부',
	`change_password_date` TIMESTAMP NULL COMMENT '패스워드변경일시',
	`uuid` VARCHAR(64) NULL COMMENT '계정UUID' COLLATE 'utf8mb4_unicode_ci',
	`leave_code` VARCHAR(32) NULL COMMENT '탈퇴코드' COLLATE 'utf8mb4_general_ci',
	`recommend_id` VARCHAR(32) NULL COMMENT '추천인 아이디' COLLATE 'utf8mb4_general_ci',
	`quick_start_status` INT(11) NOT NULL DEFAULT -1 COMMENT 'quick 상태 (-1: quick start아님, 1: quick start 2: quick start 종료)',
	`quick_start_bot_status` INT(11) NOT NULL DEFAULT -1 COMMENT 'quick bot 상태 (-1: 생성 안됨, 1: 생성)',
	`bot_display_yn` CHAR(1) NULL DEFAULT Y COMMENT 'bot 화면표시 여부YN' COLLATE 'utf8mb4_general_ci',
	`quick_start_from` DATE NULL COMMENT 'quick start 시작일',
	`quick_start_to` DATE NULL COMMENT 'quick start 종료일',
	`mobile_overseas_code` VARCHAR(10) NULL DEFAULT +82 COMMENT '모바일 해외 번호' COLLATE 'utf8mb4_general_ci',
	PRIMARY KEY (`pk_company_staff`) USING BTREE,
	INDEX `idx_company_staff_solution_type` (`solution_type`) USING BTREE,
	INDEX `idx_company_staff_user_type` (`user_type`) USING BTREE,
	INDEX `idx_company_staff_fk_company` (`fk_company`) USING BTREE,
	INDEX `idx_company_staff_fk_staff_work` (`fk_staff_work`) USING BTREE,
	INDEX `idx_company_staff_staff_id` (`fd_staff_id`) USING BTREE,
	INDEX `idx_company_staff_staff_ai_yn` (`fd_staff_ai_yn`) USING BTREE,
	INDEX `idx_company_staff_staff_level_code` (`fd_staff_level_code`) USING BTREE,
	INDEX `idx_company_staff_staff_status_code` (`fd_staff_status_code`) USING BTREE,
	INDEX `idx_company_staff_staff_response_status_code` (`fd_staff_response_status_code`) USING BTREE,
	INDEX `idx_company_staff_staff_mobile` (`fd_staff_mobile`) USING BTREE,
	INDEX `idx_company_staff_staff_phone` (`fd_staff_phone`) USING BTREE,
	INDEX `idx_company_staff_staff_email` (`fd_staff_email`) USING BTREE
)
COMMENT='직원'
COLLATE='utf8mb4_general_ci'
ENGINE=InnoDB
AUTO_INCREMENT=12101
;

-- 테이블 aice.tbl_admin_user 구조 내보내기
DROP TABLE IF EXISTS `tbl_admin_user`;
CREATE TABLE IF NOT EXISTS `tbl_admin_user` (
    `pk_admin_user` bigint(20) NOT NULL AUTO_INCREMENT,
    `user_id` varchar(128) NOT NULL COMMENT '로그인id',
    `user_token` varchar(512) DEFAULT NULL,
    `user_pw` varchar(128) NOT NULL COMMENT '로그인pw',
    `user_name` varchar(64) DEFAULT NULL COMMENT '표시 이름',
    `user_level` int(11) NOT NULL DEFAULT 11 COMMENT '권한(큰값일수록 더 높은 권한,최대:2,100,000,000)',
    `user_email` varchar(200) DEFAULT NULL,
    `user_mobile` varchar(20) DEFAULT NULL,
    `use_yn` varchar(1) NOT NULL DEFAULT 'Y',
    `memo` varchar(200) DEFAULT NULL,
    `fk_writer` bigint(20) DEFAULT NULL,
    `fd_regdate` datetime DEFAULT NULL,
    `fk_modifier` bigint(20) DEFAULT NULL,
    `fd_moddate` datetime DEFAULT NULL,
    `role` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'admin 권한',
    `uuid` varchar(64) DEFAULT NULL COMMENT '계정UUDI',
    PRIMARY KEY (`pk_admin_user`),
    UNIQUE KEY `user_id` (`user_id`),
    KEY `idx_admin_user_use_yn` (`use_yn`),
    KEY `idx_admin_user_token` (`user_token`)
    ) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 테이블 데이터 aice.tbl_admin_user:~3 rows (대략적) 내보내기
/*!40000 ALTER TABLE `tbl_admin_user` DISABLE KEYS */;
INSERT INTO `tbl_admin_user` (`pk_admin_user`, `user_id`, `user_token`, `user_pw`, `user_name`, `user_level`, `user_email`, `user_mobile`, `use_yn`, `memo`, `fk_writer`, `fd_regdate`, `fk_modifier`, `fd_moddate`, `role`, `uuid`) VALUES
(1, 'ploonet', NULL, '{bcrypt}$2a$10$CSldFB5Su4L3hKV5NA2WWuXqqIfoKz9aQ5f77VddvOXb07axMKRJq', '관리자', 11, NULL, NULL, 'Y', NULL, NULL, NULL, NULL, NULL, 'ADMIN_ADMIN', '438d6e57-6649-4f07-afb3-b6ffb5ce2b9a'),
(2, 'ryuke', NULL, '{bcrypt}$2a$10$jyP.ty2biCV6JBtsSY/ajOtK0xsLi77pozRu9lLJhVjZkD5HKew/.', 'ryuke', 2100000000, NULL, NULL, 'Y', NULL, 0, '2022-10-24 11:11:44', NULL, NULL, 'ADMIN_ADMIN', '0533d21a-ac74-4226-81ab-d9bfbf81966c'),
(3, 'temp.administrator@ploonet.com', NULL, '{bcrypt}$2a$10$vob88ane4Mt0kh9sqY74vOVtWpUl3luzZp61OahOQOyxxp/X8Wt42', '운영자', 11, NULL, NULL, 'Y', NULL, NULL, NULL, NULL, NULL, 'ADMIN_ADMIN', '1672e1f1-4ead-4c5c-83d0-c31e38c901e9');
/*!40000 ALTER TABLE `tbl_admin_user` ENABLE KEYS */;

-- 테이블 aice.tbl_admin_user2 구조 내보내기
DROP TABLE IF EXISTS `tbl_admin_user2`;
CREATE TABLE IF NOT EXISTS `tbl_admin_user2` (
    `pk_admin_user` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'admin pk',
    `fd_regdate` timestamp NULL DEFAULT current_timestamp() COMMENT '[직원]등록일시',
    `fd_moddate` timestamp NULL DEFAULT NULL COMMENT '[직원]수정일시',
    `user_email` varchar(200) DEFAULT NULL COMMENT '이메일',
    `fk_modifier` bigint(20) DEFAULT NULL COMMENT '[직원]수정자 fk',
    `fk_writer` bigint(20) DEFAULT NULL COMMENT '[직원]등록자 fk',
    `user_level` int(11) NOT NULL DEFAULT 11 COMMENT '권한(큰값일수록 더 높은 권한,최대:2,100,000,000)',
    `user_id` varchar(128) NOT NULL COMMENT '로그인id',
    `memo` varchar(200) DEFAULT NULL COMMENT '메모',
    `user_mobile` varchar(20) DEFAULT NULL COMMENT '핸드폰',
    `user_name` varchar(64) DEFAULT NULL COMMENT '표시 이름',
    `user_pw` varchar(128) NOT NULL COMMENT '로그인pw',
    `role` varchar(64) DEFAULT NULL COMMENT '권한',
    `use_yn` char(1) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'Y' COMMENT '사용 여부 YN',
    `uuid` varchar(64) DEFAULT NULL COMMENT '계정UUDI',
    PRIMARY KEY (`pk_admin_user`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;



-- 테이블 aice.tbl_company_staff 구조 내보내기
DROP TABLE IF EXISTS `tbl_company_staff`;
CREATE TABLE IF NOT EXISTS `tbl_company_staff` (
    `pk_company_staff` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '직원 pk',
    `solution_type` varchar(10) NOT NULL DEFAULT 'B11' COMMENT '솔루션타입',
    `user_type` varchar(10) NOT NULL DEFAULT 'B2001' COMMENT '사용자타입',
    `fd_staff_id` varchar(128) DEFAULT NULL COMMENT '직원 id',
    `fd_staff_ai_yn` char(1) DEFAULT 'N' COMMENT 'AI직원 여부YN',
    `fd_staff_level_code` varchar(64) DEFAULT NULL COMMENT '직원 구분 코드',
    `fd_staff_status_code` varchar(64) DEFAULT NULL COMMENT '직원 계정 상태 코드',
    `fd_staff_response_status_code` varchar(64) DEFAULT 'A1201' COMMENT '직원 응답 상태 코드',
    `auto_response_yn` varchar(1) DEFAULT 'N' COMMENT '손비서 자동 자리비움',
    `fk_company` bigint(20) DEFAULT NULL COMMENT '회사 fk',
    `fk_staff_work` bigint(20) DEFAULT NULL COMMENT '담당 직무 fk',
    `fd_company_master_yn` char(1) DEFAULT 'N' COMMENT '회사 대표직원 여부YN',
    `fd_default_ai` char(1) DEFAULT 'N' COMMENT '디폴트 AI직원 (대표 AI직원)',
    `fd_staff_pw` varchar(512) DEFAULT NULL COMMENT '직원 pw[단방향]',
    `fd_signup_keycode` varchar(256) DEFAULT NULL COMMENT '직원 가입 초대코드',
    `fd_signup_keycode_date` timestamp NULL DEFAULT NULL COMMENT '직원 가입 초대코드 생성일시',
    `fd_signup_keycode_ok_yn` char(1) DEFAULT NULL COMMENT '초대코드 컨펌 여부YN',
    `fd_staff_ai_uid` varchar(128) DEFAULT NULL COMMENT 'AI직원 uid',
    `fd_dnis` varchar(128) DEFAULT NULL COMMENT '할당번호',
    `fd_staff_name` varchar(64) DEFAULT NULL COMMENT '직원 이름',
    `staff_nick_name` varchar(128) DEFAULT NULL,
    `fd_staff_name_en` varchar(64) DEFAULT NULL COMMENT '직원 이름 영어',
    `fd_staff_mobile` varchar(64) DEFAULT NULL COMMENT '직원 휴대전화',
    `dnis_hand` varchar(32) DEFAULT NULL COMMENT '손비서 내선번호',
    `fd_staff_mobile_type` varchar(64) DEFAULT NULL COMMENT '직원 휴대전화 통신사',
    `fd_staff_mobile_verify_dt` datetime DEFAULT NULL COMMENT '본인인증일시',
    `fd_staff_phone` varchar(64) DEFAULT NULL COMMENT '직원 일반전화',
    `fd_staff_email` varchar(128) DEFAULT NULL COMMENT '직원 이메일',
    `fd_staff_duty` varchar(64) DEFAULT NULL COMMENT '임무',
    `fd_staff_birth` varchar(16) DEFAULT NULL COMMENT '직원 생년월일',
    `fd_staff_gender_mf` char(1) DEFAULT NULL COMMENT '직원 성별 MF',
    `fd_staff_national_yn` char(1) DEFAULT NULL COMMENT '내국인 여부YN',
    `fd_address_zipcode` varchar(64) DEFAULT NULL COMMENT '주소 우편번호',
    `fd_address_common` varchar(128) DEFAULT NULL COMMENT '주소 기본',
    `fd_address_detail` varchar(128) DEFAULT NULL COMMENT '주소 상세',
    `fd_logo_file_path` varchar(128) DEFAULT NULL COMMENT '개인심볼(aws path)',
    `fd_staff_di` varchar(128) DEFAULT NULL COMMENT '직원 DI',
    `fd_staff_ci` varchar(128) DEFAULT NULL COMMENT '직원 CI',
    `fd_staff_persona` varchar(64) DEFAULT '20' COMMENT 'AI직원 목소리 설정',
    `interj_yn` varchar(1) DEFAULT 'N' COMMENT '간투사 사용 여부',
    `call_fwd_yn` varchar(1) DEFAULT 'N' COMMENT '착신설정 여부',
    `fd_push_noti_yn` char(1) DEFAULT NULL COMMENT 'push',
    `fd_push_token` varchar(256) DEFAULT NULL COMMENT 'push token',
    `fd_login_date` timestamp NULL DEFAULT NULL COMMENT '로그인 일시',
    `dept_disp_name` varchar(254) DEFAULT NULL COMMENT '부서명',
    `ad_agree_sms_yn` varchar(1) DEFAULT 'Y',
    `ad_agree_email_yn` varchar(1) DEFAULT 'Y',
    `leave_reason` varchar(254) DEFAULT NULL COMMENT '탈퇴사유',
    `fk_writer` bigint(20) DEFAULT NULL COMMENT '[직원]등록자 fk',
    `fd_regdate` timestamp NULL DEFAULT NULL COMMENT '[직원]등록일시',
    `fk_modifier` bigint(20) DEFAULT NULL COMMENT '[직원]수정자 fk',
    `fd_moddate` timestamp NULL DEFAULT current_timestamp() COMMENT '[직원]수정일시',
    `fk_staff_work_code` varchar(64) DEFAULT NULL COMMENT 'ai직원 담당업무 코드',
    `fd_state_code` varchar(64) DEFAULT NULL COMMENT '직원 활성화 상태',
    `fd_sign_up_path_code` varchar(64) DEFAULT NULL COMMENT '회원 가입 경로',
    `is_change_password` tinyint(1) NOT NULL DEFAULT 0 COMMENT '패스워드 변경 여부',
    `change_password_date` timestamp NULL DEFAULT NULL COMMENT '패스워드변경일시',
    `uuid` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '계정UUID',
    `leave_code` varchar(32) DEFAULT NULL COMMENT '탈퇴코드',
    `recommend_id` varchar(32) DEFAULT NULL COMMENT '추천인 아이디',
    `quick_start_status` int(11) NOT NULL DEFAULT -1 COMMENT 'quick 상태 (-1: quick start아님, 1: quick start 2: quick start 종료)',
    `quick_start_bot_status` int(11) NOT NULL DEFAULT -1 COMMENT 'quick bot 상태 (-1: 생성 안됨, 1: 생성)',
    `bot_display_yn` char(1) DEFAULT 'Y' COMMENT 'bot 화면표시 여부YN',
    `quick_start_from` date DEFAULT NULL COMMENT 'quick start 시작일',
    `quick_start_to` date DEFAULT NULL COMMENT 'quick start 종료일',
    `mobile_overseas_code` varchar(10) DEFAULT '+82' COMMENT '모바일 해외 번호',
    PRIMARY KEY (`pk_company_staff`),
    KEY `idx_company_staff_solution_type` (`solution_type`),
    KEY `idx_company_staff_user_type` (`user_type`),
    KEY `idx_company_staff_fk_company` (`fk_company`),
    KEY `idx_company_staff_fk_staff_work` (`fk_staff_work`),
    KEY `idx_company_staff_staff_id` (`fd_staff_id`),
    KEY `idx_company_staff_staff_ai_yn` (`fd_staff_ai_yn`),
    KEY `idx_company_staff_staff_level_code` (`fd_staff_level_code`),
    KEY `idx_company_staff_staff_status_code` (`fd_staff_status_code`),
    KEY `idx_company_staff_staff_response_status_code` (`fd_staff_response_status_code`),
    KEY `idx_company_staff_staff_mobile` (`fd_staff_mobile`),
    KEY `idx_company_staff_staff_phone` (`fd_staff_phone`),
    KEY `idx_company_staff_staff_email` (`fd_staff_email`)
    ) ENGINE=InnoDB AUTO_INCREMENT=12101 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='직원';

-- 테이블 데이터 aice.tbl_company_staff:~8,265 rows (대략적) 내보내기
/*!40000 ALTER TABLE `tbl_company_staff` DISABLE KEYS */;
INSERT INTO `tbl_company_staff` (`pk_company_staff`, `solution_type`, `user_type`, `fd_staff_id`, `fd_staff_ai_yn`, `fd_staff_level_code`, `fd_staff_status_code`, `fd_staff_response_status_code`, `auto_response_yn`, `fk_company`, `fk_staff_work`, `fd_company_master_yn`, `fd_default_ai`, `fd_staff_pw`, `fd_signup_keycode`, `fd_signup_keycode_date`, `fd_signup_keycode_ok_yn`, `fd_staff_ai_uid`, `fd_dnis`, `fd_staff_name`, `staff_nick_name`, `fd_staff_name_en`, `fd_staff_mobile`, `dnis_hand`, `fd_staff_mobile_type`, `fd_staff_mobile_verify_dt`, `fd_staff_phone`, `fd_staff_email`, `fd_staff_duty`, `fd_staff_birth`, `fd_staff_gender_mf`, `fd_staff_national_yn`, `fd_address_zipcode`, `fd_address_common`, `fd_address_detail`, `fd_logo_file_path`, `fd_staff_di`, `fd_staff_ci`, `fd_staff_persona`, `interj_yn`, `call_fwd_yn`, `fd_push_noti_yn`, `fd_push_token`, `fd_login_date`, `dept_disp_name`, `ad_agree_sms_yn`, `ad_agree_email_yn`, `leave_reason`, `fk_writer`, `fd_regdate`, `fk_modifier`, `fd_moddate`, `fk_staff_work_code`, `fd_state_code`, `fd_sign_up_path_code`, `is_change_password`, `change_password_date`, `uuid`, `leave_code`, `recommend_id`, `quick_start_status`, `quick_start_bot_status`, `bot_display_yn`, `quick_start_from`, `quick_start_to`, `mobile_overseas_code`) VALUES
(1, 'B11', 'B2001', 'ceoseo', 'N', 'A1003', 'A1101', 'A1202', 'N', 1, NULL, 'Y', 'N', '{bcrypt}$2a$10$8pzPejRe1itEHD07vTrXcu8PNdYspNZNd6073./sp1kcgMGRQpfv.', 'T1938926907', '2022-07-29 10:46:58', 'N', '', NULL, '이종원', NULL, NULL, '', NULL, NULL, NULL, '01027161479', 'ceoseo@naver.com', '', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'N', 'N', 'Y', 'ereYkL9kR0eHHciSsFoO2_:APA91bE1UgHTPUbnd8id_mNecSjifH9y_xU-FD85HKveE4C6ozRXrk6flpjrmokkCTnIUJva_eq8RESuTC_lmrgs5kqrONrp47PMieOrxZMgdvw3DxGTKkLc7P2LWQ8H-oWBBbIEKP6I', '2022-06-20 16:51:23', NULL, 'Y', 'Y', NULL, NULL, '2022-04-11 10:57:31', 1, '2023-07-26 12:55:13', 'CTGR1003', NULL, NULL, 0, NULL, NULL, NULL, NULL, -1, -1, 'Y', NULL, NULL, '+82'),
(2, 'B11', 'B2001', 'guest.master@ploonet.com', 'N', 'A1001', 'A1101', 'A1207', 'N', 2, NULL, 'Y', 'N', '{bcrypt}$2a$10$R/xY9CdndqI13XVXjsJ/reMFPwo1Y2KxZy/ETBoMLIqm4c9.9CPk6', NULL, NULL, NULL, NULL, NULL, '체험하기마스터', NULL, NULL, '01000000000', NULL, NULL, NULL, '01027161479', 'joy@quick.com', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'N', 'N', NULL, NULL, '2024-04-05 14:23:33', NULL, 'Y', 'Y', NULL, NULL, '2022-04-11 10:57:31', NULL, '2022-04-11 10:57:31', 'CTGR1003', NULL, NULL, 0, NULL, NULL, NULL, NULL, -1, -1, 'Y', NULL, NULL, '+82'),
(3, 'B11', 'B2001', 'guest.ai@ploonet.com', 'Y', 'A1004', 'A1101', 'A1201', 'N', 2, NULL, 'N', 'N', '', NULL, NULL, NULL, NULL, NULL, '조이', NULL, NULL, '', NULL, NULL, NULL, '01031238227', 'fc06', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '33', 'N', 'N', NULL, NULL, NULL, NULL, 'Y', 'Y', NULL, NULL, '2022-04-11 10:57:31', 2, '2023-10-27 13:29:56', 'CTGR1003', NULL, NULL, 0, NULL, NULL, NULL, NULL, -1, -1, 'Y', NULL, NULL, '+82'),
(4, 'B11', 'B2001', 'test', 'N', 'A1000', 'A1101', 'A1201', 'N', 3, NULL, 'N', 'N', '', NULL, NULL, NULL, NULL, NULL, '테스트류크', NULL, NULL, '', NULL, NULL, NULL, '01088667935', 'ceoseo@naver.com', '', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '5', 'N', 'N', NULL, NULL, NULL, NULL, 'Y', 'Y', NULL, NULL, '2022-04-11 10:57:31', 11, '2022-12-29 19:09:14', 'CTGR1003', NULL, NULL, 0, NULL, NULL, NULL, NULL, -1, -1, 'Y', NULL, NULL, '+82'),
(5, 'B11', 'B2001', 'ljw', 'N', 'A1000', 'A1101', 'A1201', 'N', 1, NULL, 'N', 'N', '1357', NULL, NULL, NULL, NULL, NULL, '일반문의이종원', NULL, NULL, '', NULL, NULL, NULL, '01027161479', 'ceoseo@naver.com', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'N', 'N', NULL, NULL, NULL, NULL, 'Y', 'Y', NULL, NULL, '2022-04-11 10:57:31', NULL, '2022-04-11 10:57:31', 'CTGR1003', NULL, NULL, 0, NULL, NULL, NULL, NULL, -1, -1, 'Y', NULL, NULL, '+82'),
(6, 'B11', 'B2001', 'ljw@saltlux.com', 'N', 'A1000', 'A1101', 'A1203', 'N', 1, NULL, 'N', 'N', '{bcrypt}$2a$10$xpSqHP/OVXZE/E2QRnUCCOSGNxQjyfOZnPfi6I2J80pOnKtjuJybW', 'T0584682750', NULL, NULL, NULL, NULL, '이종원', NULL, NULL, '', NULL, NULL, NULL, '01027161479', 'ceoseo@naver.com', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'N', 'N', NULL, NULL, NULL, NULL, 'Y', 'Y', NULL, NULL, '2022-04-11 10:57:31', NULL, '2022-04-11 10:57:31', 'CTGR1003', NULL, NULL, 0, NULL, NULL, NULL, NULL, -1, -1, 'Y', NULL, NULL, '+82');








///////////////////////////////////////////////////////
////  MYSQL  command
///////////////////////////////////////////////////////

grant all privileges on *.* to 'itcms'@'localhost' identified by 'itcms1234';
grant all privileges on *.* to 'stock'@'localhost' identified by 'stock123';
grant all privileges on *.* to 'itcms'@'192.168.100.127' identified by 'itcms1234';
grant all privileges on *.* to 'itcms'@'192.168.100.128' identified by 'itcms1234';

set global max_allowed_packet=100000000;
set global net_buffer_length=1000000;
set global max_connections=5000;

mysqldump -uroot -pitcms1234 --all-databases > alldb.sql

mysqldump -h192.168.100.222 -uitcms -pitcms1234 admin_itcms > admin_itcms.sql
mysqldump -h192.168.100.222 -uitcms -pitcms1234 ctl_itcms > ctl_itcms.sql
mysqldump -h192.168.100.222 -uitcms -pitcms1234 mgt_itcms > mgt_itcms.sql
mysqldump -h192.168.100.222 -uitcms -pitcms1234 agt_1_itcms > agt_1_itcms.sql
mysqldump -h127.0.0.1 -ustock -pstock123 stock2 > stock2.sql
mysqldump -h127.0.0.1 -ustock -pstock123 stock > stock.sql

mysqldump -uitcms -pitcms1234 admin_itcms > admin_itcms.sql
mysqldump -uitcms -pitcms1234 ctl_itcms > ctl_itcms.sql
mysqldump -uitcms -pitcms1234 mgt_itcms > mgt_itcms.sql
mysqldump -uitcms -pitcms1234 agt_1_itcms > agt_1_itcms.sql

mysql -uitcms -pitcms1234 -e 'drop database admin_itcms'
mysql -uitcms -pitcms1234 -e 'drop database ctl_itcms'
mysql -uitcms -pitcms1234 -e 'drop database mgt_itcms'
mysql -uitcms -pitcms1234 -e 'drop database agt_1_itcms'
mysql -uitcms -pitcms1234 -e 'drop database agt_2_itcms'

mysql -uitcms -pitcms1234 -e 'create database admin_itcms'
mysql -uitcms -pitcms1234 admin_itcms < ./admin_itcms.sql

mysql -uitcms -pitcms1234 -e 'create database admin_itcms'
mysql -uitcms -pitcms1234 -e 'create database ctl_itcms'
mysql -uitcms -pitcms1234 -e 'create database mgt_itcms'
mysql -uitcms -pitcms1234 -e 'create database agt_1_itcms'
mysql -uitcms -pitcms1234 -e 'create database agt_2_itcms'

mysql -uitcms -pitcms1234 admin_itcms < admin_itcms.sql
mysql -uitcms -pitcms1234 ctl_itcms < ctl_itcms.sql
mysql -uitcms -pitcms1234 mgt_itcms < mgt_itcms.sql
mysql -uitcms -pitcms1234 agt_1_itcms < agt_1_itcms.sql
mysql -uitcms -pitcms1234 agt_2_itcms < agt_2_itcms.sql
mysql -uitcms -pitcms1234 agt_3_itcms < agt_3_itcms.sql
mysql -uitcms -pitcms1234 agt_4_itcms < agt_4_itcms.sql
mysql -uitcms -pitcms1234 agt_5_itcms < agt_5_itcms.sql
mysql -uitcms -pitcms1234 agt_6_itcms < agt_6_itcms.sql
mysql -uitcms -pitcms1234 agt_7_itcms < agt_7_itcms.sql

mysql -uitcms -pitcms1234 agt_75_itcms < agt_75_itcms.sql
mysql -ustock -pstock123 stock < C:\download\stock.sql
mysql -ustock -pstock123 stock2 < stock2.sql


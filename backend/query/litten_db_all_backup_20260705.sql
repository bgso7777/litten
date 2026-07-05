-- --------------------------------------------------------
-- 호스트:                          203.245.29.74
-- 서버 버전:                        10.6.22-MariaDB-0ubuntu0.22.04.1 - Ubuntu 22.04
-- 서버 OS:                        debian-linux-gnu
-- HeidiSQL 버전:                  12.17.0.7270
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

-- 테이블 litten7.cloud_file 구조 내보내기
CREATE TABLE IF NOT EXISTS `cloud_file` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '파일 ID',
  `member_id` varchar(128) NOT NULL COMMENT '회원 ID',
  `litten_id` varchar(128) NOT NULL COMMENT '리튼 ID',
  `local_id` varchar(128) NOT NULL COMMENT '로컬 파일 ID',
  `file_type` varchar(20) NOT NULL COMMENT '파일 유형 (audio/text/handwriting)',
  `file_name` varchar(255) NOT NULL COMMENT '파일명',
  `file_path` varchar(512) DEFAULT NULL COMMENT '서버 저장 경로',
  `file_size` bigint(20) DEFAULT 0 COMMENT '파일 크기(bytes)',
  `content_type` varchar(100) DEFAULT NULL COMMENT 'MIME 타입',
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0 COMMENT '삭제 여부',
  `deleted_at` timestamp NULL DEFAULT NULL COMMENT '삭제 일시',
  `local_updated_at` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '로컬 파일 수정일시 (동기화 비교용)',
  `insert_pk` bigint(20) DEFAULT NULL COMMENT '등록 회원 ID(seq)',
  `update_pk` bigint(20) DEFAULT NULL COMMENT '수정 회원 ID(seq)',
  `insert_date_time` datetime DEFAULT NULL COMMENT '등록일시',
  `update_date_time` datetime DEFAULT NULL COMMENT '수정일시',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_member_id` (`member_id`),
  KEY `idx_litten_id` (`litten_id`),
  KEY `idx_local_id` (`local_id`),
  KEY `idx_is_deleted` (`is_deleted`)
) ENGINE=InnoDB AUTO_INCREMENT=351 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='클라우드 파일';

-- 내보낼 데이터가 선택되어 있지 않습니다.

-- 테이블 litten7.cloud_file_backup 구조 내보내기
CREATE TABLE IF NOT EXISTS `cloud_file_backup` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '백업 ID',
  `cloud_file_id` bigint(20) NOT NULL COMMENT '원본 cloud_file ID',
  `backup_path` varchar(512) NOT NULL COMMENT '백업 파일 경로',
  `file_size` bigint(20) DEFAULT 0 COMMENT '백업 파일 크기(bytes)',
  `backed_up_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT '백업 일시',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_cloud_file_id` (`cloud_file_id`),
  CONSTRAINT `fk_backup_cloud_file` FOREIGN KEY (`cloud_file_id`) REFERENCES `cloud_file` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3599 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='클라우드 파일 백업';

-- 내보낼 데이터가 선택되어 있지 않습니다.

-- 테이블 litten7.note_channel_watch_state 구조 내보내기
CREATE TABLE IF NOT EXISTS `note_channel_watch_state` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `member_id` varchar(128) NOT NULL COMMENT '회원 ID',
  `channel_id` varchar(64) NOT NULL COMMENT '유튜브 채널 ID',
  `last_seen_at` timestamp NULL DEFAULT NULL COMMENT '마지막 확인 시점 최신 영상 게시일',
  `last_seen_video_id` varchar(50) DEFAULT NULL COMMENT '마지막 확인 videoId',
  `synced_at` timestamp NOT NULL DEFAULT current_timestamp() COMMENT '상태 갱신 시각',
  `insert_pk` bigint(20) DEFAULT NULL,
  `update_pk` bigint(20) DEFAULT NULL,
  `insert_date_time` datetime DEFAULT NULL,
  `update_date_time` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_watch_member_channel` (`member_id`,`channel_id`),
  KEY `idx_watch_member` (`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 내보낼 데이터가 선택되어 있지 않습니다.

-- 테이블 litten7.note_file_share 구조 내보내기
CREATE TABLE IF NOT EXISTS `note_file_share` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '공유 ID',
  `sender_member_id` varchar(128) NOT NULL COMMENT '발신자 회원 ID',
  `sender_name` varchar(100) DEFAULT NULL COMMENT '발신자 표시 이름(스냅샷)',
  `target_type` varchar(10) NOT NULL COMMENT '대상 유형 (user/group)',
  `group_id` bigint(20) DEFAULT NULL COMMENT '그룹 ID(group일 때)',
  `group_name` varchar(100) DEFAULT NULL COMMENT '그룹 이름(스냅샷)',
  `litten_title` varchar(255) DEFAULT NULL COMMENT '원본 리튼 이름(표시용)',
  `file_type` varchar(20) NOT NULL COMMENT '파일 유형 (text/audio/handwriting/attachment)',
  `file_name` varchar(255) NOT NULL COMMENT '파일명',
  `content_type` varchar(100) DEFAULT NULL COMMENT 'MIME 타입',
  `file_size` bigint(20) DEFAULT 0 COMMENT '파일 크기(bytes)',
  `stored_path` varchar(512) DEFAULT NULL COMMENT '공유 저장소 경로',
  `message` varchar(500) DEFAULT NULL COMMENT '보낸 메시지',
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0 COMMENT '삭제/취소 여부',
  `deleted_at` timestamp NULL DEFAULT NULL COMMENT '삭제/취소 일시',
  `insert_pk` bigint(20) DEFAULT NULL,
  `update_pk` bigint(20) DEFAULT NULL,
  `insert_date_time` datetime DEFAULT NULL,
  `update_date_time` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_share_sender` (`sender_member_id`,`is_deleted`)
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='파일 공유';

-- 내보낼 데이터가 선택되어 있지 않습니다.

-- 테이블 litten7.note_file_share_delivery 구조 내보내기
CREATE TABLE IF NOT EXISTS `note_file_share_delivery` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '전달 ID',
  `share_id` bigint(20) NOT NULL COMMENT '공유 ID',
  `recipient_member_id` varchar(128) NOT NULL COMMENT '수신자 회원 ID',
  `status` varchar(10) NOT NULL DEFAULT 'pending' COMMENT '상태 (pending/accepted/rejected)',
  `responded_at` timestamp NULL DEFAULT NULL COMMENT '응답 일시',
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0 COMMENT '삭제/취소 여부',
  `insert_pk` bigint(20) DEFAULT NULL,
  `update_pk` bigint(20) DEFAULT NULL,
  `insert_date_time` datetime DEFAULT NULL,
  `update_date_time` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_delivery_recipient` (`recipient_member_id`,`is_deleted`,`status`),
  KEY `idx_delivery_share` (`share_id`,`is_deleted`)
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='파일 공유 전달(수신자별)';

-- 내보낼 데이터가 선택되어 있지 않습니다.

-- 테이블 litten7.note_hidden_conversation 구조 내보내기
CREATE TABLE IF NOT EXISTS `note_hidden_conversation` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '숨김 ID',
  `member_id` varchar(128) NOT NULL COMMENT '회원 ID',
  `conv_key` varchar(256) NOT NULL COMMENT '대화 key(u:이메일 / g:그룹명)',
  `hidden_at` timestamp NULL DEFAULT NULL COMMENT '숨긴 시각',
  `insert_pk` bigint(20) DEFAULT NULL COMMENT '등록 회원 ID(seq)',
  `update_pk` bigint(20) DEFAULT NULL COMMENT '수정 회원 ID(seq)',
  `insert_date_time` datetime DEFAULT NULL COMMENT '등록일시',
  `update_date_time` datetime DEFAULT NULL COMMENT '수정일시',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_member_conv` (`member_id`,`conv_key`),
  KEY `idx_hidden_member` (`member_id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 내보낼 데이터가 선택되어 있지 않습니다.

-- 테이블 litten7.note_litten 구조 내보내기
CREATE TABLE IF NOT EXISTS `note_litten` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `member_id` varchar(128) NOT NULL COMMENT '회원 ID',
  `litten_id` varchar(64) NOT NULL COMMENT '클라이언트 리튼 UUID',
  `title` varchar(512) NOT NULL COMMENT '리튼 제목',
  `description` text DEFAULT NULL COMMENT '리튼 설명',
  `extra_json` longtext DEFAULT NULL COMMENT '리튼 전체 JSON blob',
  `client_created_at` timestamp NULL DEFAULT NULL COMMENT '클라이언트 생성일시',
  `client_updated_at` timestamp NOT NULL DEFAULT current_timestamp() COMMENT '클라이언트 수정일시',
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0 COMMENT '삭제 여부',
  `deleted_at` timestamp NULL DEFAULT NULL COMMENT '삭제 일시',
  `insert_pk` bigint(20) DEFAULT NULL COMMENT '등록 회원 seq',
  `update_pk` bigint(20) DEFAULT NULL COMMENT '수정 회원 seq',
  `insert_date_time` datetime DEFAULT NULL COMMENT '등록일시',
  `update_date_time` datetime DEFAULT NULL COMMENT '수정일시',
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_member_litten` (`member_id`,`litten_id`),
  KEY `idx_litten_member` (`member_id`,`is_deleted`)
) ENGINE=InnoDB AUTO_INCREMENT=42 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 내보낼 데이터가 선택되어 있지 않습니다.

-- 테이블 litten7.note_member 구조 내보내기
CREATE TABLE IF NOT EXISTS `note_member` (
  `sequence` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '회원pk',
  `uuid` varchar(64) DEFAULT NULL COMMENT '계정UUID',
  `uuid1` varchar(64) DEFAULT NULL COMMENT '로그인 디바이스 UUID 1',
  `uuid2` varchar(64) DEFAULT NULL COMMENT '로그인 디바이스 UUID 2',
  `uuid3` varchar(64) DEFAULT NULL COMMENT '로그인 디바이스 UUID 3',
  `id` varchar(128) DEFAULT NULL COMMENT '회원아이디',
  `password` varchar(512) DEFAULT NULL COMMENT '직원 pw[단방향]',
  `id_insert_date_time` timestamp NULL DEFAULT NULL COMMENT 'ID 등록일시',
  `is_change_password` tinyint(1) NOT NULL DEFAULT 0 COMMENT '패스워드 변경 여부',
  `change_password_date_time` timestamp NULL DEFAULT NULL COMMENT '패스워드 변경 일시',
  `name` varchar(64) DEFAULT NULL COMMENT '직원 이름',
  `name_english` varchar(64) DEFAULT NULL COMMENT '직원 이름 영어',
  `mobile` varchar(64) DEFAULT NULL COMMENT '직원 휴대전화',
  `mobile_type` varchar(64) DEFAULT NULL COMMENT '직원 휴대전화 통신사',
  `mobile_verify_date_time` datetime DEFAULT NULL COMMENT '본인인증일시',
  `email` varchar(64) DEFAULT NULL COMMENT '이메일',
  `state` varchar(64) DEFAULT NULL COMMENT '활성화 상태',
  `subscription_plan` varchar(20) NOT NULL DEFAULT 'free' COMMENT '구독 플랜 (free/standard/premium)',
  `plan_expired_at` timestamp NULL DEFAULT NULL COMMENT '플랜 만료일시',
  `insert_date_time` timestamp NULL DEFAULT current_timestamp() COMMENT '[직원]등록일시',
  `update_pk` bigint(20) DEFAULT NULL COMMENT '[직원]수정자 fk',
  `update_date_time` timestamp NULL DEFAULT NULL COMMENT '[직원]수정일시',
  `insert_pk` bigint(20) DEFAULT NULL COMMENT '[직원]등록자 fk',
  PRIMARY KEY (`sequence`) USING BTREE,
  KEY `index_of_id` (`id`) USING BTREE,
  KEY `index_of_uuid` (`uuid`) USING BTREE,
  KEY `index_of_mobile` (`mobile`),
  KEY `index_of_email` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=38 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='회원';

-- 내보낼 데이터가 선택되어 있지 않습니다.

-- 테이블 litten7.note_member_log 구조 내보내기
CREATE TABLE IF NOT EXISTS `note_member_log` (
  `sequence_log` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '계정로그',
  `sequence` bigint(20) DEFAULT NULL COMMENT '계정',
  `uuid` varchar(64) DEFAULT NULL COMMENT '계정UUID',
  `id` varchar(128) DEFAULT NULL COMMENT '회원아이디',
  `password` varchar(512) DEFAULT NULL COMMENT '직원 pw[단방향]',
  `id_insert_date_time` timestamp NULL DEFAULT NULL COMMENT 'ID 등록일시',
  `is_change_password` tinyint(1) NOT NULL DEFAULT 0 COMMENT '패스워드 변경 여부',
  `change_password_date_time` timestamp NULL DEFAULT NULL COMMENT '패스워드 변경 일시',
  `name` varchar(64) DEFAULT NULL COMMENT '직원 이름',
  `name_english` varchar(64) DEFAULT NULL COMMENT '직원 이름 영어',
  `mobile` varchar(64) DEFAULT NULL COMMENT '직원 휴대전화',
  `mobile_type` varchar(64) DEFAULT NULL COMMENT '직원 휴대전화 통신사',
  `mobile_verify_date_time` datetime DEFAULT NULL COMMENT '본인인증일시',
  `email` varchar(64) DEFAULT NULL COMMENT '이메일',
  `state` varchar(64) DEFAULT NULL COMMENT '활성화 상태',
  `query_code` varchar(10) DEFAULT NULL COMMENT '쿼리 코드',
  `query_date` timestamp NULL DEFAULT NULL COMMENT '쿼리 실행 일시',
  `query_token_id` varchar(128) DEFAULT NULL COMMENT '쿼리 실행 로그인 id',
  `insert_date_time` timestamp NULL DEFAULT current_timestamp() COMMENT '[직원]등록일시',
  `update_pk` bigint(20) DEFAULT NULL COMMENT '[직원]수정자 fk',
  `update_date_time` timestamp NULL DEFAULT NULL COMMENT '[직원]수정일시',
  `insert_pk` bigint(20) DEFAULT NULL COMMENT '[직원]등록자 fk',
  PRIMARY KEY (`sequence_log`) USING BTREE,
  KEY `index_of_sequence` (`sequence`) USING BTREE,
  KEY `index_of_id` (`id`) USING BTREE,
  KEY `index_of_uuid` (`uuid`) USING BTREE,
  KEY `index_of_mobile` (`mobile`),
  KEY `index_of_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='회원로그';

-- 내보낼 데이터가 선택되어 있지 않습니다.

-- 테이블 litten7.note_member_youtube_channel 구조 내보내기
CREATE TABLE IF NOT EXISTS `note_member_youtube_channel` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `member_id` varchar(128) NOT NULL COMMENT '회원 ID',
  `channel_id` varchar(64) NOT NULL COMMENT '유튜브 채널 ID',
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `auto_title` tinyint(1) NOT NULL DEFAULT 1,
  `auto_memo` tinyint(1) NOT NULL DEFAULT 0,
  `auto_summary` tinyint(1) NOT NULL DEFAULT 0,
  `summary_type` varchar(32) DEFAULT NULL,
  `auto_quiz` tinyint(1) NOT NULL DEFAULT 0,
  `quiz_type` varchar(32) DEFAULT NULL,
  `quiz_custom_count` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `insert_pk` bigint(20) DEFAULT NULL COMMENT '등록 회원 ID(seq)',
  `update_pk` bigint(20) DEFAULT NULL COMMENT '수정 회원 ID(seq)',
  `insert_date_time` datetime DEFAULT NULL COMMENT '등록일시',
  `update_date_time` datetime DEFAULT NULL COMMENT '수정일시',
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_member_channel` (`member_id`,`channel_id`),
  KEY `idx_member_channel_member` (`member_id`,`is_active`),
  KEY `idx_member_channel_channel` (`channel_id`,`is_active`)
) ENGINE=InnoDB AUTO_INCREMENT=38 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 내보낼 데이터가 선택되어 있지 않습니다.

-- 테이블 litten7.note_message 구조 내보내기
CREATE TABLE IF NOT EXISTS `note_message` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '메시지 ID',
  `sender_member_id` varchar(128) NOT NULL COMMENT '발신자 회원 ID',
  `sender_name` varchar(100) DEFAULT NULL COMMENT '발신자 표시 이름(스냅샷)',
  `target_type` varchar(10) NOT NULL COMMENT '대상 유형 (user/group)',
  `group_id` bigint(20) DEFAULT NULL COMMENT '그룹 ID(group일 때)',
  `group_name` varchar(100) DEFAULT NULL COMMENT '그룹 이름(스냅샷)',
  `content` varchar(2000) NOT NULL COMMENT '메시지 내용',
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0 COMMENT '삭제 여부',
  `insert_pk` bigint(20) DEFAULT NULL COMMENT '등록 회원 ID(seq)',
  `update_pk` bigint(20) DEFAULT NULL COMMENT '수정 회원 ID(seq)',
  `insert_date_time` datetime DEFAULT NULL COMMENT '등록일시',
  `update_date_time` datetime DEFAULT NULL COMMENT '수정일시',
  PRIMARY KEY (`id`),
  KEY `idx_msg_sender` (`sender_member_id`)
) ENGINE=InnoDB AUTO_INCREMENT=31 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 내보낼 데이터가 선택되어 있지 않습니다.

-- 테이블 litten7.note_message_delivery 구조 내보내기
CREATE TABLE IF NOT EXISTS `note_message_delivery` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '전달 ID',
  `message_id` bigint(20) NOT NULL COMMENT '메시지 ID',
  `recipient_member_id` varchar(128) NOT NULL COMMENT '수신자 회원 ID',
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0 COMMENT '삭제 여부',
  `insert_pk` bigint(20) DEFAULT NULL COMMENT '등록 회원 ID(seq)',
  `update_pk` bigint(20) DEFAULT NULL COMMENT '수정 회원 ID(seq)',
  `insert_date_time` datetime DEFAULT NULL COMMENT '등록일시',
  `update_date_time` datetime DEFAULT NULL COMMENT '수정일시',
  PRIMARY KEY (`id`),
  KEY `idx_msgdlv_recipient` (`recipient_member_id`),
  KEY `idx_msgdlv_message` (`message_id`)
) ENGINE=InnoDB AUTO_INCREMENT=37 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 내보낼 데이터가 선택되어 있지 않습니다.

-- 테이블 litten7.note_prompt_config 구조 내보내기
CREATE TABLE IF NOT EXISTS `note_prompt_config` (
  `sequence` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '설정 PK',
  `type` varchar(20) NOT NULL COMMENT '유형 (summary|remind)',
  `prompt_role` varchar(20) NOT NULL COMMENT '역할 (system|user)',
  `file_type` varchar(50) NOT NULL COMMENT '파일 유형 (youtube|text|pdf|xls|doc|ppt|audio|handwriting)',
  `summary_level` tinyint(4) DEFAULT NULL COMMENT '요약 수준 1~5 (summary용; remind는 NULL)',
  `level_name` varchar(20) DEFAULT NULL COMMENT '수준 코드명',
  `prompt_name` varchar(100) NOT NULL COMMENT '프롬프트 이름',
  `prompt` text DEFAULT NULL COMMENT '실제 프롬프트 내용. 플레이스홀더: {{LEVEL_DETAIL}} {{SOURCE_LANG}} {{OUTPUT_LANG}}',
  `is_active` tinyint(1) NOT NULL DEFAULT 1 COMMENT '활성 여부',
  `description` varchar(500) DEFAULT NULL COMMENT '설명',
  `insert_pk` bigint(20) DEFAULT NULL COMMENT '등록자 FK',
  `update_pk` bigint(20) DEFAULT NULL COMMENT '수정자 FK',
  `insert_date_time` timestamp NOT NULL DEFAULT current_timestamp() COMMENT '등록일시',
  `update_date_time` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp() COMMENT '수정일시',
  `ai_provider` varchar(20) DEFAULT 'openai',
  `ai_model` varchar(100) DEFAULT NULL,
  `max_tokens` int(11) DEFAULT NULL,
  `quiz_max_count` int(11) DEFAULT NULL,
  `quiz_max_group` int(11) DEFAULT NULL,
  `quiz_type_filter` varchar(500) DEFAULT NULL,
  PRIMARY KEY (`sequence`) USING BTREE,
  UNIQUE KEY `unique_type_role_file_level` (`type`,`prompt_role`,`file_type`,`summary_level`) USING BTREE,
  KEY `idx_prompt_type_role_file` (`type`,`prompt_role`,`file_type`) USING BTREE,
  KEY `idx_prompt_active` (`is_active`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=191 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='프롬프트 관리 (요약/리마인드, system/user 통합)';

-- 내보낼 데이터가 선택되어 있지 않습니다.

-- 테이블 litten7.note_prompt_config_copy 구조 내보내기
CREATE TABLE IF NOT EXISTS `note_prompt_config_copy` (
  `sequence` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '설정 PK',
  `type` varchar(20) NOT NULL COMMENT '유형 (summary|remind)',
  `prompt_role` varchar(20) NOT NULL COMMENT '역할 (system|user)',
  `file_type` varchar(50) NOT NULL COMMENT '파일 유형 (youtube|text|pdf|xls|doc|ppt|audio|handwriting)',
  `summary_level` tinyint(4) DEFAULT NULL COMMENT '요약 수준 1~5 (summary용; remind는 NULL)',
  `level_name` varchar(20) DEFAULT NULL COMMENT '수준 코드명',
  `prompt_name` varchar(100) NOT NULL COMMENT '프롬프트 이름',
  `prompt` text DEFAULT NULL COMMENT '실제 프롬프트 내용. 플레이스홀더: {{LEVEL_DETAIL}} {{SOURCE_LANG}} {{OUTPUT_LANG}}',
  `is_active` tinyint(1) NOT NULL DEFAULT 1 COMMENT '활성 여부',
  `description` varchar(500) DEFAULT NULL COMMENT '설명',
  `insert_pk` bigint(20) DEFAULT NULL COMMENT '등록자 FK',
  `update_pk` bigint(20) DEFAULT NULL COMMENT '수정자 FK',
  `insert_date_time` timestamp NOT NULL DEFAULT current_timestamp() COMMENT '등록일시',
  `update_date_time` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp() COMMENT '수정일시',
  `ai_provider` varchar(20) DEFAULT 'openai',
  `ai_model` varchar(100) DEFAULT NULL,
  `max_tokens` int(11) DEFAULT NULL,
  `remind_max_count` int(11) DEFAULT NULL,
  `remind_max_group` int(11) DEFAULT NULL,
  `remind_type_filter` varchar(500) DEFAULT NULL,
  PRIMARY KEY (`sequence`) USING BTREE,
  UNIQUE KEY `unique_type_role_file_level` (`type`,`prompt_role`,`file_type`,`summary_level`) USING BTREE,
  KEY `idx_prompt_type_role_file` (`type`,`prompt_role`,`file_type`) USING BTREE,
  KEY `idx_prompt_active` (`is_active`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=168 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='프롬프트 관리 (요약/리마인드, system/user 통합)';

-- 내보낼 데이터가 선택되어 있지 않습니다.

-- 테이블 litten7.note_quiz_result 구조 내보내기
CREATE TABLE IF NOT EXISTS `note_quiz_result` (
  `sequence` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '결과 PK',
  `summary_result_id` bigint(20) NOT NULL COMMENT 'note_summary_result FK',
  `group_name` varchar(200) NOT NULL COMMENT '1단 그룹명',
  `group_order` int(11) NOT NULL DEFAULT 0 COMMENT '그룹 정렬 순서',
  `item_type` varchar(50) NOT NULL COMMENT '2단 유형 (일정|액션|핵심개념|적용포인트|학습할것|외부대기|리스크|기타)',
  `item_content` text NOT NULL COMMENT '2단 세부항목 내용',
  `assignee` varchar(100) DEFAULT NULL COMMENT '담당자 (없으면 -)',
  `deadline` varchar(100) DEFAULT NULL COMMENT '기한 (없으면 -)',
  `detail_text` text DEFAULT NULL COMMENT '3단 부가 설명 (여러 줄은 \\n 구분)',
  `sort_order` int(11) NOT NULL DEFAULT 0 COMMENT '그룹 내 항목 정렬 순서',
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0 COMMENT '삭제 여부',
  `insert_pk` bigint(20) DEFAULT NULL COMMENT '등록자 FK',
  `update_pk` bigint(20) DEFAULT NULL COMMENT '수정자 FK',
  `insert_date_time` timestamp NOT NULL DEFAULT current_timestamp() COMMENT '등록일시',
  `update_date_time` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp() COMMENT '수정일시',
  PRIMARY KEY (`sequence`) USING BTREE,
  KEY `idx_quiz_result_summary` (`summary_result_id`) USING BTREE,
  KEY `idx_quiz_result_group` (`summary_result_id`,`group_order`,`sort_order`) USING BTREE,
  CONSTRAINT `fk_remind_result_summary` FOREIGN KEY (`summary_result_id`) REFERENCES `note_summary_result` (`sequence`)
) ENGINE=InnoDB AUTO_INCREMENT=97 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='리마인드 항목 결과 (1행 = 1 RemindItem)';

-- 내보낼 데이터가 선택되어 있지 않습니다.

-- 테이블 litten7.note_schedule 구조 내보내기
CREATE TABLE IF NOT EXISTS `note_schedule` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '일정 ID(PK)',
  `member_id` varchar(128) NOT NULL COMMENT '회원 ID',
  `litten_id` varchar(64) NOT NULL COMMENT '일정이 속한 리튼 UUID',
  `title` varchar(512) DEFAULT NULL COMMENT '표시용 리튼 제목(비정규화)',
  `schedule_date` date NOT NULL COMMENT '시작 날짜 (yyyy-MM-dd, 벽시계 기준 floating)',
  `end_date` date DEFAULT NULL COMMENT '종료 날짜 (null이면 당일 일정)',
  `start_time` time NOT NULL COMMENT '시작 시각 (HH:mm)',
  `end_time` time NOT NULL COMMENT '종료 시각 (HH:mm)',
  `notes` text DEFAULT NULL COMMENT '일정 메모',
  `notification_rules` longtext DEFAULT NULL COMMENT '알림 규칙 JSON 배열 (NotificationRule[])',
  `notification_start_time` time DEFAULT NULL COMMENT '알림 허용 시작 시각 (from)',
  `notification_end_time` time DEFAULT NULL COMMENT '알림 허용 종료 시각 (to, null이면 제한 없음)',
  `notification_count` int(11) NOT NULL DEFAULT 0 COMMENT '알림 발생 횟수',
  `schema_version` int(11) NOT NULL DEFAULT 2 COMMENT '일정 데이터 스키마 버전 (LittenSchedule.version)',
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0 COMMENT '삭제 여부 (tombstone)',
  `deleted_at` timestamp NULL DEFAULT NULL COMMENT '삭제 일시',
  `client_updated_at` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '클라이언트 수정일시 (LWW 충돌 해결 기준 = 리튼 updatedAt)',
  `insert_pk` bigint(20) DEFAULT NULL COMMENT '등록 회원 ID(seq)',
  `update_pk` bigint(20) DEFAULT NULL COMMENT '수정 회원 ID(seq)',
  `insert_date_time` datetime DEFAULT NULL COMMENT '등록일시',
  `update_date_time` datetime DEFAULT NULL COMMENT '수정일시',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_schedule_member_litten` (`member_id`,`litten_id`),
  KEY `idx_schedule_member` (`member_id`,`is_deleted`),
  KEY `idx_schedule_date` (`member_id`,`schedule_date`)
) ENGINE=InnoDB AUTO_INCREMENT=30 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='캘린더 일정 (로그인 회원 단위)';

-- 내보낼 데이터가 선택되어 있지 않습니다.

-- 테이블 litten7.note_self_chat 구조 내보내기
CREATE TABLE IF NOT EXISTS `note_self_chat` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '셀프챗 방 ID',
  `member_id` varchar(128) NOT NULL COMMENT '회원 ID',
  `client_id` varchar(64) DEFAULT NULL COMMENT '클라이언트 로컬 방 ID(매칭/중복방지)',
  `name` varchar(100) NOT NULL COMMENT '방 이름',
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0 COMMENT '삭제 여부',
  `deleted_at` timestamp NULL DEFAULT NULL COMMENT '삭제 일시',
  `insert_pk` bigint(20) DEFAULT NULL COMMENT '등록 회원 ID(seq)',
  `update_pk` bigint(20) DEFAULT NULL COMMENT '수정 회원 ID(seq)',
  `insert_date_time` datetime DEFAULT NULL COMMENT '등록일시',
  `update_date_time` datetime DEFAULT NULL COMMENT '수정일시',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_selfchat_member_client` (`member_id`,`client_id`),
  KEY `idx_selfchat_member` (`member_id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 내보낼 데이터가 선택되어 있지 않습니다.

-- 테이블 litten7.note_self_chat_item 구조 내보내기
CREATE TABLE IF NOT EXISTS `note_self_chat_item` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '항목 ID',
  `self_chat_id` bigint(20) NOT NULL COMMENT '셀프챗 방 ID',
  `member_id` varchar(128) NOT NULL COMMENT '회원 ID',
  `item_type` varchar(10) NOT NULL COMMENT 'text | file',
  `content` varchar(2000) DEFAULT NULL COMMENT '텍스트 내용',
  `file_name` varchar(255) DEFAULT NULL COMMENT '파일명',
  `file_type` varchar(20) DEFAULT NULL COMMENT '파일 종류',
  `content_type` varchar(100) DEFAULT NULL COMMENT 'MIME 타입',
  `file_size` bigint(20) DEFAULT NULL COMMENT '파일 크기(bytes)',
  `stored_path` varchar(512) DEFAULT NULL COMMENT '서버 저장 경로',
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0 COMMENT '삭제 여부',
  `insert_pk` bigint(20) DEFAULT NULL COMMENT '등록 회원 ID(seq)',
  `update_pk` bigint(20) DEFAULT NULL COMMENT '수정 회원 ID(seq)',
  `insert_date_time` datetime DEFAULT NULL COMMENT '등록일시',
  `update_date_time` datetime DEFAULT NULL COMMENT '수정일시',
  PRIMARY KEY (`id`),
  KEY `idx_selfitem_chat` (`self_chat_id`)
) ENGINE=InnoDB AUTO_INCREMENT=26 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 내보낼 데이터가 선택되어 있지 않습니다.

-- 테이블 litten7.note_share_group 구조 내보내기
CREATE TABLE IF NOT EXISTS `note_share_group` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '그룹 ID',
  `owner_member_id` varchar(128) NOT NULL COMMENT '그룹 소유자 회원 ID',
  `name` varchar(100) NOT NULL COMMENT '그룹 이름',
  `password` varchar(128) DEFAULT NULL COMMENT '그룹 비밀번호',
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0 COMMENT '삭제 여부',
  `deleted_at` timestamp NULL DEFAULT NULL COMMENT '삭제 일시',
  `insert_pk` bigint(20) DEFAULT NULL,
  `update_pk` bigint(20) DEFAULT NULL,
  `insert_date_time` datetime DEFAULT NULL,
  `update_date_time` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_group_owner` (`owner_member_id`,`is_deleted`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='공유 그룹';

-- 내보낼 데이터가 선택되어 있지 않습니다.

-- 테이블 litten7.note_share_group_member 구조 내보내기
CREATE TABLE IF NOT EXISTS `note_share_group_member` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '그룹 멤버 ID',
  `group_id` bigint(20) NOT NULL COMMENT '그룹 ID',
  `member_id` varchar(128) NOT NULL COMMENT '멤버 회원 ID(수신 대상)',
  `member_name` varchar(100) DEFAULT NULL COMMENT '표시 이름(스냅샷)',
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0 COMMENT '삭제 여부',
  `insert_pk` bigint(20) DEFAULT NULL,
  `update_pk` bigint(20) DEFAULT NULL,
  `insert_date_time` datetime DEFAULT NULL,
  `update_date_time` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_group_member` (`group_id`,`member_id`),
  KEY `idx_gm_group` (`group_id`,`is_deleted`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='공유 그룹 멤버';

-- 내보낼 데이터가 선택되어 있지 않습니다.

-- 테이블 litten7.note_summary_result 구조 내보내기
CREATE TABLE IF NOT EXISTS `note_summary_result` (
  `sequence` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '결과 PK',
  `config_id` bigint(20) DEFAULT NULL COMMENT 'note_summary_config FK (NULL=config 없음)',
  `file_type` varchar(50) NOT NULL COMMENT '파일 유형',
  `file_uuid` varchar(64) DEFAULT NULL COMMENT '파일 UUID (text/handwriting/audio용)',
  `youtube_video_id` varchar(50) DEFAULT NULL COMMENT '유튜브 영상 ID (youtube용)',
  `member_uuid` varchar(64) DEFAULT NULL COMMENT '회원 UUID (개인 파일; 공유=NULL)',
  `is_shared` tinyint(1) NOT NULL DEFAULT 0 COMMENT '공유 여부 (1=공통/유튜브, 0=개인)',
  `source_text` longtext DEFAULT NULL COMMENT '원본 텍스트 (자막/OCR/STT 결과)',
  `summary_level` tinyint(4) NOT NULL DEFAULT 3 COMMENT '실제 적용된 요약 수준 1~5',
  `summary_full` longtext DEFAULT NULL COMMENT 'AI 응답 전체 텍스트 (요약+리마인드)',
  `summary_only` longtext DEFAULT NULL COMMENT '순수 요약 텍스트 (리마인드 구분선 이전)',
  `total_quiz_count` int(11) NOT NULL DEFAULT 0 COMMENT '리마인드 총 세부항목 수 (빠른 조회용)',
  `status` varchar(20) NOT NULL DEFAULT 'pending' COMMENT '처리 상태 (pending|done|error)',
  `error_message` varchar(1024) DEFAULT NULL COMMENT '오류 메시지',
  `processed_at` timestamp NULL DEFAULT NULL COMMENT '처리 완료일시',
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0 COMMENT '삭제 여부',
  `deleted_date_time` timestamp NULL DEFAULT NULL COMMENT '삭제 일시',
  `insert_pk` bigint(20) DEFAULT NULL COMMENT '등록자 FK',
  `update_pk` bigint(20) DEFAULT NULL COMMENT '수정자 FK',
  `insert_date_time` timestamp NOT NULL DEFAULT current_timestamp() COMMENT '등록일시',
  `update_date_time` timestamp NULL DEFAULT NULL ON UPDATE current_timestamp() COMMENT '수정일시',
  PRIMARY KEY (`sequence`) USING BTREE,
  UNIQUE KEY `unique_youtube_video` (`youtube_video_id`,`summary_level`) USING BTREE,
  UNIQUE KEY `unique_file_member` (`file_uuid`,`member_uuid`,`summary_level`) USING BTREE,
  KEY `idx_file_type_status` (`file_type`,`status`) USING BTREE,
  KEY `idx_member_uuid` (`member_uuid`) USING BTREE,
  KEY `idx_is_shared` (`is_shared`) USING BTREE,
  KEY `idx_config_id` (`config_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=122 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='파일별 요약/리마인드 처리 결과';

-- 내보낼 데이터가 선택되어 있지 않습니다.

-- 테이블 litten7.tbl_admin_user 구조 내보내기
CREATE TABLE IF NOT EXISTS `tbl_admin_user` (
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

-- 내보낼 데이터가 선택되어 있지 않습니다.

-- 테이블 litten7.youtube_channel 구조 내보내기
CREATE TABLE IF NOT EXISTS `youtube_channel` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `channel_id` varchar(64) NOT NULL COMMENT '유튜브 채널 ID',
  `channel_name` varchar(256) NOT NULL COMMENT '채널명',
  `channel_thumbnail` varchar(512) DEFAULT NULL COMMENT '채널 썸네일 URL',
  `insert_pk` bigint(20) DEFAULT NULL,
  `update_pk` bigint(20) DEFAULT NULL,
  `update_date_time` datetime DEFAULT NULL,
  `insert_date_time` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=26 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 내보낼 데이터가 선택되어 있지 않습니다.

-- 테이블 litten7.youtube_video 구조 내보내기
CREATE TABLE IF NOT EXISTS `youtube_video` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `channel_id` varchar(64) NOT NULL COMMENT '유튜브 채널 ID',
  `video_id` varchar(32) NOT NULL COMMENT '유튜브 영상 ID',
  `title` varchar(512) NOT NULL COMMENT '영상 제목',
  `published_at` datetime DEFAULT NULL COMMENT '영상 게시일시',
  `transcript_text` longtext DEFAULT NULL COMMENT '추출된 자막 텍스트',
  `summary` longtext DEFAULT NULL COMMENT 'AI 요약 결과',
  `status` varchar(32) NOT NULL DEFAULT 'pending' COMMENT '처리 상태',
  `error_message` varchar(1024) DEFAULT NULL COMMENT '오류 메시지',
  `processed_at` datetime DEFAULT NULL COMMENT '처리 완료일시',
  `insert_pk` bigint(20) DEFAULT NULL,
  `update_pk` bigint(20) DEFAULT NULL,
  `update_date_time` datetime DEFAULT NULL,
  `insert_date_time` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_video_id` (`video_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3011 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 내보낼 데이터가 선택되어 있지 않습니다.

/*!40103 SET TIME_ZONE=IFNULL(@OLD_TIME_ZONE, 'system') */;
/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IFNULL(@OLD_FOREIGN_KEY_CHECKS, 1) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40111 SET SQL_NOTES=IFNULL(@OLD_SQL_NOTES, 1) */;

-- --------------------------------------------------------
-- 호스트:                          localhost
-- 서버 버전:                        10.11.2-MariaDB - mariadb.org binary distribution
-- 서버 OS:                        Win64
-- HeidiSQL 버전:                  11.0.0.5919
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;


-- litten 데이터베이스 구조 내보내기
CREATE DATABASE IF NOT EXISTS `litten` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci */;
USE `litten`;

-- 테이블 litten.note_member 구조 내보내기
DROP TABLE IF EXISTS `note_member`;
CREATE TABLE IF NOT EXISTS `note_member` (
  `sequence` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '회원pk',
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
  `state_code` varchar(64) DEFAULT NULL COMMENT '활성화 상태',
  `insert_date_time` timestamp NULL DEFAULT current_timestamp() COMMENT '[직원]등록일시',
  `update_pk` bigint(20) DEFAULT NULL COMMENT '[직원]수정자 fk',
  `update_date_time` timestamp NULL DEFAULT NULL COMMENT '[직원]수정일시',
  `insert_pk` bigint(20) DEFAULT NULL COMMENT '[직원]등록자 fk',
  PRIMARY KEY (`sequence`) USING BTREE,
  KEY `index_of_id` (`id`) USING BTREE,
  KEY `index_of_uuid` (`uuid`) USING BTREE,
  KEY `index_of_mobile` (`mobile`),
  KEY `index_of_email` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='회원';

-- 테이블 데이터 litten.note_member:~0 rows (대략적) 내보내기
DELETE FROM `note_member`;
/*!40000 ALTER TABLE `note_member` DISABLE KEYS */;
INSERT INTO `note_member` (`sequence`, `uuid`, `id`, `password`, `id_insert_date_time`, `is_change_password`, `change_password_date_time`, `name`, `name_english`, `mobile`, `mobile_type`, `mobile_verify_date_time`, `email`, `state_code`, `insert_date_time`, `update_pk`, `update_date_time`, `insert_pk`) VALUES
	(4, 'sdajf-asdjfls-02394iowjfi-sadj1', 'sdajf-asdjfls-02394iowjfi-sadj1', NULL, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'install', '2025-10-09 19:00:09', NULL, NULL, NULL),
	(6, 'sdajf-asdjfls-02394iowjfi-sadj1', 'bgso777@naver.com', '{bcrypt}$2a$10$2oGwLy/be3IL29yhgDtDcevjaRVtNN/CLHYaZNEpmo.l7v/vhFOaC', NULL, 1, '2025-10-09 21:19:18', NULL, NULL, NULL, NULL, NULL, NULL, 'withdraw', '2025-10-09 19:03:39', NULL, '2025-10-09 22:12:28', NULL);
/*!40000 ALTER TABLE `note_member` ENABLE KEYS */;

/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IF(@OLD_FOREIGN_KEY_CHECKS IS NULL, 1, @OLD_FOREIGN_KEY_CHECKS) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;

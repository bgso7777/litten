-- ============================================================
-- 마이그레이션: 2026-05-03
-- ============================================================

-- -------------------------------------------------------
-- 1. note_member: state_code → state 컬럼명 변경
--    엔티티(NoteMemberCommon.java)가 'state' 컬럼을 매핑하므로 DB 컬럼명을 맞춤
-- -------------------------------------------------------
ALTER TABLE `note_member`
    CHANGE COLUMN `state_code` `state` VARCHAR(64) NULL DEFAULT NULL COMMENT '상태';

-- note_member_log 동일하게 변경
ALTER TABLE `note_member_log`
    CHANGE COLUMN `state_code` `state` VARCHAR(64) NULL DEFAULT NULL COMMENT '상태';


-- -------------------------------------------------------
-- 2. note_member: subscription_plan 컬럼 추가
-- -------------------------------------------------------
ALTER TABLE `note_member`
    ADD COLUMN `subscription_plan` VARCHAR(20) NOT NULL DEFAULT 'free' COMMENT '구독 플랜 (free/standard/premium)'
    AFTER `state`;


-- -------------------------------------------------------
-- 3. note_member: plan_expired_at 컬럼 추가
-- -------------------------------------------------------
ALTER TABLE `note_member`
    ADD COLUMN `plan_expired_at` TIMESTAMP NULL DEFAULT NULL COMMENT '플랜 만료일시'
    AFTER `subscription_plan`;


-- -------------------------------------------------------
-- 4. cloud_file 테이블 생성 (CloudFile.java + BaseEntity)
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS `cloud_file` (
    `id`              BIGINT(20)    NOT NULL AUTO_INCREMENT COMMENT '파일 ID',
    `member_id`       VARCHAR(128)  NOT NULL               COMMENT '회원 ID',
    `litten_id`       VARCHAR(128)  NOT NULL               COMMENT '리튼 ID',
    `local_id`        VARCHAR(128)  NOT NULL               COMMENT '로컬 파일 ID',
    `file_type`       VARCHAR(20)   NOT NULL               COMMENT '파일 유형 (audio/text/handwriting)',
    `file_name`       VARCHAR(255)  NOT NULL               COMMENT '파일명',
    `file_path`       VARCHAR(512)  NULL DEFAULT NULL      COMMENT '서버 저장 경로',
    `file_size`       BIGINT(20)    NULL DEFAULT 0         COMMENT '파일 크기(bytes)',
    `content_type`    VARCHAR(100)  NULL DEFAULT NULL      COMMENT 'MIME 타입',
    `is_deleted`      TINYINT(1)    NOT NULL DEFAULT 0     COMMENT '삭제 여부',
    `deleted_at`      TIMESTAMP     NULL DEFAULT NULL      COMMENT '삭제 일시',
    `local_updated_at` TIMESTAMP   NOT NULL               COMMENT '로컬 파일 수정일시 (동기화 비교용)',
    -- BaseEntity 컬럼
    `insert_pk`       BIGINT(20)    NULL DEFAULT NULL      COMMENT '등록 회원 ID(seq)',
    `update_pk`       BIGINT(20)    NULL DEFAULT NULL      COMMENT '수정 회원 ID(seq)',
    `insert_date_time` DATETIME     NULL                   COMMENT '등록일시',
    `update_date_time` DATETIME     NULL                   COMMENT '수정일시',
    PRIMARY KEY (`id`) USING BTREE,
    INDEX `idx_member_id`  (`member_id`),
    INDEX `idx_litten_id`  (`litten_id`),
    INDEX `idx_local_id`   (`local_id`),
    INDEX `idx_is_deleted` (`is_deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='클라우드 파일';


-- -------------------------------------------------------
-- 5. cloud_file_backup 테이블 생성 (CloudFileBackup.java)
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS `cloud_file_backup` (
    `id`            BIGINT(20)   NOT NULL AUTO_INCREMENT COMMENT '백업 ID',
    `cloud_file_id` BIGINT(20)   NOT NULL               COMMENT '원본 cloud_file ID',
    `backup_path`   VARCHAR(512) NOT NULL               COMMENT '백업 파일 경로',
    `file_size`     BIGINT(20)   NULL DEFAULT 0         COMMENT '백업 파일 크기(bytes)',
    `backed_up_at`  TIMESTAMP    NOT NULL               COMMENT '백업 일시',
    PRIMARY KEY (`id`) USING BTREE,
    INDEX `idx_cloud_file_id` (`cloud_file_id`),
    CONSTRAINT `fk_backup_cloud_file`
        FOREIGN KEY (`cloud_file_id`) REFERENCES `cloud_file` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='클라우드 파일 백업';

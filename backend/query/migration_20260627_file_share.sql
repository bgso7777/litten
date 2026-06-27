-- ============================================================================
-- 사용자 간 파일 공유 + 공유 그룹 (2026-06-27)
--   note_share_group         : 공유 그룹 (소유자 단위)
--   note_share_group_member  : 그룹 멤버 (수신 대상 회원)
--   note_file_share          : 공유 1건 (발신자 + 대상[개인/그룹] + 파일 본문 메타)
--   note_file_share_delivery : 공유의 수신자별 전달/응답 (수락/거절)
-- 회원 식별: note_member.id (로그인 계정 id) = member_id
-- ============================================================================

CREATE TABLE IF NOT EXISTS `note_share_group` (
    `id`              BIGINT(20)   NOT NULL AUTO_INCREMENT COMMENT '그룹 ID',
    `owner_member_id` VARCHAR(128) NOT NULL COMMENT '그룹 소유자 회원 ID',
    `name`            VARCHAR(100) NOT NULL COMMENT '그룹 이름',
    `password`        VARCHAR(128) NULL DEFAULT NULL COMMENT '그룹 비밀번호',
    `is_deleted`      TINYINT(1)   NOT NULL DEFAULT 0 COMMENT '삭제 여부',
    `deleted_at`      TIMESTAMP    NULL DEFAULT NULL COMMENT '삭제 일시',
    `insert_pk`       BIGINT(20)   NULL DEFAULT NULL,
    `update_pk`       BIGINT(20)   NULL DEFAULT NULL,
    `insert_date_time` DATETIME    NULL,
    `update_date_time` DATETIME    NULL,
    PRIMARY KEY (`id`),
    INDEX `idx_group_owner` (`owner_member_id`, `is_deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='공유 그룹';

CREATE TABLE IF NOT EXISTS `note_share_group_member` (
    `id`          BIGINT(20)   NOT NULL AUTO_INCREMENT COMMENT '그룹 멤버 ID',
    `group_id`    BIGINT(20)   NOT NULL COMMENT '그룹 ID',
    `member_id`   VARCHAR(128) NOT NULL COMMENT '멤버 회원 ID(수신 대상)',
    `member_name` VARCHAR(100) NULL DEFAULT NULL COMMENT '표시 이름(스냅샷)',
    `is_deleted`  TINYINT(1)   NOT NULL DEFAULT 0 COMMENT '삭제 여부',
    `insert_pk`   BIGINT(20)   NULL DEFAULT NULL,
    `update_pk`   BIGINT(20)   NULL DEFAULT NULL,
    `insert_date_time` DATETIME NULL,
    `update_date_time` DATETIME NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_group_member` (`group_id`, `member_id`),
    INDEX `idx_gm_group` (`group_id`, `is_deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='공유 그룹 멤버';

CREATE TABLE IF NOT EXISTS `note_file_share` (
    `id`               BIGINT(20)   NOT NULL AUTO_INCREMENT COMMENT '공유 ID',
    `sender_member_id` VARCHAR(128) NOT NULL COMMENT '발신자 회원 ID',
    `sender_name`      VARCHAR(100) NULL DEFAULT NULL COMMENT '발신자 표시 이름(스냅샷)',
    `target_type`      VARCHAR(10)  NOT NULL COMMENT '대상 유형 (user/group)',
    `group_id`         BIGINT(20)   NULL DEFAULT NULL COMMENT '그룹 ID(group일 때)',
    `group_name`       VARCHAR(100) NULL DEFAULT NULL COMMENT '그룹 이름(스냅샷)',
    `litten_title`     VARCHAR(255) NULL DEFAULT NULL COMMENT '원본 리튼 이름(표시용)',
    `file_type`        VARCHAR(20)  NOT NULL COMMENT '파일 유형 (text/audio/handwriting/attachment)',
    `file_name`        VARCHAR(255) NOT NULL COMMENT '파일명',
    `content_type`     VARCHAR(100) NULL DEFAULT NULL COMMENT 'MIME 타입',
    `file_size`        BIGINT(20)   NULL DEFAULT 0 COMMENT '파일 크기(bytes)',
    `stored_path`      VARCHAR(512) NULL DEFAULT NULL COMMENT '공유 저장소 경로',
    `message`          VARCHAR(500) NULL DEFAULT NULL COMMENT '보낸 메시지',
    `is_deleted`       TINYINT(1)   NOT NULL DEFAULT 0 COMMENT '삭제/취소 여부',
    `deleted_at`       TIMESTAMP    NULL DEFAULT NULL COMMENT '삭제/취소 일시',
    `insert_pk`        BIGINT(20)   NULL DEFAULT NULL,
    `update_pk`        BIGINT(20)   NULL DEFAULT NULL,
    `insert_date_time` DATETIME     NULL,
    `update_date_time` DATETIME     NULL,
    PRIMARY KEY (`id`),
    INDEX `idx_share_sender` (`sender_member_id`, `is_deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='파일 공유';

CREATE TABLE IF NOT EXISTS `note_file_share_delivery` (
    `id`                  BIGINT(20)   NOT NULL AUTO_INCREMENT COMMENT '전달 ID',
    `share_id`            BIGINT(20)   NOT NULL COMMENT '공유 ID',
    `recipient_member_id` VARCHAR(128) NOT NULL COMMENT '수신자 회원 ID',
    `status`              VARCHAR(10)  NOT NULL DEFAULT 'pending' COMMENT '상태 (pending/accepted/rejected)',
    `responded_at`        TIMESTAMP    NULL DEFAULT NULL COMMENT '응답 일시',
    `is_deleted`          TINYINT(1)   NOT NULL DEFAULT 0 COMMENT '삭제/취소 여부',
    `insert_pk`           BIGINT(20)   NULL DEFAULT NULL,
    `update_pk`           BIGINT(20)   NULL DEFAULT NULL,
    `insert_date_time`    DATETIME     NULL,
    `update_date_time`    DATETIME     NULL,
    PRIMARY KEY (`id`),
    INDEX `idx_delivery_recipient` (`recipient_member_id`, `is_deleted`, `status`),
    INDEX `idx_delivery_share` (`share_id`, `is_deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='파일 공유 전달(수신자별)';

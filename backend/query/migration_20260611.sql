-- ============================================================
-- 마이그레이션: 2026-06-11
-- 캘린더 일정 전용 테이블 note_schedule 신설
--
-- 배경:
--   - 기존엔 일정(LittenSchedule)이 리튼(Litten.toJson)의 일부로 note_litten.extra_json
--     blob에만 들어가, 프리미엄(파일 동기화) 게이트에 묶여 있었다.
--   - 캘린더를 "로그인 기준 독립 기능"으로 분리: 비로그인=로컬 저장 / 로그인=서버 저장.
--   - 일정만 독립적으로 로그인 기준 서버 CRUD 하기 위해 전용 테이블을 둔다.
--
-- 설계 원칙:
--   - 일정은 리튼당 0..1개 → (member_id, litten_id) UNIQUE.
--   - 캘린더 날짜 조회/필터를 위해 schedule_date/end_date는 컬럼으로 펼친다(정규화).
--   - 알림 규칙(NotificationRule[])은 가변 구조라 JSON(LONGTEXT)으로 보관.
--   - 충돌 해결: client_updated_at 기준 LWW (note_litten과 동일).
--   - 삭제: is_deleted/deleted_at tombstone 으로 다른 기기에 삭제 전파.
--   - title은 캘린더 표시용 비정규화 컬럼(리튼 제목 복제) — 일정만 받아도 목록 렌더 가능.
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS `note_schedule` (
    `id`                      BIGINT(20)   NOT NULL AUTO_INCREMENT COMMENT '일정 ID(PK)',
    `member_id`               VARCHAR(128) NOT NULL               COMMENT '회원 ID',
    `litten_id`               VARCHAR(64)  NOT NULL               COMMENT '일정이 속한 리튼 UUID',
    `title`                   VARCHAR(512) NULL DEFAULT NULL      COMMENT '표시용 리튼 제목(비정규화)',
    `schedule_date`           DATE         NOT NULL               COMMENT '시작 날짜 (yyyy-MM-dd, 벽시계 기준 floating)',
    `end_date`                DATE         NULL DEFAULT NULL      COMMENT '종료 날짜 (null이면 당일 일정)',
    `start_time`              TIME         NOT NULL               COMMENT '시작 시각 (HH:mm)',
    `end_time`                TIME         NOT NULL               COMMENT '종료 시각 (HH:mm)',
    `notes`                   TEXT         NULL DEFAULT NULL      COMMENT '일정 메모',
    `notification_rules`      LONGTEXT     NULL DEFAULT NULL      COMMENT '알림 규칙 JSON 배열 (NotificationRule[])',
    `notification_start_time` TIME         NULL DEFAULT NULL      COMMENT '알림 허용 시작 시각 (from)',
    `notification_end_time`   TIME         NULL DEFAULT NULL      COMMENT '알림 허용 종료 시각 (to, null이면 제한 없음)',
    `notification_count`      INT          NOT NULL DEFAULT 0     COMMENT '알림 발생 횟수',
    `schema_version`          INT          NOT NULL DEFAULT 2     COMMENT '일정 데이터 스키마 버전 (LittenSchedule.version)',
    `is_deleted`              TINYINT(1)   NOT NULL DEFAULT 0     COMMENT '삭제 여부 (tombstone)',
    `deleted_at`              TIMESTAMP    NULL DEFAULT NULL      COMMENT '삭제 일시',
    `client_updated_at`       TIMESTAMP    NOT NULL               COMMENT '클라이언트 수정일시 (LWW 충돌 해결 기준 = 리튼 updatedAt)',
    -- BaseEntity 컬럼
    `insert_pk`               BIGINT(20)   NULL DEFAULT NULL      COMMENT '등록 회원 ID(seq)',
    `update_pk`               BIGINT(20)   NULL DEFAULT NULL      COMMENT '수정 회원 ID(seq)',
    `insert_date_time`        DATETIME     NULL                   COMMENT '등록일시',
    `update_date_time`        DATETIME     NULL                   COMMENT '수정일시',
    PRIMARY KEY (`id`) USING BTREE,
    UNIQUE KEY `uk_schedule_member_litten` (`member_id`, `litten_id`),
    INDEX `idx_schedule_member`  (`member_id`, `is_deleted`),
    INDEX `idx_schedule_date`    (`member_id`, `schedule_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='캘린더 일정 (로그인 회원 단위)';

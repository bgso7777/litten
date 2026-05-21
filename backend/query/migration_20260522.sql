-- ============================================================
-- 마이그레이션: 2026-05-22
-- note_member: 다중 디바이스 로그인 지원 — 최대 3대 (uuid1, uuid2, uuid3 슬롯)
-- ============================================================

-- uuid1, uuid2, uuid3 컬럼 추가 (기존 uuid 컬럼은 가입 디바이스 기록용으로 그대로 유지)
ALTER TABLE `note_member`
    ADD COLUMN `uuid1` VARCHAR(64) NULL DEFAULT NULL COMMENT '로그인 디바이스 UUID 1' AFTER `uuid`,
    ADD COLUMN `uuid2` VARCHAR(64) NULL DEFAULT NULL COMMENT '로그인 디바이스 UUID 2' AFTER `uuid1`,
    ADD COLUMN `uuid3` VARCHAR(64) NULL DEFAULT NULL COMMENT '로그인 디바이스 UUID 3' AFTER `uuid2`;

-- 기존 회원의 가입 UUID를 첫 슬롯(uuid1)에 복사 — 기존 디바이스 그대로 로그인 가능하게 보장
UPDATE `note_member`
SET `uuid1` = `uuid`
WHERE `uuid1` IS NULL AND `uuid` IS NOT NULL;

-- 공유 그룹에 비밀번호 컬럼 추가 (이미 note_share_group 생성된 DB용)
-- 신규 설치는 migration_20260627_file_share.sql에 이미 포함됨.
ALTER TABLE `note_share_group`
    ADD COLUMN `password` VARCHAR(128) NULL DEFAULT NULL COMMENT '그룹 비밀번호' AFTER `name`;

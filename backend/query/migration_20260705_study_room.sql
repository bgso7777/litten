-- =====================================================================
-- 채팅/메시지 도메인 → 스터디룸(Study Room) 전면 리네임 마이그레이션 (2026-07-05)
--
-- 백엔드 코드(패키지/엔티티/@Table/@Column/엔드포인트)가 스터디룸 도메인으로
-- 전면 리네임됨에 따라 DB 테이블/컬럼 물리명을 코드와 1:1로 맞춘다.
--
--   note.share    → note.studyroom          (ShareGroup→StudyRoom, FileShare→RoomShare ...)
--   note.message  → note.studyroom.message  (NoteMessage→RoomMessage ...)
--   note.selfchat → note.selfroom           (SelfChat→SelfStudyRoom ...)
--   note.hidden   → note.hiddenroom         (HiddenConversation→HiddenRoom)
--
-- ⚠️ 배포 순서: 이 마이그레이션 적용 → 백엔드 WAR 재배포 → 앱 배포
--    (ddl-auto: none 이라 코드만 바뀌고 DB 이름이 안 맞으면 조회 실패)
-- ⚠️ MariaDB 10.5.2+ 필요 (RENAME TABLE / CHANGE COLUMN). FK 없음·무손실.
-- ⚠️ 적용 전 대상 테이블 mysqldump 백업 권장.
--
-- 동결(변경 안 함): target_type 값 'user'/'group', conv_key 접두사 'u:'/'g:',
--   message_id / share_id / member_id / owner_member_id / sender_member_id /
--   client_id / stored_path / file_* / group_name 컬럼.
-- =====================================================================

-- =====================================================================
-- Forward (적용)
-- =====================================================================

-- 1) 테이블 리네임 (9개)
RENAME TABLE `note_share_group`          TO `note_study_room`;
RENAME TABLE `note_share_group_member`   TO `note_study_room_member`;
RENAME TABLE `note_file_share`           TO `note_room_share`;
RENAME TABLE `note_file_share_delivery`  TO `note_room_share_delivery`;
RENAME TABLE `note_message`              TO `note_room_message`;
RENAME TABLE `note_message_delivery`     TO `note_room_message_delivery`;
RENAME TABLE `note_self_chat`            TO `note_self_study_room`;
RENAME TABLE `note_self_chat_item`       TO `note_self_study_room_item`;
RENAME TABLE `note_hidden_conversation`  TO `note_hidden_room`;

-- 2) 컬럼 리네임 (group_id / self_chat_id → room_id)
--    엔티티 @Column 정의와 1:1 일치.
ALTER TABLE `note_study_room_member`
    CHANGE COLUMN `group_id` `room_id` BIGINT(20) NOT NULL COMMENT '룸 ID';

ALTER TABLE `note_room_message`
    CHANGE COLUMN `group_id` `room_id` BIGINT(20) NULL DEFAULT NULL COMMENT '룸 ID(group일 때)';

ALTER TABLE `note_room_share`
    CHANGE COLUMN `group_id` `room_id` BIGINT(20) NULL DEFAULT NULL COMMENT '룸 ID(group일 때)';

ALTER TABLE `note_self_study_room_item`
    CHANGE COLUMN `self_chat_id` `room_id` BIGINT(20) NOT NULL COMMENT '나만의 스터디룸 ID';

-- (선택) 인덱스명은 코드/JPA 동작과 무관하므로 그대로 둔다.
--   uk_member_conv 유니크(member_id, conv_key)는 컬럼명이 유지되어 그대로 유효.


-- =====================================================================
-- Rollback (역순 복구) — 필요 시 아래 블록만 실행
-- =====================================================================
/*
-- 2') 컬럼 원복 (room_id → group_id / self_chat_id)
ALTER TABLE `note_self_study_room_item`
    CHANGE COLUMN `room_id` `self_chat_id` BIGINT(20) NOT NULL COMMENT '셀프챗 방 ID';

ALTER TABLE `note_room_share`
    CHANGE COLUMN `room_id` `group_id` BIGINT(20) NULL DEFAULT NULL COMMENT '그룹 ID(group일 때)';

ALTER TABLE `note_room_message`
    CHANGE COLUMN `room_id` `group_id` BIGINT(20) NULL DEFAULT NULL COMMENT '그룹 ID(group일 때)';

ALTER TABLE `note_study_room_member`
    CHANGE COLUMN `room_id` `group_id` BIGINT(20) NOT NULL COMMENT '그룹 ID';

-- 1') 테이블 원복 (9개)
RENAME TABLE `note_hidden_room`          TO `note_hidden_conversation`;
RENAME TABLE `note_self_study_room_item` TO `note_self_chat_item`;
RENAME TABLE `note_self_study_room`      TO `note_self_chat`;
RENAME TABLE `note_room_message_delivery` TO `note_message_delivery`;
RENAME TABLE `note_room_message`         TO `note_message`;
RENAME TABLE `note_room_share_delivery`  TO `note_file_share_delivery`;
RENAME TABLE `note_room_share`           TO `note_file_share`;
RENAME TABLE `note_study_room_member`    TO `note_share_group_member`;
RENAME TABLE `note_study_room`           TO `note_share_group`;
*/

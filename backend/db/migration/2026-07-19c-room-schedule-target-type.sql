-- 셀 일정을 1:1·나만의 셀까지 확장 (2026-07-19)
--
-- 셀 종류마다 실체 테이블이 달라 키를 따로 둔다.
--   group : room_id        (note_study_room)      — 방장/멤버 전원의 캘린더
--   self  : self_room_id   (note_self_study_room) — 본인만
--   user  : peer_member_id (1:1 — 전용 테이블 없음) — 작성자와 상대 둘 다
--
-- target_type DEFAULT 'group' + room_id NULL 허용으로,
-- 이미 들어간 그룹 일정 행은 수정 없이 그대로 유효하다.
--
-- 선행 조건: 2026-07-19b-room-schedule.sql
ALTER TABLE note_room_schedule
  ADD COLUMN target_type    VARCHAR(16)  NOT NULL DEFAULT 'group' COMMENT '셀 종류(group/self/user)' AFTER id,
  ADD COLUMN self_room_id   BIGINT       NULL DEFAULT NULL        COMMENT '나만의 셀 ID' AFTER room_id,
  ADD COLUMN peer_member_id VARCHAR(128) NULL DEFAULT NULL        COMMENT '1:1 상대 회원 ID' AFTER self_room_id,
  MODIFY COLUMN room_id     BIGINT       NULL DEFAULT NULL        COMMENT '그룹 셀(룸) ID';

-- 종류별 조회 인덱스
ALTER TABLE note_room_schedule
  ADD KEY idx_room_schedule_self (target_type, self_room_id, is_deleted),
  ADD KEY idx_room_schedule_peer (target_type, peer_member_id, is_deleted),
  ADD KEY idx_room_schedule_creator (target_type, creator_member_id, is_deleted);

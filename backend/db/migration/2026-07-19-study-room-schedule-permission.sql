-- 셀(스터디룸) 일정 생성 권한 옵션 추가 (2026-07-19)
-- allow_member_schedule : 멤버도 셀 일정 생성 가능 (기본 차단 — 방장만)
--
-- allow_member_chat / allow_member_file 과 동일한 룸 단위 옵션이다.
-- 멤버별 role 컬럼은 두지 않으며, 방장 여부는 note_study_room.owner_member_id 로 판정한다.
ALTER TABLE note_study_room
  ADD COLUMN allow_member_schedule TINYINT(1) NOT NULL DEFAULT 0 COMMENT '멤버 일정 생성 허용 여부' AFTER allow_member_file;

-- 백필하지 않는다.
-- 셀 일정 기능 자체가 이번에 신설되는 것이라 "종전 동작"이 존재하지 않으므로,
-- 기존 룸도 신규 룸과 동일하게 기본값 0(방장만 일정 생성)을 그대로 적용한다.
-- (참고: 2026-07-18 마이그레이션에서 allow_member_file 을 1 로 백필한 것은
--  그 이전까지 멤버 누구나 자료를 추가할 수 있었기 때문이며, 일정은 해당되지 않는다.)

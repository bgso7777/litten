-- 스터디룸 멤버 권한 옵션 추가 (2026-07-18)
-- allow_member_chat : 멤버도 대화 가능 (기본 허용)
-- allow_member_file : 멤버도 자료 추가 가능 (기본 차단 — 방장만)
ALTER TABLE note_study_room
  ADD COLUMN allow_member_chat TINYINT(1) NOT NULL DEFAULT 1 COMMENT '멤버 대화 허용 여부' AFTER password,
  ADD COLUMN allow_member_file TINYINT(1) NOT NULL DEFAULT 0 COMMENT '멤버 파일 추가 허용 여부' AFTER allow_member_chat;

-- 기존 룸은 종전 동작(멤버 누구나 자료 추가 가능)을 유지하도록 백필한다.
-- 신규 룸부터 기본값 0(방장만)이 적용된다. 이 UPDATE 는 컬럼 추가 직후 1회만 실행할 것.
UPDATE note_study_room SET allow_member_file = 1;

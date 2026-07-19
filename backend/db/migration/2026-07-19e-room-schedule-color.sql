-- 셀 일정에 색상 선택 저장 (2026-07-19)
--
-- 캘린더의 일정 등록 창처럼 셀 일정에도 색을 고를 수 있게 한다.
-- 값은 프론트 AppColors.scheduleColors 의 인덱스(0=기본).
--
-- 참고: 개인 일정(note_schedule)에는 colorIndex 컬럼이 없어 기기 간 색이 동기화되지 않는다.
--       셀 일정은 처음부터 서버에 저장하므로 모든 멤버가 같은 색으로 본다.
--
-- 선행 조건: 2026-07-19d-room-schedule-notification.sql
ALTER TABLE note_room_schedule
  ADD COLUMN color_index INT NOT NULL DEFAULT 0 COMMENT '일정 색상 인덱스' AFTER notification_end_time;

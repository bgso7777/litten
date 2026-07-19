-- 셀 일정에 알림 설정 저장 (2026-07-19)
--
-- 셀 일정 입력 화면을 캘린더의 일정 등록 창(SchedulePicker)과 동일하게 쓰기 위해,
-- 개인 일정(note_schedule)과 같은 알림 컬럼을 갖춘다.
-- 컬럼이 없으면 사용자가 설정한 알림이 저장되지 않고 조용히 사라진다.
--
-- 선행 조건: 2026-07-19c-room-schedule-target-type.sql
ALTER TABLE note_room_schedule
  ADD COLUMN notification_rules      LONGTEXT NULL DEFAULT NULL COMMENT '알림 규칙(JSON 배열)' AFTER notes,
  ADD COLUMN notification_start_time TIME     NULL DEFAULT NULL COMMENT '알림 허용 시작 시각' AFTER notification_rules,
  ADD COLUMN notification_end_time   TIME     NULL DEFAULT NULL COMMENT '알림 허용 종료 시각' AFTER notification_start_time;

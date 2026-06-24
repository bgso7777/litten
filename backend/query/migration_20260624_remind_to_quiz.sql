-- =====================================================================
-- 리마인드 → 퀴즈 리네임 마이그레이션 (2026-06-24)
--
-- 코드(엔티티/엔드포인트/JSON)에서 remind → quiz 로 전면 변경됨에 따라
-- DB 테이블명/인덱스명/컬럼명을 맞춘다.
--
-- ⚠️ 배포 순서: 이 마이그레이션 적용 → 백엔드(quiz) WAR 재배포 → 프론트 배포
--    (ddl-auto: none 이라 코드만 바뀌고 DB 이름이 안 맞으면 조회 실패)
-- ⚠️ MariaDB 10.5.2+ 필요 (RENAME TABLE/INDEX/COLUMN). 구버전이면 CHANGE COLUMN 사용.
-- =====================================================================

-- 1) 리마인드 결과 테이블 + 인덱스 (note_remind_result → note_quiz_result)
RENAME TABLE note_remind_result TO note_quiz_result;
ALTER TABLE note_quiz_result RENAME INDEX idx_remind_result_summary TO idx_quiz_result_summary;
ALTER TABLE note_quiz_result RENAME INDEX idx_remind_result_group   TO idx_quiz_result_group;

-- 2) 요약 결과 테이블의 카운트 컬럼 (note_summary_result.total_remind_count → total_quiz_count)
ALTER TABLE note_summary_result RENAME COLUMN total_remind_count TO total_quiz_count;

-- 3) 프롬프트 설정 테이블의 quiz 전용 컬럼 (note_prompt_config)
ALTER TABLE note_prompt_config RENAME COLUMN remind_max_count   TO quiz_max_count;
ALTER TABLE note_prompt_config RENAME COLUMN remind_max_group   TO quiz_max_group;
ALTER TABLE note_prompt_config RENAME COLUMN remind_type_filter TO quiz_type_filter;

-- 4) 유튜브 채널 자동 생성 설정 컬럼 (note_member_youtube_channel)
ALTER TABLE note_member_youtube_channel RENAME COLUMN auto_remind         TO auto_quiz;
ALTER TABLE note_member_youtube_channel RENAME COLUMN remind_type         TO quiz_type;
ALTER TABLE note_member_youtube_channel RENAME COLUMN remind_custom_count TO quiz_custom_count;

-- 5) note_prompt_config 데이터 값 변경 (컬럼명이 아니라 '값')
--    (a) type 행 키: 'remind' → 'quiz'
--        코드가 findByType(..., "quiz", ...) 로 조회/저장하므로 기존 행 키를 맞춘다.
UPDATE note_prompt_config SET type = 'quiz' WHERE type = 'remind';

--    (b) 프롬프트 본문/이름의 '리마인드' → '퀴즈'
--        QuizParser 가 '─── 📌 퀴즈 ───' 구분선과 '퀴즈 총 N개' 라인을 찾으므로,
--        AI 출력 형식을 지시하는 프롬프트 텍스트도 '퀴즈'로 맞춰야 파싱이 동작한다.
UPDATE note_prompt_config SET prompt      = REPLACE(prompt,      '리마인드', '퀴즈') WHERE prompt      LIKE '%리마인드%';
UPDATE note_prompt_config SET prompt_name = REPLACE(prompt_name, '리마인드', '퀴즈') WHERE prompt_name LIKE '%리마인드%';
UPDATE note_prompt_config SET level_name  = REPLACE(level_name,  '리마인드', '퀴즈') WHERE level_name  LIKE '%리마인드%';

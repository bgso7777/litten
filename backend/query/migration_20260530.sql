-- ================================================================================
-- Migration: 요약/리마인드 처리 테이블 생성
-- Date: 2026-05-30
-- ================================================================================

-- ────────────────────────────────────────────────────────────────────────────────
-- 1. 요약 파라미터 설정 테이블 (note_summary_config)
--    파일 유형별 AI 모델, 요약 수준, 언어 등 요약 전용 파라미터
-- ────────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS `note_summary_config`;
CREATE TABLE `note_summary_config` (
  `sequence`         BIGINT(20)   NOT NULL AUTO_INCREMENT  COMMENT '설정 PK',
  `file_type`        VARCHAR(50)  NOT NULL                  COMMENT '파일 유형 (youtube|text|pdf|xls|doc|ppt|audio|handwriting)',
  `config_name`      VARCHAR(100) NOT NULL                  COMMENT '설정 이름',
  `ai_provider`      VARCHAR(20)  NOT NULL DEFAULT 'openai' COMMENT 'AI 제공자 (openai|claude)',
  `ai_model`         VARCHAR(100) NULL                      COMMENT 'AI 모델명 (NULL=서버 기본값 사용)',

  -- 요약 파라미터 (리마인드는 note_remind_config 별도 테이블)
  `summary_enabled`  TINYINT(1)   NOT NULL DEFAULT 1         COMMENT '요약 활성 여부',
  `summary_level`    TINYINT      NOT NULL DEFAULT 3         COMMENT '요약 수준 1~5 (1=한줄/2=간단/3=일반/4=상세/5=전체)',
  `text_language`    VARCHAR(10)  NOT NULL DEFAULT 'ko'      COMMENT '입력 텍스트 언어 (ko, en, ja 등)',
  `summary_language` VARCHAR(10)  NOT NULL DEFAULT 'ko'      COMMENT '출력 요약 언어',
  `max_tokens`       INT          NULL                       COMMENT '최대 토큰 수 (NULL=서버 기본값)',

  `is_active`        TINYINT(1)   NOT NULL DEFAULT 1         COMMENT '설정 활성 여부',
  `description`      VARCHAR(500) NULL                       COMMENT '설정 설명',
  `insert_pk`        BIGINT(20)   NULL                       COMMENT '등록자 FK',
  `update_pk`        BIGINT(20)   NULL                       COMMENT '수정자 FK',
  `insert_date_time` TIMESTAMP    NOT NULL DEFAULT current_timestamp() COMMENT '등록일시',
  `update_date_time` TIMESTAMP    NULL     ON UPDATE current_timestamp() COMMENT '수정일시',

  PRIMARY KEY (`sequence`) USING BTREE,
  UNIQUE INDEX `unique_file_type` (`file_type`) USING BTREE,
  INDEX `idx_is_active` (`is_active`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='요약 처리 파라미터 설정';


-- ────────────────────────────────────────────────────────────────────────────────
-- 2. 리마인드 파라미터 설정 테이블 (note_remind_config)
--    파일 유형별 리마인드 추출 전용 파라미터 (note_summary_config 와 1:1 대응)
-- ────────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS `note_remind_config`;
CREATE TABLE `note_remind_config` (
  `sequence`           BIGINT(20)   NOT NULL AUTO_INCREMENT   COMMENT '설정 PK',
  `file_type`          VARCHAR(50)  NOT NULL                   COMMENT '파일 유형 (note_summary_config.file_type 과 동일)',
  `config_name`        VARCHAR(100) NOT NULL                   COMMENT '설정 이름',

  -- 리마인드 파라미터
  `remind_enabled`     TINYINT(1)   NOT NULL DEFAULT 1          COMMENT '리마인드 추출 활성 여부',
  `remind_max_count`   INT          NULL                        COMMENT '최대 세부항목(2단) 수 (NULL=무제한)',
  `remind_max_group`   INT          NULL                        COMMENT '최대 그룹(1단) 수 (NULL=무제한, 기본 AI 권장 2~5)',
  `remind_type_filter` VARCHAR(500) NULL                        COMMENT '추출 유형 필터, 콤마 구분 (NULL=전체). 예: 일정,액션,핵심개념,적용포인트,학습할것,외부대기,리스크,기타',

  `is_active`          TINYINT(1)   NOT NULL DEFAULT 1          COMMENT '설정 활성 여부',
  `description`        VARCHAR(500) NULL                        COMMENT '설정 설명',
  `insert_pk`          BIGINT(20)   NULL                        COMMENT '등록자 FK',
  `update_pk`          BIGINT(20)   NULL                        COMMENT '수정자 FK',
  `insert_date_time`   TIMESTAMP    NOT NULL DEFAULT current_timestamp() COMMENT '등록일시',
  `update_date_time`   TIMESTAMP    NULL     ON UPDATE current_timestamp() COMMENT '수정일시',

  PRIMARY KEY (`sequence`) USING BTREE,
  UNIQUE INDEX `unique_remind_file_type` (`file_type`) USING BTREE,
  INDEX `idx_remind_cfg_active` (`is_active`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='리마인드 처리 파라미터 설정';


-- ────────────────────────────────────────────────────────────────────────────────
-- 3. 파일별 요약/리마인드 결과 테이블 (note_summary_result)
--    모든 파일 유형 통합 저장
--    YouTube  : is_shared=1, youtube_video_id UNIQUE → 공통 사용
--    개인 파일 : is_shared=0, file_uuid + member_uuid UNIQUE → 계정별
-- ────────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS `note_summary_result`;
CREATE TABLE `note_summary_result` (
  `sequence`           BIGINT(20)    NOT NULL AUTO_INCREMENT  COMMENT '결과 PK',
  `config_id`          BIGINT(20)    NOT NULL                  COMMENT 'note_summary_config FK',

  -- 파일 식별
  `file_type`          VARCHAR(50)   NOT NULL                  COMMENT '파일 유형',
  `file_uuid`          VARCHAR(64)   NULL                      COMMENT '파일 UUID (text/handwriting/audio용)',
  `youtube_video_id`   VARCHAR(50)   NULL                      COMMENT '유튜브 영상 ID (youtube용)',
  `member_uuid`        VARCHAR(64)   NULL                      COMMENT '회원 UUID (개인 파일; 공유=NULL)',
  `is_shared`          TINYINT(1)    NOT NULL DEFAULT 0         COMMENT '공유 여부 (1=공통/유튜브, 0=개인)',

  -- 원본 텍스트
  `source_text`        LONGTEXT      NULL                      COMMENT '원본 텍스트 (자막/OCR/STT 결과)',

  -- 요약 결과
  `summary_full`       LONGTEXT      NULL                      COMMENT 'AI 응답 전체 텍스트 (요약+리마인드)',
  `summary_only`       LONGTEXT      NULL                      COMMENT '순수 요약 텍스트 (리마인드 구분선 이전)',

  -- 요약 파라미터 (실제 적용된 값 보존)
  `summary_level`      TINYINT       NOT NULL DEFAULT 3         COMMENT '실제 적용된 요약 수준 1~5',

  -- 리마인드 집계 (상세는 note_remind_result 별도 테이블)
  `total_remind_count` INT           NOT NULL DEFAULT 0         COMMENT '리마인드 총 세부항목 수 (빠른 조회용)',

  -- 처리 상태
  `status`             VARCHAR(20)   NOT NULL DEFAULT 'pending' COMMENT '처리 상태 (pending|done|error)',
  `error_message`      VARCHAR(1024) NULL                      COMMENT '오류 메시지',
  `processed_at`       TIMESTAMP     NULL                      COMMENT '처리 완료일시',

  -- 삭제
  `is_deleted`         TINYINT(1)    NOT NULL DEFAULT 0         COMMENT '삭제 여부',
  `deleted_date_time`  TIMESTAMP     NULL                      COMMENT '삭제 일시',

  `insert_pk`          BIGINT(20)    NULL                      COMMENT '등록자 FK',
  `update_pk`          BIGINT(20)    NULL                      COMMENT '수정자 FK',
  `insert_date_time`   TIMESTAMP     NOT NULL DEFAULT current_timestamp() COMMENT '등록일시',
  `update_date_time`   TIMESTAMP     NULL     ON UPDATE current_timestamp() COMMENT '수정일시',

  PRIMARY KEY (`sequence`) USING BTREE,
  UNIQUE INDEX `unique_youtube_video` (`youtube_video_id`) USING BTREE,
  UNIQUE INDEX `unique_file_member`   (`file_uuid`, `member_uuid`) USING BTREE,
  INDEX `idx_file_type_status` (`file_type`, `status`) USING BTREE,
  INDEX `idx_member_uuid`      (`member_uuid`) USING BTREE,
  INDEX `idx_is_shared`        (`is_shared`) USING BTREE,
  INDEX `idx_config_id`        (`config_id`) USING BTREE,

  CONSTRAINT `fk_summary_result_config`
    FOREIGN KEY (`config_id`) REFERENCES `note_summary_config` (`sequence`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='파일별 요약/리마인드 처리 결과';


-- ────────────────────────────────────────────────────────────────────────────────
-- 4. 리마인드 결과 테이블 (note_remind_result)
--    1 RemindItem = 1 행, note_summary_result 와 FK 연결
--    1단(group_name/group_order) → 2단(item_*) → 3단(detail_text) 계층
-- ────────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS `note_remind_result`;
CREATE TABLE `note_remind_result` (
  `sequence`          BIGINT(20)   NOT NULL AUTO_INCREMENT  COMMENT '결과 PK',
  `summary_result_id` BIGINT(20)   NOT NULL                  COMMENT 'note_summary_result FK',

  -- 1단: 그룹
  `group_name`        VARCHAR(200) NOT NULL                  COMMENT '1단 그룹명',
  `group_order`       INT          NOT NULL DEFAULT 0         COMMENT '그룹 정렬 순서',

  -- 2단: 세부항목
  `item_type`         VARCHAR(50)  NOT NULL                  COMMENT '2단 유형 (일정|액션|핵심개념|적용포인트|학습할것|외부대기|리스크|기타)',
  `item_content`      TEXT         NOT NULL                  COMMENT '2단 세부항목 내용',
  `assignee`          VARCHAR(100) NULL                      COMMENT '담당자 (없으면 -)',
  `deadline`          VARCHAR(100) NULL                      COMMENT '기한 (없으면 -)',

  -- 3단: 부가 설명
  `detail_text`       TEXT         NULL                      COMMENT '3단 부가 설명 (여러 줄은 \\n 구분)',

  `sort_order`        INT          NOT NULL DEFAULT 0         COMMENT '그룹 내 항목 정렬 순서',
  `is_deleted`        TINYINT(1)   NOT NULL DEFAULT 0         COMMENT '삭제 여부',
  `insert_pk`         BIGINT(20)   NULL                      COMMENT '등록자 FK',
  `update_pk`         BIGINT(20)   NULL                      COMMENT '수정자 FK',
  `insert_date_time`  TIMESTAMP    NOT NULL DEFAULT current_timestamp() COMMENT '등록일시',
  `update_date_time`  TIMESTAMP    NULL     ON UPDATE current_timestamp() COMMENT '수정일시',

  PRIMARY KEY (`sequence`) USING BTREE,
  INDEX `idx_remind_result_summary` (`summary_result_id`) USING BTREE,
  INDEX `idx_remind_result_group`   (`summary_result_id`, `group_order`, `sort_order`) USING BTREE,

  CONSTRAINT `fk_remind_result_summary`
    FOREIGN KEY (`summary_result_id`) REFERENCES `note_summary_result` (`sequence`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='리마인드 항목 결과 (1행 = 1 RemindItem)';


-- ────────────────────────────────────────────────────────────────────────────────
-- 5. 파라미터 초기 데이터 삽입 (소스 기준)
--
-- 요약 수준 참고 (SummaryService / OpenAiSummaryService):
--   level 1: VERY_SHORT  — 원문의 약 10%,  핵심 주제·결론 1~2문장
--   level 2: SHORT       — 원문의 약 25%,  주요 포인트·구조 유지
--   level 3: MEDIUM      — 원문의 40~50%, 흐름과 의도 포함  ← 기본값
--   level 4: LONG        — 원문의 약 70%,  흐름 대부분 유지
--   level 5: FULL        — 원문의 약 90%,  STT 오류만 제거
--
-- max_tokens 근거 (computeMaxTokens):
--   youtube, audio : 자막/녹음 길어 → 8192
--   text, pdf, doc : 일반 문서     → 4096
--   xls, ppt       : 데이터/슬라이드 → 2048
--   handwriting    : OCR 결과       → 4096
--
-- 리마인드 유형 8종 (buildPrompt):
--   일정|액션|핵심개념|적용포인트|학습할것|외부대기|리스크|기타
--
-- 리마인드 그룹 권장 2~5개 ("일반적으로 항목은 2~5개 사이가 적절하다")
-- ────────────────────────────────────────────────────────────────────────────────

-- 요약 파라미터 (note_summary_config)
INSERT INTO `note_summary_config`
  (`file_type`, `config_name`, `ai_provider`, `ai_model`,
   `summary_enabled`, `summary_level`, `text_language`, `summary_language`,
   `max_tokens`, `description`)
VALUES
  ('youtube', '유튜브 영상 요약',
   'openai', 'gpt-4o-mini',
   1, 3, 'ko', 'ko', 8192,
   '유튜브 자막(STT) 기반. 공통 저장. level3=MEDIUM(40~50%). max_tokens:8192(긴 자막 대비)'),

  ('text', '텍스트 파일 요약',
   'openai', 'gpt-4o-mini',
   1, 3, 'ko', 'ko', 4096,
   'html-editor-enhanced 텍스트. level3=MEDIUM(40~50%). max_tokens:4096'),

  ('pdf', 'PDF 파일 요약',
   'openai', 'gpt-4o-mini',
   1, 3, 'ko', 'ko', 4096,
   'PDF 텍스트 추출 후 요약. level3=MEDIUM(40~50%). max_tokens:4096'),

  ('xls', 'Excel 파일 요약',
   'openai', 'gpt-4o-mini',
   1, 2, 'ko', 'ko', 2048,
   'Excel 데이터 텍스트화. level2=SHORT(25%, 데이터 중심). max_tokens:2048'),

  ('doc', 'Word 파일 요약',
   'openai', 'gpt-4o-mini',
   1, 3, 'ko', 'ko', 4096,
   'Word 문서 텍스트 추출. level3=MEDIUM(40~50%). max_tokens:4096'),

  ('ppt', 'PPT 파일 요약',
   'openai', 'gpt-4o-mini',
   1, 2, 'ko', 'ko', 2048,
   'PPT 슬라이드 텍스트 추출. level2=SHORT(25%, 발표 요점 중심). max_tokens:2048'),

  ('audio', '녹음 파일 요약',
   'openai', 'gpt-4o-mini',
   1, 3, 'ko', 'ko', 8192,
   'STT 변환 결과 요약. STT 오인식 보정 포함. level3=MEDIUM(40~50%). max_tokens:8192(긴 녹음 대비)'),

  ('handwriting', '필기 파일 요약',
   'openai', 'gpt-4o-mini',
   1, 3, 'ko', 'ko', 4096,
   'OCR 변환 결과 요약. level3=MEDIUM(40~50%). max_tokens:4096');


-- 리마인드 파라미터 (note_remind_config)
INSERT INTO `note_remind_config`
  (`file_type`, `config_name`,
   `remind_enabled`, `remind_max_count`, `remind_max_group`, `remind_type_filter`,
   `description`)
VALUES
  ('youtube', '유튜브 리마인드',
   1, NULL, 5,
   '일정,액션,핵심개념,적용포인트,학습할것,외부대기,리스크,기타',
   '모든 유형 추출. 강의·정보 콘텐츠 중심. 그룹 최대 5개. 우선순위: 기한임박→외부대기→리스크→핵심개념/적용포인트→액션/학습'),

  ('text', '텍스트 파일 리마인드',
   1, NULL, 5,
   '일정,액션,핵심개념,적용포인트,학습할것,외부대기,리스크,기타',
   '모든 유형 추출. 서사형 텍스트. 그룹 최대 5개'),

  ('pdf', 'PDF 파일 리마인드',
   1, NULL, 5,
   '액션,핵심개념,적용포인트,학습할것,일정,외부대기,리스크,기타',
   '문서 서사 중심 유형 우선. 그룹 최대 5개'),

  ('xls', 'Excel 파일 리마인드',
   1, 10, 3,
   '액션,외부대기,리스크,일정,기타',
   '데이터·보고서 중심. 액션·외부대기·리스크 위주. 그룹 최대 3개, 항목 최대 10개'),

  ('doc', 'Word 파일 리마인드',
   1, NULL, 5,
   '일정,액션,핵심개념,적용포인트,학습할것,외부대기,리스크,기타',
   '모든 유형 추출. 일반 문서. 그룹 최대 5개'),

  ('ppt', 'PPT 파일 리마인드',
   1, 15, 4,
   '핵심개념,적용포인트,액션,학습할것,일정,기타',
   '발표 요점 중심. 핵심개념·적용포인트 위주. 그룹 최대 4개, 항목 최대 15개'),

  ('audio', '녹음 파일 리마인드',
   1, NULL, 5,
   '일정,액션,핵심개념,적용포인트,학습할것,외부대기,리스크,기타',
   '모든 유형 추출. 회의·강의 혼재. 그룹 최대 5개. STT 보정 후 추출'),

  ('handwriting', '필기 파일 리마인드',
   1, NULL, 5,
   '일정,액션,핵심개념,적용포인트,학습할것,외부대기,리스크,기타',
   '모든 유형 추출. OCR 변환 결과. 그룹 최대 5개');


-- ────────────────────────────────────────────────────────────────────────────────
-- 결과 확인
-- ────────────────────────────────────────────────────────────────────────────────
SELECT
  sc.file_type,
  sc.ai_provider, sc.ai_model, sc.summary_level, sc.max_tokens,
  rc.remind_enabled, rc.remind_max_count, rc.remind_max_group,
  rc.remind_type_filter
FROM note_summary_config sc
JOIN note_remind_config  rc ON sc.file_type = rc.file_type
ORDER BY sc.sequence;


-- ================================================================================
-- ALTER: insert_pk / update_pk 컬럼 추가 (테이블이 이미 존재할 경우 실행)
-- ================================================================================
ALTER TABLE `note_summary_config`
  ADD COLUMN `insert_pk` BIGINT(20) NULL COMMENT '등록자 FK' AFTER `description`,
  ADD COLUMN `update_pk`  BIGINT(20) NULL COMMENT '수정자 FK' AFTER `insert_pk`;

ALTER TABLE `note_remind_config`
  ADD COLUMN `insert_pk` BIGINT(20) NULL COMMENT '등록자 FK' AFTER `description`,
  ADD COLUMN `update_pk`  BIGINT(20) NULL COMMENT '수정자 FK' AFTER `insert_pk`;

ALTER TABLE `note_summary_result`
  ADD COLUMN `summary_level` TINYINT   NOT NULL DEFAULT 3 COMMENT '실제 적용된 요약 수준 1~5' AFTER `source_text`,
  ADD COLUMN `insert_pk`     BIGINT(20) NULL COMMENT '등록자 FK' AFTER `deleted_date_time`,
  ADD COLUMN `update_pk`     BIGINT(20) NULL COMMENT '수정자 FK' AFTER `insert_pk`;

ALTER TABLE `note_remind_result`
  ADD COLUMN `insert_pk` BIGINT(20) NULL COMMENT '등록자 FK' AFTER `is_deleted`,
  ADD COLUMN `update_pk`  BIGINT(20) NULL COMMENT '수정자 FK' AFTER `insert_pk`;

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
  `sequence`           BIGINT(20)    NOT NULL AUTO_INCREMENT  COMMENT '설정 PK',
  `file_type`          VARCHAR(50)   NOT NULL                  COMMENT '파일 유형 (youtube|text|pdf|xls|doc|ppt|audio|handwriting)',
  `config_name`        VARCHAR(100)  NOT NULL                  COMMENT '설정 이름',
  `ai_provider`        VARCHAR(20)   NOT NULL DEFAULT 'openai' COMMENT 'AI 제공자 (openai|claude)',
  `ai_model`           VARCHAR(100)  NULL                      COMMENT 'AI 모델명 (NULL=서버 기본값)',

  -- 요약 파라미터 (리마인드는 note_remind_config 별도)
  `summary_enabled`    TINYINT(1)    NOT NULL DEFAULT 1         COMMENT '요약 활성 여부',
  `summary_level`      TINYINT       NOT NULL DEFAULT 3         COMMENT '요약 수준 1~5',
  `text_language`      VARCHAR(10)   NOT NULL DEFAULT 'ko'      COMMENT '입력 텍스트 언어',
  `summary_language`   VARCHAR(10)   NOT NULL DEFAULT 'ko'      COMMENT '출력 요약 언어',
  `max_tokens`         INT           NULL                       COMMENT '최대 토큰 수 (NULL=서버 기본값)',

  -- 소스 buildSystemPrompt / computeMaxTokens 에서 추출한 level별 값
  `level_name`         VARCHAR(20)   NULL COMMENT '수준 코드명 (소스: VERY_SHORT|SHORT|MEDIUM|LONG|FULL)',
  `level_description`  VARCHAR(300)  NULL COMMENT '수준 설명 (소스: buildSystemPrompt levelDetail)',
  `level_ratio`        DECIMAL(4,2)  NULL COMMENT '토큰 계산 비율 (소스: computeMaxTokens ratio)',

  `is_active`          TINYINT(1)    NOT NULL DEFAULT 1         COMMENT '설정 활성 여부',
  `description`        VARCHAR(500)  NULL                       COMMENT '설정 설명',
  `insert_pk`          BIGINT(20)    NULL                       COMMENT '등록자 FK',
  `update_pk`          BIGINT(20)    NULL                       COMMENT '수정자 FK',
  `insert_date_time`   TIMESTAMP     NOT NULL DEFAULT current_timestamp() COMMENT '등록일시',
  `update_date_time`   TIMESTAMP     NULL     ON UPDATE current_timestamp() COMMENT '수정일시',

  PRIMARY KEY (`sequence`) USING BTREE,
  -- 파일유형 + 수준 조합 UNIQUE (8 유형 × 5 수준 = 40행)
  UNIQUE INDEX `unique_file_type_level` (`file_type`, `summary_level`) USING BTREE,
  INDEX `idx_is_active` (`is_active`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='요약 처리 파라미터 설정 (파일유형+수준별)';


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
  -- level별 구분 저장 (같은 파일이라도 level 1~5 각각 별도 저장)
  UNIQUE INDEX `unique_youtube_video` (`youtube_video_id`, `summary_level`) USING BTREE,
  UNIQUE INDEX `unique_file_member`   (`file_uuid`, `member_uuid`, `summary_level`) USING BTREE,
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

-- ── 요약 파라미터: 8 유형 × 5 수준 = 40행 ─────────────────────────────────
-- 소스 추출값:
--   level_name        : buildSystemPrompt switch(level) 코드명
--   level_description : buildSystemPrompt levelDetail 문자열
--   level_ratio       : computeMaxTokens ratio 값
--   max_tokens        : level5=16384(OpenAI hardLimit), 그 외 level별 실용 상한
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO `note_summary_config`
  (`file_type`, `config_name`, `ai_provider`, `ai_model`,
   `summary_enabled`, `summary_level`, `text_language`, `summary_language`, `max_tokens`,
   `level_name`, `level_description`, `level_ratio`, `description`)
VALUES
-- ── youtube ──
('youtube','유튜브 요약 Lv1','openai','gpt-4o-mini',1,1,'ko','ko', 1024,
 'VERY_SHORT','핵심 주제·결론 1~2문장. 최소 분량 유지.',0.15,'유튜브 자막. 공통 저장. 빠른 확인용'),
('youtube','유튜브 요약 Lv2','openai','gpt-4o-mini',1,2,'ko','ko', 2048,
 'SHORT','전체 목적·핵심 포인트·결론을 각 2~4문장으로 작성.',0.30,'유튜브 자막. 공통 저장. 공유용'),
('youtube','유튜브 요약 Lv3','openai','gpt-4o-mini',1,3,'ko','ko', 4096,
 'MEDIUM','각 섹션을 3~6문장의 실질적 내용으로 작성. 원본의 40~50% 분량 목표.',0.55,'유튜브 자막. 공통 저장. 기본값'),
('youtube','유튜브 요약 Lv4','openai','gpt-4o-mini',1,4,'ko','ko', 8192,
 'LONG','각 섹션을 5~10문장으로 상세히 작성. 원본의 70% 분량 목표.',0.80,'유튜브 자막. 공통 저장. 상세 검토용'),
('youtube','유튜브 요약 Lv5','openai','gpt-4o-mini',1,5,'ko','ko',16384,
 'FULL','STT 오류·추임새만 제거하고 거의 전체 내용 유지. 원본의 90% 분량 목표.',1.10,'유튜브 자막. 공통 저장. 복기/문서화용. OpenAI hardLimit=16384'),

-- ── text ──
('text','텍스트 요약 Lv1','openai','gpt-4o-mini',1,1,'ko','ko', 1024,
 'VERY_SHORT','핵심 주제·결론 1~2문장. 최소 분량 유지.',0.15,'html-editor 텍스트. 빠른 확인용'),
('text','텍스트 요약 Lv2','openai','gpt-4o-mini',1,2,'ko','ko', 2048,
 'SHORT','전체 목적·핵심 포인트·결론을 각 2~4문장으로 작성.',0.30,'html-editor 텍스트. 공유용'),
('text','텍스트 요약 Lv3','openai','gpt-4o-mini',1,3,'ko','ko', 4096,
 'MEDIUM','각 섹션을 3~6문장의 실질적 내용으로 작성. 원본의 40~50% 분량 목표.',0.55,'html-editor 텍스트. 기본값'),
('text','텍스트 요약 Lv4','openai','gpt-4o-mini',1,4,'ko','ko', 8192,
 'LONG','각 섹션을 5~10문장으로 상세히 작성. 원본의 70% 분량 목표.',0.80,'html-editor 텍스트. 상세'),
('text','텍스트 요약 Lv5','openai','gpt-4o-mini',1,5,'ko','ko',16384,
 'FULL','STT 오류·추임새만 제거하고 거의 전체 내용 유지. 원본의 90% 분량 목표.',1.10,'html-editor 텍스트. 전체 정제본. OpenAI hardLimit=16384'),

-- ── pdf ──
('pdf','PDF 요약 Lv1','openai','gpt-4o-mini',1,1,'ko','ko', 1024,
 'VERY_SHORT','핵심 주제·결론 1~2문장. 최소 분량 유지.',0.15,'PDF 텍스트 추출. 빠른 확인용'),
('pdf','PDF 요약 Lv2','openai','gpt-4o-mini',1,2,'ko','ko', 2048,
 'SHORT','전체 목적·핵심 포인트·결론을 각 2~4문장으로 작성.',0.30,'PDF 텍스트 추출. 공유용'),
('pdf','PDF 요약 Lv3','openai','gpt-4o-mini',1,3,'ko','ko', 4096,
 'MEDIUM','각 섹션을 3~6문장의 실질적 내용으로 작성. 원본의 40~50% 분량 목표.',0.55,'PDF 텍스트 추출. 기본값'),
('pdf','PDF 요약 Lv4','openai','gpt-4o-mini',1,4,'ko','ko', 8192,
 'LONG','각 섹션을 5~10문장으로 상세히 작성. 원본의 70% 분량 목표.',0.80,'PDF 텍스트 추출. 상세'),
('pdf','PDF 요약 Lv5','openai','gpt-4o-mini',1,5,'ko','ko',16384,
 'FULL','STT 오류·추임새만 제거하고 거의 전체 내용 유지. 원본의 90% 분량 목표.',1.10,'PDF 텍스트 추출. 전체 정제본. OpenAI hardLimit=16384'),

-- ── xls ──
('xls','Excel 요약 Lv1','openai','gpt-4o-mini',1,1,'ko','ko',  512,
 'VERY_SHORT','핵심 주제·결론 1~2문장. 최소 분량 유지.',0.15,'Excel 데이터. 데이터 중심, 짧게'),
('xls','Excel 요약 Lv2','openai','gpt-4o-mini',1,2,'ko','ko', 1024,
 'SHORT','전체 목적·핵심 포인트·결론을 각 2~4문장으로 작성.',0.30,'Excel 데이터. 기본값(데이터는 간단 요약으로 충분)'),
('xls','Excel 요약 Lv3','openai','gpt-4o-mini',1,3,'ko','ko', 2048,
 'MEDIUM','각 섹션을 3~6문장의 실질적 내용으로 작성. 원본의 40~50% 분량 목표.',0.55,'Excel 데이터.'),
('xls','Excel 요약 Lv4','openai','gpt-4o-mini',1,4,'ko','ko', 4096,
 'LONG','각 섹션을 5~10문장으로 상세히 작성. 원본의 70% 분량 목표.',0.80,'Excel 데이터.'),
('xls','Excel 요약 Lv5','openai','gpt-4o-mini',1,5,'ko','ko', 8192,
 'FULL','STT 오류·추임새만 제거하고 거의 전체 내용 유지. 원본의 90% 분량 목표.',1.10,'Excel 데이터. 전체 정제본'),

-- ── doc ──
('doc','Word 요약 Lv1','openai','gpt-4o-mini',1,1,'ko','ko', 1024,
 'VERY_SHORT','핵심 주제·결론 1~2문장. 최소 분량 유지.',0.15,'Word 문서 텍스트 추출. 빠른 확인용'),
('doc','Word 요약 Lv2','openai','gpt-4o-mini',1,2,'ko','ko', 2048,
 'SHORT','전체 목적·핵심 포인트·결론을 각 2~4문장으로 작성.',0.30,'Word 문서 텍스트 추출. 공유용'),
('doc','Word 요약 Lv3','openai','gpt-4o-mini',1,3,'ko','ko', 4096,
 'MEDIUM','각 섹션을 3~6문장의 실질적 내용으로 작성. 원본의 40~50% 분량 목표.',0.55,'Word 문서 텍스트 추출. 기본값'),
('doc','Word 요약 Lv4','openai','gpt-4o-mini',1,4,'ko','ko', 8192,
 'LONG','각 섹션을 5~10문장으로 상세히 작성. 원본의 70% 분량 목표.',0.80,'Word 문서 텍스트 추출. 상세'),
('doc','Word 요약 Lv5','openai','gpt-4o-mini',1,5,'ko','ko',16384,
 'FULL','STT 오류·추임새만 제거하고 거의 전체 내용 유지. 원본의 90% 분량 목표.',1.10,'Word 문서 텍스트 추출. 전체 정제본. OpenAI hardLimit=16384'),

-- ── ppt ──
('ppt','PPT 요약 Lv1','openai','gpt-4o-mini',1,1,'ko','ko',  512,
 'VERY_SHORT','핵심 주제·결론 1~2문장. 최소 분량 유지.',0.15,'PPT 슬라이드. 발표 요점, 짧게'),
('ppt','PPT 요약 Lv2','openai','gpt-4o-mini',1,2,'ko','ko', 1024,
 'SHORT','전체 목적·핵심 포인트·결론을 각 2~4문장으로 작성.',0.30,'PPT 슬라이드. 기본값(슬라이드는 간단 요약으로 충분)'),
('ppt','PPT 요약 Lv3','openai','gpt-4o-mini',1,3,'ko','ko', 2048,
 'MEDIUM','각 섹션을 3~6문장의 실질적 내용으로 작성. 원본의 40~50% 분량 목표.',0.55,'PPT 슬라이드.'),
('ppt','PPT 요약 Lv4','openai','gpt-4o-mini',1,4,'ko','ko', 4096,
 'LONG','각 섹션을 5~10문장으로 상세히 작성. 원본의 70% 분량 목표.',0.80,'PPT 슬라이드.'),
('ppt','PPT 요약 Lv5','openai','gpt-4o-mini',1,5,'ko','ko', 8192,
 'FULL','STT 오류·추임새만 제거하고 거의 전체 내용 유지. 원본의 90% 분량 목표.',1.10,'PPT 슬라이드. 전체 정제본'),

-- ── audio ──
('audio','녹음 요약 Lv1','openai','gpt-4o-mini',1,1,'ko','ko', 1024,
 'VERY_SHORT','핵심 주제·결론 1~2문장. 최소 분량 유지.',0.15,'STT 변환 결과. STT 오인식 보정 포함. 빠른 확인용'),
('audio','녹음 요약 Lv2','openai','gpt-4o-mini',1,2,'ko','ko', 2048,
 'SHORT','전체 목적·핵심 포인트·결론을 각 2~4문장으로 작성.',0.30,'STT 변환 결과. STT 오인식 보정 포함. 공유용'),
('audio','녹음 요약 Lv3','openai','gpt-4o-mini',1,3,'ko','ko', 4096,
 'MEDIUM','각 섹션을 3~6문장의 실질적 내용으로 작성. 원본의 40~50% 분량 목표.',0.55,'STT 변환 결과. STT 오인식 보정 포함. 기본값'),
('audio','녹음 요약 Lv4','openai','gpt-4o-mini',1,4,'ko','ko', 8192,
 'LONG','각 섹션을 5~10문장으로 상세히 작성. 원본의 70% 분량 목표.',0.80,'STT 변환 결과. STT 오인식 보정 포함. 상세'),
('audio','녹음 요약 Lv5','openai','gpt-4o-mini',1,5,'ko','ko',16384,
 'FULL','STT 오류·추임새만 제거하고 거의 전체 내용 유지. 원본의 90% 분량 목표.',1.10,'STT 변환 결과. 전체 정제본. OpenAI hardLimit=16384'),

-- ── handwriting ──
('handwriting','필기 요약 Lv1','openai','gpt-4o-mini',1,1,'ko','ko', 1024,
 'VERY_SHORT','핵심 주제·결론 1~2문장. 최소 분량 유지.',0.15,'OCR 변환 결과. 빠른 확인용'),
('handwriting','필기 요약 Lv2','openai','gpt-4o-mini',1,2,'ko','ko', 2048,
 'SHORT','전체 목적·핵심 포인트·결론을 각 2~4문장으로 작성.',0.30,'OCR 변환 결과. 공유용'),
('handwriting','필기 요약 Lv3','openai','gpt-4o-mini',1,3,'ko','ko', 4096,
 'MEDIUM','각 섹션을 3~6문장의 실질적 내용으로 작성. 원본의 40~50% 분량 목표.',0.55,'OCR 변환 결과. 기본값'),
('handwriting','필기 요약 Lv4','openai','gpt-4o-mini',1,4,'ko','ko', 8192,
 'LONG','각 섹션을 5~10문장으로 상세히 작성. 원본의 70% 분량 목표.',0.80,'OCR 변환 결과. 상세'),
('handwriting','필기 요약 Lv5','openai','gpt-4o-mini',1,5,'ko','ko',16384,
 'FULL','STT 오류·추임새만 제거하고 거의 전체 내용 유지. 원본의 90% 분량 목표.',1.10,'OCR 변환 결과. 전체 정제본. OpenAI hardLimit=16384');


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
  ADD COLUMN `level_name`        VARCHAR(20)  NULL COMMENT '수준 코드명 (VERY_SHORT|SHORT|MEDIUM|LONG|FULL)' AFTER `max_tokens`,
  ADD COLUMN `level_description` VARCHAR(300) NULL COMMENT '수준 설명 (소스 buildSystemPrompt levelDetail)' AFTER `level_name`,
  ADD COLUMN `level_ratio`       DECIMAL(4,2) NULL COMMENT '토큰 계산 비율 (소스 computeMaxTokens ratio)' AFTER `level_description`,
  ADD COLUMN `insert_pk`         BIGINT(20)   NULL COMMENT '등록자 FK' AFTER `description`,
  ADD COLUMN `update_pk`         BIGINT(20)   NULL COMMENT '수정자 FK' AFTER `insert_pk`;

-- UNIQUE 인덱스를 file_type → (file_type, summary_level) 로 변경
ALTER TABLE `note_summary_config`
  DROP INDEX `unique_file_type`,
  ADD UNIQUE INDEX `unique_file_type_level` (`file_type`, `summary_level`) USING BTREE;

ALTER TABLE `note_remind_config`
  ADD COLUMN `insert_pk` BIGINT(20) NULL COMMENT '등록자 FK' AFTER `description`,
  ADD COLUMN `update_pk`  BIGINT(20) NULL COMMENT '수정자 FK' AFTER `insert_pk`;

ALTER TABLE `note_summary_result`
  ADD COLUMN `summary_level` TINYINT    NOT NULL DEFAULT 3 COMMENT '실제 적용된 요약 수준 1~5' AFTER `source_text`,
  ADD COLUMN `insert_pk`     BIGINT(20) NULL COMMENT '등록자 FK' AFTER `deleted_date_time`,
  ADD COLUMN `update_pk`     BIGINT(20) NULL COMMENT '수정자 FK' AFTER `insert_pk`;

-- UNIQUE 인덱스에 summary_level 추가 (level별 구분 저장)
ALTER TABLE `note_summary_result`
  DROP INDEX `unique_youtube_video`,
  DROP INDEX `unique_file_member`,
  ADD UNIQUE INDEX `unique_youtube_video` (`youtube_video_id`, `summary_level`) USING BTREE,
  ADD UNIQUE INDEX `unique_file_member`   (`file_uuid`, `member_uuid`, `summary_level`) USING BTREE;

ALTER TABLE `note_remind_result`
  ADD COLUMN `insert_pk` BIGINT(20) NULL COMMENT '등록자 FK' AFTER `is_deleted`,
  ADD COLUMN `update_pk`  BIGINT(20) NULL COMMENT '수정자 FK' AFTER `insert_pk`;

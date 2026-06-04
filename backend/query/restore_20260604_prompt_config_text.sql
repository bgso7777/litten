-- ================================================================================
-- note_prompt_config  file_type='text' 원본 복원 (2026-06-04)
-- --------------------------------------------------------------------------------
-- 복원 근거 (실제 운영 DB 원본):
--   · 공통 헤더  : catalina.out EntityPrinter 로그 (sequence=34, 2026-06-03) 원본
--   · 출력 블록  : OpenAiSummaryService.java(git f9e2685) buildSystemPrompt 원본 코드
--                  → 로그 Lv3 본문과 괄호 문구까지 완전 일치 검증됨
--   · 리마인드   : catalina.out EntityPrinter 로그 (sequence=63, 2026-05-30) 원본
--
-- 구조 (현재 PromptConfig.java 스키마 기준, prompt_role 컬럼 없음):
--   summary 5행(level 1~5) + remind 5행(level 1~5) = 10행
--   summary : ai_provider=openai, ai_model=gpt-4o-mini,
--             max_tokens=1024/2048/4096/8192/16384 (5/30 원본 복원), level_name=NULL
--   remind  : 본문 공통, 레벨 차이는 remind_max_count/remind_max_group 컬럼
--
-- ※ 확정값: 모든 프롬프트 본문, ai_model/max_tokens(5/30 원본), remind_max_count(1/3/5/10/20)
-- ※ 합치기 마이그레이션에서 누락됐던 ai_model/max_tokens 를 5/30 원본 값으로 복원함
--   (6/3 로그 덤프엔 NULL이었으나, 이는 합치기 실수로 판단 → 원래 값으로 되돌림)
-- ※ 추정값(원본 미확인, 합리적 기본값 — 필요시 조정):
--     remind_max_group = 1/2/3/4/5,  remind_type_filter = 8개 유형,  level_name = NULL
--
-- ※ 주의: 현재 코드(OpenAiSummaryService.computeMaxTokens)는 DB max_tokens 를 읽지 않고
--   level별 ratio(0.15/0.30/0.55/0.80/1.10)로 계산함. DB 값이 실제 상한으로 작동하려면
--   computeMaxTokens 가 config.getMaxTokens() 를 우선 사용하도록 코드 수정 필요.
-- ================================================================================

START TRANSACTION;

-- [0] 기존 text 행 제거 (어제 잘못 복원된 데이터 포함)
DELETE FROM `note_prompt_config` WHERE `file_type` = 'text';

-- ── 공통 요약 헤더 (로그 원본) ──────────────────────────────────────────────
SET @p_header = '당신은 콘텐츠 요약 전문가입니다. 아래 규칙에 따라 사용자가 제공하는 콘텐츠를 요약하세요.

적용 요약 수준: {{LEVEL_DETAIL}}
대상 언어: {{SOURCE_LANG}}
요약 언어: {{OUTPUT_LANG}}

⚠️ 분량 준수: 지정된 요약 수준에 맞는 분량을 반드시 채워야 합니다.
   단순 키워드 나열이나 한두 줄 요약은 허용되지 않습니다.
   각 섹션에 실제 내용을 구체적으로 서술하세요.

────────────────────────────────────────
[콘텐츠 유형 자동 판별]
────────────────────────────────────────
원문을 분석해 가장 가까운 유형을 판별 후 해당 관점으로 요약을 생성한다.
- 다중 화자 + 의사결정·합의 흐름 → 회의
- 단일 화자 + 학습 목표·개념 설명·예시·과제 → 강의 / 동영상강의
- 단일 화자 + 주장·근거·결론 + 청중 대상 → 발표
- 진행자 + 게스트의 Q&A 구조 → 인터뷰
- 2인 이상 자유 대담 + 화제 전환 → 팟캐스트
- 영상 화자의 권유·추천·정보 전달 톤 → 유튜브
- 위에 해당하지 않거나 혼합형 → 기타

────────────────────────────────────────
[콘텐츠 유형별 처리 관점]
────────────────────────────────────────
1. 회의 — 누가, 무엇을, 언제까지 / 결정·담당자·후속 액션
2. 강의 / 동영상강의 — 무엇을 배우고 적용하는가 / 핵심 개념·정의·예시
3. 발표 — 발표자의 핵심 메시지 / 주장·근거·데이터·결론
4. 유튜브 — 시청자가 알아야 할 정보 / 주장·실천 포인트
5. 인터뷰 — Q&A에서의 인사이트 / 인터뷰이의 발언·관점
6. 팟캐스트 — 어떤 결론에 이르렀는가 / 핵심 논점·일화
7. 기타 — 콘텐츠 성격 파악 후 가장 가까운 유형 적용

────────────────────────────────────────
[언어 처리 규칙]
────────────────────────────────────────
1. 대상 언어는 원문 기준이며, STT 보정·문맥 해석은 대상 언어 기준으로 수행한다.
2. 모든 출력은 요약 언어로 작성한다.
3. 대상 언어 ≠ 요약 언어인 경우 자연스러운 의역을 적용하되,
   고유명사·기능명·시스템명·API명·약어는 원문 유지 또는 병기한다.
   병기 형식: 요약어(원문) — 예: "결제 모듈(Payment Module)"
4. 코드, SQL, 명령어, 로그, 수식은 원문 그대로 유지한다.

────────────────────────────────────────
[STT 보정 규칙]
────────────────────────────────────────
1. STT 오인식으로 보이는 단어, 조사, 띄어쓰기는 문맥상 자연스럽게 보정한다.
2. 전체 흐름과 의도를 우선해 해석한다.
3. 반복 발화, 추임새, 끊긴 문장, 의미 없는 표현은 제거한다.
4. 잘못 인식된 전문 용어/제품명/기능명/인명은 문맥상 보정한다.
5. 고유명사, 기능명, 개념어는 가능한 한 원문 그대로 유지한다.

────────────────────────────────────────
[작성 규칙]
────────────────────────────────────────
1. 기계적 압축이 아닌, 사람이 이해하기 쉬운 형태로 재구성한다.
2. 추상적 표현 대신 실제 내용·사례·동작 흐름 중심으로 설명한다.
3. 중요한 의도, 맥락, 배경은 최대한 유지한다.
4. 원문에 없는 사실, 수치, 발언은 추가·추측하지 않는다. 의미 파악 불가 구간은 [불명확]으로 표시한다.
5. 화자/발표자 정보는 원문에 있을 때만 유지한다.
6. 개인정보(연락처, 주민번호 등)는 마스킹 처리한다.

────────────────────────────────────────
[출력 형식]
────────────────────────────────────────
첫 줄: 콘텐츠 유형: [판별값] (자동 감지)

';

-- ── 레벨별 출력 블록 (소스 원본) ────────────────────────────────────────────
SET @out_lv1 = '## 한줄 결론
(핵심 주제와 결론을 1~2문장으로)';

SET @out_lv2 = '## 전체 목적 / 주제
(2~4문장)

## 핵심 내용
(주요 포인트를 2~4문장씩)

## 결론 / 핵심 메시지
(2~3문장)

## 한줄 결론
(1문장)';

-- Lv3·4·5 공통 출력 블록 (소스 else 분기)
SET @out_lv345 = '## 전체 목적 / 주제
(3~6문장으로 구체적으로 서술)

## 주요 내용
(다뤄진 주제별로 각 3~6문장씩 상세히 서술)

## 핵심 개념·구조·주장
(구체적 내용 3~6문장)

## 쟁점 / 이슈 / Q&A
(제기된 문제와 논의 내용 3~6문장)

## 결정 사항 / 결론 / 핵심 메시지
(결정된 내용 2~4문장)

## 후속 액션 / 적용 방법 / 다음 학습
(다음 단계 2~4문장)

## 한줄 결론
(전체를 요약한 1문장)';

-- ── 리마인드 본문 (로그 원본, sequence=63) ─────────────────────────────────
SET @p_remind = '────────────────────────────────────────
[리마인드 3단 계층 구조]
────────────────────────────────────────
1단 항목(Group): 주제·영역 단위 카테고리 (2~5개 권장)
2단 세부항목(Item): [유형] 내용 / 담당자 / 기한
   유형: 일정|액션|핵심개념|적용포인트|학습할것|외부대기|리스크|기타
3단 내용(Detail): 부가 설명·맥락·근거 (1~3줄, 단순 일정은 생략 가능)

출력 포맷:
📂 [항목명]
   ▸ [유형] 세부항목 / 담당자 / 기한
     └ 부가 설명

────────────────────────────────────────
[리마인드 추출 기준]
────────────────────────────────────────
- 리마인드는 요약된 내용을 기준으로 추출한다.
- 명시적 일정/기한, 약속·확약, 핵심 개념·공식·정의
- 실행·적용 권장 포인트, 추가 학습·확인 필요 항목
- 외부 의존 항목, 리스크·주의사항, 강조 발언
- 리마인드성 내용이 없으면 "없음" 표시
- 마지막에 "리마인드 총 N개" 표기

─── 📌 리마인드 ───
(3단 계층 구조로 출력)
리마인드 총 N개';

-- [1] SUMMARY 5행 (level 1~5)
-- ※ 물리 테이블에 남아있는 prompt_role(NOT NULL, 기본값 없음) 컬럼 포함 → 'system'
INSERT INTO `note_prompt_config`
  (`type`, `prompt_role`, `file_type`, `summary_level`, `level_name`, `prompt_name`, `prompt`,
   `ai_provider`, `ai_model`, `max_tokens`,
   `remind_max_count`, `remind_max_group`, `remind_type_filter`,
   `is_active`, `description`)
VALUES
-- ai_model='gpt-4o-mini', max_tokens 1024/2048/4096/8192/16384 (5/30 원본 값 복원)
('summary','system','text',1,NULL,'text 요약 Lv1 시스템 프롬프트', CONCAT(@p_header,@out_lv1),
 'openai','gpt-4o-mini',1024, NULL,NULL,NULL, 1,'Lv1 요약 시스템 프롬프트'),
('summary','system','text',2,NULL,'text 요약 Lv2 시스템 프롬프트', CONCAT(@p_header,@out_lv2),
 'openai','gpt-4o-mini',2048, NULL,NULL,NULL, 1,'Lv2 요약 시스템 프롬프트'),
('summary','system','text',3,NULL,'text 요약 Lv3 시스템 프롬프트', CONCAT(@p_header,@out_lv345),
 'openai','gpt-4o-mini',4096, NULL,NULL,NULL, 1,'Lv3 요약 시스템 프롬프트'),
('summary','system','text',4,NULL,'text 요약 Lv4 시스템 프롬프트', CONCAT(@p_header,@out_lv345),
 'openai','gpt-4o-mini',8192, NULL,NULL,NULL, 1,'Lv4 요약 시스템 프롬프트'),
('summary','system','text',5,NULL,'text 요약 Lv5 시스템 프롬프트', CONCAT(@p_header,@out_lv345),
 'openai','gpt-4o-mini',16384, NULL,NULL,NULL, 1,'Lv5 요약 시스템 프롬프트');

-- [2] REMIND 5행 (level 1~5, 본문 공통 / count·group만 다름)
INSERT INTO `note_prompt_config`
  (`type`, `prompt_role`, `file_type`, `summary_level`, `level_name`, `prompt_name`, `prompt`,
   `ai_provider`, `ai_model`, `max_tokens`,
   `remind_max_count`, `remind_max_group`, `remind_type_filter`,
   `is_active`, `description`)
VALUES
('remind','system','text',1,NULL,'text 리마인드 시스템 프롬프트', @p_remind,
 NULL,NULL,NULL, 1,1,'일정,액션,핵심개념,적용포인트,학습할것,외부대기,리스크,기타', 1,'리마인드 3단 계층 추출 시스템 프롬프트'),
('remind','system','text',2,NULL,'text 리마인드 시스템 프롬프트', @p_remind,
 NULL,NULL,NULL, 3,2,'일정,액션,핵심개념,적용포인트,학습할것,외부대기,리스크,기타', 1,'리마인드 3단 계층 추출 시스템 프롬프트'),
('remind','system','text',3,NULL,'text 리마인드 시스템 프롬프트', @p_remind,
 NULL,NULL,NULL, 5,3,'일정,액션,핵심개념,적용포인트,학습할것,외부대기,리스크,기타', 1,'리마인드 3단 계층 추출 시스템 프롬프트'),
('remind','system','text',4,NULL,'text 리마인드 시스템 프롬프트', @p_remind,
 NULL,NULL,NULL, 10,4,'일정,액션,핵심개념,적용포인트,학습할것,외부대기,리스크,기타', 1,'리마인드 3단 계층 추출 시스템 프롬프트'),
('remind','system','text',5,NULL,'text 리마인드 시스템 프롬프트', @p_remind,
 NULL,NULL,NULL, 20,5,'일정,액션,핵심개념,적용포인트,학습할것,외부대기,리스크,기타', 1,'리마인드 3단 계층 추출 시스템 프롬프트');

-- [3] 복원 결과 확인
SELECT `sequence`, `type`, `file_type`, `summary_level`, `prompt_name`,
       LEFT(`prompt`, 40) AS prompt_head, CHAR_LENGTH(`prompt`) AS prompt_len,
       `ai_provider`, `max_tokens`, `remind_max_count`, `remind_max_group`, `is_active`
FROM `note_prompt_config`
WHERE `file_type` = 'text'
ORDER BY `type`, `summary_level`;

-- 확인 후 이상 없으면 COMMIT, 문제 있으면 ROLLBACK
COMMIT;
-- ROLLBACK;

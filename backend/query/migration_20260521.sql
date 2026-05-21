-- ============================================================
-- 마이그레이션: 2026-05-21
-- youtube_channel: 요약 수준(summary_type), 리마인드 종류(remind_type) 컬럼 추가
-- ============================================================

-- summary_type:
--   'ONE_LINE'  : 한줄 요약
--   'SHORT'     : 간단 요약
--   'NORMAL'    : 일반 요약 (default)
--   'DETAILED'  : 상세 요약
--   'FULL'      : 거의 전체
-- remind_type:
--   'ONE'       : 1개 (꼭기억)
--   'THREE'     : 3개 (핵심)
--   'FIVE'      : 5개 (기본)
--   'TEN'       : 10개 (상세)
--   'TWENTY'    : 20개 (전체)
--   'CUSTOM'    : N개 (remind_custom_count 사용)
ALTER TABLE `youtube_channel`
    ADD COLUMN `summary_type` VARCHAR(32) NULL DEFAULT NULL COMMENT '요약 수준 (ONE_LINE/SHORT/NORMAL/DETAILED/FULL)'
    AFTER `auto_summary`,
    ADD COLUMN `remind_type` VARCHAR(32) NULL DEFAULT NULL COMMENT '리마인드 종류 (ONE/THREE/FIVE/TEN/TWENTY/CUSTOM)'
    AFTER `auto_remind`,
    ADD COLUMN `remind_custom_count` INT NULL DEFAULT NULL COMMENT '리마인드 CUSTOM 개수'
    AFTER `remind_type`;

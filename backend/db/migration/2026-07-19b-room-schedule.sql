-- 셀(스터디룸) 공유 일정 테이블 신설 (2026-07-19)
--
-- 개인 일정(note_schedule)과 분리한 이유:
--   * note_schedule 은 (member_id, litten_id) UNIQUE 로 "리튼당 1개"에 묶여 있어
--     셀에 여러 일정을 달 수 없다.
--   * 멤버별로 note_schedule 행을 복제하면 멤버의 리튼/일정 무료 할당량을 잠식하고
--     수정·삭제 전파를 따로 구현해야 한다.
-- 따라서 셀 단위로 1행만 두고, 조회 시 "내가 방장이거나 멤버인 셀"로 필터한다.
-- 멤버가 셀에서 나가면 별도 정리 없이 자동으로 보이지 않는다.
--
-- 선행 조건: 2026-07-19-study-room-schedule-permission.sql (allow_member_schedule 컬럼)
CREATE TABLE IF NOT EXISTS note_room_schedule (
  id                  BIGINT       NOT NULL AUTO_INCREMENT COMMENT 'PK',
  room_id             BIGINT       NOT NULL                COMMENT '셀(룸) ID',
  creator_member_id   VARCHAR(128) NOT NULL                COMMENT '작성자 회원 ID',
  creator_name        VARCHAR(128) NULL DEFAULT NULL       COMMENT '작성자 표시 이름(비정규화)',
  title               VARCHAR(512) NOT NULL                COMMENT '일정 제목',
  schedule_date       DATE         NOT NULL                COMMENT '시작일',
  end_date            DATE         NULL DEFAULT NULL       COMMENT '종료일',
  start_time          TIME         NOT NULL                COMMENT '시작 시각',
  end_time            TIME         NOT NULL                COMMENT '종료 시각',
  notes               TEXT         NULL DEFAULT NULL       COMMENT '메모',
  is_deleted          TINYINT(1)   NOT NULL DEFAULT 0      COMMENT '삭제 여부',
  deleted_at          TIMESTAMP    NULL DEFAULT NULL       COMMENT '삭제 일시',
  insert_pk           VARCHAR(128) NULL DEFAULT NULL       COMMENT '등록자',
  update_pk           VARCHAR(128) NULL DEFAULT NULL       COMMENT '수정자',
  insert_date_time    DATETIME     NULL DEFAULT NULL       COMMENT '등록일시',
  update_date_time    DATETIME     NULL DEFAULT NULL       COMMENT '수정일시',
  PRIMARY KEY (id),
  KEY idx_room_schedule_room (room_id, is_deleted),
  KEY idx_room_schedule_date (room_id, schedule_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='셀 공유 일정';

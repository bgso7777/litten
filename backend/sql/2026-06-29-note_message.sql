-- 채팅 메시지 기능용 테이블 (ddl-auto=none 이므로 운영 DB에 수동 적용)
-- 적용: MariaDB에서 실행 후 백엔드 WAR 재배포(또는 message 패키지 .class 패치 + 재기동)

CREATE TABLE IF NOT EXISTS note_message (
  id                BIGINT(20)   NOT NULL AUTO_INCREMENT COMMENT '메시지 ID',
  sender_member_id  VARCHAR(128) NOT NULL                COMMENT '발신자 회원 ID',
  sender_name       VARCHAR(100) NULL DEFAULT NULL        COMMENT '발신자 표시 이름(스냅샷)',
  target_type       VARCHAR(10)  NOT NULL                COMMENT '대상 유형 (user/group)',
  group_id          BIGINT(20)   NULL DEFAULT NULL        COMMENT '그룹 ID(group일 때)',
  group_name        VARCHAR(100) NULL DEFAULT NULL        COMMENT '그룹 이름(스냅샷)',
  content           VARCHAR(2000) NOT NULL               COMMENT '메시지 내용',
  is_deleted        TINYINT(1)   NOT NULL DEFAULT 0       COMMENT '삭제 여부',
  insert_pk         BIGINT(20)   NULL DEFAULT NULL        COMMENT '등록 회원 ID(seq)',
  update_pk         BIGINT(20)   NULL DEFAULT NULL        COMMENT '수정 회원 ID(seq)',
  insert_date_time  DATETIME     NULL                    COMMENT '등록일시',
  update_date_time  DATETIME     NULL                    COMMENT '수정일시',
  PRIMARY KEY (id),
  KEY idx_msg_sender (sender_member_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS note_message_delivery (
  id                  BIGINT(20)   NOT NULL AUTO_INCREMENT COMMENT '전달 ID',
  message_id          BIGINT(20)   NOT NULL                COMMENT '메시지 ID',
  recipient_member_id VARCHAR(128) NOT NULL                COMMENT '수신자 회원 ID',
  is_deleted          TINYINT(1)   NOT NULL DEFAULT 0       COMMENT '삭제 여부',
  insert_pk           BIGINT(20)   NULL DEFAULT NULL        COMMENT '등록 회원 ID(seq)',
  update_pk           BIGINT(20)   NULL DEFAULT NULL        COMMENT '수정 회원 ID(seq)',
  insert_date_time    DATETIME     NULL                    COMMENT '등록일시',
  update_date_time    DATETIME     NULL                    COMMENT '수정일시',
  PRIMARY KEY (id),
  KEY idx_msgdlv_recipient (recipient_member_id),
  KEY idx_msgdlv_message (message_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

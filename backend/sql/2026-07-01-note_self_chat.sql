-- '나와의 대화'(셀프 채팅) 다기기 동기화용 테이블 (ddl-auto=none 이므로 운영 DB에 수동 적용)
-- 적용: MariaDB에서 실행 후 백엔드 WAR 재배포(또는 selfchat 패키지 .class 패치 + 재기동)

CREATE TABLE IF NOT EXISTS note_self_chat (
  id               BIGINT(20)   NOT NULL AUTO_INCREMENT COMMENT '셀프챗 방 ID',
  member_id        VARCHAR(128) NOT NULL                COMMENT '회원 ID',
  client_id        VARCHAR(64)  NULL DEFAULT NULL       COMMENT '클라이언트 로컬 방 ID(매칭/중복방지)',
  name             VARCHAR(100) NOT NULL                COMMENT '방 이름',
  is_deleted       TINYINT(1)   NOT NULL DEFAULT 0       COMMENT '삭제 여부',
  deleted_at       TIMESTAMP    NULL DEFAULT NULL        COMMENT '삭제 일시',
  insert_pk        BIGINT(20)   NULL DEFAULT NULL        COMMENT '등록 회원 ID(seq)',
  update_pk        BIGINT(20)   NULL DEFAULT NULL        COMMENT '수정 회원 ID(seq)',
  insert_date_time DATETIME     NULL                     COMMENT '등록일시',
  update_date_time DATETIME     NULL                     COMMENT '수정일시',
  PRIMARY KEY (id),
  KEY idx_selfchat_member (member_id),
  UNIQUE KEY uk_selfchat_member_client (member_id, client_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS note_self_chat_item (
  id               BIGINT(20)    NOT NULL AUTO_INCREMENT COMMENT '항목 ID',
  self_chat_id     BIGINT(20)    NOT NULL                COMMENT '셀프챗 방 ID',
  member_id        VARCHAR(128)  NOT NULL                COMMENT '회원 ID',
  item_type        VARCHAR(10)   NOT NULL                COMMENT 'text | file',
  content          VARCHAR(2000) NULL DEFAULT NULL       COMMENT '텍스트 내용',
  file_name        VARCHAR(255)  NULL DEFAULT NULL       COMMENT '파일명',
  file_type        VARCHAR(20)   NULL DEFAULT NULL       COMMENT '파일 종류',
  content_type     VARCHAR(100)  NULL DEFAULT NULL       COMMENT 'MIME 타입',
  file_size        BIGINT(20)    NULL DEFAULT NULL       COMMENT '파일 크기(bytes)',
  stored_path      VARCHAR(512)  NULL DEFAULT NULL       COMMENT '서버 저장 경로',
  is_deleted       TINYINT(1)    NOT NULL DEFAULT 0       COMMENT '삭제 여부',
  insert_pk        BIGINT(20)    NULL DEFAULT NULL        COMMENT '등록 회원 ID(seq)',
  update_pk        BIGINT(20)    NULL DEFAULT NULL        COMMENT '수정 회원 ID(seq)',
  insert_date_time DATETIME      NULL                     COMMENT '등록일시',
  update_date_time DATETIME      NULL                     COMMENT '수정일시',
  PRIMARY KEY (id),
  KEY idx_selfitem_chat (self_chat_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

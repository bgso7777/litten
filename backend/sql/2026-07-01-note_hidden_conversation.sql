-- 채팅 대화 '방 나가기'(숨김) 다기기 동기화용 테이블 (ddl-auto=none 이므로 운영 DB에 수동 적용)
-- 적용: MariaDB에서 실행 후 백엔드 WAR 재배포(또는 hidden 패키지 .class 패치 + 재기동)

CREATE TABLE IF NOT EXISTS note_hidden_conversation (
  id               BIGINT(20)   NOT NULL AUTO_INCREMENT COMMENT '숨김 ID',
  member_id        VARCHAR(128) NOT NULL                COMMENT '회원 ID',
  conv_key         VARCHAR(256) NOT NULL                COMMENT '대화 key(u:이메일 / g:그룹명)',
  hidden_at        TIMESTAMP    NULL DEFAULT NULL       COMMENT '숨긴 시각',
  insert_pk        BIGINT(20)   NULL DEFAULT NULL       COMMENT '등록 회원 ID(seq)',
  update_pk        BIGINT(20)   NULL DEFAULT NULL       COMMENT '수정 회원 ID(seq)',
  insert_date_time DATETIME     NULL                    COMMENT '등록일시',
  update_date_time DATETIME     NULL                    COMMENT '수정일시',
  PRIMARY KEY (id),
  UNIQUE KEY uk_member_conv (member_id, conv_key),
  KEY idx_hidden_member (member_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

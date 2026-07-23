-- ============================================================
-- AI 셀 (주제 기반 AI 대화) 테이블
--  · note_ai_chat          : 대화방(주제·시스템프롬프트·러닝요약)
--  · note_ai_chat_message  : 대화 메시지(user/assistant)
-- ddl-auto=none 이라 수동 적용 필요. 실제 DB = www.litten7.com (원격).
-- 적용:  mysql -h <host> -u <user> -p litten7 < migration_20260723_ai_chat.sql
-- ============================================================

CREATE TABLE IF NOT EXISTS note_ai_chat (
    id                BIGINT(20)   NOT NULL AUTO_INCREMENT COMMENT 'AI 셀 ID',
    member_id         VARCHAR(128) NOT NULL COMMENT '회원 ID(소유자)',
    client_id         VARCHAR(64)  NULL DEFAULT NULL COMMENT '클라이언트 로컬 방 ID',
    topic             VARCHAR(500) NOT NULL COMMENT '대화 주제',
    title             VARCHAR(200) NOT NULL COMMENT '표시 이름',
    system_prompt     TEXT         NULL COMMENT '주제 기반 시스템 프롬프트',
    running_summary   MEDIUMTEXT   NULL COMMENT '오래된 대화의 러닝 요약',
    summarized_msg_id BIGINT(20)   NOT NULL DEFAULT 0 COMMENT '이 ID 이하 메시지는 러닝요약에 반영됨',
    is_deleted        TINYINT(1)   NOT NULL DEFAULT 0 COMMENT '삭제 여부',
    deleted_at        TIMESTAMP    NULL DEFAULT NULL COMMENT '삭제 일시',
    insert_pk         BIGINT(20)   NULL DEFAULT NULL COMMENT '등록 회원 ID(seq)',
    update_pk         BIGINT(20)   NULL DEFAULT NULL COMMENT '수정 회원 ID(seq)',
    insert_date_time  DATETIME     NULL COMMENT '등록일시',
    update_date_time  DATETIME     NULL COMMENT '수정일시',
    PRIMARY KEY (id),
    KEY idx_ai_chat_member (member_id, is_deleted, update_date_time),
    KEY idx_ai_chat_member_client (member_id, client_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI 셀(주제 기반 AI 대화방)';

CREATE TABLE IF NOT EXISTS note_ai_chat_message (
    id                BIGINT(20)   NOT NULL AUTO_INCREMENT COMMENT '메시지 ID',
    chat_id           BIGINT(20)   NOT NULL COMMENT 'AI 셀 ID',
    member_id         VARCHAR(128) NOT NULL COMMENT '회원 ID(소유자)',
    role              VARCHAR(16)  NOT NULL COMMENT 'user 또는 assistant',
    content           MEDIUMTEXT   NOT NULL COMMENT '메시지 내용',
    is_deleted        TINYINT(1)   NOT NULL DEFAULT 0 COMMENT '삭제 여부',
    insert_pk         BIGINT(20)   NULL DEFAULT NULL COMMENT '등록 회원 ID(seq)',
    update_pk         BIGINT(20)   NULL DEFAULT NULL COMMENT '수정 회원 ID(seq)',
    insert_date_time  DATETIME     NULL COMMENT '등록일시',
    update_date_time  DATETIME     NULL COMMENT '수정일시',
    PRIMARY KEY (id),
    KEY idx_ai_chat_msg_chat (chat_id, is_deleted, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI 셀 대화 메시지';

package com.litten.note.aichat;

import com.litten.common.dynamic.BaseEntity;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.*;
import java.io.Serializable;
import java.time.LocalDateTime;

/**
 * 'AI 셀' — 회원이 주제(topic)를 정하고 그 주제 안에서 AI와 대화하는 방.
 * 회원별로 여러 개 생성 가능. 방에 다시 들어오면 과거 대화를 기억하고 이어간다.
 *
 * 대화 이어가기(메모리) 효율화:
 *  - 최근 N턴은 {@link AiChatMessage} 원문으로 AI에 전달
 *  - 그보다 오래된 대화는 running_summary(러닝 요약)로 압축해 토큰/비용 상한을 확보
 *  - summarized_msg_id 이하의 메시지는 running_summary 로 접혀 들어간 것으로 간주
 */
@Getter
@Setter
@Entity(name = "AiChat")
@Table(name = "note_ai_chat")
@NoArgsConstructor
public class AiChat extends BaseEntity implements Serializable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id", columnDefinition = "BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT 'AI 셀 ID'")
    private Long id;

    @Column(name = "member_id", columnDefinition = "VARCHAR(128) NOT NULL COMMENT '회원 ID(소유자)'")
    private String memberId;

    // 클라이언트 로컬에서 만든 방과 매칭/중복방지용(밀리초 등). 없으면 null.
    @Column(name = "client_id", columnDefinition = "VARCHAR(64) NULL DEFAULT NULL COMMENT '클라이언트 로컬 방 ID'")
    private String clientId;

    @Column(name = "topic", columnDefinition = "VARCHAR(500) NOT NULL COMMENT '대화 주제'")
    private String topic;

    @Column(name = "title", columnDefinition = "VARCHAR(200) NOT NULL COMMENT '표시 이름'")
    private String title;

    @Column(name = "system_prompt", columnDefinition = "TEXT NULL COMMENT '주제 기반 시스템 프롬프트'")
    private String systemPrompt;

    @Column(name = "running_summary", columnDefinition = "MEDIUMTEXT NULL COMMENT '오래된 대화의 러닝 요약'")
    private String runningSummary;

    @Column(name = "summarized_msg_id", columnDefinition = "BIGINT(20) NOT NULL DEFAULT 0 COMMENT '이 ID 이하 메시지는 러닝요약에 반영됨'")
    private Long summarizedMsgId = 0L;

    @Column(name = "is_deleted", columnDefinition = "TINYINT(1) NOT NULL DEFAULT 0 COMMENT '삭제 여부'")
    private Boolean isDeleted = false;

    @Column(name = "deleted_at", columnDefinition = "TIMESTAMP NULL DEFAULT NULL COMMENT '삭제 일시'")
    private LocalDateTime deletedAt;
}

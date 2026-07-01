package com.litten.note.hidden;

import com.litten.common.dynamic.BaseEntity;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.*;
import java.io.Serializable;
import java.time.LocalDateTime;

/**
 * 채팅 대화 '방 나가기'(숨김) 상태 — 회원별로 대화 key를 숨긴 시각과 함께 저장한다.
 * 클라이언트는 대화의 최신 활동시각(lastAt)이 hidden_at 이하이면 목록에서 숨긴다.
 * 새 메시지/공유가 오면(lastAt > hidden_at) 자동으로 다시 보인다.
 * conv_key 예: 'u:이메일'(1:1), 'g:그룹명'(그룹).
 */
@Getter
@Setter
@Entity(name = "HiddenConversation")
@Table(name = "note_hidden_conversation",
        uniqueConstraints = @UniqueConstraint(name = "uk_member_conv",
                columnNames = {"member_id", "conv_key"}))
@NoArgsConstructor
public class HiddenConversation extends BaseEntity implements Serializable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id", columnDefinition = "BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '숨김 ID'")
    private Long id;

    @Column(name = "member_id", columnDefinition = "VARCHAR(128) NOT NULL COMMENT '회원 ID'")
    private String memberId;

    @Column(name = "conv_key", columnDefinition = "VARCHAR(256) NOT NULL COMMENT '대화 key(u:이메일 / g:그룹명)'")
    private String convKey;

    @Column(name = "hidden_at", columnDefinition = "TIMESTAMP NULL DEFAULT NULL COMMENT '숨긴 시각'")
    private LocalDateTime hiddenAt;
}

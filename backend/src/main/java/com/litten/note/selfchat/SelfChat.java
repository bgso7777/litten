package com.litten.note.selfchat;

import com.litten.common.dynamic.BaseEntity;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.*;
import java.io.Serializable;
import java.time.LocalDateTime;

/** '나와의 대화'(셀프 채팅방) — 회원별로 여러 개 생성. 방 안에 텍스트/파일 항목을 쌓는다. 기기 간 동기화용. */
@Getter
@Setter
@Entity(name = "SelfChat")
@Table(name = "note_self_chat")
@NoArgsConstructor
public class SelfChat extends BaseEntity implements Serializable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id", columnDefinition = "BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '셀프챗 방 ID'")
    private Long id;

    @Column(name = "member_id", columnDefinition = "VARCHAR(128) NOT NULL COMMENT '회원 ID'")
    private String memberId;

    // 클라이언트 로컬에서 만든 방과 매칭/중복방지용(밀리초 등). 없으면 null.
    @Column(name = "client_id", columnDefinition = "VARCHAR(64) NULL DEFAULT NULL COMMENT '클라이언트 로컬 방 ID'")
    private String clientId;

    @Column(name = "name", columnDefinition = "VARCHAR(100) NOT NULL COMMENT '방 이름'")
    private String name;

    @Column(name = "is_deleted", columnDefinition = "TINYINT(1) NOT NULL DEFAULT 0 COMMENT '삭제 여부'")
    private Boolean isDeleted = false;

    @Column(name = "deleted_at", columnDefinition = "TIMESTAMP NULL DEFAULT NULL COMMENT '삭제 일시'")
    private LocalDateTime deletedAt;
}

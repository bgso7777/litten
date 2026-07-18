package com.litten.note.studyroom;

import com.litten.common.dynamic.BaseEntity;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.*;
import java.io.Serializable;
import java.time.LocalDateTime;

/** 스터디룸 (소유자 단위). 룸에 멤버를 넣고 학습자료를 룸 전체에 공유한다. */
@Getter
@Setter
@Entity(name = "StudyRoom")
@Table(name = "note_study_room")
@NoArgsConstructor
public class StudyRoom extends BaseEntity implements Serializable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id", columnDefinition = "BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '룸 ID'")
    private Long id;

    @Column(name = "owner_member_id", columnDefinition = "VARCHAR(128) NOT NULL COMMENT '룸 소유자 회원 ID'")
    private String ownerMemberId;

    @Column(name = "name", columnDefinition = "VARCHAR(100) NOT NULL COMMENT '룸 이름'")
    private String name;

    @Column(name = "password", columnDefinition = "VARCHAR(128) NULL DEFAULT NULL COMMENT '룸 비밀번호'")
    private String password;

    @Column(name = "allow_member_chat", columnDefinition = "TINYINT(1) NOT NULL DEFAULT 1 COMMENT '멤버 대화 허용 여부'")
    private Boolean allowMemberChat = true;

    @Column(name = "allow_member_file", columnDefinition = "TINYINT(1) NOT NULL DEFAULT 0 COMMENT '멤버 파일 추가 허용 여부'")
    private Boolean allowMemberFile = false;

    @Column(name = "is_deleted", columnDefinition = "TINYINT(1) NOT NULL DEFAULT 0 COMMENT '삭제 여부'")
    private Boolean isDeleted = false;

    @Column(name = "deleted_at", columnDefinition = "TIMESTAMP NULL DEFAULT NULL COMMENT '삭제 일시'")
    private LocalDateTime deletedAt;
}

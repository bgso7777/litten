package com.litten.note.studyroom;

import com.litten.common.dynamic.BaseEntity;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.*;
import java.io.Serializable;

/** 스터디룸 멤버 (수신 대상 회원). */
@Getter
@Setter
@Entity(name = "StudyRoomMember")
@Table(name = "note_study_room_member")
@NoArgsConstructor
public class StudyRoomMember extends BaseEntity implements Serializable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id", columnDefinition = "BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '룸 멤버 ID'")
    private Long id;

    @Column(name = "room_id", columnDefinition = "BIGINT(20) NOT NULL COMMENT '룸 ID'")
    private Long roomId;

    @Column(name = "member_id", columnDefinition = "VARCHAR(128) NOT NULL COMMENT '멤버 회원 ID(수신 대상)'")
    private String memberId;

    @Column(name = "member_name", columnDefinition = "VARCHAR(100) NULL DEFAULT NULL COMMENT '표시 이름(스냅샷)'")
    private String memberName;

    @Column(name = "is_deleted", columnDefinition = "TINYINT(1) NOT NULL DEFAULT 0 COMMENT '삭제 여부'")
    private Boolean isDeleted = false;
}

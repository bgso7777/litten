package com.litten.note;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import javax.persistence.*;
import java.io.Serializable;

@Getter
@Setter
@Entity(name="NoteMember")
@Table(name = "note_member")
@NoArgsConstructor
public class NoteMember extends NoteMemberCommon implements Serializable {

    @GeneratedValue(strategy=GenerationType.IDENTITY)
    @Column(name="sequence", columnDefinition="BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '회원sequence'")
    private Integer sequence;

    @Id
    @Column(name="id", columnDefinition="VARCHAR(128) NULL DEFAULT NULL COMMENT '계정 id' COLLATE 'utf8mb4_unicode_ci'")
    private String id;

}

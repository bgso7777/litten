package com.litten.note;

import com.fasterxml.jackson.databind.annotation.JsonDeserialize;
import com.fasterxml.jackson.databind.annotation.JsonSerialize;
import com.fasterxml.jackson.datatype.jsr310.deser.LocalDateTimeDeserializer;
import com.fasterxml.jackson.datatype.jsr310.ser.LocalDateTimeSerializer;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.springframework.data.annotation.CreatedDate;

import javax.persistence.*;
import java.io.Serializable;
import java.time.LocalDateTime;

//@Getter
//@Setter
//@Entity(name="NoteMember")
//@Table(name="note_member")
//@AllArgsConstructor
//@NoArgsConstructor
//public class NoteMember extends BaseEntity {

@Getter
@Setter
@Entity(name="NoteMemberLog")
@Table(name = "note_member_log")
@NoArgsConstructor
public class NoteMemberLog extends NoteMemberCommon implements Serializable {

    @Id
    @GeneratedValue(strategy=GenerationType.IDENTITY)
    @Column(name="sequence_log", columnDefinition="BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '회원sequence'")
    private Integer sequenceLog;

    @Column(name="sequence", columnDefinition="BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '회원sequence'")
    private Integer sequence;

    @Column(name="id", columnDefinition="VARCHAR(128) NULL DEFAULT NULL COMMENT '계정 id' COLLATE 'utf8mb4_unicode_ci'")
    private String id;

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    @Column(name="query_code", columnDefinition="VARCHAR(10) NOT NULL DEFAULT 'B2001' COMMENT '쿼리 코드' COLLATE 'utf8mb4_unicode_ci'")
    private String queryCode;

    @Column(name="query_token_id", columnDefinition="VARCHAR(128) NULL DEFAULT NULL COMMENT '쿼리 실행 로그인 id' COLLATE 'utf8mb4_unicode_ci'")
    private String queryTokenId;

    @JsonSerialize(using= LocalDateTimeSerializer.class)
    @JsonDeserialize(using= LocalDateTimeDeserializer.class)
    @CreatedDate
    @Column(name="query_date", columnDefinition="TIMESTAMP NULL DEFAULT NULL COMMENT '쿼리 실행 일시' COLLATE 'utf8mb4_unicode_ci'")
    private LocalDateTime queryDate;

//	@OneToMany(mappedBy="companyLog")
//	private Collection<MemberLog> memberLogs = new ArrayList<>();
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//    @Getter
//    @Setter
//    @Entity(name="CompanyLog")
//    @Table(name = "tbl_company_log")
//    @NoArgsConstructor
//    public class CompanyLog extends CompanyCommon implements Serializable {
//
//        @Id
//        @Column(name="pk_company_log", columnDefinition="BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '회사 로그 pk'")
//        @GeneratedValue(strategy=GenerationType.IDENTITY)
//        private Long companyLogSeq;
//
//        @Column(name="pk_company", columnDefinition="BIGINT(20) NOT NULL COMMENT '회사 pk'")
//        private Long companySeq;
//
//
//    }

}

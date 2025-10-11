package com.litten.common.domain;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.annotation.JsonDeserialize;
import com.fasterxml.jackson.databind.annotation.JsonSerialize;
import com.fasterxml.jackson.datatype.jsr310.deser.LocalDateTimeDeserializer;
import com.fasterxml.jackson.datatype.jsr310.ser.LocalDateTimeSerializer;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import lombok.extern.log4j.Log4j2;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import jakarta.persistence.Column;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.MappedSuperclass;
import java.io.Serializable;
import java.time.LocalDateTime;

@Log4j2
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@EntityListeners(AuditingEntityListener.class)
@JsonIgnoreProperties(ignoreUnknown = true)
@MappedSuperclass
public class Domain implements Serializable {

    public String toJson() {
        StringBuilder sb = new StringBuilder();
        try {
            ObjectMapper mapper = new ObjectMapper();
            sb.append(mapper.writeValueAsString(this));
        }catch(Exception e) {
            log.error("json parse error",e);
        }
        return sb.toString();
    }

    @JsonSerialize(using=LocalDateTimeSerializer.class)
    @JsonDeserialize(using=LocalDateTimeDeserializer.class)
    @CreatedDate
    @Column(name="fd_regdate", columnDefinition="TIMESTAMP NULL DEFAULT current_timestamp() COMMENT '[직원]등록일시'")
    private LocalDateTime insertDate;

    @JsonSerialize(using=LocalDateTimeSerializer.class)
    @JsonDeserialize(using=LocalDateTimeDeserializer.class)
    @LastModifiedDate
    @Column(name="fd_moddate", columnDefinition="TIMESTAMP NULL DEFAULT NULL COMMENT '[직원]수정일시'")
    private LocalDateTime updateDate;

}
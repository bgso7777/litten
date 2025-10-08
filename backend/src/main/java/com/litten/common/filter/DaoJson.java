package com.litten.common.filter;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonInclude.Include;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import lombok.ToString;
import lombok.extern.log4j.Log4j2;

@ToString
@Log4j2
@JsonInclude(Include.NON_EMPTY)
@JsonIgnoreProperties(ignoreUnknown = true)
public class DaoJson {
    public String toJson() {
        StringBuilder sb = new StringBuilder();
        try {
            ObjectMapper mapper = new ObjectMapper().enable(SerializationFeature.INDENT_OUTPUT);
            sb.append(mapper.writeValueAsString(this));
        }catch(Exception e) {
            log.error("json parse error",e);
        }
        return sb.toString();
    }
}

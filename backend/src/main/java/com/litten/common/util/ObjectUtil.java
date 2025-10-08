package com.litten.common.util;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import lombok.extern.log4j.Log4j2;

@Log4j2
public class ObjectUtil {

    public static Object copy(Object sourceObject, Class c) {
        Object retObject = null;
        try {
            ObjectMapper objectMapper = new ObjectMapper();
            objectMapper.registerModule(new JavaTimeModule());
            String contactResultJsonString = objectMapper.writeValueAsString(sourceObject);
            retObject = objectMapper.readValue(contactResultJsonString, c);
        } catch(Exception e) {
            log.error(e);
        }
        return retObject;
    }
}

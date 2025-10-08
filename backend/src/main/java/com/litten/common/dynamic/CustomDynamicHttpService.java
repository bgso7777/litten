package com.litten.common.dynamic;

import org.springframework.stereotype.Service;

import java.util.Map;

@Service
public interface CustomDynamicHttpService {
    Map<String,Object> get(String methodName, Object... args);
    Map<String,Object> post(String methodName, Object... args);
    Map<String,Object> put(String methodName, Object... args);
    Map<String,Object> patch(String methodName, Object... args);
    Map<String,Object> delete(String methodName, Object... args);
    Map<String, Object> count(String methodName, Object... args);

    Map<String, Object> process(String methodName, Object... args);
}

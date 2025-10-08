package com.litten.common.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.litten.Constants;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

@Component
public class AccessDeniedHandlerImpl implements AccessDeniedHandler {

    @Override
    public void handle(HttpServletRequest request, HttpServletResponse response, AccessDeniedException exception) throws IOException {

//        response.sendRedirect("/error/accessdenied"); // 권한 없음

        // 계속 재발행 시 악용의 소지가 있으므로 삭제한다.
        response.setHeader(Constants.TAG_HTTP_HEADER_AUTH_TOKEN, "");
        response.setHeader(Constants.TAG_HTTP_HEADER_TOKEN_EXPIRED_DATE, "");

        // 권한이 없는 경로로 접근 시.
        Map<String,Object> json = new HashMap();
        json.put(Constants.TAG_RESULT, Constants.RESULT_AUTH_TOKEN_ROLE_ERROR);
        json.put(Constants.TAG_RESULT_MESSAGE, "token role error");
        response.setContentType(Constants.TAG_HTTP_HEADER_JSON_CONTENT_TYPE);
        ObjectMapper mapper = new ObjectMapper();
        String responseData = mapper.writeValueAsString(json);

        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);

        response.getWriter().write(responseData);
        response.flushBuffer();

    }
}
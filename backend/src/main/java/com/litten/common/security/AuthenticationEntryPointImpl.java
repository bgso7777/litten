package com.litten.common.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.litten.Constants;
import lombok.extern.log4j.Log4j2;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

@Log4j2
@Component
public class AuthenticationEntryPointImpl implements AuthenticationEntryPoint {

    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response,
                         AuthenticationException authException) throws IOException, ServletException {

//        // 계속 재발행 시 악용의 소지가 있으므로 삭제한다.
//        response.setHeader(Constants.TAG_HTTP_HEADER_AUTH_TOKEN, "");
//        response.setHeader(Constants.TAG_HTTP_HEADER_TOKEN_EXPIRED_DATE, "");
//
//        Map<String,Object> json = new HashMap();
//        String result = response.getHeader(Constants.TAG_RESULT);
//        if( result!=null && !result.equals("") ) { // result가 있는 경우는 catch가 된 경우임
//            json.put(Constants.TAG_RESULT, Constants.RESULT_AUTH_TOKEN_ERROR);
//            json.put(Constants.TAG_RESULT_MESSAGE, "token error");
//        } else {
//            json.put(Constants.TAG_RESULT, Constants.RESULT_API_GETEWAY_ERROR);
//            json.put(Constants.TAG_RESULT_MESSAGE, "gateway("+request.getRemoteHost()+") or not allowed path("+request.getRequestURI()+") or header auth-token");
//        }
//        response.setContentType(Constants.TAG_HTTP_HEADER_JSON_CONTENT_TYPE);
//        ObjectMapper mapper = new ObjectMapper();
//        String responseData = mapper.writeValueAsString(json);
//
//        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
//
//        response.getWriter().write(responseData);
//        response.flushBuffer();
    }
}

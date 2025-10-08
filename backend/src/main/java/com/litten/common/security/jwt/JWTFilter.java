package com.litten.common.security.jwt;

import com.litten.Constants;
import com.litten.common.config.Config;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import lombok.extern.log4j.Log4j2;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.GenericFilterBean;

import javax.servlet.FilterChain;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.ZonedDateTime;

@Log4j2
public class JWTFilter extends GenericFilterBean {

    private final TokenProvider tokenProvider;

    public JWTFilter(TokenProvider tokenProvider) {
        this.tokenProvider = tokenProvider;
    }

    @Override
    public void doFilter(ServletRequest servletRequest, ServletResponse servletResponse, FilterChain filterChain) throws IOException, ServletException {

        HttpServletRequest httpServletRequest = (HttpServletRequest) servletRequest;
        HttpServletResponse httpServletResponse = (HttpServletResponse) servletResponse;

        String remoteAddr = httpServletRequest.getRemoteAddr();
        String remoteHost = httpServletRequest.getRemoteHost();

        logger.debug("httpServletRequest.getRemoteAddr() --> "+remoteAddr);
        logger.debug("httpServletRequest.getRemoteHost() --> "+remoteHost);

        String jwt = resolveToken((HttpServletRequest) servletRequest);
        logger.debug("jwt --> "+jwt);
        if( jwt==null || jwt.equals("") ){
        } else {
            try {
                if (tokenProvider.validateToken(jwt)) { // 일자가 유효한 token 이면 일단 발행 권한은 이후에 체크
                    Authentication authentication = this.tokenProvider.getAuthentication(jwt);
                    SecurityContextHolder.getContext().setAuthentication(authentication);
                    Boolean isMobile = (Boolean) tokenProvider.getValue(jwt,"isMobile");
                    String newJwt = "";
                    if( isMobile==null || !isMobile )
                        newJwt = tokenProvider.createToken(authentication, Config.getInstance().getTokenValidityInMilliseconds(),false);
                    else
                        newJwt = tokenProvider.createToken(authentication,Config.getInstance().getMobileTokenValidityInMilliseconds(),isMobile);
                    Long tokenExpiredDate = ZonedDateTime.now().plusSeconds((long) (tokenProvider.getTokenValidityInMilliseconds() * 0.001)).toInstant().toEpochMilli();
                    // auth-token을 업데이트 후 response에 재전송
                    httpServletResponse.setHeader(Constants.TAG_HTTP_HEADER_AUTH_TOKEN, newJwt);
                    httpServletResponse.setHeader(Constants.TAG_HTTP_HEADER_TOKEN_EXPIRED_DATE, tokenExpiredDate.toString());
                } else {
                    logger.error("jwt --> " + jwt);
                }
            } catch (ExpiredJwtException e1) {
                httpServletResponse.setHeader(Constants.TAG_RESULT, Integer.toString(Constants.RESULT_AUTH_TOKEN_ERROR));
                log.error("ExpiredJwtException : {}"+" authToken-->>"+jwt, e1);
            } catch (JwtException e2) {
                httpServletResponse.setHeader(Constants.TAG_RESULT, Integer.toString(Constants.RESULT_AUTH_TOKEN_ERROR));
                log.error("JwtException : {}"+" authToken-->>"+jwt, e2);
            } catch (Exception e4) {
//                httpServletResponse.setHeader(Constants.TAG_RESULT, Integer.toString(Constants.RESULT_AUTH_TOKEN_ERROR));
                log.error("IllegalArgumentException : {}"+" authToken-->>"+jwt, e4);
            }
        }
        filterChain.doFilter(servletRequest, servletResponse);
    }

    public static String resolveToken(HttpServletResponse response) {
        String token = response.getHeader(Constants.TAG_HTTP_HEADER_AUTH_TOKEN);
        return resolveToken(token);
    }

    public static String resolveToken(HttpServletRequest request) {
        String token = request.getHeader(Constants.TAG_HTTP_HEADER_AUTH_TOKEN);
        return resolveToken(token);
    }

    private static String resolveToken(String token) {
        if (StringUtils.hasText(token)) {
            if (token.startsWith("Bearer ")) {
                return token.substring(7);  // Bearer token 일 때 처리
            } else {
                return token;
            }
        }
        if (StringUtils.hasText(token)) {
            return token;
        }
        return "";
    }
}

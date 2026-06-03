package com.litten.common.security.jwt;

import com.litten.common.security.AuthoritiesConstants;
import lombok.extern.log4j.Log4j2;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.GenericFilterBean;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import jakarta.servlet.http.HttpServletRequest;
import java.io.IOException;
import java.util.List;

/**
 * 비로그인 게스트 인증 필터.
 *
 * JWTFilter 이후에 동작하며, JWT 인증이 없는 경우에만 device-uuid 헤더를 검사한다.
 *   - device-uuid 헤더가 있으면 principal = "guest:<uuid>" 로 SecurityContext 설정
 *   - 권한은 ROLE_GUEST 단일 부여 → 민감 엔드포인트(hasAuthority 검증)와 분리
 *
 * 이렇게 하면 기존 컨트롤러의 SecurityUtils.getCurrentUserLogin() 이
 * "guest:<uuid>" 를 반환하여 멤버 기반 로직을 코드 변경 없이 재사용한다.
 */
@Log4j2
public class GuestUuidAuthenticationFilter extends GenericFilterBean {

    public static final String GUEST_PREFIX = "guest:";
    private static final String HEADER_DEVICE_UUID = "device-uuid";

    @Override
    public void doFilter(ServletRequest servletRequest, ServletResponse servletResponse, FilterChain filterChain)
            throws IOException, ServletException {

        // JWT 인증이 이미 설정돼 있으면 게스트 처리 생략 (로그인 사용자 우선)
        if (SecurityContextHolder.getContext().getAuthentication() == null) {
            HttpServletRequest request = (HttpServletRequest) servletRequest;
            String deviceUuid = request.getHeader(HEADER_DEVICE_UUID);

            if (StringUtils.hasText(deviceUuid)) {
                String principal = GUEST_PREFIX + deviceUuid;
                UsernamePasswordAuthenticationToken authentication =
                        new UsernamePasswordAuthenticationToken(
                                principal, null,
                                List.of(AuthoritiesConstants.ROLE_GUEST));
                SecurityContextHolder.getContext().setAuthentication(authentication);
                log.debug("[GuestUuidAuthenticationFilter] 게스트 인증 설정 - principal: {}", principal);
            }
        }

        filterChain.doFilter(servletRequest, servletResponse);
    }
}

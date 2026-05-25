package com.litten.common.filter;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.http.MediaType;
import org.springframework.http.server.ServletServerHttpRequest;
import org.springframework.stereotype.Component;
import org.springframework.util.AntPathMatcher;
import org.springframework.util.ObjectUtils;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.web.util.ContentCachingRequestWrapper;
import org.springframework.web.util.ContentCachingResponseWrapper;
import org.springframework.web.util.UriComponentsBuilder;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.*;

//https://www.springcloud.io/post/2022-03/record-request-and-response-bodies/#gsc.tab=0

@Component
public class HttpLoggingFilter extends OncePerRequestFilter {
    final Logger log = LoggerFactory.getLogger(getClass());
    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

    // 로깅용 본문 캡처 한도 (8KB) — 이걸 넘으면 잘라서 기록. 파일 업로드/다운로드 응답이 통째로 메모리에 잡히는 것을 차단.
    private static final int MAX_BODY_LOG_BYTES = 8192;

    @Override
    protected void doFilterInternal(
        HttpServletRequest httpServletRequest
        ,HttpServletResponse httpServletResponse
        ,FilterChain filterChain
    ) throws ServletException, IOException {
        httpServletResponse.setHeader("Access-Control-Allow-Origin","*");
        httpServletResponse.setHeader("Access-Control-Allow-Headers","*");
        httpServletResponse.setHeader("Access-Control-Expose-Headers","Access-Control-Allow-Origin, Access-Control-Allow-Credentials");
        httpServletResponse.setIntHeader("Access-Control-Max-Age", 10);

        try {
            if ("OPTIONS".equalsIgnoreCase(httpServletRequest.getMethod())) {
                httpServletResponse.setStatus(HttpServletResponse.SC_OK);
                return;
            }

            // 큰 본문이 오가는 엔드포인트(파일 업/다운로드, PDF 변환)는
            // ContentCachingRequest/ResponseWrapper 자체를 우회 — 본문 byte[]를 메모리에 캐시하지 않는다.
            if (this.isExcludeLogging(httpServletRequest)) {
                filterChain.doFilter(httpServletRequest, httpServletResponse);
                return;
            }

            ContentCachingRequestWrapper cachingReq = new ContentCachingRequestWrapper(httpServletRequest);
            ContentCachingResponseWrapper cachingRes = new ContentCachingResponseWrapper(httpServletResponse);
            filterChain.doFilter(cachingReq, cachingRes);

            this.loggingReq(cachingReq, cachingRes);
            cachingRes.copyBodyToResponse();
        } catch (Exception e) {
            if (isBrokenPipe(e)) {
                log.debug("[HttpLoggingFilter] 클라이언트 연결 끊김 (broken pipe) - uri: {}", httpServletRequest.getRequestURI());
            } else {
                log.error("[HttpLoggingFilter] 요청 처리 중 오류 - uri: {}", httpServletRequest.getRequestURI(), e);
                if (e instanceof IOException) throw (IOException) e;
                if (e instanceof ServletException) throw (ServletException) e;
                throw new ServletException(e);
            }
        }
    }

    /**
     * <h2>예외처리</h2>
     */
    boolean isExcludeLogging(HttpServletRequest req) {
        AntPathMatcher pathMatcher = new AntPathMatcher();
        // 큰 페이로드 엔드포인트는 로깅+캐싱 모두 스킵 — 메모리 폭주 방지.
        List<String> excludeUrlPatterns = List.of(
            "/health/**"
            ,"/note/v1/files"           // 파일 업로드(POST 멀티파트)
            ,"/note/v1/files/*"         // 파일 PUT(멀티파트)/DELETE
            ,"/note/v1/files/*/download"// 파일 다운로드(바이너리 응답)
            ,"/note/v1/convert/**"      // PDF 변환(멀티파트 입력, 바이너리 응답)
        );
        return excludeUrlPatterns
                .stream()
                .anyMatch(p -> pathMatcher.match(p, req.getServletPath()));
    }

    void loggingReq(
        ContentCachingRequestWrapper req
        ,ContentCachingResponseWrapper res
    ) {
        try {
            VoHttpLogItem logItemReq = new VoHttpLogItem();
            logItemReq.setMethod(req.getMethod());
            logItemReq.setContentType(req.getContentType());
            logItemReq.setUri(UriComponentsBuilder.fromHttpRequest(new ServletServerHttpRequest(req)).build().toUriString());
            logItemReq.setHeaders(this.getHeadersReq(req));
            logItemReq.setClientIp(this.getClientIp(req));
            logItemReq.setSessionId(req.getSession().getId());
            MediaType mediaType = MediaType.APPLICATION_JSON;
            if (ObjectUtils.isEmpty(req.getContentType()) == false) {
                mediaType = MediaType.valueOf(req.getContentType());
            }
            if (this.isLoggingBody(mediaType) == true) {
                logItemReq.setBody(this.convToMap(this.getReqBody(req)));
            }

            VoHttpLogItem logItemRes = new VoHttpLogItem();
            String resContentType = res.getContentType();
            logItemRes.setContentType(resContentType != null ? resContentType : mediaType.toString());
            logItemRes.setHeaders(this.getHeadersRes(res));
            // 응답도 로깅 가능한 MediaType일 때만 본문 기록 — 파일 다운로드/바이너리 응답이 메모리에서 String으로 변환되는 것을 차단.
            if (resContentType != null) {
                try {
                    MediaType resMediaType = MediaType.valueOf(resContentType);
                    if (this.isLoggingBody(resMediaType)) {
                        logItemRes.setBody(this.convToMap(this.getResBody(res)));
                    }
                } catch (Exception ignore) {
                    // content-type 파싱 실패 시 본문 로깅 스킵
                }
            }

            VoHttpLog voHttpLog = new VoHttpLog();
            voHttpLog.setReq(logItemReq);
            voHttpLog.setRes(logItemRes);

            log.info("request logging {}----------------------------------------------------------------------------------------------------{}{}{}----------------------------------------------------------------------------------------------------"
                    , System.lineSeparator()
                    , System.lineSeparator()
                    , voHttpLog.toJson()
                    , System.lineSeparator()
            );
        } catch(Exception ee) {
            ee.printStackTrace();
        }
    }

    boolean isLoggingBody(MediaType mediaType) {
        // MULTIPART_FORM_DATA 의도적 제외 — 파일 업로드 본문이 메모리에서 String으로 복제되는 것을 차단.
        List<MediaType> VISIBLE_TYPES = Arrays.asList(
                MediaType.valueOf("text/*")
                ,MediaType.APPLICATION_FORM_URLENCODED
                ,MediaType.APPLICATION_JSON
                ,MediaType.APPLICATION_XML
                ,MediaType.valueOf("application/*+json")
                ,MediaType.valueOf("application/*+xml")
        );
        return VISIBLE_TYPES.stream()
                .anyMatch(visibleType -> visibleType.includes(mediaType));
    }

    Map<String,String> getHeadersReq(ContentCachingRequestWrapper req) {
        Map<String,String> headers = new HashMap<>();
        try {
            Enumeration<String> headerMap = req.getHeaderNames();
            while(headerMap.hasMoreElements()) {
                String key = headerMap.nextElement();
                headers.put(key,req.getHeader(key));
            }
        }catch(Exception e1) {
            log.error("getHeadersReq",e1);
        }
        return headers;
    }

    Map<String,String> getHeadersRes(ContentCachingResponseWrapper res) {
        Map<String,String> headers = new HashMap<>();
        try {
            Collection<String> headerMap = res.getHeaderNames();
            for(String str : headerMap) {
                headers.put(str,res.getHeader(str));
            }
        }catch(Exception e1) {
            log.error("getHeadersRes",e1);
        }
        return headers;
    }

    String getReqBody(ContentCachingRequestWrapper req) {
        try {
            byte[] reqBody = req.getContentAsByteArray();
            if (ObjectUtils.isEmpty(reqBody)) return "";
            return truncatedString(reqBody);
        } catch (Exception e1) {
            log.error("getReqBody", e1);
            return "";
        }
    }

    String getResBody(ContentCachingResponseWrapper res) {
        try {
            byte[] resBody = res.getContentAsByteArray();
            if (ObjectUtils.isEmpty(resBody)) return "";
            return truncatedString(resBody);
        } catch (Exception e1) {
            log.error("getResBody", e1);
            return "";
        }
    }

    // 본문 byte[]을 MAX_BODY_LOG_BYTES까지만 String으로 변환. 큰 페이로드를 통째로 String 복제하는 것을 차단.
    private String truncatedString(byte[] body) {
        int len = Math.min(body.length, MAX_BODY_LOG_BYTES);
        String s = new String(body, 0, len, StandardCharsets.UTF_8);
        if (body.length > MAX_BODY_LOG_BYTES) {
            s += "...[truncated " + (body.length - MAX_BODY_LOG_BYTES) + " bytes]";
        }
        return s;
    }

    Map<String,Object> convToMap(String jsonBody){
        if(ObjectUtils.isEmpty(jsonBody) == true) {
            return null;
        }
        try {
            return OBJECT_MAPPER.readValue(jsonBody,new TypeReference<Map<String,Object>>() {});
        }catch(Exception e1) {
            log.debug("[HttpLoggingFilter] convToMap 파싱 실패 (body가 잘렸을 수 있음): {}", e1.getMessage());
        }
        return null;
    }

    /**
     * <h2>get client ip</h2>
     */
    String getClientIp(HttpServletRequest httpServletRequest) {
        String clientIp  = null;
        try {
            clientIp = httpServletRequest.getHeader("True-Client-IP");
            if(ObjectUtils.isEmpty(clientIp) == true) {
                clientIp = httpServletRequest.getHeader("X-FORWARDED-FOR");
            }
            if(ObjectUtils.isEmpty(clientIp) == true) {
                clientIp = httpServletRequest.getHeader("Proxy-Client-IP");
            }
            if(ObjectUtils.isEmpty(clientIp) == true) {
                clientIp = httpServletRequest.getHeader("WL-Proxy-Client-IP");
            }
            if(ObjectUtils.isEmpty(clientIp) == true) {
                clientIp = httpServletRequest.getHeader("HTTP_CLIENT_IP");
            }
            if(ObjectUtils.isEmpty(clientIp) == true) {
                clientIp = httpServletRequest.getHeader("HTTP_X_FORWARDED_FOR");
            }
            if(ObjectUtils.isEmpty(clientIp) == true) {
                clientIp = httpServletRequest.getRemoteAddr();
            }
            if(ObjectUtils.isEmpty(clientIp) == true) {
                clientIp = "0.0.0.0";
            }
            if(ObjectUtils.isEmpty(clientIp) == false) {
                if(clientIp.contains(",") == true) {
                    String[] arrIp = clientIp.split(",",-1);
                    clientIp = arrIp[0];
                }else {
                    clientIp = clientIp.replaceAll("(\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}).*","$1");
                }
            }
        }catch(Exception e1) {
            log.error("getClientIp",e1);
        }
        return clientIp;
    }

    private boolean isBrokenPipe(Throwable t) {
        while (t != null) {
            if ("ClientAbortException".equals(t.getClass().getSimpleName())) return true;
            if (t instanceof IOException) {
                String msg = t.getMessage();
                if (msg != null && (msg.contains("Broken pipe") || msg.contains("Connection reset"))) return true;
            }
            t = t.getCause();
        }
        return false;
    }

    @Override
    public void destroy() {
        MDC.clear();
    }
}























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

import javax.servlet.FilterChain;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.*;

//https://www.springcloud.io/post/2022-03/record-request-and-response-bodies/#gsc.tab=0

@Component
public class HttpLoggingFilter extends OncePerRequestFilter {
    final Logger log = LoggerFactory.getLogger(getClass());

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
            } else {
                //            filterChain.doFilter(httpServletRequest,httpServletResponse);

                ContentCachingRequestWrapper cachingReq = new ContentCachingRequestWrapper(httpServletRequest);
                ContentCachingResponseWrapper cachingRes = new ContentCachingResponseWrapper(httpServletResponse);
                filterChain.doFilter(cachingReq, cachingRes);

                if (this.isExcludeLogging(cachingReq) == false) {
                    this.loggingReq(cachingReq, cachingRes);
                }

                cachingRes.copyBodyToResponse();
            }
        } catch(Exception e) {
            e.printStackTrace();
        }
    }

    /**
     * <h2>예외처리</h2>
     */
    boolean isExcludeLogging(ContentCachingRequestWrapper req) {
        AntPathMatcher pathMatcher = new AntPathMatcher();
        List<String> excludeUrlPatterns = List.of(
            "/health/**"
        );
        return excludeUrlPatterns
                .stream()
                .anyMatch(p -> pathMatcher.match(p,req.getServletPath()));
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
            logItemRes.setContentType(mediaType.toString());
            logItemRes.setHeaders(this.getHeadersRes(res));
            logItemRes.setBody(this.convToMap(this.getResBody(res)));

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
        List<MediaType> VISIBLE_TYPES = Arrays.asList(
                MediaType.valueOf("text/*")
                ,MediaType.APPLICATION_FORM_URLENCODED
                ,MediaType.APPLICATION_JSON
                ,MediaType.APPLICATION_XML
                ,MediaType.valueOf("application/*+json")
                ,MediaType.valueOf("application/*+xml")
                ,MediaType.MULTIPART_FORM_DATA
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
        StringBuilder sbReqBody = new StringBuilder();
        try {
            byte[] reqBody = req.getContentAsByteArray();
            if(ObjectUtils.isEmpty(reqBody) == false) {
                sbReqBody.append(new String(reqBody,StandardCharsets.UTF_8));
            }
        }catch(Exception e1) {
            log.error("getReqBody",e1);
        }
        return sbReqBody.toString();
    }

    String getResBody(ContentCachingResponseWrapper res) {
        StringBuilder sbReqBody = new StringBuilder();
        try {
            byte[] reqBody = res.getContentAsByteArray();
            if(ObjectUtils.isEmpty(reqBody) == false) {
                sbReqBody.append(new String(reqBody,StandardCharsets.UTF_8));
            }
        }catch(Exception e1) {
            log.error("getResBody",e1);
        }
        return sbReqBody.toString();
    }

    Map<String,Object> convToMap(String jsonBody){
        if(ObjectUtils.isEmpty(jsonBody) == true) {
            return null;
        }
        try {
            ObjectMapper mapper = new ObjectMapper();
            return mapper.readValue(jsonBody,new TypeReference<Map<String,Object>>() {});
        }catch(Exception e1) {
            log.error("convToMap",e1);
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

    @Override
    public void destroy() {
        MDC.clear();
    }
}























package com.litten.common.filter;

import java.util.Map;

public class VoHttpLogItem extends DaoJson {
    private String method;
    private String uri;
    private String contentType;
    private Map<String,String> headers;
    private Object body;
    private String clientIp;
    private String sessionId;
    public String getMethod() {
        return method;
    }
    public void setMethod(String method) {
        this.method=method;
    }
    public String getUri() {
        return uri;
    }
    public void setUri(String uri) {
        this.uri=uri;
    }
    public String getContentType() {
        return contentType;
    }
    public void setContentType(String contentType) {
        this.contentType=contentType;
    }
    public Map<String, String> getHeaders() {
        return headers;
    }
    public void setHeaders(Map<String, String> headers) {
        this.headers=headers;
    }
    public Object getBody() {
        return body;
    }
    public void setBody(Object body) {
        this.body=body;
    }
    public String getClientIp() {
        return clientIp;
    }
    public void setClientIp(String clientIp) {
        this.clientIp=clientIp;
    }
    public String getSessionId() {
        return sessionId;
    }
    public void setSessionId(String sessionId) {
        this.sessionId=sessionId;
    }
}

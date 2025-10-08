package com.litten.common.config;

public class Config {

    private static Config config;
    private String version = "0.1.41";

    private String[] filterIps = {};
    private String port;
    private String protocol;
    private String domain;
    private String prefixPath;
    private String developerMail;
    private String billingUrl;
    private String configManagerUrl;
    private String talkbotUrl;
    private String messageUrl;
    private String messageKakaoUrl;
    private String unionUrl;

    private String activateOnProfile;

    private String ploonettotalDatasourceDriverClassName;
    private String ploonettotalDatasourceJdbcUrl;
    private String ploonettotalDatasourceUsername;
    private String ploonettotalDatasourcePassword;

    private Long tokenValidityInMilliseconds;
    private Long mobileTokenValidityInMilliseconds;

    private Long csCenterCompanySeq;

    public static Config getInstance() {
        if(config==null) {
            config = new Config();
        }
        return config;
    }

    private Config(){
    }

    public String[] getFilterIps() {
        return filterIps;
    }

    public void setFilterIps(String[] filterIps) {
        this.filterIps = filterIps;
    }

    public String getPort() {
        return port;
    }

    public void setPort(String port) {
        this.port = port;
    }

    public String getProtocol() {
        return protocol;
    }

    public void setProtocol(String protocol) {
        this.protocol = protocol;
    }

    public String getDomain() {
        return domain;
    }

    public void setDomain(String domain) {
        this.domain = domain;
    }

    public String getVersion() {
        return version;
    }

    public String getPrefixPath() {
        return prefixPath;
    }

    public void setPrefixPath(String prefixPath) {
        this.prefixPath = prefixPath;
    }

    public String getDeveloperMail() {
        return developerMail;
    }

    public void setDeveloperMail(String developerMail) {
        this.developerMail = developerMail;
    }

    public String getBillingUrl() {
        return billingUrl;
    }

    public void setBillingUrl(String billingUrl) {
        this.billingUrl = billingUrl;
    }

    public String getConfigManagerUrl() {
        return configManagerUrl;
    }

    public void setConfigManagerUrl(String configManagerUrl) {
        this.configManagerUrl = configManagerUrl;
    }

    public String getMessageUrl() {
        return messageUrl;
    }

    public void setMessageUrl(String messageUrl) {
        this.messageUrl = messageUrl;
    }

    public String getMessageKakaoUrl() {
        return messageKakaoUrl;
    }

    public void setMessageKakaoUrl(String messageKakaoUrl) {
        this.messageKakaoUrl = messageKakaoUrl;
    }

    public String getActivateOnProfile() {
        return activateOnProfile;
    }

    public void setActivateOnProfile(String activateOnProfile) {
        this.activateOnProfile = activateOnProfile;
    }

    public String getPloonettotalDatasourceDriverClassName() {
        return ploonettotalDatasourceDriverClassName;
    }

    public void setPloonettotalDatasourceDriverClassName(String ploonettotalDatasourceDriverClassName) {
        this.ploonettotalDatasourceDriverClassName = ploonettotalDatasourceDriverClassName;
    }

    public String getPloonettotalDatasourceJdbcUrl() {
        return ploonettotalDatasourceJdbcUrl;
    }

    public void setPloonettotalDatasourceJdbcUrl(String ploonettotalDatasourceJdbcUrl) {
        this.ploonettotalDatasourceJdbcUrl = ploonettotalDatasourceJdbcUrl;
    }

    public String getPloonettotalDatasourceUsername() {
        return ploonettotalDatasourceUsername;
    }

    public void setPloonettotalDatasourceUsername(String ploonettotalDatasourceUsername) {
        this.ploonettotalDatasourceUsername = ploonettotalDatasourceUsername;
    }

    public String getPloonettotalDatasourcePassword() {
        return ploonettotalDatasourcePassword;
    }

    public void setPloonettotalDatasourcePassword(String ploonettotalDatasourcePassword) {
        this.ploonettotalDatasourcePassword = ploonettotalDatasourcePassword;
    }

    public String getTalkbotUrl() {
        return talkbotUrl;
    }

    public void setTalkbotUrl(String talkbotUrl) {
        this.talkbotUrl = talkbotUrl;
    }


    public Long getTokenValidityInMilliseconds() {
        return tokenValidityInMilliseconds;
    }

    public void setTokenValidityInMilliseconds(Long tokenValidityInMilliseconds) {
        this.tokenValidityInMilliseconds = tokenValidityInMilliseconds;
    }

    public Long getMobileTokenValidityInMilliseconds() {
        return mobileTokenValidityInMilliseconds;
    }

    public void setMobileTokenValidityInMilliseconds(Long mobileTokenValidityInMilliseconds) {
        this.mobileTokenValidityInMilliseconds = mobileTokenValidityInMilliseconds;
    }

    public void setUnionUrl(String unionUrl) {
        this.unionUrl = unionUrl;
    }

    public String getUnionUrl() {
        return unionUrl;
    }


    public Long getCsCenterCompanySeq() {
        return csCenterCompanySeq;
    }

    public void setCsCenterCompanySeq(Long csCenterCompanySeq) {
        this.csCenterCompanySeq = csCenterCompanySeq;
    }

}
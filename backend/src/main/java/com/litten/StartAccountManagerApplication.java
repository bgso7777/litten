package com.litten;

import com.litten.common.config.Config;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.Async;
import org.springframework.scheduling.annotation.EnableScheduling;

import javax.annotation.PostConstruct;

@EnableScheduling
@Async
@SpringBootApplication
public class StartAccountManagerApplication {

	@Value("${spring.security.filter.ips}")
	private String filterIps;

	@Value("${server.port}")
	private String port;

	@Value("${server.protocol}")
	private String protocol;

	@Value("${server.domain}")
	private String domain;

	@Value("${server.prefix-path}")
	private String prefixPath;

	@Value("${server.developer-mail}")
	private String developerMail;

	@Value("${server.billing-url}")
	private String billingUrl;

	@Value("${server.config-manager-url}")
	private String configManagerUrl;

	@Value("${server.message-url}")
	private String messageUrl;

	@Value("${server.message-kakao-url}")
	private String messageKakaoUrl;

	@Value("${spring.config.activate.on-profile}")
	private String activateOnProfile;

	@Value("${server.talkbot-url}")
	private String talkbotUrl;

	@Value("${server.union-url}")
	private String unionUrl;

	@Value("${jwt.token-validity-in-milliseconds:#{86400000}}")
	private Long tokenValidityInMilliseconds;

	@Value("${jwt.mobile-token-validity-in-milliseconds:#{86400000}}")
	private Long mobileTokenValidityInMilliseconds;

	@Value("${cs-center-company-seq}")
	private Long csCenterCompanySeq;

//	@Value("${spring.datasource-ploonettotal.driver-class-name}")
	private String ploonettotaldatasourceDriverClassName;

//	@Value("${spring.datasource-ploonettotal.jdbc-url}")
	private String ploonettotaldatasourceJdbcUrl;

//	@Value("${spring.datasource-ploonettotal.username}")
	private String ploonettotaldatasourceUsername;

//	@Value("${spring.datasource-ploonettotal.password}")
	private String ploonettotaldatasourcePassword;

	public static void main(String[] args) {
		SpringApplication.run(StartAccountManagerApplication.class, args);
	}

	@PostConstruct
	public void setPropertiesValue(){
		initSeedData();
	}

//	@EventListener
//	public void setSeedData(ContextRefreshedEvent event) {
//		initSeedData();
//	}

	private void initSeedData() {
		Config.getInstance().setFilterIps(filterIps.split(Constants.SEPARATER_IPS));
		Config.getInstance().setPort(port);
		Config.getInstance().setProtocol(protocol);
		Config.getInstance().setDomain(domain);
		Config.getInstance().setPrefixPath(prefixPath);
		Config.getInstance().setBillingUrl(billingUrl);
		Config.getInstance().setConfigManagerUrl(configManagerUrl);
		Config.getInstance().setUnionUrl(unionUrl);
		Config.getInstance().setMessageUrl(messageUrl);
		Config.getInstance().setMessageKakaoUrl(messageKakaoUrl);
		Config.getInstance().setActivateOnProfile(activateOnProfile);
		Config.getInstance().setTalkbotUrl(talkbotUrl);
		Config.getInstance().setTokenValidityInMilliseconds(tokenValidityInMilliseconds);
		Config.getInstance().setMobileTokenValidityInMilliseconds(mobileTokenValidityInMilliseconds);
		Config.getInstance().setCsCenterCompanySeq(csCenterCompanySeq);

//		Config.getInstance().setPloonettotalDatasourceDriverClassName(ploonettotaldatasourceDriverClassName);
//		Config.getInstance().setPloonettotalDatasourceJdbcUrl(ploonettotaldatasourceJdbcUrl);
//		Config.getInstance().setPloonettotalDatasourceUsername(ploonettotaldatasourceUsername);
//		Config.getInstance().setPloonettotalDatasourcePassword(ploonettotaldatasourcePassword);
	}
}

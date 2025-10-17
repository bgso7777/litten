package com.litten.common.security;

import com.litten.common.config.Config;
import com.litten.common.security.jwt.JWTConfigurer;
import com.litten.common.security.jwt.TokenProvider;
import lombok.extern.log4j.Log4j2;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.factory.PasswordEncoderFactories;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.header.writers.StaticHeadersWriter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

@Log4j2
@Configuration
@EnableWebSecurity
public class SecurityConfiguration {

    @Autowired
    private final TokenProvider tokenProvider;

    @Autowired
    AccessDeniedHandlerImpl accessDeniedHandlerImpl;

    @Autowired
    AuthenticationEntryPointImpl authenticationEntryPointImpl;

    public SecurityConfiguration(TokenProvider tokenProvider) {
        this.tokenProvider = tokenProvider;
    }

    /**
     -. 보안을 적용하기 위한 메소드
         access(String)	주어진 SpEL 표현식이 참이면 접근 허용
         anonymous()	익명의 사용자 접근을 허용
         authenticated()	인증된 사용자의 접근을 허용
         denyAll()	무조건 접근 허용하지 않음
         fullyAuthenticated()	사용자가 완전히 인증되면 접근 허용(기억되지 않음)
         hasAnyAuthority(String...)	사용자가 주어진 권한 중 어떤 것이라도 있다면 접근허용
         hasAnyRole(String...)	사용자가 주어진 역할 중 어떤 것이라도 있다면 접근허용
         hasAuthority(String)	사용자가 주어진 권한이 있다면 접근허용
         hasRole(String)	사용자가 주어진 역할이 있다면 접근허용
         hasIpAddress(String)	주어진 ip 주소로 오는 요청은 참
         not()	다른 접근 방식의 효과를 무효화
         permitAll()	무조건 접근 허용
         rememberMe()	기억하기를 통해 인증된 사용자의 접근을 허용

     -. Spring Security 에서 사용 가능한 SpEL
         authentication	사용자의 인증 객체
         denyAll	항상 거짓으로 평가
         hasAnyRole(역할목록)	사용자가 역할 목록 중 하나라도 해당하면 참
         hasRole(역할)	사용자가 역할이 있는 경우 참
         hasIpAddress(주소)	주어진 ip 주소로 오는 요청은 참
         isAnonymous()	사용자가 익명이면 참
         isAuthenticated()	사용자가 인증된 경우 참
         isFullyAuthenticated()	사용자가 완전히 인증된 경우 참(remember-me 로는 인증되지 않음)
         isRememverMe()	사용자가 기억하기(remember-me)로 인증된 경우 참
         permitAll	항상 참
         principal	사용자의 주체 객체

     * @param http
     * @return
     * @throws Exception
     */
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {

        StringBuffer hasIpAddress = new StringBuffer(" ");
        int i = 0;
        for (String ip : Config.getInstance().getFilterIps() ) {
            i++;
            hasIpAddress.append("hasIpAddress('"+ip+"') ");
            if(Config.getInstance().getFilterIps().length!=i) {
                hasIpAddress.append("or ");
            }
        }

        http

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        .headers()
        .frameOptions()
        .disable()
        .addHeaderWriter(new StaticHeadersWriter("X-FRAME-OPTIONS", "ALLOW-FROM " + "127.0.0.1"))
        .addHeaderWriter(new StaticHeadersWriter("X-FRAME-OPTIONS", "ALLOW-FROM " + "www.litten7.com"))
        .and()

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        .httpBasic().disable() // rest api 이므로 기본설정 사용안함. 기본설정은 비인증시 로그인폼 화면으로 리다이렉트 된다.

        .cors().configurationSource(corsConfigurationSource())
        .and()

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        .csrf().disable() // rest api이므로 csrf 보안이 필요없으므로 disable처리.
        .sessionManagement().sessionCreationPolicy(SessionCreationPolicy.STATELESS) // jwt token으로 인증할것이므로 세션필요없으므로 생성안함.
        .and()

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        .authorizeRequests()

        // 로그인 전 서비스 처리
        //////////////////////////////////////////////////////
        // administrator 인증 토큰 발행
//        .requestMatchers("/account/administrator/svc/authentication/**").access(hasIpAddress.toString())
//        .requestMatchers("/account/administrator/svc/authentication-mobile/**").access(hasIpAddress.toString())
//
//        // administrator 서비스
//        .requestMatchers("/account/administrator/**").access(hasIpAddress.toString())
//        .requestMatchers("/account/administrator/**").hasAnyAuthority( AuthoritiesConstants.MEMBER_ADMIN_ADMIN )
//
//        // 버젼 조회
//        .requestMatchers("/account/anon/version/**").access(hasIpAddress.toString())
//
//        // 로그인, 아이디중복조회, 아이디찾기, 인증토큰발행(anonymous), 사용자정보유효성확인, 비번변경
//        .requestMatchers("/account/anon/**").access(hasIpAddress.toString())
//
//        // 롤백
//        .requestMatchers("/account/anon/svc/member/rollback/**").access(hasIpAddress.toString())
//
//        // health check
//        .requestMatchers("/aice/account/health/check/**").permitAll()
//        .requestMatchers("/health/check/**").permitAll()
//
//        // support page
////        .requestMatchers("/support/sample/html/**").permitAll()
//        .requestMatchers("/account/anon/svc/support/sample/html/**").permitAll()
//
//        // file upload
//        .requestMatchers("/account/staff/file/**").permitAll()
//
//        // account v2 members
//        .requestMatchers("/account/v2/members/**").permitAll()
//
//        // 로그인 후 서비스 처리
//        //////////////////////////////////////////////////////
////        .requestMatchers("/account/**").hasAnyAuthority(AuthoritiesConstants.MEMBER,AuthoritiesConstants.ADMIN)
//
////        .requestMatchers("/account/**")
////        .access("hasIpAddress('0:0:0:0:0:0:0:1') or " +
////                         "hasIpAddress('192.168.100.100') " +
////                         "and hasAnyAuthority('"+AuthoritiesConstants.MEMBER+"','"+AuthoritiesConstants.ADMIN+"')")
//
////        .access(hasIpAddress.toString() +
////                " and hasAnyAuthority('"+AuthoritiesConstants.MEMBER+"','"+AuthoritiesConstants.ADMIN+"')")
//
//        // anonymous용 토큰 발행 보류 20220128
////        .requestMatchers("/account/svc/authentication").access(hasIpAddress.toString())
////        .requestMatchers("/account/svc/authentication").hasAnyAuthority( AuthoritiesConstants.ANONYMOUS )
//
//        .requestMatchers("/account/member-temporary/**").access(hasIpAddress.toString())
//        .requestMatchers("/account/member-temporary/**").hasAnyAuthority(   AuthoritiesConstants.MEMBER_ADMIN_ADMIN,
//                                                                                    AuthoritiesConstants.MEMBER_INDIVIDUAL,
//                                                                                    AuthoritiesConstants.MEMBER_INDIVIDUAL_MASTER,
//                                                                                    AuthoritiesConstants.MEMBER_COMPANY,
//                                                                                    AuthoritiesConstants.MEMBER_COMPANY_MASTER,
//                                                                                    AuthoritiesConstants.ANONYMOUS)
//
//        .requestMatchers("/account/member-temporary/*/dummy/*").access(hasIpAddress.toString())
//        .requestMatchers("/account/member-temporary/*/dummy/*").hasAnyAuthority(   AuthoritiesConstants.MEMBER_ADMIN_ADMIN,
//                                                                                        AuthoritiesConstants.MEMBER_INDIVIDUAL,
//                                                                                        AuthoritiesConstants.MEMBER_INDIVIDUAL_MASTER,
//                                                                                        AuthoritiesConstants.MEMBER_COMPANY,
//                                                                                        AuthoritiesConstants.MEMBER_COMPANY_MASTER,
//                                                                                        AuthoritiesConstants.ANONYMOUS)
//
//        .requestMatchers("/account/**").access(hasIpAddress.toString())
//        .requestMatchers("/account/**").hasAnyAuthority( AuthoritiesConstants.MEMBER_ADMIN_ADMIN,
//                                                                AuthoritiesConstants.MEMBER_INDIVIDUAL,
//                                                                AuthoritiesConstants.MEMBER_INDIVIDUAL_MASTER,
//                                                                AuthoritiesConstants.MEMBER_COMPANY,
//                                                                AuthoritiesConstants.MEMBER_COMPANY_MASTER,
//                                                                AuthoritiesConstants.ANONYMOUS )
//
//        .requestMatchers("/account/staff").access(hasIpAddress.toString())
//        .requestMatchers("/account/staff").hasAnyAuthority(  AuthoritiesConstants.MEMBER_ADMIN_ADMIN,
//                                                                        AuthoritiesConstants.MEMBER_INDIVIDUAL,
//                                                                        AuthoritiesConstants.MEMBER_INDIVIDUAL_MASTER,
//                                                                        AuthoritiesConstants.MEMBER_COMPANY,
//                                                                        AuthoritiesConstants.MEMBER_COMPANY_MASTER,
//                                                                        AuthoritiesConstants.ANONYMOUS )
//
//        .requestMatchers("/account/brand/member").access(hasIpAddress.toString())
//        .requestMatchers("/account/brand/member").hasAnyAuthority( AuthoritiesConstants.MEMBER_ADMIN_ADMIN )


        // litten
        .requestMatchers("/litten/note/v1/members/**").permitAll()
        .requestMatchers("/litten/note/v1/members/install/**").permitAll()
        .requestMatchers("/litten/note/v1/members/signup/**").permitAll()
        .requestMatchers("/litten/note/v1/members/password/**").permitAll()
        .requestMatchers("/litten/note/v1/members/password-url/**").permitAll()
        .requestMatchers("/litten/note/v1/members/login/web/**").permitAll()
        .requestMatchers("/litten/note/v1/members/login/mobile/**").permitAll()

        // Static resources (HTML pages)
        .requestMatchers("/", "/index.html", "/note.html", "/test").permitAll()
        .requestMatchers("/*.html", "/*.css", "/*.js", "/*.png", "/*.jpg", "/*.ico").permitAll()

        .requestMatchers("/litten/anon/svc/support/sample/html/**").permitAll()
//        .requestMatchers("/anon/svc/members/change-password2/**/**").permitAll()
        .requestMatchers("/litten/anon/svc/members/change-password2/**").permitAll()
        .requestMatchers("/litten/anon/svc/members/change-password2/**").permitAll()
        .requestMatchers("/litten/anon/svc/members/change-password3/**").permitAll()

        .requestMatchers("/litten/anon/**").access(hasIpAddress.toString())
        .requestMatchers("/litten/anon/svc/support/sample/html/**").permitAll()

        .anyRequest().authenticated()
        .and()
        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//        .httpBasic()
//        .and()

        // 302 권한 없는 경우
        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        .exceptionHandling().accessDeniedHandler(accessDeniedHandlerImpl)
        //.accessDeniedPage("")
        .and()

        // 401 token error
        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        .exceptionHandling().authenticationEntryPoint(authenticationEntryPointImpl)
        //.accessDeniedPage(AUTHENTICATION_ERROR_PATH)
        .and()

        //
        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        .apply(securityConfigurerAdapter());

        return http.build();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();
        configuration.addAllowedOrigin("*");
        configuration.addAllowedHeader("*");
        configuration.addAllowedMethod("*");
        //configuration.setAllowCredentials(true); // configuration.addAllowedOrigin("*"); 와 동시에 못씀
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }

    private JWTConfigurer securityConfigurerAdapter() {
        return new JWTConfigurer(tokenProvider);
    }

    @Bean
    public BCryptPasswordEncoder bCryptPasswordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return PasswordEncoderFactories.createDelegatingPasswordEncoder();
    }
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// apereo cas
// https://www.baeldung.com/spring-security-cas-sso
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//import lombok.extern.log4j.Log4j2;
//import org.jasig.cas.client.session.SingleSignOutFilter;
//import org.jasig.cas.client.validation.Cas30ServiceTicketValidator;
//import org.jasig.cas.client.validation.TicketValidator;
//import org.springframework.beans.factory.annotation.Autowired;
//import org.springframework.context.annotation.Bean;
//import org.springframework.context.annotation.Configuration;
//import org.springframework.security.authentication.AuthenticationManager;
//import org.springframework.security.cas.ServiceProperties;
//import org.springframework.security.cas.authentication.CasAuthenticationProvider;
//import org.springframework.security.cas.web.CasAuthenticationFilter;
//import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
//import org.springframework.security.config.annotation.web.builders.HttpSecurity;
//import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
//import org.springframework.security.core.authority.AuthorityUtils;
//import org.springframework.security.web.SecurityFilterChain;
//import org.springframework.security.web.authentication.logout.LogoutFilter;
//import org.springframework.security.web.authentication.logout.SecurityContextLogoutHandler;
//
//@Log4j2
//@Configuration
//@EnableWebSecurity
//public class SecurityConfiguration {//extends WebSecurityConfigurerAdapter {
//
//    @Autowired
//    AuthenticationEntryPointImpl authenticationEntryPointImpl;
//
//
//////    @Override
////    @Bean
////    protected void configure(HttpSecurity http) throws Exception {
////        http.authorizeRequests().requestMatchers( "/secured", "/login")
////            .authenticated()
////            .and().exceptionHandling()
////            .authenticationEntryPoint(authenticationEntryPointImpl);
////    }
//    @Bean
//    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
//        http.authorizeRequests().requestMatchers( "/secured", "/login")
//                .authenticated()
//                .and().exceptionHandling()
//                .authenticationEntryPoint(authenticationEntryPointImpl);
//        return http.build();
//    }
//
//    public SecurityConfiguration(AuthenticationConfiguration authConfiguration) {
//        this.authConfiguration = authConfiguration;
//    }
//
//    private final AuthenticationConfiguration authConfiguration;
//
//    @Bean
//    public AuthenticationManager authenticationManager() throws Exception {
//        return authConfiguration.getAuthenticationManager();
//    }
//
////    @Bean
////    @Override
////    public AuthenticationManager authenticationManagerBean() throws Exception {
////        return super.authenticationManagerBean();
////    }
//
//    @Bean
//    public CasAuthenticationFilter casAuthenticationFilter(
//            AuthenticationManager authenticationManager,
//            ServiceProperties serviceProperties) throws Exception {
//        CasAuthenticationFilter filter = new CasAuthenticationFilter();
//        filter.setAuthenticationManager(authenticationManager);
////        filter.setAuthenticationManager(authenticationManagerBean());
//        filter.setServiceProperties(serviceProperties);
//        return filter;
//    }
//
//    @Bean
//    public ServiceProperties serviceProperties() {
////        logger.info("service properties");
//        ServiceProperties serviceProperties = new ServiceProperties();
//        serviceProperties.setService("http://192.168.110.33:8989/login/cas");
//        serviceProperties.setSendRenew(false);
//        return serviceProperties;
//    }
//
//    @Bean
//    public TicketValidator ticketValidator() {
//        return new Cas30ServiceTicketValidator("https://sso.ploonet.com:8443/");
//    }
//
//    @Bean
//    public CasAuthenticationProvider casAuthenticationProvider(
//            TicketValidator ticketValidator,
//            ServiceProperties serviceProperties) {
//        CasAuthenticationProvider provider = new CasAuthenticationProvider();
//        provider.setServiceProperties(serviceProperties);
//        provider.setTicketValidator(ticketValidator);
////        provider.setUserDetailsService(
////                s -> new Membe("test@test.com", "Mellon", true, true, true, true,
////                        AuthorityUtils.createAuthorityList("ROLE_ADMIN")));
//        MemberDetails principal = new MemberDetails("테스트사용자명", "test@test.com", "Mellon", AuthorityUtils.createAuthorityList("ROLE_ADMIN"));
//        provider.setUserDetailsService(s -> principal);
//        provider.setKey("CAS_PROVIDER_LOCALHOST_8989");
//        return provider;
//    }
//
//    @Bean
//    public CasAuthenticationProvider casAuthenticationProvider() {
//        CasAuthenticationProvider provider = new CasAuthenticationProvider();
//        provider.setServiceProperties(serviceProperties());
//        provider.setTicketValidator(ticketValidator());
////        provider.setUserDetailsService(
////                s -> new User("test@test.com", "Mellon", true, true, true, true,
////                        AuthorityUtils.createAuthorityList("ROLE_ADMIN")));
//        MemberDetails principal = new MemberDetails("테스트사용자명", "test@test.com", "Mellon", AuthorityUtils.createAuthorityList("ROLE_ADMIN"));
//        provider.setKey("CAS_PROVIDER_LOCALHOST_8989");
//        return provider;
//    }
//
//
//
//    @Bean
//    public SecurityContextLogoutHandler securityContextLogoutHandler() {
//        return new SecurityContextLogoutHandler();
//    }
//
//    @Bean
//    public LogoutFilter logoutFilter() {
//        LogoutFilter logoutFilter = new LogoutFilter("https://sso.ploonet.com:8443/logout",
//                securityContextLogoutHandler());
//        logoutFilter.setFilterProcessesUrl("/logout/cas");
//        return logoutFilter;
//    }
//
//    @Bean
//    public SingleSignOutFilter singleSignOutFilter() {
//        SingleSignOutFilter singleSignOutFilter = new SingleSignOutFilter();
////        singleSignOutFilter.setCasServerUrlPrefix("https://localhost:8443");
////        singleSignOutFilter.setLogoutCallbackPath("/exit/cas");
//        singleSignOutFilter.setLogoutCallbackPath("https://sso.ploonet.com:8443/exit/cas");
//        singleSignOutFilter.setIgnoreInitConfiguration(true);
//        return singleSignOutFilter;
//    }
//
//}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

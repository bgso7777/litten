package com.litten.common.security.jwt;

import com.litten.common.security.MemberDetails;
import io.jsonwebtoken.*;
import lombok.extern.log4j.Log4j2;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.stereotype.Component;

import jakarta.annotation.PostConstruct;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.Base64;
import java.util.Collection;
import java.util.Date;
import java.util.stream.Collectors;

@Log4j2
@Component
public class TokenProvider {

    private static final String AUTHORITIES_KEY = "auth";
    private static final String REAL_NAME_KEY   = "real_name";
    private static final String IS_MOBILE       = "isMobile";

    private Long   tokenValidityInMilliseconds;
    private String secret;
    private String secretBase64;
    private Boolean isMobile;

//    public TokenProvider(@Value("${jwt.token-validity-in-milliseconds:#{86400000}}") Long tokenValidityInMilliseconds,
//                         @Value("${jwt.secret:#{'jwtsecretparsetargettobase64'}}") String secret) {
//        this.tokenValidityInMilliseconds = tokenValidityInMilliseconds;
//        this.secret = secret;
//    }
    public TokenProvider(@Value("${jwt.secret:#{'jwtsecretparsetargettobase64'}}") String secret) {
        this.secret = secret;
    }

    @PostConstruct
    public void init() {
        secretBase64 = Base64.getEncoder().encodeToString(secret.getBytes(StandardCharsets.UTF_8));
    }

    public String createToken(Authentication authentication, Long tokenValidityInMilliseconds, Boolean isMobile) {
        String authorities = authentication.getAuthorities().stream()
                                           .map(GrantedAuthority::getAuthority)
                                           .collect(Collectors.joining(","));

        this.isMobile = isMobile;
        this.tokenValidityInMilliseconds = tokenValidityInMilliseconds;

        long now = (new Date()).getTime();
        Date validity = new Date(now + this.tokenValidityInMilliseconds);

        MemberDetails user = (MemberDetails) authentication.getPrincipal();

        return Jwts.builder()
                   .setSubject(authentication.getName())
                   .claim(AUTHORITIES_KEY, authorities)
                   .claim(REAL_NAME_KEY, user.getRealName())
                   .claim(IS_MOBILE, isMobile)
                   .signWith(SignatureAlgorithm.HS512, secretBase64)
                   .setExpiration(validity)
                   .compact();
    }

    public Authentication getAuthentication(String token) {
        Claims claims = Jwts.parser()
                            .setSigningKey(secretBase64)
                            .parseClaimsJws(token)
                            .getBody();

        Collection<? extends GrantedAuthority> authorities = Arrays.stream(claims.get(AUTHORITIES_KEY).toString().split(","))
                                                                   .map(SimpleGrantedAuthority::new)
                                                                   .collect(Collectors.toList());
        String realName = (String) claims.get(REAL_NAME_KEY);

        MemberDetails principal = new MemberDetails(realName, claims.getSubject(), "", authorities);

        return new UsernamePasswordAuthenticationToken(principal, token, authorities);
    }

    public boolean validateToken(String authToken) {
        if(authToken==null||authToken.equals(""))
            return false;
        Jwts.parser().setSigningKey(secretBase64).parseClaimsJws(authToken);
        return true;
    }

    public Long getTokenValidityInMilliseconds() {
        return tokenValidityInMilliseconds;
    }

    public Object getValue(String token, String key) {
        Claims claims = Jwts.parser()
                .setSigningKey(secretBase64)
                .parseClaimsJws(token)
                .getBody();
        Collection<? extends GrantedAuthority> authorities = Arrays.stream(claims.get(AUTHORITIES_KEY).toString().split(","))
                .map(SimpleGrantedAuthority::new)
                .collect(Collectors.toList());
        return claims.get(key);
    }
}

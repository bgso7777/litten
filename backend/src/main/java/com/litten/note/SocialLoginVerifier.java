package com.litten.note;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.math.BigInteger;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.security.KeyFactory;
import java.security.interfaces.RSAPublicKey;
import java.security.spec.RSAPublicKeySpec;
import java.time.Duration;
import java.util.Arrays;
import java.util.Base64;
import java.util.List;
import java.util.stream.Collectors;

/**
 * 소셜 로그인(구글/애플) ID Token 검증 유틸.
 *
 * - 구글: Google tokeninfo 엔드포인트로 검증(서명/만료/발급자 검증을 구글이 수행) 후 aud(클라이언트 ID) 화이트리스트 확인.
 * - 애플: Apple JWKS(공개키)로 RS256 서명을 직접 검증하고 iss/aud/exp 확인.
 *
 * 허용 aud(클라이언트 ID)는 application.yml 의 social.google.client-ids / social.apple.client-ids 로 설정.
 * (콤마 구분. 비어 있으면 모든 토큰을 거부하여 안전하게 실패한다.)
 */
@Slf4j
@Component
public class SocialLoginVerifier {

    private static final String GOOGLE_TOKENINFO_URL = "https://oauth2.googleapis.com/tokeninfo?id_token=";
    private static final String APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys";
    private static final String APPLE_ISSUER = "https://appleid.apple.com";

    private final ObjectMapper mapper = new ObjectMapper();
    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(5))
            .build();

    @Value("${social.google.client-ids:}")
    private String googleClientIdsRaw;

    @Value("${social.apple.client-ids:}")
    private String appleClientIdsRaw;

    /** 소셜 로그인으로 확인된 사용자 프로필. */
    public static class SocialProfile {
        public final String provider;   // "google" | "apple"
        public final String providerId; // 제공자 고유 사용자 ID(sub)
        public final String email;      // 이메일(없을 수 있음)
        public final String name;       // 표시 이름(없을 수 있음)

        public SocialProfile(String provider, String providerId, String email, String name) {
            this.provider = provider;
            this.providerId = providerId;
            this.email = email;
            this.name = name;
        }
    }

    private List<String> parseClientIds(String raw) {
        if (raw == null || raw.isBlank()) return List.of();
        return Arrays.stream(raw.split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .collect(Collectors.toList());
    }

    // ==================== 구글 ====================

    /**
     * 구글 ID Token 검증. 유효하면 SocialProfile 반환, 아니면 IllegalArgumentException.
     */
    public SocialProfile verifyGoogle(String idToken) throws Exception {
        List<String> allowed = parseClientIds(googleClientIdsRaw);
        if (allowed.isEmpty()) {
            log.error("[SocialLoginVerifier] social.google.client-ids 미설정 — 구글 로그인 거부");
            throw new IllegalArgumentException("google client-ids not configured");
        }

        String url = GOOGLE_TOKENINFO_URL + URLEncoder.encode(idToken, StandardCharsets.UTF_8);
        HttpRequest request = HttpRequest.newBuilder(URI.create(url))
                .timeout(Duration.ofSeconds(5))
                .GET()
                .build();
        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() != 200) {
            log.warn("[SocialLoginVerifier] 구글 tokeninfo 실패 status={} body={}", response.statusCode(), response.body());
            throw new IllegalArgumentException("invalid google id token");
        }

        JsonNode node = mapper.readTree(response.body());
        String aud = node.path("aud").asText(null);
        String iss = node.path("iss").asText(null);
        String sub = node.path("sub").asText(null);
        String email = node.path("email").asText(null);
        boolean emailVerified = node.path("email_verified").asBoolean(false)
                || "true".equalsIgnoreCase(node.path("email_verified").asText(""));
        String name = node.path("name").asText(null);

        if (aud == null || !allowed.contains(aud)) {
            log.warn("[SocialLoginVerifier] 구글 aud 불일치 aud={} allowed={}", aud, allowed);
            throw new IllegalArgumentException("google aud mismatch");
        }
        if (iss == null || !(iss.equals("accounts.google.com") || iss.equals("https://accounts.google.com"))) {
            log.warn("[SocialLoginVerifier] 구글 iss 불일치 iss={}", iss);
            throw new IllegalArgumentException("google iss mismatch");
        }
        if (sub == null || sub.isBlank()) {
            throw new IllegalArgumentException("google sub missing");
        }
        // 이메일 미검증 계정은 이메일 기반 계정 병합에 위험하므로 이메일을 신뢰하지 않음(null 처리)
        String trustedEmail = (email != null && emailVerified) ? email.toLowerCase() : null;

        log.info("[SocialLoginVerifier] 구글 검증 성공 sub={} email={} emailVerified={}", sub, email, emailVerified);
        return new SocialProfile("google", sub, trustedEmail, name);
    }

    // ==================== 애플 ====================

    /**
     * 애플 ID Token 검증(JWKS RS256). 유효하면 SocialProfile 반환, 아니면 예외.
     */
    public SocialProfile verifyApple(String idToken) throws Exception {
        List<String> allowed = parseClientIds(appleClientIdsRaw);
        if (allowed.isEmpty()) {
            log.error("[SocialLoginVerifier] social.apple.client-ids 미설정 — 애플 로그인 거부");
            throw new IllegalArgumentException("apple client-ids not configured");
        }

        String[] parts = idToken.split("\\.");
        if (parts.length < 2) {
            throw new IllegalArgumentException("malformed apple id token");
        }
        // 헤더에서 kid 추출(서명 검증 전이므로 신뢰하지 않고 공개키 선택에만 사용)
        JsonNode header = mapper.readTree(Base64.getUrlDecoder().decode(parts[0]));
        String kid = header.path("kid").asText(null);
        if (kid == null) {
            throw new IllegalArgumentException("apple token kid missing");
        }

        RSAPublicKey publicKey = fetchApplePublicKey(kid);

        // 서명/만료 검증(jjwt) — 서명 불일치·만료 시 예외
        Claims claims = Jwts.parser()
                .setSigningKey(publicKey)
                .parseClaimsJws(idToken)
                .getBody();

        String iss = claims.getIssuer();
        String aud = claims.getAudience();
        String sub = claims.getSubject();
        String email = claims.get("email", String.class);
        Object emailVerifiedClaim = claims.get("email_verified");
        boolean emailVerified = emailVerifiedClaim != null
                && ("true".equalsIgnoreCase(String.valueOf(emailVerifiedClaim)) || Boolean.TRUE.equals(emailVerifiedClaim));

        if (iss == null || !iss.equals(APPLE_ISSUER)) {
            log.warn("[SocialLoginVerifier] 애플 iss 불일치 iss={}", iss);
            throw new IllegalArgumentException("apple iss mismatch");
        }
        if (aud == null || !allowed.contains(aud)) {
            log.warn("[SocialLoginVerifier] 애플 aud 불일치 aud={} allowed={}", aud, allowed);
            throw new IllegalArgumentException("apple aud mismatch");
        }
        if (sub == null || sub.isBlank()) {
            throw new IllegalArgumentException("apple sub missing");
        }
        String trustedEmail = (email != null && emailVerified) ? email.toLowerCase() : null;

        log.info("[SocialLoginVerifier] 애플 검증 성공 sub={} email={} emailVerified={}", sub, email, emailVerified);
        return new SocialProfile("apple", sub, trustedEmail, null);
    }

    /** Apple JWKS에서 kid에 해당하는 RSA 공개키를 조회해 생성. */
    private RSAPublicKey fetchApplePublicKey(String kid) throws Exception {
        HttpRequest request = HttpRequest.newBuilder(URI.create(APPLE_JWKS_URL))
                .timeout(Duration.ofSeconds(5))
                .GET()
                .build();
        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() != 200) {
            throw new IllegalArgumentException("apple jwks fetch failed status=" + response.statusCode());
        }
        JsonNode keys = mapper.readTree(response.body()).path("keys");
        for (JsonNode key : keys) {
            if (kid.equals(key.path("kid").asText(null))) {
                byte[] nBytes = Base64.getUrlDecoder().decode(key.path("n").asText());
                byte[] eBytes = Base64.getUrlDecoder().decode(key.path("e").asText());
                BigInteger modulus = new BigInteger(1, nBytes);
                BigInteger exponent = new BigInteger(1, eBytes);
                return (RSAPublicKey) KeyFactory.getInstance("RSA")
                        .generatePublic(new RSAPublicKeySpec(modulus, exponent));
            }
        }
        throw new IllegalArgumentException("apple public key not found for kid=" + kid);
    }
}

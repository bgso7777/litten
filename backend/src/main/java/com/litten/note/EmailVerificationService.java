package com.litten.note;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 회원가입 이메일 인증번호 임시 저장/검증 서비스 (인메모리).
 *
 * Redis 미사용 환경이라 6자리 인증번호를 서버 메모리에 10분 TTL로 보관한다.
 * 발송→검증→가입이 수 분 내에 이어지는 흐름이므로 인메모리로 충분하며,
 * 서버 재시작 시 미완료 인증은 초기화된다(사용자는 재발송으로 복구).
 *
 * - issueCode : 인증번호 발급/재발급 (기존 항목 갱신)
 * - verify    : 인증번호 검증 → 성공 시 verified 마킹(가입 완료 전까지 30분 유효)
 * - isVerified: 가입 시점에 이메일 인증 여부 확인
 * - consume   : 가입 성공 후 항목 제거(1회성)
 */
@Slf4j
@Service
public class EmailVerificationService {

    /** 인증번호 유효시간(분) — 메일 템플릿 안내(10분)와 일치 */
    private static final long CODE_TTL_MINUTES = 10;
    /** 인증 완료 후 실제 가입까지 허용하는 유효시간(분) */
    private static final long VERIFIED_TTL_MINUTES = 30;
    /** 인증번호 검증 최대 시도 횟수(무차별 대입 방지) */
    private static final int MAX_ATTEMPTS = 5;

    private final SecureRandom random = new SecureRandom();
    private final ConcurrentHashMap<String, Entry> store = new ConcurrentHashMap<>();

    private static class Entry {
        String code;
        LocalDateTime expiresAt;
        boolean verified;
        int attempts;
    }

    /**
     * 6자리 인증번호 발급(재요청 시 갱신). 반환: 발급된 코드.
     */
    public String issueCode(String email) {
        String key = normalize(email);
        String code = String.format("%06d", random.nextInt(1_000_000));
        Entry e = new Entry();
        e.code = code;
        e.expiresAt = LocalDateTime.now().plusMinutes(CODE_TTL_MINUTES);
        e.verified = false;
        e.attempts = 0;
        store.put(key, e);
        log.info("[EmailVerification] 인증번호 발급 - email: {}, expiresAt: {}", key, e.expiresAt);
        return code;
    }

    /**
     * 인증번호 검증. 성공 시 verified 마킹 및 유효시간을 가입 유효시간으로 갱신.
     * 만료/시도초과 시 항목을 제거한다.
     */
    public boolean verify(String email, String code) {
        String key = normalize(email);
        Entry e = store.get(key);
        if (e == null) {
            log.info("[EmailVerification] 검증 실패(발급 이력 없음) - email: {}", key);
            return false;
        }
        if (LocalDateTime.now().isAfter(e.expiresAt)) {
            log.info("[EmailVerification] 검증 실패(만료) - email: {}", key);
            store.remove(key);
            return false;
        }
        if (e.attempts >= MAX_ATTEMPTS) {
            log.warn("[EmailVerification] 검증 실패(시도 초과) - email: {}", key);
            store.remove(key);
            return false;
        }
        e.attempts++;
        if (code != null && code.trim().equals(e.code)) {
            e.verified = true;
            e.expiresAt = LocalDateTime.now().plusMinutes(VERIFIED_TTL_MINUTES);
            log.info("[EmailVerification] 인증 성공 - email: {}", key);
            return true;
        }
        log.info("[EmailVerification] 인증번호 불일치 - email: {}, attempts: {}/{}", key, e.attempts, MAX_ATTEMPTS);
        return false;
    }

    /**
     * 가입 시점 인증 여부 확인. 인증 완료 상태이고 아직 유효하면 true.
     */
    public boolean isVerified(String email) {
        String key = normalize(email);
        Entry e = store.get(key);
        if (e == null) return false;
        if (LocalDateTime.now().isAfter(e.expiresAt)) {
            store.remove(key);
            return false;
        }
        return e.verified;
    }

    /**
     * 가입 성공 후 항목 제거(1회성 인증 보장).
     */
    public void consume(String email) {
        store.remove(normalize(email));
    }

    private String normalize(String email) {
        return email == null ? "" : email.trim().toLowerCase();
    }
}

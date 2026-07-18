package com.litten.note;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.litten.Constants;
import com.litten.common.security.SecurityUtils;
import com.litten.common.security.AuthoritiesConstants;
import com.litten.common.config.Config;
import com.litten.common.dynamic.BeanUtil;
import com.litten.common.dynamic.ConstantsDynamic;
import com.litten.common.dynamic.CustomHttpService;
import com.litten.common.security.jwt.TokenProvider;
import com.litten.common.util.Crypto;
import com.litten.common.util.DateUtil;
import com.litten.common.util.Mailer;
import com.litten.note.summary.SummaryResultRepository;
import com.litten.note.youtube.MemberYoutubeChannelRepository;
import com.litten.note.youtube.ChannelWatchStateRepository;
import lombok.extern.log4j.Log4j2;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.config.annotation.authentication.builders.AuthenticationManagerBuilder;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Log4j2
@Service
public class NoteMemberService extends CustomHttpService {

    @Transactional
    public Map<String, Object> putProcessCustomCRUD(Object requestObject) throws Exception {
        Map<String, Object> result = new HashMap<>();
        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_SUCCESS);

        return result;
    }

    public Map<String, Object> getMyInfo(String memberId) throws Exception {
        log.debug("[NoteMemberService] getMyInfo 진입 - memberId: {}", memberId);

        Map<String, Object> result = new HashMap<>();
        result.put(Constants.TAG_RESULT, Constants.RESULT_SUCCESS);

        NoteMemberRepository noteMemberRepository = BeanUtil.getBean2(NoteMemberRepository.class);
        NoteMember noteMember = noteMemberRepository.findByIdAndState(memberId, "signup");

        if (noteMember == null) {
            log.warn("[NoteMemberService] getMyInfo - 회원 없음: {}", memberId);
            result.put(Constants.TAG_RESULT, Constants.RESULT_NOT_FOUND);
            result.put(Constants.TAG_RESULT_MESSAGE, "회원을 찾을 수 없습니다.");
        } else {
            log.info("[NoteMemberService] getMyInfo - 성공: {}, plan: {}", memberId, noteMember.getSubscriptionPlan());
            result.put(Constants.TAG_MEMBER_ID, noteMember.getId());
            result.put("name", noteMember.getName()); // 닉네임 — 다기기 로그인 시 설정 화면/제목 표시용
            result.put(Constants.TAG_SUBSCRIPTION_PLAN, noteMember.getSubscriptionPlan());
            result.put(Constants.TAG_PLAN_EXPIRED_AT, noteMember.getPlanExpiredAt());
        }

        return result;
    }

    @Transactional
    public Map<String, Object> updatePlan(JsonNode requestBody, String memberId) throws Exception {
        log.debug("[NoteMemberService] updatePlan 진입 - memberId: {}", memberId);

        Map<String, Object> result = new HashMap<>();
        result.put(Constants.TAG_RESULT, Constants.RESULT_SUCCESS);

        String plan = requestBody.get(Constants.TAG_SUBSCRIPTION_PLAN).asText();
        log.info("[NoteMemberService] updatePlan - memberId: {}, plan: {}", memberId, plan);

        if (!plan.equals(Constants.SUBSCRIPTION_PLAN_FREE)
                && !plan.equals(Constants.SUBSCRIPTION_PLAN_STANDARD)
                && !plan.equals(Constants.SUBSCRIPTION_PLAN_PREMIUM)) {
            result.put(Constants.TAG_RESULT, Constants.RESULT_REQUEST_DATA_ERROR);
            result.put(Constants.TAG_RESULT_MESSAGE, "유효하지 않은 플랜: " + plan);
            return result;
        }

        NoteMemberRepository noteMemberRepository = BeanUtil.getBean2(NoteMemberRepository.class);
        NoteMember noteMember = noteMemberRepository.findByIdAndState(memberId, "signup");

        if (noteMember == null) {
            log.warn("[NoteMemberService] updatePlan - 회원 없음: {}", memberId);
            result.put(Constants.TAG_RESULT, Constants.RESULT_NOT_FOUND);
            result.put(Constants.TAG_RESULT_MESSAGE, "회원을 찾을 수 없습니다.");
        } else {
            noteMember.setSubscriptionPlan(plan);
            if (requestBody.has(Constants.TAG_PLAN_EXPIRED_AT) && !requestBody.get(Constants.TAG_PLAN_EXPIRED_AT).isNull()) {
                noteMember.setPlanExpiredAt(LocalDateTime.parse(requestBody.get(Constants.TAG_PLAN_EXPIRED_AT).asText()));
            }
            noteMember.setUpdateDateTime(LocalDateTime.now());
            noteMemberRepository.save(noteMember);
            log.info("[NoteMemberService] updatePlan - 플랜 변경 완료: {} -> {}", memberId, plan);
            result.put(Constants.TAG_SUBSCRIPTION_PLAN, noteMember.getSubscriptionPlan());
        }

        return result;
    }

    /**
     * id(가입 이메일) 기반 구독 플랜 변경 — 비인증 인터페이스.
     * 로그아웃 상태(토큰 없음)에서도 플랜 전환을 서버 DB에 반영하기 위함.
     * (free↔standard, standard→free 등 비프리미엄 전환 대응)
     *
     * 보안: 인증 없이 id로 플랜을 바꾸므로 개발/결제연동 전 단계 전용.
     *       운영에서는 결제 영수증 검증 등으로 보호해야 한다.
     */
    @Transactional
    public Map<String, Object> updatePlanById(JsonNode requestBody) throws Exception {
        Map<String, Object> result = new HashMap<>();
        result.put(Constants.TAG_RESULT, Constants.RESULT_SUCCESS);

        String id = requestBody.has(Constants.TAG_ID) ? requestBody.get(Constants.TAG_ID).asText() : null;
        String plan = requestBody.has(Constants.TAG_SUBSCRIPTION_PLAN) ? requestBody.get(Constants.TAG_SUBSCRIPTION_PLAN).asText() : null;
        log.info("[NoteMemberService] updatePlanById - id: {}, plan: {}", id, plan);

        if (id == null || plan == null) {
            result.put(Constants.TAG_RESULT, Constants.RESULT_REQUEST_DATA_ERROR);
            result.put(Constants.TAG_RESULT_MESSAGE, "id와 subscriptionPlan은 필수입니다.");
            return result;
        }
        if (!plan.equals(Constants.SUBSCRIPTION_PLAN_FREE)
                && !plan.equals(Constants.SUBSCRIPTION_PLAN_STANDARD)
                && !plan.equals(Constants.SUBSCRIPTION_PLAN_PREMIUM)) {
            result.put(Constants.TAG_RESULT, Constants.RESULT_REQUEST_DATA_ERROR);
            result.put(Constants.TAG_RESULT_MESSAGE, "유효하지 않은 플랜: " + plan);
            return result;
        }

        NoteMemberRepository noteMemberRepository = BeanUtil.getBean2(NoteMemberRepository.class);
        // 가입 회원(signup) 우선 조회, 없으면 device_uuid 기반 행(install 등)도 허용.
        // → 미가입 비로그인 상태에서도 device_uuid로 플랜 변경을 서버에 반영(구독 변경 자유).
        NoteMember noteMember = noteMemberRepository.findByIdAndState(id, "signup");
        if (noteMember == null) {
            noteMember = noteMemberRepository.findById(id).orElse(null);
        }
        if (noteMember == null) {
            log.warn("[NoteMemberService] updatePlanById - 대상 없음: {}", id);
            result.put(Constants.TAG_RESULT, Constants.RESULT_NOT_FOUND);
            result.put(Constants.TAG_RESULT_MESSAGE, "대상을 찾을 수 없습니다.");
            return result;
        }

        noteMember.setSubscriptionPlan(plan);
        if (requestBody.has(Constants.TAG_PLAN_EXPIRED_AT) && !requestBody.get(Constants.TAG_PLAN_EXPIRED_AT).isNull()) {
            noteMember.setPlanExpiredAt(LocalDateTime.parse(requestBody.get(Constants.TAG_PLAN_EXPIRED_AT).asText()));
        }
        noteMember.setUpdateDateTime(LocalDateTime.now());
        noteMemberRepository.save(noteMember);
        log.info("[NoteMemberService] updatePlanById - 플랜 변경 완료: {} -> {}", id, plan);
        result.put(Constants.TAG_SUBSCRIPTION_PLAN, plan);
        return result;
    }

    public Map<String, Object> postInstall(JsonNode requestBody) throws Exception {
        Map<String, Object> result = new HashMap<>();
        result.put(Constants.TAG_RESULT, Constants.RESULT_SUCCESS);


        return result;
    }

    public Map<String, Object> postSignup(JsonNode requestBody) throws Exception {
        Map<String, Object> result = new HashMap<>();
        result.put(Constants.TAG_RESULT, Constants.RESULT_SUCCESS);


        return result;
    }

    public Map<String, Object> postLogin(JsonNode requestBody, Boolean isMobile) throws Exception {

        ObjectNode objectNode = requestBody.deepCopy();

        String value1 = objectNode.get("id").textValue();
        String value2 = objectNode.get("password").textValue();
        String uuid = objectNode.get("uuid").textValue();

        HttpServletRequest httpServletRequest = ((ServletRequestAttributes) RequestContextHolder.currentRequestAttributes()).getRequest();
        String host = httpServletRequest.getRemoteHost();
        String addr = httpServletRequest.getRemoteAddr();

        Map<String, Object> result = new HashMap<>();
        result.put(Constants.TAG_RESULT,Constants.RESULT_SUCCESS);

//        log.debug("-->"+value1+" -->"+value2);

//        value1 = Crypto.decodeIdPw(value1);
//        value2 = Crypto.decodeIdPw(value2);

        log.debug("-->"+value1+" -->"+value2);

        NoteMemberRepository noteMemberRepository = BeanUtil.getBean2(NoteMemberRepository.class);
        NoteMember noteMember = noteMemberRepository.findByIdAndState(value1,"signup");

        if (noteMember==null) {
            result.put(Constants.TAG_RESULT, Constants.RESULT_NOT_FOUND);
            result.put(Constants.TAG_MEMBER_SEQ, null);
            result.put(Constants.TAG_RESULT_MESSAGE, "아이디를 찾을 수 없습니다.");
        } else if (noteMember.getPassword() == null) {
            // 소셜 로그인 전용 계정 — 비밀번호가 없으므로 비번 로그인 불가(구글/애플로 로그인 안내)
            log.info("[NoteMemberService] 비번 로그인 차단(소셜 전용 계정) id={} provider={}", value1, noteMember.getProvider());
            result.put(Constants.TAG_RESULT, Constants.RESULT_NOT_FOUND);
            result.put(Constants.TAG_RESULT_MESSAGE, "소셜 로그인으로 가입된 계정입니다. 구글/애플 로그인을 이용해 주세요.");
        } else {
            String encryptPassword = noteMember.getPassword().substring(8);
            if (Crypto.matchesMemberPassword(value2, encryptPassword)) {
                // 다중 디바이스 로그인 — uuid1/uuid2/uuid3 슬롯 매칭 (최대 3대)
                // 1) 요청 uuid가 슬롯 중 하나와 일치 → 즉시 허용 (기존 디바이스 재로그인)
                // 2) 빈 슬롯(uuid1 → uuid2 → uuid3 순)이 있으면 새 디바이스로 등록 후 허용
                // 3) 세 슬롯 모두 점유 중이고 일치 항목 없음 → 거부 ("최대 3대")
                String uuid1 = noteMember.getUuid1();
                String uuid2 = noteMember.getUuid2();
                String uuid3 = noteMember.getUuid3();
                boolean slot1Empty = uuid1 == null || uuid1.isBlank();
                boolean slot2Empty = uuid2 == null || uuid2.isBlank();
                boolean slot3Empty = uuid3 == null || uuid3.isBlank();

                // 플랜별 로그인 기기 정책: 프리미엄=최대 3대, 무료/스탠다드=1대(다른 기기 로그인 중이면 거부).
                String plan = noteMember.getSubscriptionPlan();
                boolean isPremium = plan != null && plan.equalsIgnoreCase("premium");

                boolean matched;      // 이미 등록된 기기(재로그인)
                boolean canRegister;  // 새 기기를 등록해 로그인 허용 가능
                if (isPremium) {
                    matched = (uuid1 != null && uuid1.equals(uuid))
                            || (uuid2 != null && uuid2.equals(uuid))
                            || (uuid3 != null && uuid3.equals(uuid));
                    canRegister = !matched && (slot1Empty || slot2Empty || slot3Empty);
                } else {
                    // 무료/스탠다드: 등록 기기는 uuid1 하나만 인정. 등록된 기기와 다르면 거부(2번째 기기 로그인 불가).
                    matched = uuid1 != null && uuid1.equals(uuid);
                    canRegister = !matched && slot1Empty;
                }
                log.info("[NoteMemberService] postLogin uuid 매칭 - id: {}, plan: {}, reqUuid: {}, uuid1: {}, uuid2: {}, uuid3: {}, matched: {}, canRegister: {}",
                        value1, plan, uuid, uuid1, uuid2, uuid3, matched, canRegister);
                if (matched || canRegister) {
                    if (!matched) {
                        String registeredSlot;
                        if (!isPremium) {
                            // 무료/스탠다드: 1대만 — 기존 기기 슬롯을 모두 해제하고 이 기기를 유일 기기로 등록(기존 기기 로그아웃)
                            noteMember.setUuid1(uuid);
                            noteMember.setUuid2(null);
                            noteMember.setUuid3(null);
                            registeredSlot = "uuid1(단일기기)";
                        } else if (slot1Empty) {
                            // 프리미엄: 빈 슬롯에 새 디바이스 등록 (uuid1 → uuid2 → uuid3 순서)
                            noteMember.setUuid1(uuid);
                            registeredSlot = "uuid1";
                        } else if (slot2Empty) {
                            noteMember.setUuid2(uuid);
                            registeredSlot = "uuid2";
                        } else {
                            noteMember.setUuid3(uuid);
                            registeredSlot = "uuid3";
                        }
                        noteMemberRepository.save(noteMember);
                        log.info("[NoteMemberService] 새 디바이스 등록 - id: {}, plan: {}, slot: {}, uuid: {}",
                                value1, plan, registeredSlot, uuid);
                    }
                    try {
                        UsernamePasswordAuthenticationToken authenticationToken = new UsernamePasswordAuthenticationToken(value1, value2); // id, pw
                        AuthenticationManagerBuilder authenticationManagerBuilder = BeanUtil.getBean2(AuthenticationManagerBuilder.class);
                        org.springframework.security.core.Authentication authentication = null;
                        authentication = authenticationManagerBuilder.getObject().authenticate(authenticationToken);
                        SecurityContextHolder.getContext().setAuthentication(authentication);

                        // jwt token 생성
                        Long tokenValidityInMilliseconds;
                        if (isMobile)
                            tokenValidityInMilliseconds = Config.getInstance().getMobileTokenValidityInMilliseconds();
                        else
                            tokenValidityInMilliseconds = Config.getInstance().getTokenValidityInMilliseconds();
                        TokenProvider tokenProvider = BeanUtil.getBean2(TokenProvider.class);
                        String jwt = tokenProvider.createToken(authentication, tokenValidityInMilliseconds, isMobile);
                        Integer tokenExpiredDate = (Integer) tokenProvider.getValue(jwt, Constants.TAG_JWT_EXPIRED_DATE);
                        result.put(Constants.TAG_SEQUENCE, noteMember.getSequence());
                        result.put(Constants.TAG_UUID, noteMember.getUuid());
                        result.put(Constants.TAG_AUTH_TOKEN, jwt);
                        result.put(Constants.TAG_TOKEN_EXPIRED_DATE, tokenExpiredDate);
                        result.put(Constants.TAG_MEMBER_ID, noteMember.getId());

                        HttpServletResponse httpServletResponse = ((ServletRequestAttributes) RequestContextHolder.currentRequestAttributes()).getResponse();
                        httpServletResponse.setHeader(Constants.TAG_HTTP_HEADER_AUTH_TOKEN, jwt);
                        httpServletResponse.setHeader(Constants.TAG_HTTP_HEADER_TOKEN_EXPIRED_DATE, tokenExpiredDate.toString());

                    } catch (BadCredentialsException e) {
                        log.error("Authentication.get", e);
                        result.put(Constants.TAG_RESULT, Constants.RESULT_BAD_CREDENTIALS);
                        result.put(Constants.TAG_RESULT_MESSAGE, "bad credentials");
                    }
                } else {
                    // 로그인 거부: 무료/스탠다드는 다른 기기가 이미 로그인 중, 프리미엄은 3대 초과
                    log.warn("[NoteMemberService] 로그인 거부 - id: {}, plan: {}, reqUuid: {}, uuid1: {}, uuid2: {}, uuid3: {}",
                            value1, plan, uuid, uuid1, uuid2, uuid3);
                    result.put(Constants.TAG_RESULT, Constants.RESULT_NOT_FOUND);
                    result.put(Constants.TAG_RESULT_MESSAGE, isPremium
                            ? "이미 3대의 디바이스에서 로그인되어 있습니다. 기존 디바이스에서 로그아웃 후 다시 시도해 주세요."
                            : "무료 플랜은 1대에서만 로그인할 수 있습니다. 기존 기기에서 로그아웃 후 다시 시도해 주세요.");
                }
            } else {
                result.put(Constants.TAG_RESULT, Constants.RESULT_NOT_FOUND);
                result.put(Constants.TAG_RESULT_MESSAGE, "비번 불일치 id-->"+value1);
            }
        }
        return result;
    }

    // ==================== 소셜 로그인(구글/애플) ====================

    public Map<String, Object> postLoginGoogle(JsonNode requestBody, Boolean isMobile) throws Exception {
        return loginSocial(requestBody, isMobile, "google");
    }

    public Map<String, Object> postLoginApple(JsonNode requestBody, Boolean isMobile) throws Exception {
        return loginSocial(requestBody, isMobile, "apple");
    }

    public Map<String, Object> postLoginKakao(JsonNode requestBody, Boolean isMobile) throws Exception {
        return loginSocial(requestBody, isMobile, "kakao");
    }

    public Map<String, Object> postLoginNaver(JsonNode requestBody, Boolean isMobile) throws Exception {
        return loginSocial(requestBody, isMobile, "naver");
    }

    /**
     * 소셜 로그인 공통 처리: ID Token 검증 → find-or-create(providerId 우선, 검증 이메일 병합) → 디바이스 슬롯 → 자체 JWT 발급.
     * 요청 바디: { "idToken": "...", "uuid": "디바이스 UUID" }
     */
    private Map<String, Object> loginSocial(JsonNode requestBody, Boolean isMobile, String provider) throws Exception {
        Map<String, Object> result = new HashMap<>();
        result.put(Constants.TAG_RESULT, Constants.RESULT_SUCCESS);

        String idToken = requestBody.has("idToken") && !requestBody.get("idToken").isNull() ? requestBody.get("idToken").asText() : null;
        String uuid = requestBody.has("uuid") && !requestBody.get("uuid").isNull() ? requestBody.get("uuid").asText() : null;
        // 신규 계정 자동 생성 허용 여부. 로그인 버튼=false(기존 회원만), 회원가입 버튼=true(신규 가입 허용).
        // 탈퇴 후 로그인 시 자동 재가입을 막고 명시적 회원가입을 거치게 하기 위함.
        boolean allowSignup = requestBody.has("allowSignup") && requestBody.get("allowSignup").asBoolean(false);
        if (idToken == null || idToken.isBlank() || uuid == null || uuid.isBlank()) {
            result.put(Constants.TAG_RESULT, Constants.RESULT_REQUEST_DATA_ERROR);
            result.put(Constants.TAG_RESULT_MESSAGE, "idToken과 uuid는 필수입니다.");
            return result;
        }

        // 1) ID Token 검증(서명/발급자/aud/만료)
        SocialLoginVerifier verifier = BeanUtil.getBean2(SocialLoginVerifier.class);
        SocialLoginVerifier.SocialProfile profile;
        try {
            // 구글/애플=ID Token, 카카오/네이버=accessToken (요청 idToken 필드로 공통 전달)
            switch (provider) {
                case "google": profile = verifier.verifyGoogle(idToken); break;
                case "apple":  profile = verifier.verifyApple(idToken); break;
                case "kakao":  profile = verifier.verifyKakao(idToken); break;
                case "naver":  profile = verifier.verifyNaver(idToken); break;
                default: throw new IllegalArgumentException("unknown provider: " + provider);
            }
        } catch (Exception e) {
            log.warn("[NoteMemberService] 소셜 토큰 검증 실패 provider={} err={}", provider, e.getMessage());
            result.put(Constants.TAG_RESULT, Constants.RESULT_NOT_FOUND);
            result.put(Constants.TAG_RESULT_MESSAGE, "소셜 로그인 인증에 실패했습니다.");
            return result;
        }

        NoteMemberRepository noteMemberRepository = BeanUtil.getBean2(NoteMemberRepository.class);

        // 2) find-or-create
        //   (a) provider + providerId(sub) 로 기존 소셜 계정 조회
        NoteMember noteMember = noteMemberRepository.findFirstByProviderAndProviderIdAndState(provider, profile.providerId, "signup");
        //   (b) 검증된 이메일이 있으면 동일 이메일 계정에 소셜 연결(이메일↔소셜 병합)
        if (noteMember == null && profile.email != null) {
            NoteMember byEmail = noteMemberRepository.findByIdAndState(profile.email, "signup");
            if (byEmail != null) {
                byEmail.setProvider(provider);
                byEmail.setProviderId(profile.providerId);
                noteMemberRepository.save(byEmail);
                noteMember = byEmail;
                log.info("[NoteMemberService] 소셜-이메일 계정 병합 id={} provider={}", byEmail.getId(), provider);
            }
        }
        //   (c-0) 계정이 없는데 자동 가입이 허용되지 않으면(로그인 버튼) → 가입 필요 응답(계정 생성 안 함).
        //         탈퇴 후 로그인 시 자동 재가입을 막고 회원가입을 유도한다.
        if (noteMember == null && !allowSignup) {
            log.info("[NoteMemberService] 소셜 로그인 - 미가입 계정, 회원가입 필요 provider={} email={}", provider, profile.email);
            result.put(Constants.TAG_RESULT, Constants.RESULT_NOT_FOUND);
            result.put("needSignup", true);
            result.put(Constants.TAG_RESULT_MESSAGE, "가입되지 않은 계정입니다. 회원가입 후 이용해 주세요.");
            return result;
        }
        //   (c) 신규 계정 생성
        if (noteMember == null) {
            String newId = profile.email != null ? profile.email : (provider + ":" + profile.providerId);
            NoteMember created = new NoteMember();
            created.setId(newId);
            created.setEmail(profile.email);
            created.setUuid(java.util.UUID.randomUUID().toString());
            created.setState("signup");
            created.setProvider(provider);
            created.setProviderId(profile.providerId);
            created.setSubscriptionPlan("free");
            created.setIdInsertDateTime(LocalDateTime.now());
            // 소셜 계정: 사용자가 알 수 없는 임의 비번 해시(비번 로그인 경로 NPE 방지 및 무단 로그인 차단)
            created.setPassword(Crypto.getMemberPassword(java.util.UUID.randomUUID().toString()));
            // 표시 이름(닉네임) — 값이 있고 중복이 아니면 설정
            if (profile.name != null && !profile.name.isBlank()
                    && noteMemberRepository.findFirstByName(profile.name.trim()) == null) {
                created.setName(profile.name.trim());
            }
            noteMemberRepository.save(created);
            noteMember = created;
            log.info("[NoteMemberService] 소셜 신규 계정 생성 id={} provider={} sub={}", newId, provider, profile.providerId);
        }

        // 3) 디바이스 슬롯 정책(비번 로그인과 동일: 무료/스탠다드=1대, 프리미엄=3대)
        String plan = noteMember.getSubscriptionPlan();
        boolean isPremium = plan != null && plan.equalsIgnoreCase("premium");
        String uuid1 = noteMember.getUuid1();
        String uuid2 = noteMember.getUuid2();
        String uuid3 = noteMember.getUuid3();
        boolean slot1Empty = uuid1 == null || uuid1.isBlank();
        boolean slot2Empty = uuid2 == null || uuid2.isBlank();
        boolean slot3Empty = uuid3 == null || uuid3.isBlank();

        boolean matched;
        boolean canRegister;
        if (isPremium) {
            matched = (uuid1 != null && uuid1.equals(uuid)) || (uuid2 != null && uuid2.equals(uuid)) || (uuid3 != null && uuid3.equals(uuid));
            canRegister = !matched && (slot1Empty || slot2Empty || slot3Empty);
        } else {
            matched = uuid1 != null && uuid1.equals(uuid);
            canRegister = !matched && slot1Empty;
        }
        log.info("[NoteMemberService] 소셜 로그인 uuid 매칭 - id: {}, provider: {}, plan: {}, matched: {}, canRegister: {}",
                noteMember.getId(), provider, plan, matched, canRegister);

        if (!(matched || canRegister)) {
            log.warn("[NoteMemberService] 소셜 로그인 거부(기기 한도) id={} plan={}", noteMember.getId(), plan);
            result.put(Constants.TAG_RESULT, Constants.RESULT_NOT_FOUND);
            result.put(Constants.TAG_RESULT_MESSAGE, isPremium
                    ? "이미 3대의 디바이스에서 로그인되어 있습니다. 기존 디바이스에서 로그아웃 후 다시 시도해 주세요."
                    : "무료 플랜은 1대에서만 로그인할 수 있습니다. 기존 기기에서 로그아웃 후 다시 시도해 주세요.");
            return result;
        }
        if (!matched) {
            if (!isPremium) {
                noteMember.setUuid1(uuid);
                noteMember.setUuid2(null);
                noteMember.setUuid3(null);
            } else if (slot1Empty) {
                noteMember.setUuid1(uuid);
            } else if (slot2Empty) {
                noteMember.setUuid2(uuid);
            } else {
                noteMember.setUuid3(uuid);
            }
            noteMemberRepository.save(noteMember);
        }

        // 4) 자체 JWT 발급 — 비번 없이 인증 객체 직접 구성(권한은 일반 로그인과 동일: ROLE_MEMBER_INDIVIDUAL)
        // principal은 반드시 MemberDetails 타입이어야 함(TokenProvider가 principal을 MemberDetails로 캐스팅).
        java.util.List<org.springframework.security.core.GrantedAuthority> authorities = new java.util.ArrayList<>();
        authorities.add(AuthoritiesConstants.ROLE_MEMBER_INDIVIDUAL);
        com.litten.common.security.MemberDetails principal = new com.litten.common.security.MemberDetails(
                noteMember.getName(), noteMember.getId(), noteMember.getPassword(), authorities);
        org.springframework.security.core.Authentication authentication =
                new UsernamePasswordAuthenticationToken(principal, null, authorities);
        SecurityContextHolder.getContext().setAuthentication(authentication);

        Long tokenValidityInMilliseconds = isMobile
                ? Config.getInstance().getMobileTokenValidityInMilliseconds()
                : Config.getInstance().getTokenValidityInMilliseconds();
        TokenProvider tokenProvider = BeanUtil.getBean2(TokenProvider.class);
        String jwt = tokenProvider.createToken(authentication, tokenValidityInMilliseconds, isMobile);
        Integer tokenExpiredDate = (Integer) tokenProvider.getValue(jwt, Constants.TAG_JWT_EXPIRED_DATE);

        result.put(Constants.TAG_SEQUENCE, noteMember.getSequence());
        result.put(Constants.TAG_UUID, noteMember.getUuid());
        result.put(Constants.TAG_AUTH_TOKEN, jwt);
        result.put(Constants.TAG_TOKEN_EXPIRED_DATE, tokenExpiredDate);
        result.put(Constants.TAG_MEMBER_ID, noteMember.getId());
        result.put("name", noteMember.getName());
        result.put(Constants.TAG_SUBSCRIPTION_PLAN, noteMember.getSubscriptionPlan());
        result.put(Constants.TAG_PLAN_EXPIRED_AT, noteMember.getPlanExpiredAt());

        // 응답 헤더 토큰(기존 로그인과 동일 — 클라이언트 재발급 저장 로직과 호환)
        HttpServletResponse httpServletResponse = ((ServletRequestAttributes) RequestContextHolder.currentRequestAttributes()).getResponse();
        if (httpServletResponse != null) {
            httpServletResponse.setHeader(Constants.TAG_HTTP_HEADER_AUTH_TOKEN, jwt);
            httpServletResponse.setHeader(Constants.TAG_HTTP_HEADER_TOKEN_EXPIRED_DATE, tokenExpiredDate.toString());
        }

        return result;
    }

    public Map<String, Object> putChangePassword(JsonNode requestBody) throws Exception {
        Map<String, Object> result = new HashMap<>();
        result.put(Constants.TAG_RESULT, Constants.RESULT_SUCCESS);

        String value1 = requestBody.get("id").textValue();
        String value2 = requestBody.get("password").textValue();

        NoteMemberRepository noteMemberRepository = BeanUtil.getBean2(NoteMemberRepository.class);
        NoteMember noteMember = noteMemberRepository.findByIdAndState(value1,"signup");

        if (noteMember==null) {
            result.put(Constants.TAG_RESULT, Constants.RESULT_NOT_FOUND);
            result.put(Constants.TAG_MEMBER_SEQ, null);
            result.put(Constants.TAG_RESULT_MESSAGE, "아이디를 찾을 수 없습니다.");
        } else {
            String encryptPassword = noteMember.getPassword().substring(8);
            if (Crypto.matchesMemberPassword(value2, encryptPassword)) {
                try {
                    noteMember.setPassword(Crypto.getMemberPassword(requestBody.deepCopy().get("newPassword").asText()));
                    noteMember.setChangePasswordDateTime(LocalDateTime.now());
                    noteMember.setIsChangePassword(true);
                    noteMemberRepository.save(noteMember);
                } catch (BadCredentialsException e) {
                    log.error("Authentication.get", e);
                    result.put(Constants.TAG_RESULT, Constants.RESULT_BAD_CREDENTIALS);
                    result.put(Constants.TAG_RESULT_MESSAGE, "bad credentials");
                }
            } else {
                result.put(Constants.TAG_RESULT, Constants.RESULT_NOT_FOUND);
                result.put(Constants.TAG_RESULT_MESSAGE, Constants.RESULT_NOT_FOUND_MESSAGE + " 비밀번호 불일치");
            }
        }
        return result;
    }

    /**
     * 비밀번호 초기화
     *   1.회원에게 비밀번호 변경 이메일을 보낸다. (전용 url생성)
     * 비밀번호 업데이트
     */
    public Map<String, Object> postChangePasswordUrl(JsonNode requestBody) throws Exception {
        Map<String, Object> result = new HashMap<>();
        result.put(Constants.TAG_RESULT,Constants.RESULT_SUCCESS);
        HttpServletRequest httpServletRequest = ((ServletRequestAttributes) RequestContextHolder.currentRequestAttributes()).getRequest();
        String ip = httpServletRequest.getRemoteAddr();
        String id = requestBody.get(Constants.TAG_ID).asText();
        try {
            NoteMemberRepository noteMemberRepository = BeanUtil.getBean2(NoteMemberRepository.class);
            NoteMember noteMember = noteMemberRepository.findByIdAndState(id,"signup");
            if (noteMember == null) {
                result.put(Constants.TAG_RESULT, Constants.RESULT_NOT_FOUND);
            } else {
                String memberUrl = "";
                // local
                // http://localhost:8989/account/anon/svc/member/change-password2
                // http://localhost:8989/account/anon/svc/member/change-password3

                // 개발
                // https://dev-api.ploonet.com/api/account/v1/members/change-password2
                // https://dev-api.ploonet.com/api/account/v1/members/change-password3

                // 운영
                // https://api.ploonet.com/api/account/v1/members/change-password2
                // https://api.ploonet.com/api/account/v1/members/change-password3

//                if (Config.getInstance().getProtocol().equals("http")) {
//                    if (Config.getInstance().getPort().equals("80"))
//                        memberUrl = "http://" + Config.getInstance().getDomain() + Config.getInstance().getPrefixPath() + Constants.PATH_OF_CHANGE_PASSWORD_PATH;
//                    else
//                        memberUrl = "http://" + Config.getInstance().getDomain() + Config.getInstance().getPrefixPath() + Constants.PATH_OF_CHANGE_PASSWORD_PATH;
//                } else if (Config.getInstance().getProtocol().equals("https")) {
//                    memberUrl = "https://" + Config.getInstance().getDomain() + Config.getInstance().getPrefixPath() + Constants.PATH_OF_CHANGE_PASSWORD_PATH;
//                } else {
//                    memberUrl = Config.getInstance().getProtocol() + "://" + Config.getInstance().getDomain() + ":" + Config.getInstance().getPort() + Config.getInstance().getPrefixPath() + Constants.PATH_OF_CHANGE_PASSWORD_PATH;
//                }
                memberUrl = Config.getInstance().getProtocol()+"://" + Config.getInstance().getDomain() + Config.getInstance().getPrefixPath() + Constants.PATH_OF_CHANGE_PASSWORD_PATH;

                String cypherMemberId = Crypto.encryptChangePasswordMemberId(noteMember.getId());
                String cypherDueDate = Crypto.encryptChangePasswordDueDate(DateUtil.getchangePasswordDueDate(Constants.CHANGE_PASSWORD_DUE_MINUTE));
                memberUrl = memberUrl + "/" + cypherDueDate + "/" + cypherMemberId;

                Mailer mailer = new Mailer();
                mailer.sendChangePassword(noteMember.getId(), "", memberUrl, ip);
                result.put(Constants.TAG_EMAIL, noteMember.getId());
            }
        } catch (IllegalArgumentException e) {
            log.error("MemberService.update", e);
            if (e.getMessage().indexOf("base64") != -1) {
                result.put(Constants.TAG_RESULT, Constants.RESULT_DATA_DECRYPT_ERROR);
                result.put(Constants.TAG_RESULT_MESSAGE, "check url value (Encode base64 url value)");
            }
        } catch (NoSuchMethodException e) {
            log.error("MemberService.update", e);
            result.put(Constants.TAG_RESULT, Constants.RESULT_NO_SUCH_METHOD);
        }

        return result;
    }

    /**
     * 개인회원 비밀번호 초기화
     *    2.이메일내의 url을 방문한다.
     * @param value1
     * @param value2
     * @return
     * @throws Exception
     */
//    @Override
    public Map<String, Object> get(String value1, String value2) throws Exception {
        log.debug("value1 -->> {}", value1);
        log.debug("value2 -->> {}", value2);

        Map<String, Object> result = new HashMap<>();
        result.put(Constants.TAG_RESULT,Constants.RESULT_SUCCESS);

        HttpServletRequest httpServletRequest = ((ServletRequestAttributes) RequestContextHolder.currentRequestAttributes()).getRequest();
        HttpServletResponse httpServletResponse = ((ServletRequestAttributes) RequestContextHolder.currentRequestAttributes()).getResponse();

        result.put(Constants.TAG_DUE_DATE_TIME, value1);
        result.put(Constants.TAG_MEMBER_ID, value2);

        String plainDueDateTime = Crypto.decryptChangePasswordDueDate(value1);
        String plainMemberId = Crypto.decryptChangePasswordMemberId(value2);

        String currentDateTime = DateUtil.getchangePasswordDueDate(0);

        if(Long.parseLong(currentDateTime) > Long.parseLong(plainDueDateTime) ) {
            result.put(Constants.TAG_RESULT,Constants.RESULT_NOT_FOUND);
        }

        result.put(Constants.TAG_PLAIN_DUE_DATE_TIME,plainDueDateTime);
        result.put(Constants.TAG_PLAIN_MEMBER_ID,plainMemberId);

        return result;
    }

    /**
     * 개인회원 비밀번호 초기화
     *   3.입력 받은 비밀번호를 등록한다.
     * @param requestBody
     * @return
     * @throws Exception
     */
    public Map<String, Object> put(JsonNode requestBody) throws Exception {

        Map<String, Object> result = new HashMap<>();
        result.put(Constants.TAG_RESULT,Constants.RESULT_SUCCESS);

        String memberId = requestBody.get(Constants.TAG_MEMBER_ID).asText();
        String dueDateTime = requestBody.get(Constants.TAG_DUE_DATE_TIME).asText();

        String plainMemberId = Crypto.decryptChangePasswordDueDate(memberId);
        String plainDueDateTime = Crypto.decryptChangePasswordMemberId(dueDateTime);

        result.put(Constants.TAG_PLAIN_DUE_DATE_TIME,plainDueDateTime);
        result.put(Constants.TAG_PLAIN_MEMBER_ID,plainMemberId);

        String currentDateTime = DateUtil.getchangePasswordDueDate(0);
        if(Long.parseLong(currentDateTime) > Long.parseLong(plainDueDateTime) ) {
            result.put(Constants.TAG_RESULT,Constants.RESULT_NOT_FOUND);
        } else {
            NoteMemberRepository memberRepository = BeanUtil.getBean2(NoteMemberRepository.class);
            NoteMember noteMember = memberRepository.findByIdAndState(plainMemberId, "signup");
            if ( noteMember==null ) {
                result.put(Constants.TAG_RESULT,Constants.RESULT_NOT_FOUND);
            } else {
                noteMember.setPassword(Crypto.getMemberPassword(requestBody.get(Constants.TAG_PASSWORD2).asText()));
                noteMember.setIsChangePassword(true);
                noteMember.setChangePasswordDateTime(LocalDateTime.now());
                memberRepository.save(noteMember);
                Mailer mailer = new Mailer();
                mailer.completeChangePassword(noteMember.getId(), "");
            }
        }
        return result;
    }

    @Transactional
    public Map<String, Object> delete(String id) throws Exception {
        Map<String, Object> result = new HashMap<>();
        NoteMemberRepository memberRepository = BeanUtil.getBean2(NoteMemberRepository.class);
        NoteMember noteMember = memberRepository.findByIdAndState(id, "signup");
        if ( noteMember==null ) {
            result.put(Constants.TAG_RESULT,Constants.RESULT_NOT_FOUND);
            result.put(Constants.TAG_RESULT_MESSAGE,Constants.RESULT_NOT_FOUND_MESSAGE+" id-->"+id+" state-->signup");
        } else {
            noteMember.setState("withdraw");
            noteMember.setUpdateDateTime(LocalDateTime.now());
            memberRepository.save(noteMember);
            List<NoteMember> noteMembers = memberRepository.findByUuid(noteMember.getUuid());

            for (NoteMember tempNoteMember : noteMembers) {
                tempNoteMember.setUpdateDateTime(LocalDateTime.now());
                try {
                    backup(tempNoteMember,Constants.CODE_LOG_DELETE_QUERY);
                } catch (Exception e) {
                    log.error(e);
                }
            }

//            for (NoteMember tempNoteMember : noteMembers)
//                memberRepository.delete(tempNoteMember);

            // 연관 서버 데이터(파일/리튼/일정/요약/유튜브/스터디룸 등) 삭제 — 계정 레코드 삭제 전에 정리
            deleteMemberAssociatedData(noteMember.getId(), noteMember.getUuid());

            memberRepository.deleteByUuid(noteMember.getUuid());

            // 성공 결과 설정
            result.put(Constants.TAG_RESULT,Constants.RESULT_SUCCESS);
            result.put(Constants.TAG_RESULT_MESSAGE,"회원탈퇴 성공");
        }
        return result;
    }

    /**
     * 회원 탈퇴 시 연관 서버 데이터 삭제.
     * memberId(=이메일) 기준 데이터 + memberUuid(계정 UUID) 기준 요약/퀴즈를 정리한다.
     * 각 단계를 개별 try-catch로 감싸 하나가 실패해도 나머지 삭제와 계정 삭제는 진행한다.
     * (스터디룸 '발신자 탈퇴 표시'는 A-2에서 별도 처리. 여기서는 본인 데이터만 삭제.)
     */
    private void deleteMemberAssociatedData(String memberId, String memberUuid) {
        // 1) 동기화 파일: 서버 저장 파일 삭제 후 DB 레코드 삭제
        try {
            var cfr = BeanUtil.getBean2(com.litten.note.sync.CloudFileRepository.class);
            var lss = BeanUtil.getBean2(com.litten.note.sync.LocalStorageService.class);
            var files = cfr.findAllByMemberId(memberId);
            for (var f : files) {
                if (f.getFilePath() != null) {
                    try { lss.delete(f.getFilePath()); }
                    catch (Exception e) { log.warn("[탈퇴] 파일 삭제 실패 path={} err={}", f.getFilePath(), e.getMessage()); }
                }
            }
            cfr.deleteByMemberId(memberId);
            log.info("[탈퇴] 파일 {}건 삭제 id={}", files.size(), memberId);
        } catch (Exception e) { log.error("[탈퇴] 파일 삭제 오류 id=" + memberId, e); }

        // 2) 리튼 메타
        try { BeanUtil.getBean2(com.litten.note.sync.LittenRepository.class).deleteByMemberId(memberId); }
        catch (Exception e) { log.error("[탈퇴] 리튼 삭제 오류 id=" + memberId, e); }

        // 3) 일정
        try { BeanUtil.getBean2(com.litten.note.sync.NoteScheduleRepository.class).deleteByMemberId(memberId); }
        catch (Exception e) { log.error("[탈퇴] 일정 삭제 오류 id=" + memberId, e); }

        // 4) 요약/퀴즈 (memberUuid 기준) — 퀴즈를 먼저(요약 FK) 삭제 후 요약 삭제
        try {
            BeanUtil.getBean2(com.litten.note.summary.QuizResultRepository.class).deleteByMemberUuidViaSummary(memberUuid);
            BeanUtil.getBean2(SummaryResultRepository.class).deleteByMemberUuid(memberUuid);
        } catch (Exception e) { log.error("[탈퇴] 요약/퀴즈 삭제 오류 uuid=" + memberUuid, e); }

        // 5) 나만의 스터디룸(항목 → 룸)
        try { BeanUtil.getBean2(com.litten.note.selfroom.SelfStudyRoomItemRepository.class).deleteByMemberId(memberId); }
        catch (Exception e) { log.error("[탈퇴] 셀프룸 항목 삭제 오류 id=" + memberId, e); }
        try { BeanUtil.getBean2(com.litten.note.selfroom.SelfStudyRoomRepository.class).deleteByMemberId(memberId); }
        catch (Exception e) { log.error("[탈퇴] 셀프룸 삭제 오류 id=" + memberId, e); }

        // 6) 유튜브 채널/시청상태
        try { BeanUtil.getBean2(MemberYoutubeChannelRepository.class).deleteByMemberId(memberId); }
        catch (Exception e) { log.error("[탈퇴] 유튜브 채널 삭제 오류 id=" + memberId, e); }
        try { BeanUtil.getBean2(ChannelWatchStateRepository.class).deleteByMemberId(memberId); }
        catch (Exception e) { log.error("[탈퇴] 유튜브 시청상태 삭제 오류 id=" + memberId, e); }

        // 7) 받은 공유/메시지(수신자 기준)
        try { BeanUtil.getBean2(com.litten.note.studyroom.RoomShareDeliveryRepository.class).deleteByRecipientMemberId(memberId); }
        catch (Exception e) { log.error("[탈퇴] 받은 공유 삭제 오류 id=" + memberId, e); }
        try { BeanUtil.getBean2(com.litten.note.studyroom.message.RoomMessageDeliveryRepository.class).deleteByRecipientMemberId(memberId); }
        catch (Exception e) { log.error("[탈퇴] 받은 메시지 삭제 오류 id=" + memberId, e); }

        // 8) 룸 멤버십
        try { BeanUtil.getBean2(com.litten.note.studyroom.StudyRoomMemberRepository.class).deleteByMemberId(memberId); }
        catch (Exception e) { log.error("[탈퇴] 룸 멤버십 삭제 오류 id=" + memberId, e); }

        // 9) 내가 보낸 공유/메시지 → 삭제하지 않고 '발신자 탈퇴'로 표시(수신자 화면에 탈퇴 표시)
        try { BeanUtil.getBean2(com.litten.note.studyroom.RoomShareRepository.class).markSenderWithdrawn(memberId); }
        catch (Exception e) { log.error("[탈퇴] 공유 발신자탈퇴 표시 오류 id=" + memberId, e); }
        try { BeanUtil.getBean2(com.litten.note.studyroom.message.RoomMessageRepository.class).markSenderWithdrawn(memberId); }
        catch (Exception e) { log.error("[탈퇴] 메시지 발신자탈퇴 표시 오류 id=" + memberId, e); }

        // 10) 내가 방장인 그룹 스터디룸 → 룸 및 룸 멤버십 삭제(룸 삭제 정책)
        try {
            var srr = BeanUtil.getBean2(com.litten.note.studyroom.StudyRoomRepository.class);
            var srmr = BeanUtil.getBean2(com.litten.note.studyroom.StudyRoomMemberRepository.class);
            var rooms = srr.findByOwnerMemberId(memberId);
            for (var room : rooms) srmr.deleteByRoomId(room.getId());
            srr.deleteByOwnerMemberId(memberId);
            log.info("[탈퇴] 방장 룸 {}건 삭제 id={}", rooms.size(), memberId);
        } catch (Exception e) { log.error("[탈퇴] 방장 룸 삭제 오류 id=" + memberId, e); }

        log.info("[탈퇴] 연관 데이터 삭제 완료 id={} uuid={}", memberId, memberUuid);
    }

    /**
     * 프리미엄 전환 시 디바이스 UUID → 회원 UUID 데이터 이관.
     *
     * 무료/스탠다드 시절 note_summary_result 에 저장된 member_uuid(=디바이스UUID)를
     * 로그인 회원의 uuid로 일괄 업데이트한다.
     *
     * @param deviceUuid 앱 디바이스 UUID (무료/스탠다드 시절 사용)
     * @param memberId   현재 로그인한 회원 ID
     */
    @Transactional
    public Map<String, Object> migrateDeviceData(String deviceUuid, String memberId) throws Exception {
        log.debug("[NoteMemberService] migrateDeviceData 진입 - memberId: {}, deviceUuid: {}", memberId, deviceUuid);

        Map<String, Object> result = new HashMap<>();
        result.put(Constants.TAG_RESULT, Constants.RESULT_SUCCESS);

        if (deviceUuid == null || deviceUuid.isBlank()) {
            result.put(Constants.TAG_RESULT, Constants.RESULT_REQUEST_DATA_ERROR);
            result.put(Constants.TAG_RESULT_MESSAGE, "deviceUuid는 필수입니다.");
            return result;
        }

        // 로그인 회원의 uuid 조회
        NoteMemberRepository noteMemberRepository = BeanUtil.getBean2(NoteMemberRepository.class);
        NoteMember noteMember = noteMemberRepository.findByIdAndState(memberId, "signup");
        if (noteMember == null || noteMember.getUuid() == null) {
            log.warn("[NoteMemberService] migrateDeviceData - 회원 없음 또는 uuid 없음: {}", memberId);
            result.put(Constants.TAG_RESULT, Constants.RESULT_NOT_FOUND);
            result.put(Constants.TAG_RESULT_MESSAGE, "회원 정보를 찾을 수 없습니다.");
            return result;
        }

        String memberUuid = noteMember.getUuid();

        // 1) note_summary_result 이관 (member_uuid = deviceUuid → memberUuid)
        //    deviceUuid == memberUuid(회원가입 기기)면 사실상 무효과(동일 값 갱신)지만,
        //    아래 채널/watch-state는 "guest:<deviceUuid>"로 별도 키되어 이 경우에도 반드시 이관해야 하므로
        //    조기 return 하지 않는다. (이전 버그: 가입 기기가 자기 게스트 채널을 영영 이관 못 함)
        SummaryResultRepository summaryResultRepository = BeanUtil.getBean2(SummaryResultRepository.class);
        int summaryMigrated = deviceUuid.equals(memberUuid)
                ? 0
                : summaryResultRepository.migrateMemberUuid(deviceUuid, memberUuid);

        // 2) note_member_youtube_channel 이관 (member_id = "guest:<deviceUuid>" → memberId)
        //    회원이 이미 구독 중인 채널은 제외하고 이관, 나머지 게스트 행은 삭제
        String guestId = "guest:" + deviceUuid;
        MemberYoutubeChannelRepository memberChannelRepository = BeanUtil.getBean2(MemberYoutubeChannelRepository.class);
        int channelMigrated = memberChannelRepository.migrateGuestToMember(guestId, memberId);
        int channelRemoved  = memberChannelRepository.deleteByMemberId(guestId);

        // 3) note_channel_watch_state 이관 (new 표시 확인 상태)
        ChannelWatchStateRepository watchStateRepository = BeanUtil.getBean2(ChannelWatchStateRepository.class);
        int watchMigrated = watchStateRepository.migrateGuestToMember(guestId, memberId);
        int watchRemoved  = watchStateRepository.deleteByMemberId(guestId);

        log.info("[NoteMemberService] migrateDeviceData 완료 - memberId: {}, deviceUuid: {}, summaryMigrated: {}, channelMigrated: {}, channelRemoved(중복): {}, watchMigrated: {}, watchRemoved(중복): {}",
                memberId, deviceUuid, summaryMigrated, channelMigrated, channelRemoved, watchMigrated, watchRemoved);

        result.put("migratedCount", summaryMigrated);
        result.put("channelMigratedCount", channelMigrated);
        result.put("watchStateMigratedCount", watchMigrated);
        result.put("memberUuid", memberUuid);
        return result;
    }

    /**
     * 로그아웃 / 디바이스 원격 해제.
     * 회원의 uuid1/2/3 슬롯 중 전달된 uuid와 일치하는 슬롯을 비운다.
     * 1계정 3장치 제한에서 슬롯을 반납해 다른/신규 기기가 로그인할 수 있게 한다.
     */
    @Transactional
    public Map<String, Object> logout(String uuid, String memberId) throws Exception {
        log.debug("[NoteMemberService] logout 진입 - memberId: {}, uuid: {}", memberId, uuid);

        Map<String, Object> result = new HashMap<>();
        result.put(Constants.TAG_RESULT, Constants.RESULT_SUCCESS);

        if (uuid == null || uuid.isBlank()) {
            result.put(Constants.TAG_RESULT, Constants.RESULT_REQUEST_DATA_ERROR);
            result.put(Constants.TAG_RESULT_MESSAGE, "uuid는 필수입니다.");
            return result;
        }

        NoteMemberRepository noteMemberRepository = BeanUtil.getBean2(NoteMemberRepository.class);
        NoteMember noteMember = noteMemberRepository.findByIdAndState(memberId, "signup");
        if (noteMember == null) {
            log.warn("[NoteMemberService] logout - 회원 없음: {}", memberId);
            result.put(Constants.TAG_RESULT, Constants.RESULT_NOT_FOUND);
            result.put(Constants.TAG_RESULT_MESSAGE, "회원을 찾을 수 없습니다.");
            return result;
        }

        boolean cleared = false;
        if (uuid.equals(noteMember.getUuid1())) { noteMember.setUuid1(null); cleared = true; }
        if (uuid.equals(noteMember.getUuid2())) { noteMember.setUuid2(null); cleared = true; }
        if (uuid.equals(noteMember.getUuid3())) { noteMember.setUuid3(null); cleared = true; }

        if (cleared) {
            noteMember.setUpdateDateTime(LocalDateTime.now());
            noteMemberRepository.save(noteMember);
            log.info("[NoteMemberService] logout - 슬롯 해제 완료 - memberId: {}, uuid: {}", memberId, uuid);
        } else {
            log.info("[NoteMemberService] logout - 일치 슬롯 없음(이미 해제됨) - memberId: {}, uuid: {}", memberId, uuid);
        }
        result.put("cleared", cleared);
        return result;
    }

    /**
     * 회원의 등록 디바이스(uuid1/2/3 슬롯) 목록 조회. 디바이스 관리 화면용.
     */
    public Map<String, Object> getDevices(String memberId) throws Exception {
        log.debug("[NoteMemberService] getDevices 진입 - memberId: {}", memberId);

        Map<String, Object> result = new HashMap<>();
        result.put(Constants.TAG_RESULT, Constants.RESULT_SUCCESS);

        NoteMemberRepository noteMemberRepository = BeanUtil.getBean2(NoteMemberRepository.class);
        NoteMember noteMember = noteMemberRepository.findByIdAndState(memberId, "signup");
        if (noteMember == null) {
            result.put(Constants.TAG_RESULT, Constants.RESULT_NOT_FOUND);
            result.put(Constants.TAG_RESULT_MESSAGE, "회원을 찾을 수 없습니다.");
            return result;
        }

        java.util.List<Map<String, Object>> devices = new java.util.ArrayList<>();
        addDeviceSlot(devices, 1, noteMember.getUuid1());
        addDeviceSlot(devices, 2, noteMember.getUuid2());
        addDeviceSlot(devices, 3, noteMember.getUuid3());
        result.put("devices", devices);
        log.info("[NoteMemberService] getDevices - memberId: {}, 점유 슬롯: {}",
                memberId, devices.stream().filter(d -> Boolean.TRUE.equals(d.get("occupied"))).count());
        return result;
    }

    private void addDeviceSlot(java.util.List<Map<String, Object>> list, int slot, String uuid) {
        Map<String, Object> d = new HashMap<>();
        d.put("slot", slot);
        d.put("uuid", uuid);
        d.put("occupied", uuid != null && !uuid.isBlank());
        list.add(d);
    }

    @Transactional
    public int backup(Object backupDomain, String queryCode) throws Exception {
        int ret = -1;
        if(backupDomain==null) {
            return Constants.RESULT_NOT_FOUND;
        } else {
            NoteMember deleteNoteMember = (NoteMember)backupDomain;
            ObjectMapper objectMapper = new ObjectMapper();
            String companyLogJson = objectMapper.writeValueAsString(deleteNoteMember);
            NoteMemberLog noteMemberLog = objectMapper.readValue(companyLogJson, NoteMemberLog.class);
            noteMemberLog.setQueryCode(queryCode);
            noteMemberLog.setQueryDate(LocalDateTime.now());
//            try{
//                companyLog.setQueryTokenId(getJwtMemberId(((ServletRequestAttributes) RequestContextHolder.currentRequestAttributes()).getResponse()));
//            } catch(Exception e) {
//                // batch job으로 실행될 경우
//                e.printStackTrace();
//            }
            NoteMemberLogRepository noteMemberLogRepository = BeanUtil.getBean2(NoteMemberLogRepository.class);
            noteMemberLogRepository.save(noteMemberLog);
            ret = noteMemberLog.getSequence().intValue();
        }
        return ret;
    }
}

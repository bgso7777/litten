package com.litten.note;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.litten.Constants;
import com.litten.common.security.SecurityUtils;
import com.litten.common.config.Config;
import com.litten.common.dynamic.BeanUtil;
import com.litten.common.dynamic.ConstantsDynamic;
import com.litten.common.dynamic.CustomHttpService;
import com.litten.common.security.jwt.TokenProvider;
import com.litten.common.util.Crypto;
import com.litten.common.util.DateUtil;
import com.litten.common.util.Mailer;
import com.litten.note.summary.SummaryResultRepository;
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
                boolean matched =
                        (uuid1 != null && uuid1.equals(uuid)) ||
                        (uuid2 != null && uuid2.equals(uuid)) ||
                        (uuid3 != null && uuid3.equals(uuid));
                boolean slot1Empty = uuid1 == null || uuid1.isBlank();
                boolean slot2Empty = uuid2 == null || uuid2.isBlank();
                boolean slot3Empty = uuid3 == null || uuid3.isBlank();
                boolean canRegister = !matched && (slot1Empty || slot2Empty || slot3Empty);
                log.info("[NoteMemberService] postLogin uuid 매칭 - id: {}, reqUuid: {}, uuid1: {}, uuid2: {}, uuid3: {}, matched: {}, canRegister: {}",
                        value1, uuid, uuid1, uuid2, uuid3, matched, canRegister);
                if (matched || canRegister) {
                    if (!matched) {
                        // 빈 슬롯에 새 디바이스 등록 (uuid1 → uuid2 → uuid3 순서)
                        String registeredSlot;
                        if (slot1Empty) {
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
                        log.info("[NoteMemberService] 새 디바이스 등록 - id: {}, slot: {}, uuid: {}",
                                value1, registeredSlot, uuid);
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
                    // 세 슬롯 모두 다른 디바이스가 점유 중 → 거부
                    log.warn("[NoteMemberService] 로그인 거부 - 최대 3대 초과 - id: {}, reqUuid: {}, uuid1: {}, uuid2: {}, uuid3: {}",
                            value1, uuid, uuid1, uuid2, uuid3);
                    result.put(Constants.TAG_RESULT, Constants.RESULT_NOT_FOUND);
                    result.put(Constants.TAG_RESULT_MESSAGE, "이미 3대의 디바이스에서 로그인되어 있습니다. 기존 디바이스에서 로그아웃 후 다시 시도해 주세요.");
                }
            } else {
                result.put(Constants.TAG_RESULT, Constants.RESULT_NOT_FOUND);
                result.put(Constants.TAG_RESULT_MESSAGE, "비번 불일치 id-->"+value1);
            }
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

            memberRepository.deleteByUuid(noteMember.getUuid());

            // 성공 결과 설정
            result.put(Constants.TAG_RESULT,Constants.RESULT_SUCCESS);
            result.put(Constants.TAG_RESULT_MESSAGE,"회원탈퇴 성공");
        }
        return result;
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

        // deviceUuid와 memberUuid가 같으면 이관 불필요
        if (deviceUuid.equals(memberUuid)) {
            log.info("[NoteMemberService] migrateDeviceData - deviceUuid와 memberUuid 동일, 이관 불필요");
            result.put("migratedCount", 0);
            return result;
        }

        // note_summary_result 이관 (member_uuid = deviceUuid → memberUuid)
        SummaryResultRepository summaryResultRepository = BeanUtil.getBean2(SummaryResultRepository.class);
        int migratedCount = summaryResultRepository.migrateMemberUuid(deviceUuid, memberUuid);

        log.info("[NoteMemberService] migrateDeviceData 완료 - memberId: {}, deviceUuid: {}, memberUuid: {}, migratedCount: {}",
                memberId, deviceUuid, memberUuid, migratedCount);

        result.put("migratedCount", migratedCount);
        result.put("memberUuid", memberUuid);
        return result;
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

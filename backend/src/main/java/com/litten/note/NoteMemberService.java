package com.litten.note;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.litten.Constants;
import com.litten.common.config.Config;
import com.litten.common.dynamic.BeanUtil;
import com.litten.common.dynamic.ConstantsDynamic;
import com.litten.common.dynamic.CustomHttpService;
import com.litten.common.security.jwt.TokenProvider;
import com.litten.common.util.Crypto;
import com.litten.common.util.DateUtil;
import com.litten.common.util.Mailer;
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
                if( noteMember.getUuid().equals(uuid) ) {
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
                    result.put(Constants.TAG_RESULT, Constants.RESULT_NOT_FOUND);
                    result.put(Constants.TAG_RESULT_MESSAGE, "다른 장치에서 가입된 계정입니다. id-->"+value1+" uuid-->"+uuid);
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

                if (Config.getInstance().getProtocol().equals("http")) {
                    if (Config.getInstance().getDomain().equals("80"))
                        memberUrl = "http://" + Config.getInstance().getDomain() + Config.getInstance().getPrefixPath() + Constants.PATH_OF_CHANGE_PASSWORD_PATH;
                    else
                        memberUrl = "http://" + Config.getInstance().getDomain() + ":" + Config.getInstance().getPort() + Config.getInstance().getPrefixPath() + Constants.PATH_OF_CHANGE_PASSWORD_PATH;
                } else if (Config.getInstance().getProtocol().equals("https")) {
                    memberUrl = "https://" + Config.getInstance().getDomain() + Config.getInstance().getPrefixPath() + Constants.PATH_OF_CHANGE_PASSWORD_PATH;
                } else {
                    memberUrl = Config.getInstance().getProtocol() + "://" + Config.getInstance().getDomain() + ":" + Config.getInstance().getPort() + Config.getInstance().getPrefixPath() + Constants.PATH_OF_CHANGE_PASSWORD_PATH;
                }

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

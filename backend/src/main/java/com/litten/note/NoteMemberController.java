package com.litten.note;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.litten.common.dynamic.ConstantsDynamic;
import com.litten.common.dynamic.ControllerDynamicServiceBridge;
import com.litten.common.security.SecurityUtils;
import com.litten.common.util.Crypto;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@Slf4j
@RestController
@RequiredArgsConstructor
public class NoteMemberController {

    @Autowired
    ControllerDynamicServiceBridge controllerDynamicServiceBridge;

    @Autowired
    NoteMemberRepository noteMemberRepository;

//    @CrossOrigin(origins="*", allowedHeaders="*")
//    @PostMapping("/note/v1/members")
//    @ResponseBody
//    public ResponseEntity<Map<String, Object>> saveNoteMember(
//            @RequestParam(value="is-admin", required=false) Boolean isAdmin,
//            @RequestBody JsonNode requestBody ) {
//        String domainName = "NoteMemberDomain";
//        Boolean isCheckAllowedClassValue = true;
//        if( isAdmin!=null && isAdmin )
//            isCheckAllowedClassValue = false;
//        Map<String, Object> result = controllerDynamicServiceBridge.saveDomain(domainName,isCheckAllowedClassValue,requestBody);
//        return ResponseEntity.ok(result);
//    }

    @CrossOrigin(origins="*", allowedHeaders="*")
    @PostMapping("/note/v1/members/install")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> postInstall(@RequestBody JsonNode requestBody) {
        String domainName = "NoteMember";
        Map<String, Object> result = new HashMap<>();
        String uuid = requestBody.deepCopy().get("uuid").asText();
        result = controllerDynamicServiceBridge.findDomainById(domainName,uuid);
        if( result.get(ConstantsDynamic.TAG_RESULT).equals(ConstantsDynamic.RESULT_SUCCESS) ){
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_ALEADY_EXIST);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_ALEADY_EXIST_MESSAGE+" uuid-->"+uuid);
        } else {
            requestBody = ((ObjectNode) requestBody.deepCopy()).put("id", uuid);
            requestBody = ((ObjectNode) requestBody.deepCopy()).put("stateCode", "install");
            result = controllerDynamicServiceBridge.saveDomain(domainName, true, requestBody);
        }
        return ResponseEntity.ok(result);
    }

    @CrossOrigin(origins="*", allowedHeaders="*")
    @PostMapping("/note/v1/members/signup")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> postSignup(@RequestBody JsonNode requestBody) {
        log.info("회원가입 요청: {}", requestBody);

        String domainName = "NoteMember";
        Map<String, Object> result = new HashMap<>();
        String id = requestBody.deepCopy().get("id").asText();
        String uuid = requestBody.deepCopy().get("uuid").asText();

        log.info("회원가입 대상 ID: {}", id);

        // 닉네임(name)은 선택 입력 — 입력된 경우 중복(유일성) 검증
        String signupNickname = (requestBody.has("name") && !requestBody.get("name").isNull())
                ? requestBody.get("name").asText().trim() : null;
        if (signupNickname != null && !signupNickname.isEmpty()
                && noteMemberRepository.findFirstByName(signupNickname) != null) {
            log.warn("회원가입 닉네임 중복: {}", signupNickname);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_ALEADY_EXIST);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, "이미 사용 중인 닉네임입니다: " + signupNickname);
            return ResponseEntity.ok(result);
        }

        // 1. stateCode='signup'인 계정이 있는지 확인
        result = controllerDynamicServiceBridge.findDomainByThreeColumn(
            domainName,
            "id", id, ConstantsDynamic.TYPE_OF_STRING,
            "uuid", uuid, ConstantsDynamic.TYPE_OF_STRING,
            "state", "signup", ConstantsDynamic.TYPE_OF_STRING
        );

        if( ((Integer)result.get(ConstantsDynamic.TAG_RESULT)).equals(ConstantsDynamic.RESULT_SUCCESS) ) {
            // 이미 가입된 계정이 존재
            log.warn("이미 가입된 계정: {}", id);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_ALEADY_EXIST);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_ALEADY_EXIST_MESSAGE+" id-->"+id);
        } else {
//            // 2. stateCode='withdraw'인 계정이 있는지 확인 (탈퇴한 계정)
//            result = controllerDynamicServiceBridge.findDomainByThreeColumn(
//                domainName,
//                "id", id, ConstantsDynamic.TYPE_OF_STRING,
//                "uuid", uuid, ConstantsDynamic.TYPE_OF_STRING
////                "state", "withdraw", ConstantsDynamic.TYPE_OF_STRING
//            );
//
//            if( ((Integer)result.get(ConstantsDynamic.TAG_RESULT)).equals(ConstantsDynamic.RESULT_SUCCESS) ) {
//                // 탈퇴한 계정 재활성화
//                log.info("탈퇴한 계정 재가입: {}", id);
//                ObjectMapper mapper = new ObjectMapper();
//                ObjectNode objectNode = mapper.createObjectNode();
//                objectNode.put("password", Crypto.getMemberPassword(requestBody.deepCopy().get("password").asText()));
//                objectNode.put("state", "signup");
//                objectNode.put("uuid", requestBody.deepCopy().get("uuid").asText());
//                result = controllerDynamicServiceBridge.updateDomainById(domainName, true, objectNode, id);
//                log.info("계정 재활성화 완료: result={}", result.get(ConstantsDynamic.TAG_RESULT));
//            } else {
                // 3. 완전히 새로운 계정 생성
//                log.info("새 계정 생성: {}", id);
                requestBody = ((ObjectNode) requestBody.deepCopy()).put("password", Crypto.getMemberPassword(requestBody.deepCopy().get("password").asText()));
                requestBody = ((ObjectNode) requestBody.deepCopy()).put("state", "signup");
                result = controllerDynamicServiceBridge.saveDomain(domainName, true, requestBody);
//                log.info("계정 생성 완료: result={}", result.get(ConstantsDynamic.TAG_RESULT));
//            }
        }

        return ResponseEntity.ok(result);
    }

    @CrossOrigin(origins="*", allowedHeaders="*")
    @PostMapping("/note/v1/members/login/web")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> postLoginWeb(@RequestBody JsonNode requestBody) {
        String servicePackage = "com.litten.note.";
        String serviceClassName = "NoteMemberService";
        String method = "post";
        String serviceMethodName = "postLogin";
        Boolean isMobile = false;
        Map<String, Object> result = controllerDynamicServiceBridge.processCustomDynamicServiceMethod(servicePackage, serviceClassName, method, serviceMethodName, requestBody, isMobile);
        return ResponseEntity.ok(result);
    }

    @CrossOrigin(origins="*", allowedHeaders="*")
    @PostMapping("/note/v1/members/login/mobile")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> postLoginMobile(@RequestBody JsonNode requestBody) {
        String servicePackage = "com.litten.note.";
        String serviceClassName = "NoteMemberService";
        String method = "post";
        String serviceMethodName = "postLogin";
        Boolean isMobile = true;
        Map<String, Object> result = controllerDynamicServiceBridge.processCustomDynamicServiceMethod(servicePackage, serviceClassName, method, serviceMethodName, requestBody, isMobile);
        return ResponseEntity.ok(result);
    }

    @CrossOrigin(origins="*", allowedHeaders="*")
    @PutMapping("/note/v1/members/password")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> postChangePassword(@RequestBody JsonNode requestBody) {
        String servicePackage = "com.litten.note.";
        String serviceClassName = "NoteMemberService";
        String method = "put";
        String serviceMethodName = "putChangePassword";
        Map<String, Object> result = controllerDynamicServiceBridge.processCustomDynamicServiceMethod(servicePackage, serviceClassName, method, serviceMethodName, requestBody);
        return ResponseEntity.ok(result);
    }

    /**
     * PUT /note/v1/members/plan/by-id
     * id(가입 이메일) 기반 구독 플랜 변경 — 비인증(로그아웃 상태에서도 호출 가능).
     * Request Body: { "id": "...", "subscriptionPlan": "free|standard|premium", "planExpiredAt": "..."(선택) }
     */
    @CrossOrigin(origins="*", allowedHeaders="*")
    @PutMapping("/note/v1/members/plan/by-id")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> updatePlanById(@RequestBody JsonNode requestBody) {
        log.info("[NoteMemberController] PUT /note/v1/members/plan/by-id 진입");
        String servicePackage = "com.litten.note.";
        String serviceClassName = "NoteMemberService";
        String method = "put";
        String serviceMethodName = "updatePlanById";
        Map<String, Object> result = controllerDynamicServiceBridge.processCustomDynamicServiceMethod(servicePackage, serviceClassName, method, serviceMethodName, requestBody);
        return ResponseEntity.ok(result);
    }

    @CrossOrigin(origins="*", allowedHeaders="*")
    @PostMapping("/note/v1/members/password-url")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> postChangePasswordUrl(@RequestBody JsonNode requestBody) {
        String servicePackage = "com.litten.note.";
        String serviceClassName = "NoteMemberService";
        String method = "post";
        String serviceMethodName = "postChangePasswordUrl";
        Map<String, Object> result = controllerDynamicServiceBridge.processCustomDynamicServiceMethod(servicePackage, serviceClassName, method, serviceMethodName, requestBody);
        return ResponseEntity.ok(result);
    }

    @CrossOrigin(origins="*", allowedHeaders="*")
    @GetMapping({"/note/v1/members","/note/v1/members/{id}"})
    @ResponseBody
    public ResponseEntity<Map<String, Object>> findNoteMember( @RequestParam(value="from", required=false) String from,
                                                              @RequestParam(value="to", required=false) String to,
                                                              @RequestParam(value="page", required=false) Integer page,
                                                              @RequestParam(value="size", required=false) Integer size,
                                                              @PathVariable(value="id", required=false) String id,
                                                              @RequestParam(value="uuid", required=false) String uuid ,
                                                              @RequestParam(value="state", required=false) String state ) {
//                                                              @RequestParam(value="name", required=false) String name) {

        String domainName = "NoteMember";
        String fieldName = "insertDateTime";
        if( from!=null )
            from = from+" 00:00:00";
        if( to!=null )
            to = to+" 23:59:59";
        String format = "yyyy-MM-dd HH:mm:ss";
        String sortColumn = "insertDateTime";
        String sortDirection = ConstantsDynamic.ORDER_DESCENDING;

        String columnName0 = "uuid";
        Object value0 = uuid;
        String type0 = ConstantsDynamic.TYPE_OF_STRING;

        String columnName1 = "id";
        Object value1 = id;
        String type1 = ConstantsDynamic.TYPE_OF_STRING;

        String columnName2 = "state";
        Object value2 = null;
        if( state!=null )
            value2 = state;
        String type2 = ConstantsDynamic.TYPE_OF_STRING;

//        String columnName3 = "nameLike";
//        Object value3 = null;
//        if( name!=null )
//            value3 = "%"+name+"%";
//        String type3 = ConstantsDynamic.TYPE_OF_STRING;

        Map<String, Object> result = new HashMap<>();
        if (from == null && to == null)
            result = controllerDynamicServiceBridge.findDomain( domainName, id,
                    columnName0, value0, type0,
                    columnName1, value1, type1,
                    columnName2, value2, type2,
                    null, null, null,
                    null, null, null,
                    null, null, null,
                    page, size, sortColumn, sortDirection);
        else
            result = controllerDynamicServiceBridge.findDomain( domainName, fieldName, from, to, format,
                    page, size, sortColumn, sortDirection,
                    id,
                    columnName0, value0, type0,
                    columnName1, value1, type1,
                    columnName2, value2, type2,
                    null, null, null,
                    null, null, null,
                    null, null, null);
        return ResponseEntity.ok(result);
    }

//    @PutMapping("/note/v1/members/{id}")
//    @ResponseBody
//    public ResponseEntity<Map<String, Object>> updateNoteMember(
//            @PathVariable(value="id", required=false) String id,
//            @RequestParam(value="is-admin", required=false) Boolean isAdmin,
//            @RequestBody JsonNode requestBody ) {
//        Map<String, Object> result = new HashMap<>();
//        if( id==null ) {
//            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR);
//            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR_MESSAGE);
//        } else {
//            String domainName = "NoteMemberDomain";
//            String columnName = "id";
//            Object value = id;
//            String type = ConstantsDynamic.TYPE_OF_STRING;
//            Boolean isCheckAllowedClassValue = true;
//            if (isAdmin != null && isAdmin)
//                isCheckAllowedClassValue = false;
//            result = controllerDynamicServiceBridge.updateDomainByOneColumn(domainName, isCheckAllowedClassValue, requestBody, columnName, value, type);
//        }
//        return ResponseEntity.ok(result);
//    }

    @CrossOrigin(origins="*", allowedHeaders="*")
    @GetMapping("/note/v1/members/me")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> getMyInfo() {
        log.debug("[NoteMemberController] GET /note/v1/members/me 진입");
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        log.info("[NoteMemberController] getMyInfo - memberId: {}", memberId);

        if (memberId == null) {
            Map<String, Object> result = new java.util.HashMap<>();
            result.put(com.litten.Constants.TAG_RESULT, com.litten.Constants.RESULT_NOT_FOUND);
            result.put(com.litten.Constants.TAG_RESULT_MESSAGE, "인증 정보가 없습니다.");
            return ResponseEntity.ok(result);
        }

        String servicePackage = "com.litten.note.";
        String serviceClassName = "NoteMemberService";
        String method = "get";
        String serviceMethodName = "getMyInfo";
        Map<String, Object> result = controllerDynamicServiceBridge.processCustomDynamicServiceMethod(servicePackage, serviceClassName, method, serviceMethodName, memberId);
        return ResponseEntity.ok(result);
    }

    /**
     * GET /note/v1/members/nickname/check?nickname=xxx
     * 닉네임(name) 사용 가능 여부 확인. 반환: { result:1, available: true/false }
     * 비인증 — 가입 화면에서도 호출 가능.
     */
    @CrossOrigin(origins="*", allowedHeaders="*")
    @GetMapping("/note/v1/members/nickname/check")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> checkNickname(@RequestParam("nickname") String nickname) {
        Map<String, Object> result = new HashMap<>();
        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_SUCCESS);
        String n = (nickname == null) ? "" : nickname.trim();
        boolean available = !n.isEmpty() && noteMemberRepository.findFirstByName(n) == null;
        result.put("available", available);
        log.info("[NoteMemberController] 닉네임 중복확인 - nickname: {}, available: {}", n, available);
        return ResponseEntity.ok(result);
    }

    /**
     * PUT /note/v1/members/nickname
     * 로그인 회원의 닉네임(name) 변경. 빈 값이면 닉네임 해제(null).
     * 중복 시 result=2(RESULT_ALEADY_EXIST). 인증 필수(JWT).
     * Request Body: { "name": "새닉네임" }
     */
    @CrossOrigin(origins="*", allowedHeaders="*")
    @PutMapping("/note/v1/members/nickname")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> updateNickname(@RequestBody JsonNode requestBody) {
        Map<String, Object> result = new HashMap<>();
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        log.info("[NoteMemberController] 닉네임 변경 - memberId: {}, body: {}", memberId, requestBody);
        if (memberId == null) {
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, "인증 정보가 없습니다.");
            return ResponseEntity.ok(result);
        }
        String nickname = (requestBody.has("name") && !requestBody.get("name").isNull())
                ? requestBody.get("name").asText().trim() : "";
        // 중복 체크 (본인은 제외)
        if (!nickname.isEmpty()) {
            NoteMember dup = noteMemberRepository.findFirstByName(nickname);
            if (dup != null && !memberId.equals(dup.getId())) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_ALEADY_EXIST);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, "이미 사용 중인 닉네임입니다.");
                return ResponseEntity.ok(result);
            }
        }
        NoteMember me = noteMemberRepository.findByIdAndState(memberId, "signup");
        if (me == null) {
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, "회원을 찾을 수 없습니다.");
            return ResponseEntity.ok(result);
        }
        me.setName(nickname.isEmpty() ? null : nickname);
        me.setUpdateDateTime(java.time.LocalDateTime.now());
        noteMemberRepository.save(me);
        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_SUCCESS);
        result.put("name", me.getName());
        log.info("[NoteMemberController] 닉네임 변경 완료 - memberId: {} -> {}", memberId, me.getName());
        return ResponseEntity.ok(result);
    }

    @CrossOrigin(origins="*", allowedHeaders="*")
    @PutMapping("/note/v1/members/plan")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> updatePlan(@RequestBody JsonNode requestBody) {
        log.debug("[NoteMemberController] PUT /note/v1/members/plan 진입");
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        log.info("[NoteMemberController] updatePlan - memberId: {}, body: {}", memberId, requestBody);

        if (memberId == null) {
            Map<String, Object> result = new java.util.HashMap<>();
            result.put(com.litten.Constants.TAG_RESULT, com.litten.Constants.RESULT_NOT_FOUND);
            result.put(com.litten.Constants.TAG_RESULT_MESSAGE, "인증 정보가 없습니다.");
            return ResponseEntity.ok(result);
        }

        String servicePackage = "com.litten.note.";
        String serviceClassName = "NoteMemberService";
        String method = "put";
        String serviceMethodName = "updatePlan";
        Map<String, Object> result = controllerDynamicServiceBridge.processCustomDynamicServiceMethod(servicePackage, serviceClassName, method, serviceMethodName, requestBody, memberId);
        return ResponseEntity.ok(result);
    }

    /**
     * POST /note/v1/members/migrate
     * 프리미엄 전환 시 무료/스탠다드 시절 디바이스 UUID → 회원 UUID 데이터 이관.
     * 로그인 필수 (JWT 토큰).
     *
     * Request Body: { "deviceUuid": "앱-디바이스-UUID" }
     * Response: { "result": 1, "migratedCount": N, "memberUuid": "회원UUID" }
     */
    @CrossOrigin(origins="*", allowedHeaders="*")
    @PostMapping("/note/v1/members/migrate")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> migrateDeviceData(@RequestBody JsonNode requestBody) {
        log.info("[NoteMemberController] POST /note/v1/members/migrate 진입");
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);

        if (memberId == null) {
            Map<String, Object> result = new java.util.HashMap<>();
            result.put(com.litten.Constants.TAG_RESULT, com.litten.Constants.RESULT_NOT_FOUND);
            result.put(com.litten.Constants.TAG_RESULT_MESSAGE, "인증 정보가 없습니다.");
            return ResponseEntity.ok(result);
        }

        String servicePackage = "com.litten.note.";
        String serviceClassName = "NoteMemberService";
        String method = "post";
        String serviceMethodName = "migrateDeviceData";
        String deviceUuid = requestBody.has("deviceUuid") ? requestBody.get("deviceUuid").asText() : null;
        Map<String, Object> result = controllerDynamicServiceBridge
                .processCustomDynamicServiceMethod(servicePackage, serviceClassName, method, serviceMethodName, deviceUuid, memberId);
        return ResponseEntity.ok(result);
    }

    /**
     * POST /note/v1/members/logout
     * 로그아웃 시 현재 기기의 디바이스 슬롯(uuid1/2/3 중 일치) 해제. JWT 필요.
     * Request Body: { "uuid": "앱-디바이스-UUID" }
     */
    @CrossOrigin(origins="*", allowedHeaders="*")
    @PostMapping("/note/v1/members/logout")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> logout(@RequestBody JsonNode requestBody) {
        log.info("[NoteMemberController] POST /note/v1/members/logout 진입");
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorizedResponse();

        String uuid = requestBody.has("uuid") ? requestBody.get("uuid").asText() : null;
        Map<String, Object> result = controllerDynamicServiceBridge
                .processCustomDynamicServiceMethod("com.litten.note.", "NoteMemberService", "post", "logout", uuid, memberId);
        return ResponseEntity.ok(result);
    }

    /**
     * GET /note/v1/members/devices
     * 현재 회원의 등록 디바이스(uuid1/2/3 슬롯) 목록 조회. 디바이스 관리 화면용. JWT 필요.
     */
    @CrossOrigin(origins="*", allowedHeaders="*")
    @GetMapping("/note/v1/members/devices")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> getDevices() {
        log.debug("[NoteMemberController] GET /note/v1/members/devices 진입");
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorizedResponse();

        Map<String, Object> result = controllerDynamicServiceBridge
                .processCustomDynamicServiceMethod("com.litten.note.", "NoteMemberService", "get", "getDevices", memberId);
        return ResponseEntity.ok(result);
    }

    /**
     * DELETE /note/v1/members/devices
     * 디바이스 관리 화면에서 특정 기기 원격 해제(슬롯 비우기). JWT 필요.
     * Request Body: { "uuid": "해제할-디바이스-UUID" }
     */
    @CrossOrigin(origins="*", allowedHeaders="*")
    @DeleteMapping("/note/v1/members/devices")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> removeDevice(@RequestBody JsonNode requestBody) {
        log.info("[NoteMemberController] DELETE /note/v1/members/devices 진입");
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorizedResponse();

        String uuid = requestBody.has("uuid") ? requestBody.get("uuid").asText() : null;
        // 슬롯 해제 로직은 logout과 동일 (특정 uuid 슬롯 비우기)
        Map<String, Object> result = controllerDynamicServiceBridge
                .processCustomDynamicServiceMethod("com.litten.note.", "NoteMemberService", "post", "logout", uuid, memberId);
        return ResponseEntity.ok(result);
    }

    private ResponseEntity<Map<String, Object>> unauthorizedResponse() {
        Map<String, Object> result = new java.util.HashMap<>();
        result.put(com.litten.Constants.TAG_RESULT, com.litten.Constants.RESULT_NOT_FOUND);
        result.put(com.litten.Constants.TAG_RESULT_MESSAGE, "인증 정보가 없습니다.");
        return ResponseEntity.ok(result);
    }

    @DeleteMapping("/note/v1/members/{id}")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> deleteNoteMember(@PathVariable(value="id", required=false) String id) {
        String servicePackage = "com.litten.note.";
        String serviceClassName = "NoteMemberService";
        String method = "delete";
        String serviceMethodName = "delete";
        Map<String, Object> result = controllerDynamicServiceBridge.processCustomDynamicServiceMethod(servicePackage, serviceClassName, method, serviceMethodName, id);
        return ResponseEntity.ok(result);
    }

//    @DeleteMapping("/note/v1/members/{member-seq}")
//    @ResponseBody
//    public ResponseEntity<Map<String, Object>> deleteNoteMember(
//            @PathVariable(value="target-id", required=true) Integer memberSeq ) {
//        String domainName = "NoteMemberDomain";
//        String columnName1 = "member-seq";
//        Object value1 = memberSeq;
//        String type1 = ConstantsDynamic.TYPE_OF_INTEGER;
//        Map<String, Object> result = new HashMap<>();
//        if (value1 != null) {
//            result = controllerDynamicServiceBridge.deleteDomainByOneColumn(domainName, columnName1, value1, type1);
//        } else {
//            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR);
//            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR_MESSAGE);
//        }
//        return ResponseEntity.ok(result);
//    }

//    @DeleteMapping("/note/v1/members")
//    @ResponseBody
//    public ResponseEntity<Map<String, Object>> deleteNoteMember( @RequestBody(required=true) JsonNode requestBody ) {
//        Map<String, Object> result = new HashMap<>();
//        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_SUCCESS);
//        if (requestBody == null) {
//            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR);
//            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR_MESSAGE);
//        } else {
//            JsonNode jsonNode = requestBody.get(ConstantsDynamic.TAG_IDS);
//            if (jsonNode == null) {
//                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
//                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NOT_FOUND_MESSAGE + "ids array");
//            } else {
//                String domainName = "NoteMemberDomain";
//                result = controllerDynamicServiceBridge.deleteDomain(domainName, requestBody);
//            }
//        }
//        return ResponseEntity.ok(result);
//    }

}

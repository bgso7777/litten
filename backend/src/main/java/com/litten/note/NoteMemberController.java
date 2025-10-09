package com.litten.note;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.litten.common.dynamic.ConstantsDynamic;
import com.litten.common.dynamic.ControllerDynamicServiceBridge;
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

        log.info("회원가입 대상 ID: {}", id);

        // 1. stateCode='signup'인 계정이 있는지 확인
        result = controllerDynamicServiceBridge.findDomainByTwoColumn(
            domainName,
            "id", id, ConstantsDynamic.TYPE_OF_STRING,
            "state-code", "signup", ConstantsDynamic.TYPE_OF_STRING
        );

        if( ((Integer)result.get(ConstantsDynamic.TAG_RESULT)).equals(ConstantsDynamic.RESULT_SUCCESS) ) {
            // 이미 가입된 계정이 존재
            log.warn("이미 가입된 계정: {}", id);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_ALEADY_EXIST);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_ALEADY_EXIST_MESSAGE+" id-->"+id);
        } else {
            // 2. stateCode='withdraw'인 계정이 있는지 확인 (탈퇴한 계정)
            result = controllerDynamicServiceBridge.findDomainByTwoColumn(
                domainName,
                "id", id, ConstantsDynamic.TYPE_OF_STRING,
                "state-code", "withdraw", ConstantsDynamic.TYPE_OF_STRING
            );

            if( ((Integer)result.get(ConstantsDynamic.TAG_RESULT)).equals(ConstantsDynamic.RESULT_SUCCESS) ) {
                // 탈퇴한 계정 재활성화
                log.info("탈퇴한 계정 재가입: {}", id);
                ObjectMapper mapper = new ObjectMapper();
                ObjectNode objectNode = mapper.createObjectNode();
                objectNode.put("password", Crypto.getMemberPassword(requestBody.deepCopy().get("password").asText()));
                objectNode.put("stateCode", "signup");
                objectNode.put("uuid", requestBody.deepCopy().get("uuid").asText());

                result = controllerDynamicServiceBridge.updateDomainById(domainName, true, objectNode, id);
                log.info("계정 재활성화 완료: result={}", result.get(ConstantsDynamic.TAG_RESULT));
            } else {
                // 3. 완전히 새로운 계정 생성
                log.info("새 계정 생성: {}", id);
                requestBody = ((ObjectNode) requestBody.deepCopy()).put("password", Crypto.getMemberPassword(requestBody.deepCopy().get("password").asText()));
                requestBody = ((ObjectNode) requestBody.deepCopy()).put("stateCode", "signup");
                result = controllerDynamicServiceBridge.saveDomain(domainName, true, requestBody);
                log.info("계정 생성 완료: result={}", result.get(ConstantsDynamic.TAG_RESULT));
            }
        }

        log.info("회원가입 응답: result={}, message={}",
            result.get(ConstantsDynamic.TAG_RESULT),
            result.get(ConstantsDynamic.TAG_RESULT_MESSAGE));

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
    @PostMapping("/note/v1/members/password")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> postChangePassword(@RequestBody JsonNode requestBody) {
        String servicePackage = "com.litten.note.";
        String serviceClassName = "NoteMemberService";
        String method = "put";
        String serviceMethodName = "putChangePassword";
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

//    @CrossOrigin(origins="*", allowedHeaders="*")
//    @GetMapping({"/note/v1/members","/note/v1/members/{id}"})
//    @ResponseBody
//    public ResponseEntity<Map<String, Object>> findNoteMember( @RequestParam(value="from", required=false) String from,
//                                                              @RequestParam(value="to", required=false) String to,
//                                                              @RequestParam(value="page", required=false) Integer page,
//                                                              @RequestParam(value="size", required=false) Integer size,
//                                                              @PathVariable(value="id", required=false) String id,
//                                                              @RequestParam(value="company-seq", required=false) Integer companySeq,
//                                                              @RequestParam(value="type", required=false) String type,
//                                                              @RequestParam(value="name", required=false) String name) {
//
//        if( companySeq==null || (companySeq!=null && companySeq.equals("") && companySeq.equals("null")) )
//            companySeq = null;
//        if( id==null || (id!=null && id.equals("") && id.equals("null")) )
//            id = null;
//        if( type==null || (type!=null && type.equals("") && type.equals("null")) )
//            type = null;
//
//        String domainName = "NoteMemberDomain";
//        String fieldName = "insertDateTime";
//        if( from!=null )
//            from = from+" 00:00:00";
//        if( to!=null )
//            to = to+" 23:59:59";
//        String format = "yyyy-MM-dd HH:mm:ss";
//        String sortColumn = "insertDateTime";
//        String sortDirection = ConstantsDynamic.ORDER_DESCENDING;
//
//        String columnName0 = "companySeq";
//        Object value0 = companySeq;
//        String type0 = ConstantsDynamic.TYPE_OF_INTEGER;
//
//        String columnName1 = "id";
//        Object value1 = id;
//        String type1 = ConstantsDynamic.TYPE_OF_STRING;
//
//        String columnName2 = "type";
//        Object value2 = null;
//        if( type!=null )
//            value2 = type;
//        String type2 = ConstantsDynamic.TYPE_OF_STRING;
//
//        String columnName3 = "nameLike";
//        Object value3 = null;
//        if( name!=null )
//            value3 = "%"+name+"%";
//        String type3 = ConstantsDynamic.TYPE_OF_STRING;
//
//        Map<String, Object> result = new HashMap<>();
//        if (from == null && to == null)
//            result = controllerDynamicServiceBridge.findDomain( domainName, id,
//                    columnName0, value0, type0,
//                    columnName1, value1, type1,
//                    columnName2, value2, type2,
//                    columnName3, value3, type3,
//                    null, null, null,
//                    null, null, null,
//                    page, size, sortColumn, sortDirection);
//        else
//            result = controllerDynamicServiceBridge.findDomain( domainName, fieldName, from, to, format,
//                    page, size, sortColumn, sortDirection,
//                    id,
//                    columnName0, value0, type0,
//                    columnName1, value1, type1,
//                    columnName2, value2, type2,
//                    columnName3, value3, type3,
//                    null, null, null,
//                    null, null, null);
//        return ResponseEntity.ok(result);
//    }

    @PutMapping("/note/v1/members/{id}")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> updateNoteMember(
            @PathVariable(value="id", required=false) String id,
            @RequestParam(value="is-admin", required=false) Boolean isAdmin,
            @RequestBody JsonNode requestBody ) {
        Map<String, Object> result = new HashMap<>();
        if( id==null ) {
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR_MESSAGE);
        } else {
            String domainName = "NoteMemberDomain";
            String columnName = "id";
            Object value = id;
            String type = ConstantsDynamic.TYPE_OF_STRING;
            Boolean isCheckAllowedClassValue = true;
            if (isAdmin != null && isAdmin)
                isCheckAllowedClassValue = false;
            result = controllerDynamicServiceBridge.updateDomainByOneColumn(domainName, isCheckAllowedClassValue, requestBody, columnName, value, type);
        }
        return ResponseEntity.ok(result);
    }

    @CrossOrigin(origins="*", allowedHeaders="*")
    @PostMapping("/note/v1/members/find-by-uuid")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> findMemberByUuid(@RequestBody JsonNode requestBody) {
        log.info("UUID로 계정 조회 요청: {}", requestBody);

        String domainName = "NoteMember";
        Map<String, Object> result = new HashMap<>();
        String uuid = requestBody.get("uuid").asText();

        log.info("조회 대상 UUID: {}", uuid);

        // UUID로 계정 조회 (id 컬럼이 uuid)
        result = controllerDynamicServiceBridge.findDomainById(domainName, uuid);

        if (((Integer)result.get(ConstantsDynamic.TAG_RESULT)).equals(ConstantsDynamic.RESULT_SUCCESS)) {
            log.info("UUID로 계정 조회 성공: {}", uuid);
        } else {
            log.info("UUID로 계정 조회 실패 (계정 없음): {}", uuid);
        }

        return ResponseEntity.ok(result);
    }

    @DeleteMapping("/note/v1/members/signup")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> deleteNoteMember(@RequestBody JsonNode requestBody) {
        log.info("회원탈퇴 요청: {}", requestBody);

        String domainName = "NoteMember";
        Map<String, Object> result = new HashMap<>();
        String id = requestBody.get("id").asText();

        log.info("회원탈퇴 대상 ID: {}", id);

        result = controllerDynamicServiceBridge.findDomainByTwoColumn(
            domainName,
            "id", id, ConstantsDynamic.TYPE_OF_STRING,
            "state-code", "signup", ConstantsDynamic.TYPE_OF_STRING
        );

        log.info("사용자 조회 결과: result={}", result.get(ConstantsDynamic.TAG_RESULT));

        if( ((Integer)result.get(ConstantsDynamic.TAG_RESULT)).equals(ConstantsDynamic.RESULT_SUCCESS) ) {
            // 사용자를 찾았으면 탈퇴 처리
            log.info("사용자 찾음. 탈퇴 처리 시작");
            ObjectMapper mapper = new ObjectMapper();
            ObjectNode objectNode = mapper.createObjectNode();
            objectNode.put("stateCode", "withdraw");
            result = controllerDynamicServiceBridge.updateDomainById(domainName, true, objectNode, id);
            log.info("탈퇴 처리 완료: result={}", result.get(ConstantsDynamic.TAG_RESULT));
        } else if( ((Integer)result.get(ConstantsDynamic.TAG_RESULT)).equals(ConstantsDynamic.RESULT_NOT_FOUND) ) {
            // 사용자를 못 찾았으면 에러 반환
            log.warn("사용자를 찾을 수 없음: {}", id);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NOT_FOUND_MESSAGE + " id: " + id);
        }

        log.info("회원탈퇴 응답: result={}, message={}",
            result.get(ConstantsDynamic.TAG_RESULT),
            result.get(ConstantsDynamic.TAG_RESULT_MESSAGE));

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

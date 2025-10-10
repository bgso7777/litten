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
        String uuid = requestBody.deepCopy().get("uuid").asText();

        log.info("회원가입 대상 ID: {}", id);

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

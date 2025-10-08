package com.litten.common.dynamic;

import com.fasterxml.jackson.databind.JsonNode;
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
public class SampleDynamicController {

    @Autowired
    ControllerDynamicServiceBridge controllerDynamicServiceBridge;

    // other
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // 조회
    @GetMapping("/sample/dynamic/{domainName}/{id}")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> findAllDomain(@PathVariable("domainName") String domainName,
                                                             @PathVariable("id") String id ) {
        Map<String, Object> result = controllerDynamicServiceBridge.findDomainById(domainName,id);
        return ResponseEntity.ok(result);
    }

    // 조회 전체
//    @CrossOrigin(origins="*", allowedHeaders="*")
    @GetMapping("/sample/dynamic/{domainName}/find-all")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> findAllDomain(@PathVariable("domainName") String domainName ) {
        Map<String, Object> result = controllerDynamicServiceBridge.findAllDomain(domainName);
        return ResponseEntity.ok(result);
    }

    // 조회 전체 페이징
    @CrossOrigin(origins="*", allowedHeaders="*")
    @GetMapping("/sample/dynamic/{domainName}/find-all2")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> findAllDomain(
            @PathVariable("domainName") String domainName,
            @RequestParam("page") int page,
            @RequestParam("size") int size,
            @RequestParam("column") String column,
            @RequestParam("order") String order ) {
        Map<String, Object> result = controllerDynamicServiceBridge.findAllDomain(domainName,page,size,column,order);
        return ResponseEntity.ok(result);
    }

    // 조회 ID
    @CrossOrigin(origins="*", allowedHeaders="*")
    @GetMapping("/sample/dynamic/{domainName}/find-by-id/{id}")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> findDomainById(
            @PathVariable("domainName") String domainName,
            @PathVariable("id") String id ) {
        Map<String, Object> result = controllerDynamicServiceBridge.findDomainById(domainName,id);
        return ResponseEntity.ok(result);
    }

    // 조회 필드명1
//    @CrossOrigin(origins="*", allowedHeaders="*")
    @GetMapping("/sample/dynamic/{domainName}/find-by-one-column")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> findDomainByOneColumn(
            @PathVariable("domainName") String domainName,
            @RequestParam("name") String name,
            @RequestParam("value") Object value,
            @RequestParam("type") String type ) {
        Map<String, Object> result = controllerDynamicServiceBridge.findDomainByOneColumn(domainName,name,value,type);
        return ResponseEntity.ok(result);
    }

    // 조회 필드명1
    @CrossOrigin(origins="*", allowedHeaders="*")
    @GetMapping("/sample/dynamic/{domainName}/find-by-one-column-between")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> findDomainByOneColumnBetween(
            @PathVariable("domainName") String domainName,
            @RequestParam("name") String name,
            @RequestParam("from") String from,
            @RequestParam("to") String to,
            @RequestParam("type") String type ) {
        Map<String, Object> result = controllerDynamicServiceBridge.findDomainByOneColumnBetween(domainName,name,from,to,type);
        return ResponseEntity.ok(result);
    }

    // 조회 필드명2 and
//    @CrossOrigin(origins="*", allowedHeaders="*")
    @GetMapping("/sample/dynamic/{domainName}/find-by-two-column")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> findDomainByTwoColumn(
            @PathVariable("domainName") String domainName,
            @RequestParam("name1") String name1,
            @RequestParam("value1") Object value1,
            @RequestParam("type1") String type1,
            @RequestParam("name2") String name2,
            @RequestParam("value2") Object value2,
            @RequestParam("type2") String type2 ) {
        Map<String, Object> result = controllerDynamicServiceBridge.findDomainByTwoColumn(domainName,name1,value1,type1,name2,value2,type2);
        return ResponseEntity.ok(result);
    }

    // 조회 필드명3 and
//    @CrossOrigin(origins="*", allowedHeaders="*")
    @GetMapping("/sample/dynamic/{domainName}/find-by-three-column")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> findDomainByTwoColumn(
            @PathVariable("domainName") String domainName,
            @RequestParam("name1") String name1,
            @RequestParam("value1") Object value1,
            @RequestParam("type1") String type1,
            @RequestParam("name2") String name2,
            @RequestParam("value2") Object value2,
            @RequestParam("type2") String type2,
            @RequestParam("name3") String name3,
            @RequestParam("value3") Object value3,
            @RequestParam("type3") String type3 ) {
        Map<String, Object> result = controllerDynamicServiceBridge.findDomainByThreeColumn(domainName,name1,value1,type1,name2,value2,type2,name3,value3,type3);
        return ResponseEntity.ok(result);
    }

    // 조회 필드명2
    @CrossOrigin(origins="*", allowedHeaders="*")
    @GetMapping("/sample/dynamic/{domainName}/find-by-one-column-and-one-column-between")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> findDomainByOneColumnAndOneColumnBetween(
            @PathVariable("domainName") String domainName,
            @RequestParam("name1") String name1,
            @RequestParam("value1") Object value1,
            @RequestParam("type1") String type1,
            @RequestParam("name2") String name2,
            @RequestParam("from2") String from2,
            @RequestParam("to2") String to2,
            @RequestParam("type2") String type2 ) {
        Map<String, Object> result = controllerDynamicServiceBridge.findDomainByOneColumnAndOneColumnBetween(domainName,name1,value1,type1,name2,from2,to2,type2);
        return ResponseEntity.ok(result);
    }

    // 저장
    @CrossOrigin(origins="*", allowedHeaders="*")
    @PostMapping("/sample/dynamic/{domainName}")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> saveDomain(
            @PathVariable("domainName") String domainName,
            @RequestBody JsonNode requestBody ) {
        Boolean isCheckAllowedClassValue = false;
        Map<String, Object> result = controllerDynamicServiceBridge.saveDomain(domainName,isCheckAllowedClassValue,requestBody);
        return ResponseEntity.ok(result);
    }

    @CrossOrigin(origins="*", allowedHeaders="*")
    @PutMapping("/sample/dynamic/{domainName}/{value}")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> updateDomain(
            @PathVariable("domainName") String domainName,
            @PathVariable("value") Object id,
            @RequestBody JsonNode requestBody ) {
        Boolean isCheckAllowedClassValue = false;
        Map<String, Object> result = controllerDynamicServiceBridge.updateDomainById(domainName,isCheckAllowedClassValue,requestBody,id);
        return ResponseEntity.ok(result);
    }

//    @CrossOrigin(origins="*", allowedHeaders="*")
//    @PutMapping("/sample/dynamic/{domainName}")
//    @ResponseBody
//    public ResponseEntity<Map<String, Object>> updateDomain(
//            @PathVariable("domainName") String domainName,
//            @RequestParam("field") String field,
//            @RequestParam("value") Object value,
//            @RequestParam("type") String type,
//            @RequestParam("where-field") String whereField,
//            @RequestParam("where-value") Object whereValue,
//            @RequestParam("where-type") String whereType) {
//        Boolean isCheckAllowedClassValue = false;
//        Map<String, Object> result = controllerDynamicServiceBridge.updateDomain(domainName,isCheckAllowedClassValue,field,value,type,whereField,whereValue,whereType);
//        return ResponseEntity.ok(result);
//    }

    // 삭제
    @CrossOrigin(origins="*", allowedHeaders="*")
    @DeleteMapping("/sample/dynamic/{domainName}/{value}")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> deleteDomain(
            @PathVariable("domainName") String domainName,
            @PathVariable("value") Object value) {
        Map<String, Object> result = controllerDynamicServiceBridge.deleteDomain(domainName,value);
        return ResponseEntity.ok(result);
    }

    // 삭제
    @CrossOrigin(origins="*", allowedHeaders="*")
    @DeleteMapping("/sample/dynamic/{domainName}")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> deleteDomain(
            @PathVariable("domainName") String domainName,
            @RequestParam("field") String field,
            @RequestParam("value") Object value,
            @RequestParam("type") String type) {
        Map<String, Object> result = controllerDynamicServiceBridge.deleteDomainByOneColumn(domainName,field,value,type);
        return ResponseEntity.ok(result);
    }


    // used SampleMember
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    @CrossOrigin(origins="*", allowedHeaders="*")
    @PostMapping("/sample/v1/sample-members")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> saveScenario(
            @RequestParam(value="is-admin", required=false) Boolean isAdmin,
            @RequestBody JsonNode requestBody ) {
        String domainName = "SampleMember";
        Boolean isCheckAllowedClassValue = true;
        if( isAdmin!=null && isAdmin )
            isCheckAllowedClassValue = false;
        Map<String, Object> result = controllerDynamicServiceBridge.saveDomain(domainName,isCheckAllowedClassValue,requestBody);
        return ResponseEntity.ok(result);
    }

    @CrossOrigin(origins="*", allowedHeaders="*")
    @GetMapping({"/sample/v1/sample-members","/sample/v1/sample-members/{member-seq}"})
    @ResponseBody
    public ResponseEntity<Map<String, Object>> findScenarios( @RequestParam(value="from", required=false) String from,
                                                              @RequestParam(value="to", required=false) String to,
                                                              @RequestParam(value="page", required=false) Integer page,
                                                              @RequestParam(value="size", required=false) Integer size,
                                                              @PathVariable(value="member-seq", required=false) Integer memberSeq,
                                                              @RequestParam(value="company-seq", required=false) Integer companySeq,
                                                              @RequestParam(value="type", required=false) String type,
                                                              @RequestParam(value="name", required=false) String name) {

        if( companySeq==null || (companySeq!=null && companySeq.equals("") && companySeq.equals("null")) )
            companySeq = null;
        if( memberSeq==null || (memberSeq!=null && memberSeq.equals("") && memberSeq.equals("null")) )
            memberSeq = null;
        if( type==null || (type!=null && type.equals("") && type.equals("null")) )
            type = null;

        String domainName = "SampleMember";
        String fieldName = "insertDateTime";
        if( from!=null )
            from = from+" 00:00:00";
        if( to!=null )
            to = to+" 23:59:59";
        String format = "yyyy-MM-dd HH:mm:ss";
        String sortColumn = "insertDateTime";
        String sortDirection = ConstantsDynamic.ORDER_DESCENDING;

        String columnName0 = "companySeq";
        Object value0 = companySeq;
        String type0 = ConstantsDynamic.TYPE_OF_INTEGER;

        String columnName1 = "memberSeq";
        Object value1 = memberSeq;
        String type1 = ConstantsDynamic.TYPE_OF_INTEGER;

        String columnName2 = "type";
        Object value2 = null;
        if( type!=null )
            value2 = type;
        String type2 = ConstantsDynamic.TYPE_OF_STRING;

        String columnName3 = "nameLike";
        Object value3 = null;
        if( name!=null )
            value3 = "%"+name+"%";
        String type3 = ConstantsDynamic.TYPE_OF_STRING;

        Map<String, Object> result = new HashMap<>();
        if (from == null && to == null)
            result = controllerDynamicServiceBridge.findDomain( domainName, memberSeq,
                    columnName0, value0, type0,
                    columnName1, value1, type1,
                    columnName2, value2, type2,
                    columnName3, value3, type3,
                    null, null, null,
                    null, null, null,
                    page, size, sortColumn, sortDirection);
        else
            result = controllerDynamicServiceBridge.findDomain( domainName, fieldName, from, to, format,
                    page, size, sortColumn, sortDirection,
                    memberSeq,
                    columnName0, value0, type0,
                    columnName1, value1, type1,
                    columnName2, value2, type2,
                    columnName3, value3, type3,
                    null, null, null,
                    null, null, null);
        return ResponseEntity.ok(result);
    }

    @PutMapping("/sample/v1/sample-members/{member-seq}")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> updateScenarios(
            @PathVariable(value="member-seq", required=false) Integer memberSeq,
            @RequestParam(value="is-admin", required=false) Boolean isAdmin,
            @RequestBody JsonNode requestBody ) {
        Map<String, Object> result = new HashMap<>();
        if( memberSeq==null ) {
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR_MESSAGE);
        } else {
            String domainName = "SampleMember";
            String columnName = "memberSeq";
            Object value = memberSeq;
            String type = ConstantsDynamic.TYPE_OF_INTEGER;
            Boolean isCheckAllowedClassValue = true;
            if (isAdmin != null && isAdmin)
                isCheckAllowedClassValue = false;
            result = controllerDynamicServiceBridge.updateDomainByOneColumn(domainName, isCheckAllowedClassValue, requestBody, columnName, value, type);
        }
        return ResponseEntity.ok(result);
    }

    @DeleteMapping("/sample/v1/sample-members/{memberSeq}")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> deleteScenario(
            @PathVariable(value="scenario-id", required=true) Integer memberSeq ) {
        Map<String, Object> result = new HashMap<>();
        if( memberSeq==null ) {
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR_MESSAGE);
        } else {
            String domainName = "SampleMember";
            String columnName1 = "memberSeq";
            Object value1 = memberSeq;
            String type1 = ConstantsDynamic.TYPE_OF_INTEGER;
            if (value1 != null) {
                result = controllerDynamicServiceBridge.deleteDomainByOneColumn(domainName, columnName1, value1, type1);
            } else {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR_MESSAGE);
            }
        }
        return ResponseEntity.ok(result);
    }

    @DeleteMapping("/sample/v1/sample-members/{member-seq}")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> deleteTarget(
            @PathVariable(value="target-id", required=true) Integer memberSeq ) {
        String domainName = "SampleMember";
        String columnName1 = "member-seq";
        Object value1 = memberSeq;
        String type1 = ConstantsDynamic.TYPE_OF_INTEGER;
        Map<String, Object> result = new HashMap<>();
        if (value1 != null) {
            result = controllerDynamicServiceBridge.deleteDomainByOneColumn(domainName, columnName1, value1, type1);
        } else {
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR_MESSAGE);
        }
        return ResponseEntity.ok(result);
    }

    @DeleteMapping("/sample/v1/sample-members")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> deleteScenario( @RequestBody(required=true) JsonNode requestBody ) {
        Map<String, Object> result = new HashMap<>();
        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_SUCCESS);
        if (requestBody == null) {
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR_MESSAGE);
        } else {
            JsonNode jsonNode = requestBody.get(ConstantsDynamic.TAG_IDS);
            if (jsonNode == null) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NOT_FOUND_MESSAGE + "ids array");
            } else {
                String domainName = "SampleMember";
                result = controllerDynamicServiceBridge.deleteDomain(domainName, requestBody);
            }
        }
        return ResponseEntity.ok(result);
    }

}

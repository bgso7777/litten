package com.litten.common.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.litten.common.dynamic.ConstantsDynamic;
import com.litten.common.dynamic.ControllerDynamicServiceBridge;
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
public class MemberController {

    @Autowired
    ControllerDynamicServiceBridge controllerDynamicServiceBridge;

    @CrossOrigin(origins="*", allowedHeaders="*")
    @PostMapping("/sample/v1/members")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> saveSampleMember(
            @RequestParam(value="is-admin", required=false) Boolean isAdmin,
            @RequestBody JsonNode requestBody ) {
        String domainName = "SampleMemberDomain";
        Boolean isCheckAllowedClassValue = true;
        if( isAdmin!=null && isAdmin )
            isCheckAllowedClassValue = false;
        Map<String, Object> result = controllerDynamicServiceBridge.saveDomain(domainName,isCheckAllowedClassValue,requestBody);
        return ResponseEntity.ok(result);
    }

    @CrossOrigin(origins="*", allowedHeaders="*")
    @GetMapping({"/sample/v1/members","/sample/v1/members/{member-seq}"})
    @ResponseBody
    public ResponseEntity<Map<String, Object>> findSampleMembers( @RequestParam(value="from", required=false) String from,
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

        String domainName = "SampleMemberDomain";
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

    @PutMapping("/sample/v1/members/{member-seq}")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> updateSampleMembers(
            @PathVariable(value="member-seq", required=false) Integer memberSeq,
            @RequestParam(value="is-admin", required=false) Boolean isAdmin,
            @RequestBody JsonNode requestBody ) {
        Map<String, Object> result = new HashMap<>();
        if( memberSeq==null ) {
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR_MESSAGE);
        } else {
            String domainName = "SampleMemberDomain";
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

    @DeleteMapping("/sample/v1/members/{memberSeq}")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> deleteSampleMember(
            @PathVariable(value="scenario-id", required=true) Integer memberSeq ) {
        Map<String, Object> result = new HashMap<>();
        if( memberSeq==null ) {
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR_MESSAGE);
        } else {
            String domainName = "SampleMemberDomain";
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

    @DeleteMapping("/sample/v1/members/{member-seq}")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> deleteSampleMembers(
            @PathVariable(value="target-id", required=true) Integer memberSeq ) {
        String domainName = "SampleMemberDomain";
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

    @DeleteMapping("/sample/v1/members")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> deleteSampleMember( @RequestBody(required=true) JsonNode requestBody ) {
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
                String domainName = "SampleMemberDomain";
                result = controllerDynamicServiceBridge.deleteDomain(domainName, requestBody);
            }
        }
        return ResponseEntity.ok(result);
    }

}

package com.litten.common.dynamic;

import com.fasterxml.jackson.databind.JsonNode;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.util.MultiValueMap;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

@Slf4j
@RestController
@RequiredArgsConstructor
@RequestMapping("/litten")
public class DynamicController {

    @Autowired
    ControllerDynamicServiceBridge controllerDynamicServiceBridge;

    @CrossOrigin(origins="*", allowedHeaders="*")
    @PostMapping({"/v1/{domain-name}"})
    @ResponseBody
    public ResponseEntity<ResponseVo> saveDynamicDomain( @PathVariable("domain-name") String pathDomainName,
                                                         @RequestParam(value="is-admin", required=false) Boolean isAdmin,
                                                         @RequestBody JsonNode requestBody ) {
        Boolean isCheckAllowedClassValue = true;
        if( isAdmin!=null && isAdmin )
            isCheckAllowedClassValue = false;
        Map<String, Object> result = controllerDynamicServiceBridge.saveDomain(StringUtil.getPathNameToDomainName(pathDomainName),isCheckAllowedClassValue,requestBody);
        ResponseVo response = null;
        if ((Integer)result.get(ConstantsDynamic.TAG_RESULT)==ConstantsDynamic.RESULT_SUCCESS) {
            response = new ResponseVo(200, result);
        } else {
            String responseMessage = "";
            if( result.get(ConstantsDynamic.TAG_RESULT_MESSAGE)!=null )
                responseMessage = (String)result.get(ConstantsDynamic.TAG_RESULT_MESSAGE);
            if( result.get(ConstantsDynamic.TAG_RESULT_MESSAGE2)!=null )
                responseMessage = responseMessage +" " + (String)result.get(ConstantsDynamic.TAG_RESULT_MESSAGE2);
            ResponseVo errorResponse = new ResponseVo((Integer)result.get(ConstantsDynamic.TAG_RESULT), responseMessage);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
        return ResponseEntity.ok(response);
    }

    @CrossOrigin(origins="*", allowedHeaders="*")
    @GetMapping({"/v1/{domain-name}","/v1/{domain-name}/{id}"})
    @ResponseBody
    public ResponseEntity<ResponseVo> findDynamicDomain( @PathVariable("domain-name") String pathDomainName,
                                                         @RequestParam(value="from", required=false) String from,
                                                         @RequestParam(value="to", required=false) String to,
                                                         @RequestParam(value="page", required=false) Integer page,
                                                         @RequestParam(value="size", required=false) Integer size,
                                                         @PathVariable(value="id", required=false) Object id,
                                                         @RequestParam(required=false) MultiValueMap<String, Object> params) {
        String fieldName = "insertDateTime";
        if( from!=null )
            from = from+" 00:00:00";
        if( to!=null )
            to = to+" 23:59:59";
        String format = "yyyy-MM-dd HH:mm:ss";
        String sortColumn = "insertDateTime";
        String sortDirection = ConstantsDynamic.ORDER_DESCENDING;

        String columnName0 = "";
        Object value0 = null;
        String type0 = ConstantsDynamic.TYPE_OF_LONG;

        String columnName1 = "";
        Object value1 = null;
        String type1 = ConstantsDynamic.TYPE_OF_LONG;

        String columnName2 = "";
        Object value2 = null;
        String type2 = ConstantsDynamic.TYPE_OF_LONG;

        String columnName3 = "";
        Object value3 = null;
        String type3 = ConstantsDynamic.TYPE_OF_LONG;

        if( id==null ) {
            int i = 0;
            for (String key : params.keySet()) {
                Object value = params.get(key);
                if (i==0) {
                    columnName0 = key;
                    if( value instanceof ArrayList )
                        value0 = ((ArrayList)value).get(0);
                    type0 = StringUtil.getTypeFromColumnName(value,key);
                } else if (i==1) {
                    columnName1 = key;
                    if( value instanceof ArrayList )
                        value1 = ((ArrayList)value).get(0);
                    type1 = StringUtil.getTypeFromColumnName(value,key);
                } else if (i==2) {
                    columnName2 = key;
                    if( value instanceof ArrayList )
                        value2 = ((ArrayList)value).get(0);
                    type2 = StringUtil.getTypeFromColumnName(value,key);
                }
                // TODO name에 like가 있을 경우 value "%"+name+"%";
                i++;
            }
        } else {
            columnName1 = "id";
            value1 = id;
            type1 = ConstantsDynamic.TYPE_OF_LONG;
        }

        Map<String, Object> result = new HashMap<>();
        if (from == null && to == null)
            result = controllerDynamicServiceBridge.findDomain( StringUtil.getPathNameToDomainName(pathDomainName), id,
                    columnName0, value0, type0,
                    columnName1, value1, type1,
                    columnName2, value2, type2,
                    columnName3, value3, type3,
                    null, null, null,
                    null, null, null,
                    page, size, sortColumn, sortDirection);
        else
            result = controllerDynamicServiceBridge.findDomain( StringUtil.getPathNameToDomainName(pathDomainName), fieldName, from, to, format,
                    page, size, sortColumn, sortDirection,
                    id,
                    columnName0, value0, type0,
                    columnName1, value1, type1,
                    columnName2, value2, type2,
                    columnName3, value3, type3,
                    null, null, null,
                    null, null, null);
        ResponseVo response = null;
        if ((Integer)result.get(ConstantsDynamic.TAG_RESULT)==ConstantsDynamic.RESULT_SUCCESS) {
            response = new ResponseVo(200, result);
        } else {
            String responseMessage = "";
            if( result.get(ConstantsDynamic.TAG_RESULT_MESSAGE)!=null )
                responseMessage = (String)result.get(ConstantsDynamic.TAG_RESULT_MESSAGE);
            if( result.get(ConstantsDynamic.TAG_RESULT_MESSAGE2)!=null )
                responseMessage = responseMessage +" " + (String)result.get(ConstantsDynamic.TAG_RESULT_MESSAGE2);
            ResponseVo errorResponse = new ResponseVo((Integer)result.get(ConstantsDynamic.TAG_RESULT), responseMessage);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
        return ResponseEntity.ok(response);
    }

    @PutMapping({"/v1/{domain-name}/{id}"})
    @ResponseBody
    public ResponseEntity<ResponseVo> updateDynamicDomain(  @PathVariable("domain-name") String pathDomainName,
                                                            @PathVariable(value="id", required=true) Object id,
                                                            @RequestParam(value="is-admin", required=false) Boolean isAdmin,
                                                            @RequestBody JsonNode requestBody ) {
        Map<String, Object> result = new HashMap<>();
        if( id==null ) {
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR_MESSAGE);
        } else {
            String columnName = "id";
            Object value = id;
            String type = StringUtil.getTypeFromColumnName(id,columnName);
            Boolean isCheckAllowedClassValue = true;
            if (isAdmin != null && isAdmin)
                isCheckAllowedClassValue = false;
            result = controllerDynamicServiceBridge.updateDomainByOneColumn(StringUtil.getPathNameToDomainName(pathDomainName), isCheckAllowedClassValue, requestBody, columnName, value, type);
        }
        ResponseVo response = null;
        if ((Integer)result.get(ConstantsDynamic.TAG_RESULT)==ConstantsDynamic.RESULT_SUCCESS) {
            response = new ResponseVo(200, result);
        } else {
            String responseMessage = "";
            if( result.get(ConstantsDynamic.TAG_RESULT_MESSAGE)!=null )
                responseMessage = (String)result.get(ConstantsDynamic.TAG_RESULT_MESSAGE);
            if( result.get(ConstantsDynamic.TAG_RESULT_MESSAGE2)!=null )
                responseMessage = responseMessage +" " + (String)result.get(ConstantsDynamic.TAG_RESULT_MESSAGE2);
            ResponseVo errorResponse = new ResponseVo((Integer)result.get(ConstantsDynamic.TAG_RESULT), responseMessage);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
        return ResponseEntity.ok(response);
    }

    @DeleteMapping({"/v1/{domain-name}/{id}"})
    @ResponseBody
    public ResponseEntity<ResponseVo> deleteDynamicDomain(  @PathVariable("domain-name") String pathDomainName,
                                                            @PathVariable(value="id", required=true) Object id) {
        Map<String, Object> result = new HashMap<>();
        if( id==null ) {
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR_MESSAGE);
        } else {
            String columnName1 = "id";
            Object value1 = id;
            String type1 = StringUtil.getTypeFromColumnName(id,columnName1);
            if (value1 != null) {
                result = controllerDynamicServiceBridge.deleteDomainByOneColumn(StringUtil.getPathNameToDomainName(pathDomainName), columnName1, value1, type1);
            } else {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR_MESSAGE);
            }
        }
        ResponseVo response = null;
        if ((Integer)result.get(ConstantsDynamic.TAG_RESULT)==ConstantsDynamic.RESULT_SUCCESS) {
            response = new ResponseVo(200, result);
        } else {
            String responseMessage = "";
            if( result.get(ConstantsDynamic.TAG_RESULT_MESSAGE)!=null )
                responseMessage = (String)result.get(ConstantsDynamic.TAG_RESULT_MESSAGE);
            if( result.get(ConstantsDynamic.TAG_RESULT_MESSAGE2)!=null )
                responseMessage = responseMessage +" " + (String)result.get(ConstantsDynamic.TAG_RESULT_MESSAGE2);
            ResponseVo errorResponse = new ResponseVo((Integer)result.get(ConstantsDynamic.TAG_RESULT), responseMessage);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
        return ResponseEntity.ok(response);
    }

    @DeleteMapping({"/v1/{domain-name}"})
    @ResponseBody
    public ResponseEntity<ResponseVo> deleteDynamicDomain(@PathVariable("domain-name") String pathDomainName,
                                                          @RequestBody(required=true) JsonNode requestBody ) {
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
                result = controllerDynamicServiceBridge.deleteDomain(StringUtil.getPathNameToDomainName(pathDomainName), requestBody);
            }
        }
        ResponseVo response = null;
        if ((Integer)result.get(ConstantsDynamic.TAG_RESULT)==ConstantsDynamic.RESULT_SUCCESS) {
            response = new ResponseVo(200, result);
        } else {
            String responseMessage = "";
            if( result.get(ConstantsDynamic.TAG_RESULT_MESSAGE)!=null )
                responseMessage = (String)result.get(ConstantsDynamic.TAG_RESULT_MESSAGE);
            if( result.get(ConstantsDynamic.TAG_RESULT_MESSAGE2)!=null )
                responseMessage = responseMessage +" " + (String)result.get(ConstantsDynamic.TAG_RESULT_MESSAGE2);
            ResponseVo errorResponse = new ResponseVo((Integer)result.get(ConstantsDynamic.TAG_RESULT), responseMessage);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
        return ResponseEntity.ok(response);
    }

}

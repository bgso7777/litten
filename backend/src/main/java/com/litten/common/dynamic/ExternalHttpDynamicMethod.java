package com.litten.common.dynamic;

import com.fasterxml.jackson.databind.JsonNode;

import java.util.Map;

//@Service
public interface ExternalHttpDynamicMethod {

    Map<String,Object> get(String domainName);
    Map<String,Object> get(String domainName, Object id);

    Map<String,Object> get(String domainName, String fieldName1, Object value1);

    Map<String,Object> get(String domainName, String fieldName1, Object value1, String type1);
    Map<String,Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2);
    Map<String,Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3);
    Map<String,Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, String fieldName4, Object value4, String type4);
    Map<String,Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, String fieldName4, Object value4, String type4, String fieldName5, Object value5, String type5);
    Map<String,Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, String fieldName4, Object value4, String type4, String fieldName5, Object value5, String type5, String fieldName6, Object value6, String type6);

    Map<String,Object> get(String domainName, String fieldName1, Object value1, String type1, Integer page, Integer size, String sortColumn, String sortDirection);
    Map<String,Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, Integer page, Integer size, String sortColumn, String sortDirection);
    Map<String,Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, Integer page, Integer size, String sortColumn, String sortDirection);
    Map<String,Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, String fieldName4, Object value4, String type4, Integer page, Integer size, String sortColumn, String sortDirection);
    Map<String,Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, String fieldName4, Object value4, String type4, String fieldName5, Object value5, String type5, Integer page, Integer size, String sortColumn, String sortDirection);
    Map<String,Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, String fieldName4, Object value4, String type4, String fieldName5, Object value5, String type5, String fieldName6, Object value6, String type6, Integer page, Integer size, String sortColumn, String sortDirection);

    Map<String,Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, String from2, String to2, String type2);

    Map<String,Object> get(String domainName, Integer page, Integer size, String sortColumn, String sortDirection);

    Map<String,Object> get(String domainName, String fieldName, String from, String to, String type);
    Map<String,Object> get(String domainName, String fieldName, String from, String to, String type, Integer page, Integer size, String sortColumn, String sortDirection);
    Map<String,Object> get(String domainName, String fieldName, String from, String to, String type, Integer page, Integer size, String sortColumn, String sortDirection, String fieldName1, Object value1, String type1);
    Map<String,Object> get(String domainName, String fieldName, String from, String to, String type, Integer page, Integer size, String sortColumn, String sortDirection, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2);
    Map<String,Object> get(String domainName, String fieldName, String from, String to, String type, Integer page, Integer size, String sortColumn, String sortDirection, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3);
    Map<String,Object> get(String domainName, String fieldName, String from, String to, String type, Integer page, Integer size, String sortColumn, String sortDirection, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, String fieldName4, Object value4, String type4);
    Map<String,Object> get(String domainName, String fieldName, String from, String to, String type, Integer page, Integer size, String sortColumn, String sortDirection, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, String fieldName4, Object value4, String type4, String fieldName5, Object value5, String type5);
    Map<String,Object> get(String domainName, String fieldName, String from, String to, String type, Integer page, Integer size, String sortColumn, String sortDirection, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, String fieldName4, Object value4, String type4, String fieldName5, Object value5, String type5, String fieldName6, Object value6, String type6);

    Map<String,Object> post(String domainName, Boolean isCheckAllowedClassValue, JsonNode requestBody);

    Map<String,Object> patch(String domainName, Boolean isCheckAllowedClassValue, JsonNode requestBody, Object id);
    Map<String,Object> patch(String domainName, Boolean isCheckAllowedClassValue, JsonNode requestBody, String fieldName, Object value, String type);
    Map<String,Object> patch(String domainName, Boolean isCheckAllowedClassValue, JsonNode requestBody, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2);
    Map<String,Object> patch(String domainName, Boolean isCheckAllowedClassValue, JsonNode requestBody, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3);
    Map<String,Object> patch(String domainName, Boolean isCheckAllowedClassValue, JsonNode requestBody, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, String fieldName4, Object value4, String type4);

    Map<String,Object> delete(String domainName, JsonNode requestBody);
    Map<String,Object> delete(String domainName, Object id);
    Map<String,Object> delete(String domainName, String fieldName, Object value, String type);
    Map<String,Object> delete(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2);
    Map<String,Object> delete(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3);
    Map<String,Object> delete(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, String fieldName4, Object value4, String type4);

    Map<String, Object> countBetweenAndOneColumn(String domainName, String betweenFieldName, Object from, Object to, String type, String fieldName1, Object value1, String type1);
    Map<String, Object> countBetweenAndTwoColumn(String domainName, String betweenFieldName, Object from, Object to, String type, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2);
}

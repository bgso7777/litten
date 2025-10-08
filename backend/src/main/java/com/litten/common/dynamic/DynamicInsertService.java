package com.litten.common.dynamic;

import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.exc.InvalidFormatException;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import lombok.extern.log4j.Log4j2;
import org.hibernate.exception.ConstraintViolationException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.lang.reflect.Field;
import java.lang.reflect.InvocationTargetException;
import java.util.*;

@Log4j2
@Service
@Transactional
public class DynamicInsertService extends RepositorySupport implements ExternalHttpDynamicMethod {

    @Override
    public Map<String, Object> get(String domainName, Object value) {
        return null;
    }

    @Override
    public Map<String, Object> get(String domainName) {
        return null;
    }

    @Override
    public Map<String, Object> get(String domainName, Integer page, Integer size, String sortColumn, String sortDirection) {
        return null;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName, Object value, String type) {
        return null;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName, String from, String to, String type) {
        return null;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2) {
        return null;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName, String from, String to, String type, Integer page, Integer size, String sortColumn, String sortDirection) {
        return null;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3) {
        return null;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, String fieldName4, Object value4, String type4) {
        return null;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, String fieldName4, Object value4, String type4, String fieldName5, Object value5, String type5) {
        return null;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, String fieldName4, Object value4, String type4, String fieldName5, Object value5, String type5, String fieldName6, Object value6, String type6) {
        return null;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName1, Object value1, String type1, Integer page, Integer size, String sortColumn, String sortDirection) {
        return null;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, Integer page, Integer size, String sortColumn, String sortDirection) {
        return null;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, Integer page, Integer size, String sortColumn, String sortDirection) {
        return null;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, String fieldName4, Object value4, String type4, Integer page, Integer size, String sortColumn, String sortDirection) {
        return null;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, String fieldName4, Object value4, String type4, String fieldName5, Object value5, String type5, Integer page, Integer size, String sortColumn, String sortDirection) {
        return null;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, String fieldName4, Object value4, String type4, String fieldName5, Object value5, String type5, String fieldName6, Object value6, String type6, Integer page, Integer size, String sortColumn, String sortDirection) {
        return null;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, String from2, String to2, String type2) {
        return null;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName, Object value) {
        return null;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName, String from, String to, String type, Integer page, Integer size, String sortColumn, String sortDirection, String fieldName1, Object value1, String type1) {
        return null;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName, String from, String to, String type, Integer page, Integer size, String sortColumn, String sortDirection, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2) {
        return null;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName, String from, String to, String type, Integer page, Integer size, String sortColumn, String sortDirection, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3) {
        return null;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName, String from, String to, String type, Integer page, Integer size, String sortColumn, String sortDirection, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, String fieldName4, Object value4, String type4) {
        return null;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName, String from, String to, String type, Integer page, Integer size, String sortColumn, String sortDirection, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, String fieldName4, Object value4, String type4, String fieldName5, Object value5, String type5) {
        return null;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName, String from, String to, String type, Integer page, Integer size, String sortColumn, String sortDirection, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, String fieldName4, Object value4, String type4, String fieldName5, Object value5, String type5, String fieldName6, Object value6, String type6) {
        return null;
    }

    @Transactional
    @Override
    public Map<String, Object> post(String domainName, Boolean isCheckAllowedClassValue, JsonNode requestBody) {

        log.debug("domainName -->> {}", domainName);
        log.debug("requestBody -->> {}", requestBody);

        Map<String, Object> result = new HashMap<>();
        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_SUCCESS);

        Object arrayObject = requestBody.get(domainName.substring(0, 1).toLowerCase()+domainName.substring(1)+"s");
        if( arrayObject==null )
            arrayObject = requestBody.get(domainName.substring(0, 1).toLowerCase()+domainName.substring(1)+"ies");
        Integer size = 1;
        int resultSuccessCount = 0;
        if( arrayObject==null ) {
            if( requestBody instanceof ArrayNode ) {
                result = insert(domainName, requestBody, isCheckAllowedClassValue);
            } else {
                result = insert(domainName, requestBody, isCheckAllowedClassValue);
                if ((Integer) result.get(ConstantsDynamic.TAG_RESULT) == ConstantsDynamic.RESULT_SUCCESS)
                    resultSuccessCount++;
                result.put(ConstantsDynamic.TAG_SIZE, size);
                result.put(ConstantsDynamic.TAG_RESULT_SUCCESS_COUNT, resultSuccessCount);
            }
        } else {
            ArrayNode targetListArrayNode = (ArrayNode) arrayObject;
            size = targetListArrayNode.size();
            for (JsonNode jsonNode : targetListArrayNode) {
                Map<String, Object> result1 = insert(domainName, jsonNode, isCheckAllowedClassValue);
                if ((Integer) result1.get(ConstantsDynamic.TAG_RESULT) == ConstantsDynamic.RESULT_SUCCESS) {
                    resultSuccessCount++;
                }
            }
            result.put(ConstantsDynamic.TAG_SIZE, size);
            result.put(ConstantsDynamic.TAG_RESULT_SUCCESS_COUNT, resultSuccessCount);
        }
        return result;
    }

    @Transactional
    Map<String, Object> insert(String domainName, JsonNode requestBody, boolean isCheckAllowedClassValue) {

        Map<String, Object> result = new HashMap<>();
        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_SUCCESS);

        try{
            Class c = findDomainClass(domainName);
            JpaRepository jpaRepository = findJpaRepository(domainName);
            if( c==null || jpaRepository==null ) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY);
            } else {
                try {
                    if( isCheckAllowedClassValue ) {
                        for (Iterator<String> iter = requestBody.fieldNames(); iter.hasNext(); ) {
                            String requestFieldName = iter.next();
                            Object requestFieldValue = requestBody.get(requestFieldName);
                            log.debug("requestFieldName-->" + requestFieldName + " requestFieldValue-->" + requestFieldValue);
                            for (Map.Entry<String, String> entry : ConstantsDynamic.NOT_ALLOWED_INSERT_DAO_CLASS_VALUE.entrySet()) {
                                if (c.getSimpleName().equals(entry.getKey()) && requestFieldName.equals(entry.getValue())) {
                                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_ALLOWED_INSERT_ERROR);
                                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NOT_ALLOWED_INSERT_ERROR_MESSAGE + " " + entry.getKey() + " " + entry.getValue());
                                    return result;
                                }
                            }
                        }
                    }
                    ObjectMapper objectMapper = new ObjectMapper().configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);
                    objectMapper.registerModule(new JavaTimeModule());
                    if( requestBody instanceof ArrayNode ) {
                        List<Object> objects = ObjectUtil.getList(requestBody,c);
                        for (Object object : objects )
                            initInsertValue((BaseEntity) object);
                        Object saveResultObject = null;
                        saveResultObject = executeMethod(jpaRepository, "saveAll", objects); // TODO exception 나고 있음. 원인을 모르겠음..
                        initDomainId(domainName, saveResultObject, result); // 기본 값 설정도 처리
                    } else {
                        Object object = (Object) objectMapper.treeToValue(requestBody, c);
                        initInsertValue((BaseEntity) object);
                        Object saveResultObject = executeMethod(jpaRepository, "save", object);
                        initDomainId(domainName, saveResultObject, result);
                    }
                } catch (NoSuchMethodException e) {
                    if( e.getCause()!=null )
                        result.put(ConstantsDynamic.TAG_RESULT_MESSAGE,e.getCause().getMessage());
                    log.error("DynamicInsertService post ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                } catch (ClassCastException e) {
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE,e.getCause().getMessage());
                    log.error("DynamicInsertService post ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_SUPPORT_SERVICE);
                } catch (InvocationTargetException e) {
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ExceptionMessage.getMessage(e));
                    log.error("DynamicInsertService post ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_ERROR);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_DATA_ERROR_MESSAGE + " " + ExceptionMessage.getMessage(e));
                } catch (DataIntegrityViolationException e) {
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ExceptionMessage.getMessage(e));
                    log.error("DynamicInsertService post ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_INSERT_METHOD);
                } catch (ConstraintViolationException e) {
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ExceptionMessage.getMessage(e));
                    log.error("DynamicInsertService post ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_SUPPORT_SERVICE);
                } catch (InvalidFormatException e) {
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE,e.getCause().getMessage());
                    log.error("DynamicInsertService post ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FORMAT_ERROR);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_FORMAT_ERROR_MESSAGE + " " + e.getMessage());
                }
            }
        } catch(Exception e) {
            log.error("DynamicInsertService post ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    /**
     * // TODO 생성 시 id 넘기기
     * @param domainName
     * @param savedObject
     * @param result
     */
    private void initDomainId(String domainName, Object savedObject, Map<String, Object> result) {
        List<Field> allFindFields = new ArrayList<>();
        Field[] findFields1 = savedObject.getClass().getDeclaredFields();
        for (Field findField : findFields1)
            allFindFields.add(findField);
        for (Field findField : allFindFields) {
            String findFieldName = findField.getName();
            try {
                Class c = findDomainClass(domainName);
                Object objectValue = executeMethod(c.cast(savedObject), "getId" );
                if( objectValue!=null ) {
                    result.put("id",objectValue);
                }
            } catch(Exception e) {
                e.printStackTrace();
            }
        }
    }

    @Override
    public Map<String, Object> patch(String domainName, Boolean isCheckAllowedClassValue, JsonNode requestBody, Object id) {
        return null;
    }

    @Override
    public Map<String, Object> patch(String domainName, Boolean isCheckAllowedClassValue, JsonNode requestBody, String fieldName, Object value, String type) {
        return null;
    }

    @Override
    public Map<String, Object> patch(String domainName, Boolean isCheckAllowedClassValue, JsonNode requestBody, String field, Object value, String type, String whereField, Object whereValue, String whereType) {
        return null;
    }

    @Override
    public Map<String, Object> patch(String domainName, Boolean isCheckAllowedClassValue, JsonNode requestBody, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3) {
        return null;
    }

    @Override
    public Map<String, Object> patch(String domainName, Boolean isCheckAllowedClassValue, JsonNode requestBody, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, String fieldName4, Object value4, String type4) {
        return null;
    }

    @Override
    public Map<String, Object> delete(String domainName, JsonNode requestBody) {
        return null;
    }

    @Override
    public Map<String, Object> delete(String domainName, Object value) {
        return null;
    }

    @Override
    public Map<String, Object> delete(String domainName, String fieldName, Object value, String type) {
        return null;
    }

    @Override
    public Map<String, Object> delete(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2) {
        return null;
    }

    @Override
    public Map<String, Object> delete(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3) {
        return null;
    }

    @Override
    public Map<String, Object> delete(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, String fieldName4, Object value4, String type4) {
        return null;
    }

    @Override
    public Map<String, Object> countBetweenAndOneColumn(String domainName, String betweenFieldName, Object from, Object to, String type, String fieldName1, Object value1, String type1) {
        return null;
    }

    @Override
    public Map<String, Object> countBetweenAndTwoColumn(String domainName, String betweenFieldName, Object from, Object to, String type, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2) {
        return null;
    }

}

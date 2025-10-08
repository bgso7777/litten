package com.litten.common.dynamic;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.IntNode;
import lombok.extern.log4j.Log4j2;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.lang.reflect.InvocationTargetException;
import java.util.HashMap;
import java.util.Map;

@Log4j2
@Service
@Transactional
public class DynamicDeleteService extends RepositorySupport implements ExternalHttpDynamicMethod {

    @Override
    public Map<String, Object> get(String domainName, Object value) {
        return null;
    }

    @Override
    public Map<String, Object> get(String domainName) {
        return null;
    }

    @Override
    public Map<String, Object> get(String domainName, Integer page, Integer pageSize, String sortColumn, String sortDirection) {
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

    @Override
    public Map<String, Object> post(String domainName, Boolean isCheckAllowedClassValue, JsonNode requestBody) {
        return null;
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

    @Transactional
    @Override
    public Map<String, Object> delete(String domainName, JsonNode requestBody) {

        Map<String, Object> result = new HashMap<>();
        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_SUCCESS);
        JsonNode jsonNode = requestBody.get(ConstantsDynamic.TAG_IDS);
        if( jsonNode==null ) {
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NOT_FOUND_MESSAGE + "ids array");
        } else {
            Class c = findDomainClass(domainName);
            JpaRepository jpaRepository = findJpaRepository(domainName);
            if (c == null || jpaRepository == null) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY_MESSAGE);
            } else {
                int resultSuccessSize=0;
                ArrayNode arrayNode = (ArrayNode) jsonNode;
                result.put(ConstantsDynamic.TAG_ARRAY_SIZE, arrayNode.size());
                for (Object object : arrayNode) {
                    try {
                        if (object instanceof IntNode) {
                            Integer id = ((IntNode)object).intValue();
                            Object deleteResultObject = executeMethod(jpaRepository, "deleteBy"+domainName+"Id", (Integer)id);
                            resultSuccessSize++;
                        } else {
                        }
                    }catch(NoSuchMethodException e){
                        log.error("DynamicDeleteService delete ",e.getMessage());
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_SUPPORT_SERVICE);
                    } catch (InvocationTargetException e) {
                        // TODO id가 없을 경우 처리 ...?????????
                        log.error("DynamicDeleteService delete ",e.getMessage());
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_ERROR);
                        result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_DATA_ERROR_MESSAGE + " " + e.getMessage());
                    } catch(Exception e) {
                        log.error("DynamicDeleteService delete ",e.getMessage());
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
                    }
                }
                result.put(ConstantsDynamic.TAG_RESULT_SUCCESS_SIZE, resultSuccessSize);
            }
        }
        return result;
    }

    @Transactional
    @Override
    public Map<String, Object> delete(String domainName, Object id) {

        log.debug("domainName -->> {}", domainName);
        log.debug("id -->> {}", id);

        Map<String, Object> result = new HashMap<>();
        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_SUCCESS);
        try {
            Class c = findDomainClass(domainName);
            JpaRepository jpaRepository = findJpaRepository(domainName);
            if( c==null || jpaRepository==null ) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY_MESSAGE);
            } else {
                try {
                    //Object deleteResultObject =
                    executeMethod(jpaRepository, "deleteById", id);
                    result.put(ConstantsDynamic.TAG_SIZE, 1);
                }catch(NoSuchMethodException e){
                    log.error("DynamicDeleteService delete ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_SUPPORT_SERVICE);
                }
            }
        } catch (InvocationTargetException e) {
            // TODO id가 없을 경우 처리 ...?????????
            log.error("DynamicDeleteService delete ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_ERROR);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_DATA_ERROR_MESSAGE + " " + ExceptionMessage.getMessage(e));
        } catch(Exception e) {
            log.error("DynamicDeleteService delete ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    @Transactional
    @Override
    public Map<String, Object> delete(String domainName, String fieldName, Object value, String type) {

        log.debug("domainName -->> {}", domainName);
        log.debug("fieldName -->> {}", fieldName);
        log.debug("value -->> {}", value);
        log.debug("type -->> {}", type);

        Map<String, Object> result = new HashMap<>();
        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_SUCCESS);

        try {
            Class c = findDomainClass(domainName);
            JpaRepository jpaRepository = findJpaRepository(domainName);
            if( c==null || jpaRepository==null ) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY_MESSAGE);
            } else {
                try {
                    String methodName = "deleteBy" + replaceParamToMenthod(fieldName);
                    Object objectValue = castObject(type, value);
                    if (objectValue == null) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_OBJECT_TYPE_CAST_ERROR);
                    } else {
                        Object resultObject = executeMethod(jpaRepository, methodName, objectValue);
                        result.put(ConstantsDynamic.TAG_SIZE, resultObject);
                    }
                } catch (NoSuchMethodException e) {
                    log.error("DynamicDeleteService delete ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                }
            }
        } catch(Exception e) {
            log.error("DynamicDeleteService delete ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    @Transactional
    @Override
    public Map<String, Object> delete(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2) {

        log.debug("domainName -->> {}", domainName);
        log.debug("fieldName1 -->> {}", fieldName1);
        log.debug("value1 -->> {}", value1);
        log.debug("type1 -->> {}", type1);
        log.debug("fieldName2 -->> {}", fieldName2);
        log.debug("value2 -->> {}", value2);
        log.debug("type2 -->> {}", type2);

        Map<String, Object> result = new HashMap<>();
        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_SUCCESS);

        try {
//            value = Crypto.decodeBase64(value.toString());
            Class c = findDomainClass(domainName);
            JpaRepository jpaRepository = findJpaRepository(domainName);
            if( c==null || jpaRepository==null ) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY_MESSAGE);
            } else {
                try {
                    String methodName = "deleteBy"+replaceParamToMenthod(fieldName1)+"And"+replaceParamToMenthod(fieldName2);
                    Object objectValue1 = castObject(type1,value1);
                    Object objectValue2 = castObject(type2,value2);
                    if(objectValue1==null||objectValue2==null) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_OBJECT_TYPE_CAST_ERROR);
                    } else {
                        Object resultObject = executeMethod(jpaRepository, methodName, objectValue1, objectValue2);
                        if (resultObject == null) {
                            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                        } else {
                            result.put(ConstantsDynamic.TAG_SIZE, resultObject);
                        }
                    }
                } catch (NoSuchMethodException e) {
                    e.printStackTrace();
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                }
            }
        } catch (IllegalArgumentException e) {
            log.error("DynamicDeleteService delete ",e);
            if (e.getMessage().indexOf("base64") != -1) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_DECRYPT_ERROR);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, "check url value (Encode base64 url value)");
            }
        } catch(Exception e) {
            log.error("DynamicDeleteService delete ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    @Transactional
    @Override
    public Map<String, Object> delete(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3) {

        log.debug("domainName -->> {}", domainName);
        log.debug("fieldName1 -->> {}", fieldName1);
        log.debug("value1 -->> {}", value1);
        log.debug("type1 -->> {}", type1);
        log.debug("fieldName2 -->> {}", fieldName2);
        log.debug("value2 -->> {}", value2);
        log.debug("type2 -->> {}", type2);
        log.debug("fieldName3 -->> {}", fieldName3);
        log.debug("value3 -->> {}", value3);
        log.debug("type3 -->> {}", type3);

        Map<String, Object> result = new HashMap<>();
        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_SUCCESS);

        try {
//            value = Crypto.decodeBase64(value.toString());
            Class c = findDomainClass(domainName);
            JpaRepository jpaRepository = findJpaRepository(domainName);
            if( c==null || jpaRepository==null ) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY_MESSAGE);
            } else {
                try {
                    String methodName = "deleteBy"+replaceParamToMenthod(fieldName1)+"And"+replaceParamToMenthod(fieldName2)+"And"+replaceParamToMenthod(fieldName3);
                    Object objectValue1 = castObject(type1,value1);
                    Object objectValue2 = castObject(type2,value2);
                    Object objectValue3 = castObject(type3,value3);
                    if(objectValue1==null||objectValue2==null||objectValue3==null) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_OBJECT_TYPE_CAST_ERROR);
                    } else {
                        Object resultObject = executeMethod(jpaRepository, methodName, objectValue1, objectValue2, objectValue3);
                        if (resultObject == null) {
                            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                        } else {
                            if (resultObject == null) {
                                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                            } else {
                                result.put(ConstantsDynamic.TAG_SIZE, resultObject);
                            }
                        }
                    }
                } catch (NoSuchMethodException e) {
                    log.error("DynamicDeleteService delete ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                }
            }
        } catch (IllegalArgumentException e) {
            log.error("DynamicDeleteService delete ",e);
            if (e.getMessage().indexOf("base64") != -1) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_DECRYPT_ERROR);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, "check url value (Encode base64 url value)");
            }
        } catch(Exception e) {
            log.error("DynamicDeleteService delete ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    @Transactional
    @Override
    public Map<String, Object> delete(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, String fieldName4, Object value4, String type4) {

        log.debug("domainName -->> {}", domainName);
        log.debug("fieldName1 -->> {}", fieldName1);
        log.debug("value1 -->> {}", value1);
        log.debug("type1 -->> {}", type1);
        log.debug("fieldName2 -->> {}", fieldName2);
        log.debug("value2 -->> {}", value2);
        log.debug("type2 -->> {}", type2);
        log.debug("fieldName3 -->> {}", fieldName3);
        log.debug("value3 -->> {}", value3);
        log.debug("type3 -->> {}", type3);
        log.debug("fieldName4 -->> {}", fieldName4);
        log.debug("value4 -->> {}", value4);
        log.debug("type4 -->> {}", type4);

        Map<String, Object> result = new HashMap<>();
        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_SUCCESS);

        try {
//            value = Crypto.decodeBase64(value.toString());
            Class c = findDomainClass(domainName);
            JpaRepository jpaRepository = findJpaRepository(domainName);
            if( c==null || jpaRepository==null ) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY_MESSAGE);
            } else {
                try {
                    String methodName = "deleteBy"+replaceParamToMenthod(fieldName1)+"And"+replaceParamToMenthod(fieldName2)+"And"+replaceParamToMenthod(fieldName3)+"And"+replaceParamToMenthod(fieldName4);
                    Object objectValue1 = castObject(type1,value1);
                    Object objectValue2 = castObject(type2,value2);
                    Object objectValue3 = castObject(type3,value3);
                    Object objectValue4 = castObject(type3,value4);
                    if(objectValue1==null||objectValue2==null||objectValue3==null||objectValue4==null) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_OBJECT_TYPE_CAST_ERROR);
                    } else {
                        Object resultObject = executeMethod(jpaRepository, methodName, objectValue1, objectValue2, objectValue3, objectValue4);
                        if (resultObject == null) {
                            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                        } else {
                            if (resultObject == null) {
                                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                            } else {
                                result.put(ConstantsDynamic.TAG_SIZE, resultObject);
                            }
                        }
                    }
                } catch (NoSuchMethodException e) {
                    log.error("DynamicDeleteService delete ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                }
            }
        } catch (IllegalArgumentException e) {
            log.error("DynamicDeleteService delete ",e);
            if (e.getMessage().indexOf("base64") != -1) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_DECRYPT_ERROR);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, "check url value (Encode base64 url value)");
            }
        } catch(Exception e) {
            log.error("DynamicDeleteService delete ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
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

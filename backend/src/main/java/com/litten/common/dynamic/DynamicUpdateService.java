package com.litten.common.dynamic;

import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.IntNode;
import com.fasterxml.jackson.databind.node.TextNode;
import lombok.extern.log4j.Log4j2;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.lang.reflect.Field;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.*;

@Log4j2
@Service
@Transactional
public class DynamicUpdateService extends RepositorySupport implements ExternalHttpDynamicMethod {

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
    public Map<String, Object> get(String domainName, String fieldName, Object Object, String type) {
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

    @Transactional
    @Override
    public synchronized Map<String, Object> patch(String domainName, Boolean isCheckAllowedClassValue, JsonNode requestBody, Object id) {

        log.debug("domainName -->> {}", domainName);
        log.debug("requestBody -->> {}", requestBody);
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
                boolean isExist = false;
                Object findObject = jpaRepository.findById(id);
                if(findObject instanceof Optional) {
                    Optional<Object> optionalObject = (Optional<Object>) findObject;
                    if (optionalObject.isPresent()) {
                        findObject = optionalObject.get();
                        findObject = c.cast(findObject);
                        isExist = true;
                    } else {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                    }
                } else {
                    if (findObject == null) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                    } else {
                        isExist = true;
                    }
                }
                if(isExist) {
                    update(c, jpaRepository, requestBody, findObject, result, isCheckAllowedClassValue);
                    return result;
                }
            }
        } catch(Exception e) {
            log.error("DynamicUpdateService update ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    private synchronized int update(Class c, JpaRepository jpaRepository, JsonNode requestBody, Object findObject, Map<String, Object> result, boolean isCheckAllowedClassValue) throws Exception {

        int ret = ConstantsDynamic.RESULT_SUCCESS;
        boolean isSetMethod = false;
        try {
            ObjectMapper objectMapper = new ObjectMapper().configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);
            List<String> notSetKeys = new ArrayList<>();
            Iterator<String> fieldNames = requestBody.fieldNames();
            for (Iterator<String> iter = requestBody.fieldNames(); iter.hasNext(); ) {
                String requestFieldName = iter.next();
                Object requestFieldValue = requestBody.get(requestFieldName);
                log.debug("requestFieldName-->" + requestFieldName + " requestFieldValue-->" + requestFieldValue);
                for (Map.Entry<String, String> entry : ConstantsDynamic.NOT_ALLOWED_UPDATE_DAO_CLASS_VALUE.entrySet()) {
                    log.debug("entry.getKey()-->"+entry.getKey() + " entry.getValue()-->" + entry.getValue());
                    if( c.getSimpleName().equals(entry.getKey()) && requestFieldName.equals(entry.getValue()) ) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_ALLOWED_UPDATE_ERROR);
                        result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NOT_ALLOWED_UPDATE_ERROR_MESSAGE+" "+entry.getKey()+" "+entry.getValue());
                        ret = ConstantsDynamic.RESULT_NOT_ALLOWED_UPDATE_ERROR;
                        return ret;
                    }
                }
                List<Field> allFindFields = new ArrayList<>();
                Field[] findFields1 = findObject.getClass().getDeclaredFields();
                for (Field findField : findFields1)
                    allFindFields.add(findField);
                Field[] findFields2 = c.cast(findObject).getClass().getSuperclass().getDeclaredFields();
                for (Field findField : findFields2)
                    allFindFields.add(findField);

                for (Field findField : allFindFields) {
                    String findFieldName = findField.getName();
                    Object findFieldType = findField.getType();
//                    Object findFieldValue = findObject.get(requestField.getName());
                    if (requestFieldName.equals(findFieldName)) {
                        String getFieldName = "get" + requestFieldName.substring(0, 1).toUpperCase() + requestFieldName.substring(1);
                        String setFieldName = "set" + requestFieldName.substring(0, 1).toUpperCase() + requestFieldName.substring(1);
                        try {
                            // set find object
                            if( setFieldName.length()>2 && setFieldName.substring(setFieldName.length()-2,setFieldName.length()).equals("Id")) { // TODO 규칙을 지켜야 함 ????
                                try {
                                    if( requestFieldValue instanceof IntNode )
                                        executeMethod(c.cast(findObject), setFieldName, ((IntNode)requestFieldValue).intValue());
                                } catch(ClassCastException e) {
                                    executeMethod(c.cast(findObject), setFieldName, Long.parseLong(String.valueOf((IntNode)requestFieldValue)));
                                    log.error(e);
                                } catch(NoSuchMethodException e) {
                                    log.error(e);
                                    notSetKeys.add(requestFieldName);
                                }
                                try{
                                    if( requestFieldValue instanceof TextNode )
                                        executeMethod(c.cast(findObject), setFieldName, ((TextNode)requestFieldValue).asText());
                                } catch(ClassCastException e) {
                                    log.error(e);
                                } catch(NoSuchMethodException e) {
                                    log.error(e);
                                    notSetKeys.add(requestFieldName);
                                }
                            } else if( setFieldName.length()>3 && setFieldName.substring(setFieldName.length()-3,setFieldName.length()).equals("Seq")) { // TODO 규칙을 지켜야 함 ????
                                try {
                                    if( requestFieldValue instanceof IntNode )
                                        executeMethod(c.cast(findObject), setFieldName, ((IntNode)requestFieldValue).intValue());
                                } catch(ClassCastException e) {
                                    executeMethod(c.cast(findObject), setFieldName, Long.parseLong(String.valueOf((IntNode)requestFieldValue)));
                                    log.error(e);
                                } catch(NoSuchMethodException e) {
                                    log.error(e);
                                    notSetKeys.add(requestFieldName);
                                }
                                try{
                                    if( requestFieldValue instanceof TextNode )
                                        executeMethod(c.cast(findObject), setFieldName, ((TextNode)requestFieldValue).asText());
                                } catch(ClassCastException e) {
                                    log.error(e);
                                } catch(NoSuchMethodException e) {
                                    log.error(e);
                                    notSetKeys.add(requestFieldName);
                                }
                            } else if( setFieldName.length()>8 && setFieldName.substring(setFieldName.length()-8,setFieldName.length()).equals("DateTime")) { // TODO 규칙을 지켜야 함 ????
                                try {
                                    String o = ((TextNode) requestFieldValue).asText();
                                    executeMethod(c.cast(findObject), setFieldName, LocalDateTime.parse(o, DateTimeFormatter.ofPattern(ConstantsDynamic.TYPE_OF_DATETIME)));
                                } catch(ClassCastException e) {
                                    log.error(e);
                                } catch(NoSuchMethodException e) {
                                    log.error(e);
                                    notSetKeys.add(requestFieldName);
                                }
                            } else if( setFieldName.length()>4 && setFieldName.substring(setFieldName.length()-4,setFieldName.length()).equals("Time")) { // TODO 규칙을 지켜야 함 ????
                                try{
                                    String o = ((TextNode) requestFieldValue).asText();
                                    executeMethod(c.cast(findObject), setFieldName, LocalTime.parse(o, DateTimeFormatter.ofPattern(ConstantsDynamic.TYPE_OF_TIME)));
                                } catch(ClassCastException e) {
                                    log.error(e);
                                } catch(NoSuchMethodException e) {
                                    log.error(e);
                                    notSetKeys.add(requestFieldName);
                                }
                            } else if( setFieldName.length()>4 && setFieldName.substring(setFieldName.length()-4,setFieldName.length()).equals("Date")) { // TODO 규칙을 지켜야 함 ????
                                try{
                                    String o = ((TextNode) requestFieldValue).asText();
                                    executeMethod(c.cast(findObject), setFieldName, LocalDate.parse(o, DateTimeFormatter.ofPattern(ConstantsDynamic.TYPE_OF_DATE)));
                                } catch(ClassCastException e) {
                                    log.error(e);
                                } catch(NoSuchMethodException e) {
                                    log.error(e);
                                    notSetKeys.add(requestFieldName);
                                }
                            } else {
                                try{
                                    executeMethod(c.cast(findObject), setFieldName, castObject(requestFieldValue));
                                } catch(ClassCastException e) {
                                    log.error(e);
                                } catch(NoSuchMethodException e) {
                                    log.error(e);
                                    notSetKeys.add(requestFieldName);
                                }
                            }
                            isSetMethod = true;
                        } catch (Exception e) {
                            log.error("DynamicUpdateService update ",e);
                            notSetKeys.add(requestFieldName);
                        }
                    }
                }
            }
            if ( notSetKeys.size()>0 ) {
                String notSetMethods = "";
                for (String notSetMethod : notSetKeys)
                    notSetMethods = notSetMethods + " " + notSetMethod;
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE +" ("+notSetMethods+" )" + " check key or value type");
                ret = ConstantsDynamic.RESULT_NO_SUCH_METHOD;
            } else {
                if(isSetMethod) {
                    if( findObject instanceof BaseEntity)
                        initUpdateValue((BaseEntity) findObject);
                    else if( findObject instanceof BaseEntity )
                        initUpdateValue((BaseEntity) findObject);
                    Object saveResultObject = executeMethod(jpaRepository, "save", findObject);
                    result.put(ConstantsDynamic.TAG_SIZE, saveResultObject); // TODO id return 결과만 리턴 시킨다.
                } else {
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NOT_FOUND_MESSAGE);
                    ret = ConstantsDynamic.RESULT_NOT_FOUND;
                }
            }
        } catch (ClassCastException e) {
            log.error("DynamicUpdateService update ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_SUPPORT_SERVICE);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NOT_SUPPORT_SERVICE_MESSAGE);
            ret = ConstantsDynamic.RESULT_NOT_SUPPORT_SERVICE;
        } catch (DataIntegrityViolationException e) { // TODO ConSerBridge에서 잡힘
            log.error("DynamicUpdateService update ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_SUPPORT_SERVICE);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NOT_SUPPORT_SERVICE_MESSAGE);
            ret = ConstantsDynamic.RESULT_NOT_SUPPORT_SERVICE;
        }
        return ret;
    }

    @Transactional
    @Override
    public synchronized Map<String, Object> patch(String domainName, Boolean isCheckAllowedClassValue, JsonNode requestBody, String fieldName, Object value, String type) {

        log.debug("domainName -->> {}", domainName);
        log.debug("requestBody -->> {}", requestBody);
        log.debug("fieldName -->> {}", fieldName);
        log.debug("value -->> {}", value);
        log.debug("type -->> {}", type);

        Map<String, Object> result = new HashMap<>();
        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_SUCCESS);

        try {
            Class c = findDomainClass(domainName);
            JpaRepository jpaRepository = findJpaRepository(domainName);
            if (c == null || jpaRepository == null) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY_MESSAGE);
            } else {
                String methodName = "findBy" + replaceParamToMenthod(fieldName);
                Object objectValue = castObject(type, value);
                if(objectValue==null) {
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_OBJECT_TYPE_CAST_ERROR);
                } else {
                    Object resultObjects = executeMethod(jpaRepository, methodName, objectValue);
                    if (resultObjects == null) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                    } else {
                        int successCount = 0;
                        if (resultObjects instanceof ArrayList) {
                            ArrayList arrayList = (ArrayList) resultObjects;
                            result.put(ConstantsDynamic.TAG_SIZE, arrayList.size());
                            if (arrayList.size() == 0) {
                                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                            } else {
                                for (Object findObject : arrayList) {
                                    int ret = update(c, jpaRepository, requestBody, findObject, result, isCheckAllowedClassValue);
                                    if (ret == ConstantsDynamic.RESULT_SUCCESS)
                                        successCount++;
                                }
                            }
                        } else {
                            result.put(ConstantsDynamic.TAG_SIZE, 1);
                            if( resultObjects instanceof Optional )
                                resultObjects = ((Optional)resultObjects).get();
                            int ret = update(c, jpaRepository, requestBody, resultObjects, result, isCheckAllowedClassValue);
                            if (ret == ConstantsDynamic.RESULT_SUCCESS)
                                successCount++;
                        }
                        result.put(ConstantsDynamic.TAG_RESULT_SUCCESS_COUNT, successCount);
                    }
                }
            }
        } catch(NoSuchMethodException e) {
            log.error("DynamicUpdateService update ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
        } catch(Exception e) {
            log.error("DynamicUpdateService update ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    @Transactional
    @Override
    public synchronized Map<String, Object> patch(String domainName, Boolean isCheckAllowedClassValue, JsonNode requestBody, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2) {

        log.debug("domainName -->> {}", domainName);
        log.debug("requestBody -->> {}", requestBody);
        log.debug("fieldName1 -->> {}", fieldName1);
        log.debug("value1 -->> {}", value1);
        log.debug("type1 -->> {}", type1);
        log.debug("fieldName2 -->> {}", fieldName2);
        log.debug("value2 -->> {}", value2);
        log.debug("type2 -->> {}", type2);

        Map<String, Object> result = new HashMap<>();
        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_SUCCESS);

        try {
            Class c = findDomainClass(domainName);
            JpaRepository jpaRepository = findJpaRepository(domainName);
            if (c == null || jpaRepository == null) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY_MESSAGE);
            } else {
                String methodName = "findBy"+replaceParamToMenthod(fieldName1)+"And"+replaceParamToMenthod(fieldName2);
                Object objectValue1 = castObject(type1,value1);
                Object objectValue2 = castObject(type2,value2);
                if(objectValue1==null||objectValue2==null) {
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_OBJECT_TYPE_CAST_ERROR);
                } else {
                    Object resultObjects = executeMethod(jpaRepository, methodName, objectValue1, objectValue2);
                    if (resultObjects == null) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                    } else {
                        int successCount = 0;
                        if (resultObjects instanceof ArrayList) {
                            ArrayList arrayList = (ArrayList) resultObjects;
                            result.put(ConstantsDynamic.TAG_SIZE, arrayList.size());
                            if (arrayList.size() == 0) {
                                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                            } else {
                                for (Object findObject : arrayList) {
                                    int ret = update(c, jpaRepository, requestBody, findObject, result, isCheckAllowedClassValue);
                                    if (ret == ConstantsDynamic.RESULT_SUCCESS)
                                        successCount++;
                                }
                            }
                        } else {
                            result.put(ConstantsDynamic.TAG_SIZE, 1);
                            int ret = update(c, jpaRepository, requestBody, resultObjects, result, isCheckAllowedClassValue);
                            if (ret == ConstantsDynamic.RESULT_SUCCESS)
                                successCount++;
                        }
                        result.put(ConstantsDynamic.TAG_RESULT_SUCCESS_COUNT, successCount);
                    }
                }
            }
        } catch(NoSuchMethodException e) {
            log.error("DynamicUpdateService update ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
        } catch(Exception e) {
            log.error("DynamicUpdateService update ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    @Transactional
    @Override
    public synchronized Map<String, Object> patch(String domainName, Boolean isCheckAllowedClassValue, JsonNode requestBody, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3) {

        log.debug("domainName -->> {}", domainName);
        log.debug("requestBody -->> {}", requestBody);
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
            Class c = findDomainClass(domainName);
            JpaRepository jpaRepository = findJpaRepository(domainName);
            if (c == null || jpaRepository == null) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY_MESSAGE);
            } else {
                String methodName = "findBy"+replaceParamToMenthod(fieldName1)+"And"+replaceParamToMenthod(fieldName2)+"And"+replaceParamToMenthod(fieldName3);
                Object objectValue1 = castObject(type1,value1);
                Object objectValue2 = castObject(type2,value2);
                Object objectValue3 = castObject(type3,value3);
                Object resultObjects = executeMethod(jpaRepository, methodName, objectValue1, objectValue2, objectValue3);
                if(objectValue1==null||objectValue2==null||objectValue3==null) {
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_OBJECT_TYPE_CAST_ERROR);
                } else {
                    if (resultObjects == null) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                    } else {
                        int successCount = 0;
                        if (resultObjects instanceof ArrayList) {
                            ArrayList arrayList = (ArrayList) resultObjects;
                            result.put(ConstantsDynamic.TAG_SIZE, arrayList.size());
                            if (arrayList.size() == 0) {
                                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                            } else {
                                for (Object findObject : arrayList) {
                                    int ret = update(c, jpaRepository, requestBody, findObject, result, isCheckAllowedClassValue);
                                    if (ret == ConstantsDynamic.RESULT_SUCCESS)
                                        successCount++;
                                }
                            }
                        } else {
                            result.put(ConstantsDynamic.TAG_SIZE, 1);
                            int ret = update(c, jpaRepository, requestBody, resultObjects, result, isCheckAllowedClassValue);
                            if (ret == ConstantsDynamic.RESULT_SUCCESS)
                                successCount++;
                        }
                        result.put(ConstantsDynamic.TAG_RESULT_SUCCESS_COUNT, successCount);
                    }
                }
            }
        } catch(NoSuchMethodException e) {
            log.error("DynamicUpdateService update ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
        } catch(Exception e) {
            log.error("DynamicUpdateService update ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    @Transactional
    @Override
    public synchronized Map<String, Object> patch(String domainName, Boolean isCheckAllowedClassValue, JsonNode requestBody, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, String fieldName4, Object value4, String type4) {

        log.debug("domainName -->> {}", domainName);
        log.debug("requestBody -->> {}", requestBody);
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
            Class c = findDomainClass(domainName);
            JpaRepository jpaRepository = findJpaRepository(domainName);
            if (c == null || jpaRepository == null) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY_MESSAGE);
            } else {
                String methodName = "findBy"+replaceParamToMenthod(fieldName1)+"And"+replaceParamToMenthod(fieldName2)+"And"+replaceParamToMenthod(fieldName3)+"And"+replaceParamToMenthod(fieldName4);
                Object objectValue1 = castObject(type1,value1);
                Object objectValue2 = castObject(type2,value2);
                Object objectValue3 = castObject(type3,value3);
                Object objectValue4 = castObject(type3,value4);
                Object resultObjects = executeMethod(jpaRepository, methodName, objectValue1, objectValue2, objectValue3, objectValue4);
                if(objectValue1==null||objectValue2==null||objectValue3==null) {
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_OBJECT_TYPE_CAST_ERROR);
                } else {
                    if (resultObjects == null) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                    } else {
                        int successCount = 0;
                        if (resultObjects instanceof ArrayList) {
                            ArrayList arrayList = (ArrayList) resultObjects;
                            result.put(ConstantsDynamic.TAG_SIZE, arrayList.size());
                            if (arrayList.size() == 0) {
                                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                            } else {
                                for (Object findObject : arrayList) {
                                    int ret = update(c, jpaRepository, requestBody, findObject, result, isCheckAllowedClassValue);
                                    if (ret == ConstantsDynamic.RESULT_SUCCESS)
                                        successCount++;
                                }
                            }
                        } else {
                            result.put(ConstantsDynamic.TAG_SIZE, 1);
                            int ret = update(c, jpaRepository, requestBody, resultObjects, result, isCheckAllowedClassValue);
                            if (ret == ConstantsDynamic.RESULT_SUCCESS)
                                successCount++;
                        }
                        result.put(ConstantsDynamic.TAG_RESULT_SUCCESS_COUNT, successCount);
                    }
                }
            }
        } catch(NoSuchMethodException e) {
            log.error("DynamicUpdateService update ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
        } catch(Exception e) {
            log.error("DynamicUpdateService update ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
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

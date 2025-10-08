package com.litten.common.dynamic;

import com.fasterxml.jackson.databind.JsonNode;
import lombok.extern.log4j.Log4j2;
import org.springframework.data.domain.*;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.mapping.PropertyReferenceException;
import org.springframework.stereotype.Service;

import java.util.*;

@Log4j2
@Service
public class DynamicSelectService extends RepositorySupport implements ExternalHttpDynamicMethod {

    @Override
    public Map<String, Object> get(String domainName, Object id) {

        log.debug("domainName -->> {}", domainName);
//        log.debug("id -->> {}", id);

        Map<String, Object> result = new HashMap<>();
        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_SUCCESS);

        try {
            Class c = findDomainClass(domainName);
            JpaRepository jpaRepository = findJpaRepository(domainName);
            if (c == null || jpaRepository == null) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY_MESSAGE);
            } else {
                try {
                    domainName = domainName.substring(0, 1).toLowerCase() + domainName.substring(1);
                    Object object = jpaRepository.findById(id);
                    if(object instanceof Optional) {
                        Optional<Object> optionalObject = (Optional<Object>) object;
                        if (optionalObject.isPresent()) {
                            result.put(getDomainName(c.getSimpleName()), optionalObject.get());
                        } else {
                            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                        }
                    } else {
                        // TODO array object
                        if (object == null) {
                            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                        } else {
                            result.put(domainName,object);
                        }
                    }
                } catch (PropertyReferenceException e) {
                    log.error("DynamicSelectService get ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                } catch (Exception e) {
                    e.printStackTrace();
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
                }
            }
        } catch(Exception e) {
            log.error("DynamicSelectService get ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }

        return result;
    }

    @Override
    public Map<String, Object> get(String domainName) {

        log.debug("domainName -->> {}", domainName);

        Map<String, Object> result = new HashMap<>();
        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_SUCCESS);

        try {
            if (domainName.indexOf("-") != -1)
                domainName = replaceParamToMenthod(domainName);
            Class c = findDomainClass(domainName);
            JpaRepository jpaRepository = findJpaRepository(domainName);
            if (c == null || jpaRepository == null) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY_MESSAGE);
            } else {
                try {
                    List<Object> objectList = jpaRepository.findAll();
                    if (objectList == null) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                    } else {
                        if (objectList.size() == 0) {
                            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                        } else {
                            result.put(ConstantsDynamic.TAG_SIZE, objectList.size());
                            result.put(getArrayDomainName(domainName), objectList);
                        }
                    }
                } catch (PropertyReferenceException e) {
                    log.error("DynamicSelectService get ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                } catch (Exception e) {
                    log.error("DynamicSelectService get ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                }
            }
        } catch (Exception e) {
            log.error("DynamicSelectService get ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    @Override
    public Map<String, Object> get(String domainName, Integer page, Integer pageSize, String sortColumn, String sortDirection) {

        log.debug("domainName -->> {}", domainName);
        log.debug("page -->> {}", page);
        log.debug("pageSize -->> {}", pageSize);
        log.debug("sortColumn -->> {}", sortColumn);
        log.debug("sortDirection -->> {}", sortDirection);

        Map<String, Object> result = new HashMap<>();
        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_SUCCESS);

        try {
            if (domainName.indexOf("-") != -1)
                domainName = replaceParamToMenthod(domainName);
            Class c = findDomainClass(domainName);
            JpaRepository jpaRepository = findJpaRepository(domainName);
            if (c == null || jpaRepository == null) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY_MESSAGE);
            } else {
                try {
                    PageRequest pageRequest = toPageRequest(page, pageSize, replaceParamToMenthod2(sortColumn), sortDirection);
                    Page<Object> objectPage = jpaRepository.findAll(pageRequest);
                    if (objectPage == null) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                    } else {
                        PageImpl pageImpl = (PageImpl) objectPage;
                        if (pageImpl.getTotalPages()==0) {
                            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                        } else {
                            result.put(ConstantsDynamic.TAG_TOTAL_PAGE_SIZE, pageImpl.getTotalPages());
                            result.put(ConstantsDynamic.TAG_TOTAL_ELEMENT_SIZE, pageImpl.getTotalElements());
                            result.put(getArrayDomainName(c.getSimpleName()), objectPage);
                        }
                    }
                } catch (PropertyReferenceException e) {
                    log.error("DynamicSelectService get ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                } catch (Exception e) {
                    log.error("DynamicSelectService get ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName, String from, String to, String type) {

        log.debug("domainName -->> {}", domainName);
        log.debug("fieldName -->> {}", fieldName);
        log.debug("from -->> {}", from);
        log.debug("to -->> {}", to);
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
                    String methodName = "findBy"+replaceParamToMenthod(fieldName)+"Between";
                    Object objectFrom = castObject(type,from);
                    Object objectTo = castObject(type,to);
                    if(objectFrom==null||objectTo==null) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_OBJECT_TYPE_CAST_ERROR);
                    } else {
                        Object resultObject = executeMethod(jpaRepository,methodName,objectFrom,objectTo);
                        if (resultObject == null) {
                            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                        } else {
                            if( resultObject instanceof ArrayList ) {
                                ArrayList arrayList = (ArrayList) resultObject;
                                if (arrayList.size() == 0) {
                                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                                } else {
                                    result.put(ConstantsDynamic.TAG_SIZE, arrayList.size());
                                    result.put(getArrayDomainName(c.getSimpleName()), resultObject);
                                }
                            } else {
                                result.put(getDomainName(c.getSimpleName()), resultObject);
                            }
                        }
                    }
                } catch (NoSuchMethodException e) {
                    log.error("DynamicSelectService get ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                }
            }
        } catch (IllegalArgumentException e) {
            log.error("DynamicSelectService get ",e);
            if (e.getMessage().indexOf("base64") != -1) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_DECRYPT_ERROR);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, "check url value (Encode base64 url value)");
            }
        } catch(Exception e) {
            log.error("DynamicSelectService get ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName, Object value, String type) {

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
                    String methodName = "findBy" + replaceParamToMenthod(fieldName);
                    Object objectValue = castObject(type,value);
                    if( methodName.indexOf("IsNull")!=-1 )
                        objectValue = new Object();
                    if(objectValue==null) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_OBJECT_TYPE_CAST_ERROR);
                    } else {
                        Object resultObject = null;
                        if( methodName.indexOf("IsNull")!=-1 )
                            resultObject = executeMethod(jpaRepository, methodName);
                        else
                            resultObject = executeMethod(jpaRepository, methodName, objectValue);
                        if (resultObject == null) {
                            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                        } else {
                            if( resultObject instanceof ArrayList ) {
                                ArrayList arrayList = (ArrayList) resultObject;
                                if (arrayList.size() == 0) {
                                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                                } else {
                                    result.put(ConstantsDynamic.TAG_SIZE, arrayList.size());
                                    result.put(getArrayDomainName(c.getSimpleName()), resultObject);
                                }
                            } else {
                                result.put(getDomainName(c.getSimpleName()), resultObject);
                            }
                        }
                    }
                } catch (NoSuchMethodException e) {
                    log.error("DynamicSelectService get ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                }
            }
        } catch (IllegalArgumentException e) {
            log.error("DynamicSelectService get ",e);
            if (e.getMessage().indexOf("base64") != -1) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_DECRYPT_ERROR);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, "check url value (Encode base64 url value)");
            }
        } catch(Exception e) {
            log.error("DynamicSelectService get ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2) {

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
                    String methodName = "findBy"+replaceParamToMenthod(fieldName1)+"And"+replaceParamToMenthod(fieldName2);
                    Object objectValue1 = castObject(type1,value1);
                    Object objectValue2 = castObject(type2,value2);
                    if(objectValue1==null||objectValue2==null) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_OBJECT_TYPE_CAST_ERROR);
                    } else {
                        Object resultObject = executeMethod(jpaRepository, methodName, objectValue1, objectValue2);
                        if (resultObject == null) {
                            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                        } else {
                            if( resultObject instanceof ArrayList ) {
                                ArrayList arrayList = (ArrayList) resultObject;
                                if (arrayList.size() == 0) {
                                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                                } else {
                                    result.put(ConstantsDynamic.TAG_SIZE, arrayList.size());
                                    result.put(getArrayDomainName(c.getSimpleName()), resultObject);
                                }
                            } else {
                                result.put(getDomainName(c.getSimpleName()), resultObject);
                            }
                        }
                    }
                } catch (NoSuchMethodException e) {
                    log.error("DynamicSelectService get ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                }
            }
        } catch (IllegalArgumentException e) {
            log.error("DynamicSelectService get ",e);
            if (e.getMessage().indexOf("base64") != -1) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_DECRYPT_ERROR);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, "check url value (Encode base64 url value)");
            }
        } catch(Exception e) {
            log.error("DynamicSelectService get ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3) {
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
                    String methodName = "findBy"+replaceParamToMenthod(fieldName1)+"And"+replaceParamToMenthod(fieldName2)+"And"+replaceParamToMenthod(fieldName3);
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
                            if( resultObject instanceof ArrayList ) {
                                ArrayList arrayList = (ArrayList) resultObject;
                                if (arrayList.size() == 0) {
                                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                                } else {
                                    result.put(ConstantsDynamic.TAG_SIZE, arrayList.size());
                                    result.put(getArrayDomainName(c.getSimpleName()), resultObject);
                                }
                            } else {
                                result.put(getDomainName(c.getSimpleName()), resultObject);
                            }
                        }
                    }
                } catch (NoSuchMethodException e) {
                    log.error("DynamicSelectService get ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                }
            }
        } catch (IllegalArgumentException e) {
            log.error("DynamicSelectService get ",e);
            if (e.getMessage().indexOf("base64") != -1) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_DECRYPT_ERROR);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, "check url value (Encode base64 url value)");
            }
        } catch(Exception e) {
            log.error("DynamicSelectService get ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, String fieldName4, Object value4, String type4) {
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
                    String methodName = "findBy"+replaceParamToMenthod(fieldName1)+"And"+replaceParamToMenthod(fieldName2)+"And"+replaceParamToMenthod(fieldName3)+"And"+replaceParamToMenthod(fieldName4);
                    Object objectValue1 = castObject(type1,value1);
                    Object objectValue2 = castObject(type2,value2);
                    Object objectValue3 = castObject(type3,value3);
                    Object objectValue4 = castObject(type4,value4);
                    if(objectValue1==null||objectValue2==null||objectValue3==null||objectValue4==null) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_OBJECT_TYPE_CAST_ERROR);
                    } else {
                        Object resultObject = executeMethod(jpaRepository, methodName, objectValue1, objectValue2, objectValue3, objectValue4);
                        if (resultObject == null) {
                            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                        } else {
                            if( resultObject instanceof ArrayList ) {
                                ArrayList arrayList = (ArrayList) resultObject;
                                if (arrayList.size() == 0) {
                                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                                } else {
                                    result.put(ConstantsDynamic.TAG_SIZE, arrayList.size());
                                    result.put(getArrayDomainName(c.getSimpleName()), resultObject);
                                }
                            } else {
                                result.put(getDomainName(c.getSimpleName()), resultObject);
                            }
                        }
                    }
                } catch (NoSuchMethodException e) {
                    log.error("DynamicSelectService get ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                }
            }
        } catch (IllegalArgumentException e) {
            log.error("DynamicSelectService get ",e);
            if (e.getMessage().indexOf("base64") != -1) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_DECRYPT_ERROR);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, "check url value (Encode base64 url value)");
            }
        } catch(Exception e) {
            log.error("DynamicSelectService get ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, String fieldName4, Object value4, String type4, String fieldName5, Object value5, String type5) {
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
        log.debug("fieldName5 -->> {}", fieldName5);
        log.debug("value5 -->> {}", value5);
        log.debug("type5 -->> {}", type5);

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
                    String methodName = "findBy"+replaceParamToMenthod(fieldName1)+"And"+replaceParamToMenthod(fieldName2)+"And"+replaceParamToMenthod(fieldName3)+"And"+replaceParamToMenthod(fieldName4)+"And"+replaceParamToMenthod(fieldName5);
                    Object objectValue1 = castObject(type1,value1);
                    Object objectValue2 = castObject(type2,value2);
                    Object objectValue3 = castObject(type3,value3);
                    Object objectValue4 = castObject(type4,value4);
                    Object objectValue5 = castObject(type4,value5);
                    if(objectValue1==null||objectValue2==null||objectValue3==null||objectValue4==null||objectValue5==null) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_OBJECT_TYPE_CAST_ERROR);
                    } else {
                        Object resultObject = executeMethod(jpaRepository, methodName, objectValue1, objectValue2, objectValue3, objectValue4, objectValue5);
                        if (resultObject == null) {
                            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                        } else {
                            if( resultObject instanceof ArrayList ) {
                                ArrayList arrayList = (ArrayList) resultObject;
                                if (arrayList.size() == 0) {
                                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                                } else {
                                    result.put(ConstantsDynamic.TAG_SIZE, arrayList.size());
                                    result.put(getArrayDomainName(c.getSimpleName()), resultObject);
                                }
                            } else {
                                result.put(getDomainName(c.getSimpleName()), resultObject);
                            }
                        }
                    }
                } catch (NoSuchMethodException e) {
                    log.error("DynamicSelectService get ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                }
            }
        } catch (IllegalArgumentException e) {
            log.error("DynamicSelectService get ",e);
            if (e.getMessage().indexOf("base64") != -1) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_DECRYPT_ERROR);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, "check url value (Encode base64 url value)");
            }
        } catch(Exception e) {
            log.error("DynamicSelectService get ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, String fieldName4, Object value4, String type4, String fieldName5, Object value5, String type5, String fieldName6, Object value6, String type6) {
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
        log.debug("fieldName5 -->> {}", fieldName5);
        log.debug("value5 -->> {}", value5);
        log.debug("type5 -->> {}", type5);
        log.debug("fieldName6 -->> {}", fieldName6);
        log.debug("value6 -->> {}", value6);
        log.debug("type6 -->> {}", type6);

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
                    String methodName = "findBy"+replaceParamToMenthod(fieldName1)+"And"+replaceParamToMenthod(fieldName2)+"And"+replaceParamToMenthod(fieldName3)+"And"+replaceParamToMenthod(fieldName4)+"And"+replaceParamToMenthod(fieldName5)+"And"+replaceParamToMenthod(fieldName6);
                    Object objectValue1 = castObject(type1,value1);
                    Object objectValue2 = castObject(type2,value2);
                    Object objectValue3 = castObject(type3,value3);
                    Object objectValue4 = castObject(type4,value4);
                    Object objectValue5 = castObject(type4,value5);
                    Object objectValue6 = castObject(type4,value6);
                    if(objectValue1==null||objectValue2==null||objectValue3==null||objectValue4==null||objectValue5==null||objectValue6==null) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_OBJECT_TYPE_CAST_ERROR);
                    } else {
                        Object resultObject = executeMethod(jpaRepository, methodName, objectValue1, objectValue2, objectValue3, objectValue4, objectValue5, objectValue6);
                        if (resultObject == null) {
                            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                        } else {
                            if( resultObject instanceof ArrayList ) {
                                ArrayList arrayList = (ArrayList) resultObject;
                                if (arrayList.size() == 0) {
                                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                                } else {
                                    result.put(ConstantsDynamic.TAG_SIZE, arrayList.size());
                                    result.put(getArrayDomainName(c.getSimpleName()), resultObject);
                                }
                            } else {
                                result.put(getDomainName(c.getSimpleName()), resultObject);
                            }
                        }
                    }
                } catch (NoSuchMethodException e) {
                    log.error("DynamicSelectService get ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                }
            }
        } catch (IllegalArgumentException e) {
            log.error("DynamicSelectService get ",e);
            if (e.getMessage().indexOf("base64") != -1) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_DECRYPT_ERROR);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, "check url value (Encode base64 url value)");
            }
        } catch(Exception e) {
            log.error("DynamicSelectService get ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName1, Object value1, String type1, Integer page, Integer size, String sortColumn, String sortDirection) {

        log.debug("domainName -->> {}", domainName);
        log.debug("fieldName -->> {}", fieldName1);
        log.debug("value -->> {}", value1);
        log.debug("type -->> {}", type1);

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
                    String methodName = "findBy" + replaceParamToMenthod(fieldName1);
                    Object objectValue = castObject(type1,value1);
                    if(objectValue==null) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_OBJECT_TYPE_CAST_ERROR);
                    } else {
                        Sort sort = null;
                        if(sortDirection.equals("desc"))
                            sort = Sort.by(sortColumn).descending();
                        else
                            sort = Sort.by(sortColumn).ascending();
                        Pageable pageable = PageRequest.of(page, size, sort);
                        Object resultObject = executeMethod(jpaRepository, methodName, objectValue, pageable);
                        if (resultObject == null) {
                            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                        } else {
                            PageImpl pageImpl = (PageImpl) resultObject;
                            if (pageImpl.getTotalPages()==0) {
                                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                            } else {
                                result.put(ConstantsDynamic.TAG_TOTAL_PAGE_SIZE, pageImpl.getTotalPages());
                                result.put(ConstantsDynamic.TAG_TOTAL_ELEMENT_SIZE, pageImpl.getTotalElements());
                                result.put(getArrayDomainName(c.getSimpleName()), resultObject);
                            }
                        }
                    }
                } catch (NoSuchMethodException e) {
                    log.error("DynamicSelectService get ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                }
            }
        } catch (IllegalArgumentException e) {
            log.error("DynamicSelectService get ",e);
            if (e.getMessage().indexOf("base64") != -1) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_DECRYPT_ERROR);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, "check url value (Encode base64 url value)");
            }
        } catch(Exception e) {
            log.error("DynamicSelectService get ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, Integer page, Integer size, String sortColumn, String sortDirection) {

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
                    String methodName = "findBy"+replaceParamToMenthod(fieldName1)+"And"+replaceParamToMenthod(fieldName2);
                    Object objectValue1 = castObject(type1,value1);
                    Object objectValue2 = castObject(type2,value2);
                    if(objectValue1==null||objectValue2==null) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_OBJECT_TYPE_CAST_ERROR);
                    } else {
                        Sort sort = null;
                        if(sortDirection.equals("desc"))
                            sort = Sort.by(sortColumn).descending();
                        else
                            sort = Sort.by(sortColumn).ascending();
                        Pageable pageable = PageRequest.of(page, size, sort);
                        Object resultObject = executeMethod(jpaRepository, methodName, objectValue1, objectValue2, pageable);
                        if (resultObject == null) {
                            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                        } else {
                            PageImpl pageImpl = (PageImpl) resultObject;
                            if (pageImpl.getTotalPages()==0) {
                                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                            } else {
                                result.put(ConstantsDynamic.TAG_TOTAL_PAGE_SIZE, pageImpl.getTotalPages());
                                result.put(ConstantsDynamic.TAG_TOTAL_ELEMENT_SIZE, pageImpl.getTotalElements());
                                result.put(getArrayDomainName(c.getSimpleName()), resultObject);
                            }
                        }
                    }
                } catch (NoSuchMethodException e) {
                    log.error("DynamicSelectService get ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                }
            }
        } catch (IllegalArgumentException e) {
            log.error("DynamicSelectService get ",e);
            if (e.getMessage().indexOf("base64") != -1) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_DECRYPT_ERROR);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, "check url value (Encode base64 url value)");
            }
        } catch(Exception e) {
            log.error("DynamicSelectService get ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, Integer page, Integer size, String sortColumn, String sortDirection) {
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
                    String methodName = "findBy"+replaceParamToMenthod(fieldName1)+"And"+replaceParamToMenthod(fieldName2)+"And"+replaceParamToMenthod(fieldName3);
                    Object objectValue1 = castObject(type1,value1);
                    Object objectValue2 = castObject(type2,value2);
                    Object objectValue3 = castObject(type3,value3);
                    if(objectValue1==null||objectValue2==null||objectValue3==null) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_OBJECT_TYPE_CAST_ERROR);
                    } else {
                        Sort sort = null;
                        if(sortDirection.equals("desc"))
                            sort = Sort.by(sortColumn).descending();
                        else
                            sort = Sort.by(sortColumn).ascending();
                        Pageable pageable = PageRequest.of(page, size, sort);
                        Object resultObject = executeMethod(jpaRepository, methodName, objectValue1, objectValue2, objectValue3, pageable);
                        if (resultObject == null) {
                            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                        } else {
                            PageImpl pageImpl = (PageImpl) resultObject;
                            if (pageImpl.getTotalPages()==0) {
                                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                            } else {
                                result.put(ConstantsDynamic.TAG_TOTAL_PAGE_SIZE, pageImpl.getTotalPages());
                                result.put(ConstantsDynamic.TAG_TOTAL_ELEMENT_SIZE, pageImpl.getTotalElements());
                                result.put(getArrayDomainName(c.getSimpleName()), resultObject);
                            }
                        }
                    }
                } catch (NoSuchMethodException e) {
                    log.error("DynamicSelectService get ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                }
            }
        } catch (IllegalArgumentException e) {
            log.error("DynamicSelectService get ",e);
            if (e.getMessage().indexOf("base64") != -1) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_DECRYPT_ERROR);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, "check url value (Encode base64 url value)");
            }
        } catch(Exception e) {
            log.error("DynamicSelectService get ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, String fieldName4, Object value4, String type4, Integer page, Integer size, String sortColumn, String sortDirection) {
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
                    String methodName = "findBy"+replaceParamToMenthod(fieldName1)+"And"+replaceParamToMenthod(fieldName2)+"And"+replaceParamToMenthod(fieldName3)+"And"+replaceParamToMenthod(fieldName4);
                    Object objectValue1 = castObject(type1,value1);
                    Object objectValue2 = castObject(type2,value2);
                    Object objectValue3 = castObject(type3,value3);
                    Object objectValue4 = castObject(type4,value4);
                    if(objectValue1==null||objectValue2==null||objectValue3==null||objectValue4==null) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_OBJECT_TYPE_CAST_ERROR);
                    } else {
                        Sort sort = null;
                        if(sortDirection.equals("desc"))
                            sort = Sort.by(sortColumn).descending();
                        else
                            sort = Sort.by(sortColumn).ascending();
                        Pageable pageable = PageRequest.of(page, size, sort);
                        Object resultObject = executeMethod(jpaRepository, methodName, objectValue1, objectValue2, objectValue3, objectValue4, pageable);
                        if (resultObject == null) {
                            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                        } else {
                            PageImpl pageImpl = (PageImpl) resultObject;
                            if (pageImpl.getTotalPages()==0) {
                                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                            } else {
                                result.put(ConstantsDynamic.TAG_TOTAL_PAGE_SIZE, pageImpl.getTotalPages());
                                result.put(ConstantsDynamic.TAG_TOTAL_ELEMENT_SIZE, pageImpl.getTotalElements());
                                result.put(getArrayDomainName(c.getSimpleName()), resultObject);
                            }
                        }
                    }
                } catch (NoSuchMethodException e) {
                    log.error("DynamicSelectService get ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                }
            }
        } catch (IllegalArgumentException e) {
            log.error("DynamicSelectService get ",e);
            if (e.getMessage().indexOf("base64") != -1) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_DECRYPT_ERROR);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, "check url value (Encode base64 url value)");
            }
        } catch(Exception e) {
            log.error("DynamicSelectService get ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, String fieldName4, Object value4, String type4, String fieldName5, Object value5, String type5, Integer page, Integer size, String sortColumn, String sortDirection) {
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
        log.debug("fieldName5 -->> {}", fieldName5);
        log.debug("value5 -->> {}", value5);
        log.debug("type5 -->> {}", type5);

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
                    String methodName = "findBy"+replaceParamToMenthod(fieldName1)+"And"+replaceParamToMenthod(fieldName2)+"And"+replaceParamToMenthod(fieldName3)+"And"+replaceParamToMenthod(fieldName4)+"And"+replaceParamToMenthod(fieldName5);
                    Object objectValue1 = castObject(type1,value1);
                    Object objectValue2 = castObject(type2,value2);
                    Object objectValue3 = castObject(type3,value3);
                    Object objectValue4 = castObject(type4,value4);
                    Object objectValue5 = castObject(type4,value5);
                    if(objectValue1==null||objectValue2==null||objectValue3==null||objectValue4==null||objectValue5==null) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_OBJECT_TYPE_CAST_ERROR);
                    } else {
                        Sort sort = null;
                        if(sortDirection.equals("desc"))
                            sort = Sort.by(sortColumn).descending();
                        else
                            sort = Sort.by(sortColumn).ascending();
                        Pageable pageable = PageRequest.of(page, size, sort);
                        Object resultObject = executeMethod(jpaRepository, methodName, objectValue1, objectValue2, objectValue3, objectValue4, objectValue5, pageable);
                        if (resultObject == null) {
                            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                        } else {
                            PageImpl pageImpl = (PageImpl) resultObject;
                            if (pageImpl.getTotalPages()==0) {
                                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                            } else {
                                result.put(ConstantsDynamic.TAG_TOTAL_PAGE_SIZE, pageImpl.getTotalPages());
                                result.put(ConstantsDynamic.TAG_TOTAL_ELEMENT_SIZE, pageImpl.getTotalElements());
                                result.put(getArrayDomainName(c.getSimpleName()), resultObject);
                            }
                        }
                    }
                } catch (NoSuchMethodException e) {
                    log.error("DynamicSelectService get ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                }
            }
        } catch (IllegalArgumentException e) {
            log.error("DynamicSelectService get ",e);
            if (e.getMessage().indexOf("base64") != -1) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_DECRYPT_ERROR);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, "check url value (Encode base64 url value)");
            }
        } catch(Exception e) {
            log.error("DynamicSelectService get ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2, String fieldName3, Object value3, String type3, String fieldName4, Object value4, String type4, String fieldName5, Object value5, String type5, String fieldName6, Object value6, String type6, Integer page, Integer size, String sortColumn, String sortDirection) {
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
        log.debug("fieldName5 -->> {}", fieldName5);
        log.debug("value5 -->> {}", value5);
        log.debug("type5 -->> {}", type5);
        log.debug("fieldName6 -->> {}", fieldName6);
        log.debug("value6 -->> {}", value6);
        log.debug("type6 -->> {}", type6);

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
                    String methodName = "findBy"+replaceParamToMenthod(fieldName1)+
                                            "And"+replaceParamToMenthod(fieldName2)+
                                            "And"+replaceParamToMenthod(fieldName3)+
                                            "And"+replaceParamToMenthod(fieldName4)+
                                            "And"+replaceParamToMenthod(fieldName5)+
                                            "And"+replaceParamToMenthod(fieldName6);
                    Object objectValue1 = castObject(type1,value1);
                    Object objectValue2 = castObject(type2,value2);
                    Object objectValue3 = castObject(type3,value3);
                    Object objectValue4 = castObject(type4,value4);
                    Object objectValue5 = castObject(type4,value5);
                    Object objectValue6 = castObject(type4,value6);
                    if(objectValue1==null||objectValue2==null||objectValue3==null||objectValue4==null||objectValue5==null||objectValue6==null) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_OBJECT_TYPE_CAST_ERROR);
                    } else {
                        Sort sort = null;
                        if(sortDirection.equals("desc"))
                            sort = Sort.by(sortColumn).descending();
                        else
                            sort = Sort.by(sortColumn).ascending();
                        Pageable pageable = PageRequest.of(page, size, sort);
                        Object resultObject = executeMethod(jpaRepository, methodName, objectValue1, objectValue2, objectValue3, objectValue4, objectValue5, objectValue6, pageable);
                        if (resultObject == null) {
                            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                        } else {
                            PageImpl pageImpl = (PageImpl) resultObject;
                            if (pageImpl.getTotalPages()==0) {
                                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                            } else {
                                result.put(ConstantsDynamic.TAG_TOTAL_PAGE_SIZE, pageImpl.getTotalPages());
                                result.put(ConstantsDynamic.TAG_TOTAL_ELEMENT_SIZE, pageImpl.getTotalElements());
                                result.put(getArrayDomainName(c.getSimpleName()), resultObject);
                            }
                        }
                    }
                } catch (NoSuchMethodException e) {
                    log.error("DynamicSelectService get ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                }
            }
        } catch (IllegalArgumentException e) {
            log.error("DynamicSelectService get ",e);
            if (e.getMessage().indexOf("base64") != -1) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_DECRYPT_ERROR);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, "check url value (Encode base64 url value)");
            }
        } catch(Exception e) {
            log.error("DynamicSelectService get ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName1, Object value1, String type1, String fieldName2, String from2, String to2, String type2) {

        log.debug("domainName -->> {}", domainName);
        log.debug("fieldName1 -->> {}", fieldName1);
        log.debug("value1 -->> {}", value1);
        log.debug("fieldName2 -->> {}", fieldName2);
        log.debug("from2 -->> {}", from2);
        log.debug("to2 -->> {}", to2);
        log.debug("type2 -->> {}", type2);

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
                    Object objectValue1 = castObject(type1,value1);
                    String methodName = "findBy"+replaceParamToMenthod(fieldName1)+"And"+replaceParamToMenthod(fieldName2)+"Between";
                    Object objectFrom = castObject(type2,from2);
                    Object objectTo = castObject(type2,to2);
                    if(objectFrom==null||objectTo==null) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_OBJECT_TYPE_CAST_ERROR);
                    } else {
                        Object resultObject = executeMethod(jpaRepository,methodName,objectValue1,objectFrom,objectTo);
                        if (resultObject == null) {
                            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                        } else {
                            if( resultObject instanceof ArrayList ) {
                                ArrayList arrayList = (ArrayList) resultObject;
                                if (arrayList.size() == 0) {
                                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                                } else {
                                    result.put(ConstantsDynamic.TAG_SIZE, arrayList.size());
                                    result.put(getArrayDomainName(c.getSimpleName()), resultObject);
                                }
                            } else {
                                result.put(getDomainName(c.getSimpleName()), resultObject);
                            }
                        }
                    }
                } catch (NoSuchMethodException e) {
                    log.error("DynamicSelectService get ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                }
            }
        } catch (IllegalArgumentException e) {
            log.error("DynamicSelectService get ",e);
            if (e.getMessage().indexOf("base64") != -1) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_DECRYPT_ERROR);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, "check url value (Encode base64 url value)");
            }
        } catch(Exception e) {
            log.error("DynamicSelectService get ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName, Object value) {

        log.debug("domainName -->> {}", domainName);
        log.debug("fieldName -->> {}", fieldName);
        log.debug("value -->> {}", value);

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
                    String methodName = "findBy"+replaceParamToMenthod(fieldName);
                    Object resultObject = executeMethod(jpaRepository, methodName, value);
                    if (resultObject == null ) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                    } else {
                        if( resultObject instanceof ArrayList ) {
                            ArrayList arrayList = (ArrayList)resultObject;
                            if( arrayList.size() == 0 ) {
                                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                            } else {
                                result.put(ConstantsDynamic.TAG_SIZE, arrayList.size() );
                                result.put(getArrayDomainName(c.getSimpleName()), resultObject);
                            }
                        } else {
                            result.put(getDomainName(c.getSimpleName()), resultObject);
                        }
                    }
                } catch (NoSuchMethodException e) {
                    log.error("DynamicSelectService get ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                }
//                }
            }
        } catch(Exception e) {
            log.error("DynamicSelectService get ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName, String from, String to, String type, Integer page, Integer size, String sortColumn, String sortDirection) {

        log.debug("domainName -->> {}", domainName);
        log.debug("fieldName -->> {}", fieldName);
        log.debug("from -->> {}", from);
        log.debug("to -->> {}", to);
        log.debug("type -->> {}", type);
        log.debug("page -->> {}", page);
        log.debug("size -->> {}", size);
        log.debug("sortColumn -->> {}", sortColumn);
        log.debug("sortDirection -->> {}", sortDirection);

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
                    Sort sort = null;
                    if(sortDirection.equals("desc"))
                        sort = Sort.by(sortColumn).descending();
                    else
                        sort = Sort.by(sortColumn).ascending();
                    Pageable pageable = PageRequest.of(page, size, sort);
                    String methodName = "findBy"+replaceParamToMenthod(fieldName)+"Between";
                    Object objectFrom = castObject(type,from);
                    Object objectTo = castObject(type,to);
                    if(objectFrom==null||objectTo==null) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_OBJECT_TYPE_CAST_ERROR);
                    } else {
                        Object resultObject = null;
//                        if( jpaRepository instanceof CampaignRepository)
//                            // TODO NoSuchMethodException가 일어나는지 해결해야 함.
//                            resultObject = ((CampaignRepository) jpaRepository).findByInsertDateTimeBetween((LocalDateTime)objectFrom, (LocalDateTime)objectTo, pageable);
//                        else if( jpaRepository instanceof ContactResultRepository)
//                            resultObject = ((ContactResultRepository) jpaRepository).findByInsertDateTimeBetween((LocalDateTime)objectFrom, (LocalDateTime)objectTo, pageable);
//                        else
                            resultObject = executeMethod(jpaRepository, methodName, objectFrom, objectTo, pageable);
                        if (resultObject == null) {
                            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                        } else {
                            PageImpl pageImpl = (PageImpl) resultObject;
                            if (pageImpl.getTotalPages()==0) {
                                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                            } else {
                                result.put(ConstantsDynamic.TAG_TOTAL_PAGE_SIZE, pageImpl.getTotalPages());
                                result.put(ConstantsDynamic.TAG_TOTAL_ELEMENT_SIZE, pageImpl.getTotalElements());
                                result.put(getArrayDomainName(c.getSimpleName()), resultObject);
                            }
                        }
                    }
                } catch (NoSuchMethodException e) {
                    log.error("DynamicSelectService get ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                }
            }
        } catch (IllegalArgumentException e) {
            log.error("DynamicSelectService get ",e);
            if (e.getMessage().indexOf("base64") != -1) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_DECRYPT_ERROR);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, "check url value (Encode base64 url value)");
            }
        } catch(Exception e) {
            log.error("DynamicSelectService get ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName, String from, String to, String type, Integer page, Integer size, String sortColumn, String sortDirection,
                                   String fieldName0, Object value0, String type0) {

        log.debug("domainName -->> {}", domainName);
        log.debug("fieldName -->> {}", fieldName);
        log.debug("from -->> {}", from);
        log.debug("to -->> {}", to);
        log.debug("type -->> {}", type);
        log.debug("page -->> {}", page);
        log.debug("size -->> {}", size);
        log.debug("sortColumn -->> {}", sortColumn);
        log.debug("sortDirection -->> {}", sortDirection);
        log.debug("fieldName0 -->> {}", fieldName0);
        log.debug("value0 -->> {}", value0);
        log.debug("type0 -->> {}", type0);

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
                    Sort sort = null;
                    if(sortDirection.equals("desc"))
                        sort = Sort.by(sortColumn).descending();
                    else
                        sort = Sort.by(sortColumn).ascending();
                    Pageable pageable = PageRequest.of(page, size, sort);
                    String methodName = "findBy"+replaceParamToMenthod(fieldName)+"BetweenAnd"+""+replaceParamToMenthod(fieldName0);
                    Object objectFrom = castObject(type,from);
                    Object objectTo = castObject(type,to);
                    if(objectFrom==null||objectTo==null) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_OBJECT_TYPE_CAST_ERROR);
                    } else {
                        Object resultObject = executeMethod(jpaRepository, methodName, objectFrom, objectTo, pageable, castObject(type0, value0));
                        if (resultObject == null) {
                            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                        } else {
                            PageImpl pageImpl = (PageImpl) resultObject;
                            if (pageImpl.getTotalPages()==0) {
                                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                            } else {
                                result.put(ConstantsDynamic.TAG_TOTAL_PAGE_SIZE, pageImpl.getTotalPages());
                                result.put(ConstantsDynamic.TAG_TOTAL_ELEMENT_SIZE, pageImpl.getTotalElements());
                                result.put(getArrayDomainName(c.getSimpleName()), resultObject);
                            }
                        }
                    }
                } catch (NoSuchMethodException e) {
                    log.error("DynamicSelectService get ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                }
            }
        } catch (IllegalArgumentException e) {
            log.error("DynamicSelectService get ",e);
            if (e.getMessage().indexOf("base64") != -1) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_DECRYPT_ERROR);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, "check url value (Encode base64 url value)");
            }
        } catch(Exception e) {
            log.error("DynamicSelectService get ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }


    @Override
    public Map<String, Object> get(String domainName, String fieldName, String from, String to, String type, Integer page, Integer size, String sortColumn, String sortDirection,
                                   String fieldName0, Object value0, String type0,
                                   String fieldName1, Object value1, String type1) {

        log.debug("domainName -->> {}", domainName);
        log.debug("fieldName -->> {}", fieldName);
        log.debug("from -->> {}", from);
        log.debug("to -->> {}", to);
        log.debug("type -->> {}", type);
        log.debug("page -->> {}", page);
        log.debug("size -->> {}", size);
        log.debug("sortColumn -->> {}", sortColumn);
        log.debug("sortDirection -->> {}", sortDirection);
        log.debug("fieldName0 -->> {}", fieldName0);
        log.debug("value0 -->> {}", value0);
        log.debug("type0 -->> {}", type0);
        log.debug("fieldName1 -->> {}", fieldName1);
        log.debug("value1 -->> {}", value1);
        log.debug("type1 -->> {}", type1);

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
                    Sort sort = null;
                    if(sortDirection.equals("desc"))
                        sort = Sort.by(sortColumn).descending();
                    else
                        sort = Sort.by(sortColumn).ascending();
                    Pageable pageable = PageRequest.of(page, size, sort);
                    String methodName = "findBy"+replaceParamToMenthod(fieldName)+"Between"+"And"+replaceParamToMenthod(fieldName0)+"And"+
                                                                                                  replaceParamToMenthod(fieldName1);
                    Object objectFrom = castObject(type,from);
                    Object objectTo = castObject(type,to);
                    if(objectFrom==null||objectTo==null) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_OBJECT_TYPE_CAST_ERROR);
                    } else {
                        Object resultObject = executeMethod(jpaRepository, methodName, objectFrom, objectTo, pageable, castObject(type0, value0), castObject(type1, value1));
                        if (resultObject == null) {
                            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                        } else {
                            PageImpl pageImpl = (PageImpl) resultObject;
                            if (pageImpl.getTotalPages()==0) {
                                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                            } else {
                                result.put(ConstantsDynamic.TAG_TOTAL_PAGE_SIZE, pageImpl.getTotalPages());
                                result.put(ConstantsDynamic.TAG_TOTAL_ELEMENT_SIZE, pageImpl.getTotalElements());
                                result.put(getArrayDomainName(c.getSimpleName()), resultObject);
                            }
                        }
                    }
                } catch (NoSuchMethodException e) {
                    log.error("DynamicSelectService get ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                }
            }
        } catch (IllegalArgumentException e) {
            log.error("DynamicSelectService get ",e);
            if (e.getMessage().indexOf("base64") != -1) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_DECRYPT_ERROR);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, "check url value (Encode base64 url value)");
            }
        } catch(Exception e) {
            log.error("DynamicSelectService get ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName, String from, String to, String type, Integer page, Integer size, String sortColumn, String sortDirection,
                                   String fieldName0, Object value0, String type0,
                                   String fieldName1, Object value1, String type1,
                                   String fieldName2, Object value2, String type2) {

        log.debug("domainName -->> {}", domainName);
        log.debug("fieldName -->> {}", fieldName);
        log.debug("from -->> {}", from);
        log.debug("to -->> {}", to);
        log.debug("type -->> {}", type);
        log.debug("page -->> {}", page);
        log.debug("size -->> {}", size);
        log.debug("sortColumn -->> {}", sortColumn);
        log.debug("sortDirection -->> {}", sortDirection);
        log.debug("fieldName0 -->> {}", fieldName0);
        log.debug("value0 -->> {}", value0);
        log.debug("type0 -->> {}", type0);
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
            if( c==null || jpaRepository==null ) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY_MESSAGE);
            } else {
                try {
                    Sort sort = null;
                    if(sortDirection.equals("desc"))
                        sort = Sort.by(sortColumn).descending();
                    else
                        sort = Sort.by(sortColumn).ascending();
                    Pageable pageable = PageRequest.of(page, size, sort);
                    String methodName = "findBy"+replaceParamToMenthod(fieldName)+"Between"+"And"+replaceParamToMenthod(fieldName0)+"And"+
                                                                                                  replaceParamToMenthod(fieldName1)+"And"+
                                                                                                  replaceParamToMenthod(fieldName2);
                    Object objectFrom = castObject(type,from);
                    Object objectTo = castObject(type,to);
                    if(objectFrom==null||objectTo==null) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_OBJECT_TYPE_CAST_ERROR);
                    } else {
                        Object resultObject = executeMethod(jpaRepository, methodName, objectFrom, objectTo, pageable, castObject(type0, value0), castObject(type1, value1), castObject(type2, value2));
                        if (resultObject == null) {
                            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                        } else {
                            PageImpl pageImpl = (PageImpl) resultObject;
                            if (pageImpl.getTotalPages()==0) {
                                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                            } else {
                                result.put(ConstantsDynamic.TAG_TOTAL_PAGE_SIZE, pageImpl.getTotalPages());
                                result.put(ConstantsDynamic.TAG_TOTAL_ELEMENT_SIZE, pageImpl.getTotalElements());
                                result.put(getArrayDomainName(c.getSimpleName()), resultObject);
                            }
                        }
                    }
                } catch (NoSuchMethodException e) {
                    log.error("DynamicSelectService get ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                }
            }
        } catch (IllegalArgumentException e) {
            log.error("DynamicSelectService get ",e);
            if (e.getMessage().indexOf("base64") != -1) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_DECRYPT_ERROR);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, "check url value (Encode base64 url value)");
            }
        } catch(Exception e) {
            log.error("DynamicSelectService get ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName, String from, String to, String type, Integer page, Integer size, String sortColumn, String sortDirection,
                                   String fieldName0, Object value0, String type0,
                                   String fieldName1, Object value1, String type1,
                                   String fieldName2, Object value2, String type2,
                                   String fieldName3, Object value3, String type3) {
        {

            log.debug("domainName -->> {}", domainName);
            log.debug("fieldName -->> {}", fieldName);
            log.debug("from -->> {}", from);
            log.debug("to -->> {}", to);
            log.debug("type -->> {}", type);
            log.debug("page -->> {}", page);
            log.debug("size -->> {}", size);
            log.debug("sortColumn -->> {}", sortColumn);
            log.debug("sortDirection -->> {}", sortDirection);
            log.debug("fieldName0 -->> {}", fieldName0);
            log.debug("value0 -->> {}", value0);
            log.debug("type0 -->> {}", type0);
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
                if( c==null || jpaRepository==null ) {
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY_MESSAGE);
                } else {
                    try {
                        Sort sort = null;
                        if(sortDirection.equals("desc"))
                            sort = Sort.by(sortColumn).descending();
                        else
                            sort = Sort.by(sortColumn).ascending();
                        Pageable pageable = PageRequest.of(page, size, sort);
                        String methodName = "findBy"+replaceParamToMenthod(fieldName)+"Between"+"And"+replaceParamToMenthod(fieldName0)+"And"+
                                                                                                      replaceParamToMenthod(fieldName1)+"And"+
                                                                                                      replaceParamToMenthod(fieldName2)+"And"+
                                                                                                      replaceParamToMenthod(fieldName3);
                        Object objectFrom = castObject(type,from);
                        Object objectTo = castObject(type,to);
                        if(objectFrom==null||objectTo==null) {
                            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_OBJECT_TYPE_CAST_ERROR);
                        } else {
                            Object resultObject = executeMethod(jpaRepository, methodName, objectFrom, objectTo, pageable, castObject(type0, value0), castObject(type1, value1), castObject(type2, value2), castObject(type3, value3));
                            if (resultObject == null) {
                                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                            } else {
                                PageImpl pageImpl = (PageImpl) resultObject;
                                if (pageImpl.getTotalPages()==0) {
                                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                                } else {
                                    result.put(ConstantsDynamic.TAG_TOTAL_PAGE_SIZE, pageImpl.getTotalPages());
                                    result.put(ConstantsDynamic.TAG_TOTAL_ELEMENT_SIZE, pageImpl.getTotalElements());
                                    result.put(getArrayDomainName(c.getSimpleName()), resultObject);
                                }
                            }
                        }
                    } catch (NoSuchMethodException e) {
                        log.error("DynamicSelectService get ",e);
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                        result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                    }
                }
            } catch (IllegalArgumentException e) {
                log.error("DynamicSelectService get ",e);
                if (e.getMessage().indexOf("base64") != -1) {
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_DECRYPT_ERROR);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, "check url value (Encode base64 url value)");
                }
            } catch(Exception e) {
                log.error("DynamicSelectService get ",e);
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
            }
            return result;
        }
    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName, String from, String to, String type, Integer page, Integer size, String sortColumn, String sortDirection,
                                   String fieldName0, Object value0, String type0,
                                   String fieldName1, Object value1, String type1,
                                   String fieldName2, Object value2, String type2,
                                   String fieldName3, Object value3, String type3,
                                   String fieldName4, Object value4, String type4) {

            log.debug("domainName -->> {}", domainName);
            log.debug("fieldName -->> {}", fieldName);
            log.debug("from -->> {}", from);
            log.debug("to -->> {}", to);
            log.debug("type -->> {}", type);
            log.debug("page -->> {}", page);
            log.debug("size -->> {}", size);
            log.debug("sortColumn -->> {}", sortColumn);
            log.debug("sortDirection -->> {}", sortDirection);
            log.debug("value0 -->> {}", value0);
            log.debug("type0 -->> {}", type0);
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
                if( c==null || jpaRepository==null ) {
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY_MESSAGE);
                } else {
                    try {
                        Sort sort = null;
                        if(sortDirection.equals("desc"))
                            sort = Sort.by(sortColumn).descending();
                        else
                            sort = Sort.by(sortColumn).ascending();
                        Pageable pageable = PageRequest.of(page, size, sort);
                        String methodName = "findBy"+replaceParamToMenthod(fieldName)+"Between"+"And"+replaceParamToMenthod(fieldName0)+"And"+
                                                                                                      replaceParamToMenthod(fieldName1)+"And"+
                                                                                                      replaceParamToMenthod(fieldName2)+"And"+
                                                                                                      replaceParamToMenthod(fieldName3)+"And"+
                                                                                                      replaceParamToMenthod(fieldName4);
                        Object objectFrom = castObject(type,from);
                        Object objectTo = castObject(type,to);
                        if(objectFrom==null||objectTo==null) {
                            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_OBJECT_TYPE_CAST_ERROR);
                        } else {
                            Object resultObject = executeMethod(jpaRepository, methodName, objectFrom, objectTo, pageable, castObject(type0, value0), castObject(type1, value1), castObject(type2, value2), castObject(type3, value3), castObject(type4, value4));
                            if (resultObject == null) {
                                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                            } else {
                                PageImpl pageImpl = (PageImpl) resultObject;
                                if (pageImpl.getTotalPages()==0) {
                                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                                } else {
                                    result.put(ConstantsDynamic.TAG_TOTAL_PAGE_SIZE, pageImpl.getTotalPages());
                                    result.put(ConstantsDynamic.TAG_TOTAL_ELEMENT_SIZE, pageImpl.getTotalElements());
                                    result.put(getArrayDomainName(c.getSimpleName()), resultObject);
                                }
                            }
                        }
                    } catch (NoSuchMethodException e) {
                        log.error("DynamicSelectService get ",e);
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                        result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                    }
                }
            } catch (IllegalArgumentException e) {
                log.error("DynamicSelectService get ",e);
                if (e.getMessage().indexOf("base64") != -1) {
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_DECRYPT_ERROR);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, "check url value (Encode base64 url value)");
                }
            } catch(Exception e) {
                log.error("DynamicSelectService get ",e);
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
            }
            return result;

    }

    @Override
    public Map<String, Object> get(String domainName, String fieldName, String from, String to, String type, Integer page, Integer size, String sortColumn, String sortDirection,
                                   String fieldName0, Object value0, String type0,
                                   String fieldName1, Object value1, String type1,
                                   String fieldName2, Object value2, String type2,
                                   String fieldName3, Object value3, String type3,
                                   String fieldName4, Object value4, String type4,
                                   String fieldName5, Object value5, String type5) {

        log.debug("domainName -->> {}", domainName);
        log.debug("fieldName -->> {}", fieldName);
        log.debug("from -->> {}", from);
        log.debug("to -->> {}", to);
        log.debug("type -->> {}", type);
        log.debug("page -->> {}", page);
        log.debug("size -->> {}", size);
        log.debug("sortColumn -->> {}", sortColumn);
        log.debug("sortDirection -->> {}", sortDirection);
        log.debug("value0 -->> {}", value0);
        log.debug("type0 -->> {}", type0);
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
        log.debug("fieldName5 -->> {}", fieldName5);
        log.debug("value5 -->> {}", value5);
        log.debug("type5 -->> {}", type5);

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
                    Sort sort = null;
                    if(sortDirection.equals("desc"))
                        sort = Sort.by(sortColumn).descending();
                    else
                        sort = Sort.by(sortColumn).ascending();
                    Pageable pageable = PageRequest.of(page, size, sort);
                    String methodName = "findBy"+replaceParamToMenthod(fieldName)+"Between"+"And"+replaceParamToMenthod(fieldName0)+"And"+
                            replaceParamToMenthod(fieldName1)+"And"+
                            replaceParamToMenthod(fieldName2)+"And"+
                            replaceParamToMenthod(fieldName3)+"And"+
                            replaceParamToMenthod(fieldName4)+"And"+
                            replaceParamToMenthod(fieldName5);
                    Object objectFrom = castObject(type,from);
                    Object objectTo = castObject(type,to);
                    if(objectFrom==null||objectTo==null) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_OBJECT_TYPE_CAST_ERROR);
                    } else {
                        Object resultObject = executeMethod(jpaRepository, methodName, objectFrom, objectTo, pageable, castObject(type0, value0), castObject(type1, value1), castObject(type2, value2), castObject(type3, value3), castObject(type4, value4), castObject(type5, value5));
                        if (resultObject == null) {
                            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                        } else {
                            PageImpl pageImpl = (PageImpl) resultObject;
                            if (pageImpl.getTotalPages()==0) {
                                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                            } else {
                                result.put(ConstantsDynamic.TAG_TOTAL_PAGE_SIZE, pageImpl.getTotalPages());
                                result.put(ConstantsDynamic.TAG_TOTAL_ELEMENT_SIZE, pageImpl.getTotalElements());
                                result.put(getArrayDomainName(c.getSimpleName()), resultObject);
                            }
                        }
                    }
                } catch (NoSuchMethodException e) {
                    log.error("DynamicSelectService get ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                }
            }
        } catch (IllegalArgumentException e) {
            log.error("DynamicSelectService get ",e);
            if (e.getMessage().indexOf("base64") != -1) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_DECRYPT_ERROR);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, "check url value (Encode base64 url value)");
            }
        } catch(Exception e) {
            log.error("DynamicSelectService get ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    //    @Override
    public Map<String, Object> select(String domainName1, String domainName2, String fieldName, Object value) {

        log.debug("domainName1 -->> {}", domainName1);
        log.debug("domainName2 -->> {}", domainName2);
        log.debug("fieldName -->> {}", fieldName);
        log.debug("value -->> {}", value);

        Map<String, Object> result = new HashMap<>();
        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_SUCCESS);

        try {
            String domainName = domainName1 + domainName2;
            Class c = findDomainClass(domainName);
            JpaRepository jpaRepository = findJpaRepository(domainName);
            if( c==null || jpaRepository==null ) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NOT_FOUND_JPA_REPOSITORY_MESSAGE);
            } else {
                try {
                    String methodName = "findBy"+replaceParamToMenthod(fieldName);
                    Object resultObject = executeMethod(jpaRepository, methodName, value);
                    if (resultObject == null ) {
                        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                    } else {
                        if( resultObject instanceof ArrayList ) {
                            ArrayList arrayList = (ArrayList)resultObject;
                            if( arrayList.size() == 0 ) {
                                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NOT_FOUND);
                            } else {
                                result.put(ConstantsDynamic.TAG_SIZE, arrayList.size() );
                                result.put(getArrayDomainName(c.getSimpleName()), resultObject);
                            }
                        } else {
                            result.put(getDomainName(c.getSimpleName()), resultObject);
                        }
                    }
                } catch (NoSuchMethodException e) {
                    log.error("DynamicSelectService get ",e);
                    result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                    result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE + " " + e.getMessage());
                }
//                }
            }
        } catch(Exception e) {
            log.error("DynamicSelectService get ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
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

    private String getArrayDomainName(String domainName) {
        String c1 = domainName.substring(0,1).toLowerCase();
        domainName = c1+domainName.substring(1,domainName.length());
        c1 = domainName.substring(domainName.length()-1,domainName.length());
        if(c1.equals("y"))
            domainName = domainName.substring(0,domainName.length()-1) + "ies";
        else
            domainName = domainName + "s";
        return domainName;
    }

    private String getDomainName(String domainName) {
        String c1 = domainName.substring(0,1).toLowerCase();
        domainName = c1+domainName.substring(1,domainName.length());
        return domainName;
    }
}

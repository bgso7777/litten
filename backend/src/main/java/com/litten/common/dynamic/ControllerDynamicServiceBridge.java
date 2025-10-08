package com.litten.common.dynamic;

import com.fasterxml.jackson.databind.JsonNode;
import lombok.extern.log4j.Log4j2;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.Map;

@Log4j2
@Service
public class ControllerDynamicServiceBridge {

    public ControllerDynamicServiceBridge() {
    }

    public Map<String, Object> findDomainById(String domainName, Object id) {
        Map<String, Object> result = new HashMap<>();
        try {
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicSelectService.class.getSimpleName()));
            result = externalHttpDynamicMethod.get(domainName,id);
        } catch (Exception e) {
            log.error("ConSerBridge findDomainById ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> findDomainByOneColumnBetween(String domainName, String columnName, String from, String to, String type) {
        Map<String, Object> result = new HashMap<>();
        try {
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicSelectService.class.getSimpleName()));
            result = externalHttpDynamicMethod.get(domainName,columnName,from,to,type);
        } catch (Exception e) {
            log.error("ConSerBridge findDomainByOneColumnBetween ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> findDomainByOneColumn(String domainName, String columnName1, Object value1, String type1) {
        Map<String, Object> result = new HashMap<>();
        try {
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicSelectService.class.getSimpleName()));
            result = externalHttpDynamicMethod.get(domainName,columnName1,value1,type1);
        } catch (Exception e) {
            log.error("ConSerBridge findDomainByOneColumn ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> findDomainByOneColumn(String domainName, String columnName1, Object value1, String type1, Integer page, Integer size, String sortColumn, String sortDirection) {
        Map<String, Object> result = new HashMap<>();
        try {
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicSelectService.class.getSimpleName()));
            result = externalHttpDynamicMethod.get(domainName,columnName1,value1,type1,page,size,sortColumn,sortDirection);
        } catch (Exception e) {
            log.error("ConSerBridge findDomainByOneColumn ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> findDomainByTwoColumn(String domainName, String columnName1, Object value1, String type1, String columnName2, Object value2, String type2) {
        Map<String, Object> result = new HashMap<>();
        try {
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicSelectService.class.getSimpleName()));
            result = externalHttpDynamicMethod.get(domainName,columnName1,value1,type1,columnName2,value2,type2);
        } catch (Exception e) {
            log.error("ConSerBridge findDomainByTwoColumn ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> findDomainByTwoColumn(String domainName, String columnName1, Object value1, String type1, String columnName2, Object value2, String type2, Integer page, Integer size, String sortColumn, String sortDirection) {
        Map<String, Object> result = new HashMap<>();
        try {
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicSelectService.class.getSimpleName()));
            result = externalHttpDynamicMethod.get(domainName,columnName1,value1,type1,columnName2,value2,type2,page,size,sortColumn,sortDirection);
        } catch (Exception e) {
            log.error("ConSerBridge findDomainByTwoColumn ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> findDomainByThreeColumn(String domainName, String columnName1, Object value1, String type1, String columnName2, Object value2, String type2, String columnName3, Object value3, String type3) {
        Map<String, Object> result = new HashMap<>();
        try {
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicSelectService.class.getSimpleName()));
            result = externalHttpDynamicMethod.get(domainName,columnName1,value1,type1,columnName2,value2,type2,columnName3,value3,type3);
        } catch (Exception e) {
            log.error("ConSerBridge findDomainByThreeColumn ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> findDomainByThreeColumn(String domainName, String columnName1, Object value1, String type1, String columnName2, Object value2, String type2, String columnName3, Object value3, String type3, Integer page, Integer size, String sortColumn, String sortDirection) {
        Map<String, Object> result = new HashMap<>();
        try {
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicSelectService.class.getSimpleName()));
            result = externalHttpDynamicMethod.get(domainName,columnName1,value1,type1,columnName2,value2,type2,columnName3,value3,type3,page,size,sortColumn,sortDirection);
        } catch (Exception e) {
            log.error("ConSerBridge findDomainByThreeColumn ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> findDomainByFourColumn(String domainName, String columnName1, Object value1, String type1, String columnName2, Object value2, String type2, String columnName3, Object value3, String type3, String columnName4, Object value4, String type4) {
        Map<String, Object> result = new HashMap<>();
        try {
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicSelectService.class.getSimpleName()));
            result = externalHttpDynamicMethod.get(domainName,columnName1,value1,type1,columnName2,value2,type2,columnName3,value3,type3,columnName4,value4,type4);
        } catch (Exception e) {
            log.error("ConSerBridge findDomainByThreeColumn ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> findDomainByFourColumn(String domainName, String columnName1, Object value1, String type1, String columnName2, Object value2, String type2, String columnName3, Object value3, String type3, String columnName4, Object value4, String type4, Integer page, Integer size, String sortColumn, String sortDirection) {
        Map<String, Object> result = new HashMap<>();
        try {
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicSelectService.class.getSimpleName()));
            result = externalHttpDynamicMethod.get(domainName,columnName1,value1,type1,columnName2,value2,type2,columnName3,value3,type3,columnName4,value4,type4,page,size,sortColumn,sortDirection);
        } catch (Exception e) {
            log.error("ConSerBridge findDomainByThreeColumn ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> findDomainByFiveColumn(String domainName, String columnName1, Object value1, String type1, String columnName2, Object value2, String type2, String columnName3, Object value3, String type3, String columnName4, Object value4, String type4, String columnName5, Object value5, String type5) {
        Map<String, Object> result = new HashMap<>();
        try {
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicSelectService.class.getSimpleName()));
            result = externalHttpDynamicMethod.get(domainName,columnName1,value1,type1,columnName2,value2,type2,columnName3,value3,type3,columnName4,value4,type4,columnName5,value5,type5);
        } catch (Exception e) {
            log.error("ConSerBridge findDomainByThreeColumn ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> findDomainByFiveColumn(String domainName, String columnName1, Object value1, String type1, String columnName2, Object value2, String type2, String columnName3, Object value3, String type3, String columnName4, Object value4, String type4, String columnName5, Object value5, String type5, Integer page, Integer size, String sortColumn, String sortDirection) {
        Map<String, Object> result = new HashMap<>();
        try {
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicSelectService.class.getSimpleName()));
            result = externalHttpDynamicMethod.get(domainName,columnName1,value1,type1,columnName2,value2,type2,columnName3,value3,type3,columnName4,value4,type4,columnName5,value5,type5,page,size,sortColumn,sortDirection);
        } catch (Exception e) {
            log.error("ConSerBridge findDomainByThreeColumn ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> findDomainBySixColumn(String domainName, String columnName1, Object value1, String type1, String columnName2, Object value2, String type2, String columnName3, Object value3, String type3, String columnName4, Object value4, String type4, String columnName5, Object value5, String type5, String columnName6, Object value6, String type6) {
        Map<String, Object> result = new HashMap<>();
        try {
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicSelectService.class.getSimpleName()));
            result = externalHttpDynamicMethod.get(domainName,columnName1,value1,type1,columnName2,value2,type2,columnName3,value3,type3,columnName4,value4,type4,columnName5,value5,type5,columnName6,value6,type6);
        } catch (Exception e) {
            log.error("ConSerBridge findDomainByThreeColumn ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> findDomainBySixColumn(String domainName, String columnName1, Object value1, String type1, String columnName2, Object value2, String type2, String columnName3, Object value3, String type3, String columnName4, Object value4, String type4, String columnName5, Object value5, String type5, String columnName6, Object value6, String type6, Integer page, Integer size, String sortColumn, String sortDirection) {
        Map<String, Object> result = new HashMap<>();
        try {
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicSelectService.class.getSimpleName()));
            result = externalHttpDynamicMethod.get(domainName,columnName1,value1,type1,columnName2,value2,type2,columnName3,value3,type3,columnName4,value4,type4,columnName5,value5,type5,columnName6,value6,type6,page,size,sortColumn,sortDirection);
        } catch (Exception e) {
            log.error("ConSerBridge findDomainByThreeColumn ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> findDomainByOneColumnAndOneColumnBetween(String domainName, String columnName1, Object value1, String type1, String columnName2, String from2, String to2, String type2) {
        Map<String, Object> result = new HashMap<>();
        try {
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicSelectService.class.getSimpleName()));
            result = externalHttpDynamicMethod.get(domainName,columnName1,value1,type1,columnName2,from2,to2,type2);
        } catch (Exception e) {
            log.error("ConSerBridge findDomainByOneColumnAndOneColumnBetween ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> findAllDomain(String domainName) {
        Map<String, Object> result = new HashMap<>();
        try {
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicSelectService.class.getSimpleName()));
            result = externalHttpDynamicMethod.get(domainName);
        } catch (Exception e) {
            log.error("ConSerBridge findAllDomain ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> findAllDomain(String domainName, int page, int size, String sortColumn, String sortDirection) {
        Map<String, Object> result = new HashMap<>();
        try {
//            domainName = domainName.substring(0,1).toUpperCase()+domainName.substring(1); // 첫글자 대문자
//            if(domainName.length()==domainName.lastIndexOf("s")+1)// 마지막 s 제거
//                domainName = domainName.substring(0,domainName.length()-1);
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicSelectService.class.getSimpleName()));
            result = externalHttpDynamicMethod.get(domainName,page,size,sortColumn,sortDirection);
        } catch (Exception e) {
            log.error("ConSerBridge findAllDomain ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> findAllDomain(String domainName, String columnName, String from, String to, String type, int page, int size, String sortColumn, String sortDirection) {
        Map<String, Object> result = new HashMap<>();
        try {
//            domainName = domainName.substring(0,1).toUpperCase()+domainName.substring(1); // 첫글자 대문자
//            if(domainName.length()==domainName.lastIndexOf("s")+1)// 마지막 s 제거
//                domainName = domainName.substring(0,domainName.length()-1);
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicSelectService.class.getSimpleName()));
            result = externalHttpDynamicMethod.get(domainName,columnName,from,to,type,page,size,sortColumn,sortDirection);
        } catch (Exception e) {
            log.error("ConSerBridge findAllDomain ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    private Map<String, Object> findDomain( String domainName, String fieldName, String from, String to, String type, Integer page, Integer size , String sortColumn, String sortDirection,
                                           String columnName0, Object value0, String type0,
                                           String columnName1, Object value1, String type1,
                                           String columnName2, Object value2, String type2,
                                           String columnName3, Object value3, String type3,
                                           String columnName4, Object value4, String type4,
                                           String columnName5, Object value5, String type5 ) {

        Map<String, Object> result = new HashMap<>();

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        if( page==null && size==null && value0==null && value1==null && value2==null && value3==null && value4==null && value5==null ) {

            result = findAllDomain(domainName);

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        } else if( page!=null && size!=null && value0==null && value1==null && value2==null && value3==null && value4==null && value5==null ) {

            result = findAllDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection);

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        } else if( value0!=null && value1==null && value2==null && value3==null && value4==null && value5==null ) {
            result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName0, value0, type0);
        } else if( value0==null && value1!=null && value2==null && value3==null && value4==null && value5==null ) {
            result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName1, value1, type1);
        } else if( value0==null && value1==null && value2!=null && value3==null && value4==null && value5==null ) {
            result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName2, value2, type2);
        } else if( value0==null && value1==null && value2==null && value3!=null && value4==null && value5==null ) {
            result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName3, value3, type3);
        } else if( value0==null && value1==null && value2==null && value3==null && value4!=null && value5==null ) {
            result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName4, value4, type4);
        } else if( value0==null && value1==null && value2==null && value3==null && value4==null && value5!=null ) {
            result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName5, value5, type5);

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        } else if( value0!=null && value1!=null && value2==null && value3==null && value4==null && value5==null ) {
            result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName0, value0, type0,
                    columnName1, value1, type1);
        } else if( value0!=null && value1==null && value2!=null && value3==null && value4==null && value5==null ) {
            result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName0, value0, type0,
                    columnName2, value2, type2);
        } else if( value0!=null && value1==null && value2==null && value3!=null && value4==null && value5==null ) {
            result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName0, value0, type0,
                    columnName3, value3, type3);
        } else if( value0!=null && value1==null && value2==null && value3==null && value4!=null && value5==null ) {
            result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName0, value0, type0,
                    columnName4, value4, type4);
        } else if( value0!=null && value1==null && value2==null && value3==null && value4==null && value5!=null ) {
            result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName0, value0, type0,
                    columnName5, value5, type5);

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        } else if( value0!=null && value1!=null && value2!=null && value3==null && value4==null && value5==null ) {
            result = findDomain( domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName0, value0, type0,
                    columnName1, value1, type1,
                    columnName2, value2, type2);
        } else if( value0!=null && value1!=null && value2==null && value3!=null && value4==null && value5==null ) {
            result = findDomain( domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName0, value0, type0,
                    columnName1, value1, type1,
                    columnName3, value3, type3);
        } else if( value0!=null && value1!=null && value2==null && value3==null && value4!=null && value5==null ) {
            result = findDomain( domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName0, value0, type0,
                    columnName1, value1, type1,
                    columnName4, value4, type4);
        } else if( value0!=null && value1!=null && value2==null && value3==null && value4==null && value5!=null ) {
            result = findDomain( domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName0, value0, type0,
                    columnName1, value1, type1,
                    columnName5, value5, type5);

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        } else if( value0!=null && value1==null && value2!=null && value3!=null && value4==null && value5==null ) {
            result = findDomain( domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName0, value0, type0,
                    columnName2, value2, type2,
                    columnName3, value3, type3);
        } else if( value0!=null && value1==null && value2!=null && value3==null && value4!=null && value5==null ) {
            result = findDomain( domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName0, value0, type0,
                    columnName2, value2, type2,
                    columnName4, value4, type4);
        } else if( value0!=null && value1==null && value2==null && value3!=null && value4!=null && value5==null ) {
            result = findDomain( domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName0, value0, type0,
                    columnName3, value3, type3,
                    columnName4, value4, type4);
        } else if( value0!=null && value1==null && value2==null && value3!=null && value4==null && value5!=null ) {
            result = findDomain( domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName0, value0, type0,
                    columnName3, value3, type3,
                    columnName5, value5, type5);

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        } else if( value0!=null && value1!=null && value2!=null && value3!=null && value4==null && value5==null ) {
            result = findDomain( domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName0, value0, type0,
                    columnName1, value1, type1,
                    columnName2, value2, type2,
                    columnName3, value3, type3);
        } else if( value0!=null && value1!=null && value2!=null && value3==null && value4!=null && value5==null ) {
            result = findDomain( domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName0, value0, type0,
                    columnName1, value1, type1,
                    columnName2, value2, type2,
                    columnName4, value4, type4);
        } else if( value0!=null && value1!=null && value2!=null && value3==null && value4==null && value5!=null ) {
            result = findDomain( domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName0, value0, type0,
                    columnName1, value1, type1,
                    columnName2, value2, type2,
                    columnName5, value5, type5);
        } else if( value0!=null && value1!=null && value2==null && value3!=null && value4!=null && value5==null ) {
            result = findDomain( domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName0, value0, type0,
                    columnName1, value1, type1,
                    columnName3, value3, type3,
                    columnName4, value4, type4);
        } else if( value0!=null && value1!=null && value2==null && value3!=null && value4==null && value5!=null ) {
            result = findDomain( domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName0, value0, type0,
                    columnName1, value1, type1,
                    columnName3, value3, type3,
                    columnName5, value5, type5);

        } else if( value0!=null && value1==null && value2!=null && value3!=null && value4!=null && value5==null ) {
            result = findDomain( domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName0, value0, type0,
                    columnName2, value2, type2,
                    columnName3, value3, type3,
                    columnName4, value4, type4);
        } else if( value0!=null && value1==null && value2!=null && value3!=null && value4==null && value5!=null ) {
            result = findDomain( domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName0, value0, type0,
                    columnName2, value2, type2,
                    columnName3, value3, type3,
                    columnName5, value5, type5);
        } else if( value0!=null && value1==null && value2==null && value3!=null && value4!=null && value5!=null ) {
            result = findDomain( domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName0, value0, type0,
                    columnName3, value3, type3,
                    columnName4, value4, type4,
                    columnName5, value5, type5);

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        } else if( value0!=null && value1!=null && value2!=null && value3!=null && value4!=null && value5==null ) {
            result = findDomain( domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName0, value0, type0,
                    columnName1, value1, type1,
                    columnName2, value2, type2,
                    columnName3, value3, type3,
                    columnName4, value4, type4);

        } else if( value0!=null && value1!=null && value2==null && value3!=null && value4!=null && value5!=null ) {
            result = findDomain( domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName0, value0, type0,
                    columnName1, value1, type1,
                    columnName3, value3, type3,
                    columnName4, value4, type4,
                    columnName5, value5, type5);

        } else if( value0!=null && value1!=null && value2!=null && value3!=null && value4==null && value5!=null ) {
            result = findDomain( domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName0, value0, type0,
                    columnName1, value1, type1,
                    columnName2, value2, type2,
                    columnName3, value3, type3,
                    columnName5, value5, type5);

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        } else if( value0!=null && value1!=null && value2!=null && value3!=null && value4!=null && value5!=null ) {
            result = findDomain( domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                    columnName0, value0, type0,
                    columnName1, value1, type1,
                    columnName2, value2, type2,
                    columnName3, value3, type3,
                    columnName4, value4, type4,
                    columnName5, value5, type5);

        } else {
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR_MESSAGE);
        }
        return result;
    }

    public Map<String, Object> findDomain( String domainName,
                                           Object id,
                                           String columnName0, Object value0, String type0,
                                           String columnName1, Object value1, String type1,
                                           String columnName2, Object value2, String type2,
                                           String columnName3, Object value3, String type3,
                                           String columnName4, Object value4, String type4,
                                           String columnName5, Object value5, String type5 ) {

        Map<String, Object> result = new HashMap<>();
        if( id!=null ) {

            result = findDomainById(domainName,id);

        } else {

            if (value0 != null && value1 == null && value2 == null && value3 == null && value4 == null && value5 == null) {
                result = findDomainByOneColumn(domainName, columnName0, value0, type0);
            } else if (value0 == null && value1 != null && value2 == null && value3 == null && value4 == null && value5 == null) {
                result = findDomainByOneColumn(domainName, columnName1, value1, type1);
            } else if (value0 == null && value1 == null && value2 != null && value3 == null && value4 == null && value5 == null) {
                result = findDomainByOneColumn(domainName, columnName2, value2, type2);
            } else if (value0 == null && value1 == null && value2 == null && value3 != null && value4 == null && value5 == null) {
                result = findDomainByOneColumn(domainName, columnName3, value3, type3);
            } else if (value0 == null && value1 == null && value2 == null && value3 == null && value4 != null && value5 == null) {
                result = findDomainByOneColumn(domainName, columnName4, value4, type4);
            } else if (value0 == null && value1 == null && value2 == null && value3 == null && value4 == null && value5 != null) {
                result = findDomainByOneColumn(domainName, columnName5, value5, type5);

                ////////////////////////////////////////////////////////////////////////////////////////////////////////////
            } else if (value0 != null && value1 != null && value2 == null && value3 == null && value4 == null && value5 == null) {
                result = findDomainByTwoColumn(domainName, columnName0, value0, type0, columnName1, value1, type1);
            } else if (value0 != null && value1 == null && value2 != null && value3 == null && value4 == null && value5 == null) {
                result = findDomainByTwoColumn(domainName, columnName0, value0, type0, columnName2, value2, type2);
            } else if (value0 != null && value1 == null && value2 == null && value3 != null && value4 == null && value5 == null) {
                result = findDomainByTwoColumn(domainName, columnName0, value0, type0, columnName3, value3, type3);
            } else if (value0 != null && value1 == null && value2 == null && value3 == null && value4 != null && value5 == null) {
                result = findDomainByTwoColumn(domainName, columnName0, value0, type0, columnName4, value4, type4);
            } else if (value0 != null && value1 == null && value2 == null && value3 == null && value4 == null && value5 != null) {
                result = findDomainByTwoColumn(domainName, columnName0, value0, type0, columnName5, value5, type5);

                ////////////////////////////////////////////////////////////////////////////////////////////////////////////
            } else if (value0 != null && value1 == null && value2 == null && value3 == null && value4 == null && value5 == null) {
                result = findDomainByOneColumn(domainName, columnName0, value0, type0);
            } else if (value0 == null && value1 != null && value2 == null && value3 == null && value4 == null && value5 == null) {
                result = findDomainByOneColumn(domainName, columnName1, value1, type1);
            } else if (value0 == null && value1 == null && value2 != null && value3 == null && value4 == null && value5 == null) {
                result = findDomainByOneColumn(domainName, columnName2, value2, type2);
            } else if (value0 == null && value1 == null && value2 == null && value3 != null && value4 == null && value5 == null) {
                result = findDomainByOneColumn(domainName, columnName3, value3, type3);
            } else if (value0 == null && value1 == null && value2 == null && value3 == null && value4 != null && value5 == null) {
                result = findDomainByOneColumn(domainName, columnName4, value4, type4);
            } else if (value0 == null && value1 == null && value2 == null && value3 == null && value4 == null && value5 != null) {
                result = findDomainByOneColumn(domainName, columnName5, value5, type5);

                ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
            } else if (value0 != null && value1 != null && value2 == null && value3 == null && value4 == null && value5 == null) {
                result = findDomainByTwoColumn(domainName,
                        columnName0, value0, type0,
                        columnName1, value1, type1);
            } else if (value0 != null && value1 == null && value2 != null && value3 == null && value4 == null && value5 == null) {
                result = findDomainByTwoColumn(domainName,
                        columnName0, value0, type0,
                        columnName2, value2, type2);
            } else if (value0 != null && value1 == null && value2 == null && value3 != null && value4 == null && value5 == null) {
                result = findDomainByTwoColumn(domainName,
                        columnName0, value0, type0,
                        columnName3, value3, type3);
            } else if (value0 != null && value1 == null && value2 == null && value3 == null && value4 != null && value5 == null) {
                result = findDomainByTwoColumn(domainName,
                        columnName0, value0, type0,
                        columnName4, value4, type4);
            } else if (value0 != null && value1 == null && value2 == null && value3 == null && value4 == null && value5 != null) {
                result = findDomainByTwoColumn(domainName,
                        columnName0, value0, type0,
                        columnName5, value5, type5);

                ////////////////////////////////////////////////////////////////////////////////////////////////////////////
            } else if (value0 != null && value1 != null && value2 != null && value3 == null && value4 == null && value5 == null) {
                result = findDomainByThreeColumn(domainName,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName2, value2, type2);
            } else if (value0 != null && value1 != null && value2 == null && value3 != null && value4 == null && value5 == null) {
                result = findDomainByThreeColumn(domainName,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName3, value3, type3);
            } else if (value0 != null && value1 != null && value2 == null && value3 == null && value4 != null && value5 == null) {
                result = findDomainByThreeColumn(domainName,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName4, value4, type4);
            } else if (value0 != null && value1 != null && value2 == null && value3 == null && value4 == null && value5 != null) {
                result = findDomainByThreeColumn(domainName,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName5, value5, type5);

                ////////////////////////////////////////////////////////////////////////////////////////////////////////////
            } else if (value0 != null && value1 == null && value2 != null && value3 != null && value4 == null && value5 == null) {
                result = findDomainByThreeColumn(domainName,
                        columnName0, value0, type0,
                        columnName2, value2, type2,
                        columnName3, value3, type3);
            } else if (value0 != null && value1 == null && value2 != null && value3 == null && value4 != null && value5 == null) {
                result = findDomainByThreeColumn(domainName,
                        columnName0, value0, type0,
                        columnName2, value2, type2,
                        columnName4, value4, type4);
            } else if (value0 != null && value1 == null && value2 == null && value3 != null && value4 != null && value5 == null) {
                result = findDomainByThreeColumn(domainName,
                        columnName0, value0, type0,
                        columnName3, value3, type3,
                        columnName4, value4, type4);
            } else if (value0 != null && value1 == null && value2 == null && value3 != null && value4 == null && value5 != null) {
                result = findDomainByThreeColumn(domainName,
                        columnName0, value0, type0,
                        columnName3, value3, type3,
                        columnName5, value5, type5);

                ////////////////////////////////////////////////////////////////////////////////////////////////////////////
            } else if (value0 != null && value1 != null && value2 != null && value3 != null && value4 == null && value5 == null) {
                result = findDomainByFourColumn(domainName,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName2, value2, type2,
                        columnName3, value3, type3);
            } else if (value0 != null && value1 != null && value2 != null && value3 == null && value4 != null && value5 == null) {
                result = findDomainByFourColumn(domainName,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName2, value2, type2,
                        columnName4, value4, type4);
            } else if (value0 != null && value1 != null && value2 != null && value3 == null && value4 == null && value5 != null) {
                result = findDomainByFourColumn(domainName,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName2, value2, type2,
                        columnName5, value5, type5);
            } else if (value0 != null && value1 != null && value2 == null && value3 != null && value4 != null && value5 == null) {
                result = findDomainByFourColumn(domainName,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName3, value3, type3,
                        columnName4, value4, type4);
            } else if (value0 != null && value1 != null && value2 == null && value3 != null && value4 == null && value5 != null) {
                result = findDomainByFourColumn(domainName,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName3, value3, type3,
                        columnName5, value5, type5);

            } else if (value0 != null && value1 == null && value2 != null && value3 != null && value4 != null && value5 == null) {
                result = findDomainByFourColumn(domainName,
                        columnName0, value0, type0,
                        columnName2, value2, type2,
                        columnName3, value3, type3,
                        columnName4, value4, type4);
            } else if (value0 != null && value1 == null && value2 != null && value3 != null && value4 == null && value5 != null) {
                result = findDomainByFourColumn(domainName,
                        columnName0, value0, type0,
                        columnName2, value2, type2,
                        columnName3, value3, type3,
                        columnName5, value5, type5);
            } else if (value0 != null && value1 == null && value2 == null && value3 != null && value4 != null && value5 != null) {
                result = findDomainByFourColumn(domainName,
                        columnName0, value0, type0,
                        columnName3, value3, type3,
                        columnName4, value4, type4,
                        columnName5, value5, type5);

                ////////////////////////////////////////////////////////////////////////////////////////////////////////////
            } else if (value0 != null && value1 != null && value2 != null && value3 != null && value4 != null && value5 == null) {
                result = findDomainByFiveColumn(domainName,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName2, value2, type2,
                        columnName3, value3, type3,
                        columnName4, value4, type4);

            } else if (value0 != null && value1 != null && value2 == null && value3 != null && value4 != null && value5 != null) {
                result = findDomainByFiveColumn(domainName,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName3, value3, type3,
                        columnName4, value4, type4,
                        columnName5, value5, type5);

            } else if (value0 != null && value1 != null && value2 != null && value3 != null && value4 == null && value5 != null) {
                result = findDomainByFiveColumn(domainName,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName2, value2, type2,
                        columnName3, value3, type3,
                        columnName5, value5, type5);

                ////////////////////////////////////////////////////////////////////////////////////////////////////////////
            } else if (value0 != null && value1 != null && value2 != null && value3 != null && value4 != null && value5 != null) {
                result = findDomainBySixColumn(domainName,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName2, value2, type2,
                        columnName3, value3, type3,
                        columnName4, value4, type4,
                        columnName5, value5, type5);

            } else {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR_MESSAGE);
            }
        }
        return result;
    }

    public Map<String, Object> findDomain( String domainName,
                                           Object id,
                                           String columnName0, Object value0, String type0,
                                           String columnName1, Object value1, String type1,
                                           String columnName2, Object value2, String type2,
                                           String columnName3, Object value3, String type3,
                                           String columnName4, Object value4, String type4,
                                           String columnName5, Object value5, String type5,
                                           Integer page, Integer size , String sortColumn, String sortDirection ) {

        Map<String, Object> result = new HashMap<>();
        if( id!=null ) {

            result = findDomainById(domainName,id);

        } else {

            if (page == null && size == null && value0 == null && value1 == null && value2 == null && value3 == null && value4 == null && value5 == null) {

                result = findAllDomain(domainName);

            ////////////////////////////////////////////////////////////////////////////////////////////////////////////
            } else if (page == null && size == null && value0 != null && value1 == null && value2 == null && value3 == null && value4 == null && value5 == null) {
                result = findDomainByOneColumn(domainName, columnName0, value0, type0);
            } else if (page == null && size == null && value0 == null && value1 != null && value2 == null && value3 == null && value4 == null && value5 == null) {
                result = findDomainByOneColumn(domainName, columnName1, value1, type1);
            } else if (page == null && size == null && value0 == null && value1 == null && value2 != null && value3 == null && value4 == null && value5 == null) {
                result = findDomainByOneColumn(domainName, columnName2, value2, type2);
            } else if (page == null && size == null && value0 == null && value1 == null && value2 == null && value3 != null && value4 == null && value5 == null) {
                result = findDomainByOneColumn(domainName, columnName3, value3, type3);
            } else if (page == null && size == null && value0 == null && value1 == null && value2 == null && value3 == null && value4 != null && value5 == null) {
                result = findDomainByOneColumn(domainName, columnName4, value4, type4);
            } else if (page == null && size == null && value0 == null && value1 == null && value2 == null && value3 == null && value4 == null && value5 != null) {
                result = findDomainByOneColumn(domainName, columnName5, value5, type5);

            ////////////////////////////////////////////////////////////////////////////////////////////////////////////
            } else if (page == null && size == null && value0 != null && value1 != null && value2 == null && value3 == null && value4 == null && value5 == null) {
                result = findDomainByTwoColumn(domainName, columnName0, value0, type0, columnName1, value1, type1);
            } else if (page == null && size == null && value0 != null && value1 == null && value2 != null && value3 == null && value4 == null && value5 == null) {
                result = findDomainByTwoColumn(domainName, columnName0, value0, type0, columnName2, value2, type2);
            } else if (page == null && size == null && value0 != null && value1 == null && value2 == null && value3 != null && value4 == null && value5 == null) {
                result = findDomainByTwoColumn(domainName, columnName0, value0, type0, columnName3, value3, type3);
            } else if (page == null && size == null && value0 != null && value1 == null && value2 == null && value3 == null && value4 != null && value5 == null) {
                result = findDomainByTwoColumn(domainName, columnName0, value0, type0, columnName4, value4, type4);
            } else if (page == null && size == null && value0 != null && value1 == null && value2 == null && value3 == null && value4 == null && value5 != null) {
                result = findDomainByTwoColumn(domainName, columnName0, value0, type0, columnName5, value5, type5);


            // page
            ////////////////////////////////////////////////////////////////////////////////////////////////////////////

            ////////////////////////////////////////////////////////////////////////////////////////////////////////////
            } else if (page != null && size != null && value0 == null && value1 == null && value2 == null && value3 == null && value4 == null && value5 == null) {

                result = findAllDomain(domainName, page, size, sortColumn, sortDirection);

            ////////////////////////////////////////////////////////////////////////////////////////////////////////////
            } else if (value0 != null && value1 == null && value2 == null && value3 == null && value4 == null && value5 == null) {
                result = findDomainByOneColumn(domainName, columnName0, value0, type0, page, size, sortColumn, sortDirection);
            } else if (value0 == null && value1 != null && value2 == null && value3 == null && value4 == null && value5 == null) {
                result = findDomainByOneColumn(domainName, columnName1, value1, type1, page, size, sortColumn, sortDirection);
            } else if (value0 == null && value1 == null && value2 != null && value3 == null && value4 == null && value5 == null) {
                result = findDomainByOneColumn(domainName, columnName2, value2, type2, page, size, sortColumn, sortDirection);
            } else if (value0 == null && value1 == null && value2 == null && value3 != null && value4 == null && value5 == null) {
                result = findDomainByOneColumn(domainName, columnName3, value3, type3, page, size, sortColumn, sortDirection);
            } else if (value0 == null && value1 == null && value2 == null && value3 == null && value4 != null && value5 == null) {
                result = findDomainByOneColumn(domainName, columnName4, value4, type4, page, size, sortColumn, sortDirection);
            } else if (value0 == null && value1 == null && value2 == null && value3 == null && value4 == null && value5 != null) {
                result = findDomainByOneColumn(domainName, columnName5, value5, type5, page, size, sortColumn, sortDirection);

            ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
            } else if (value0 != null && value1 != null && value2 == null && value3 == null && value4 == null && value5 == null) {
                result = findDomainByTwoColumn(domainName,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        page, size, sortColumn, sortDirection);
            } else if (value0 != null && value1 == null && value2 != null && value3 == null && value4 == null && value5 == null) {
                result = findDomainByTwoColumn(domainName,
                        columnName0, value0, type0,
                        columnName2, value2, type2,
                        page, size, sortColumn, sortDirection);
            } else if (value0 != null && value1 == null && value2 == null && value3 != null && value4 == null && value5 == null) {
                result = findDomainByTwoColumn(domainName,
                        columnName0, value0, type0,
                        columnName3, value3, type3,
                        page, size, sortColumn, sortDirection);
            } else if (value0 != null && value1 == null && value2 == null && value3 == null && value4 != null && value5 == null) {
                result = findDomainByTwoColumn(domainName,
                        columnName0, value0, type0,
                        columnName4, value4, type4,
                        page, size, sortColumn, sortDirection);
            } else if (value0 != null && value1 == null && value2 == null && value3 == null && value4 == null && value5 != null) {
                result = findDomainByTwoColumn(domainName,
                        columnName0, value0, type0,
                        columnName5, value5, type5,
                        page, size, sortColumn, sortDirection);

            ////////////////////////////////////////////////////////////////////////////////////////////////////////////
            } else if (value0 != null && value1 != null && value2 != null && value3 == null && value4 == null && value5 == null) {
                result = findDomainByThreeColumn(domainName,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName2, value2, type2,
                        page, size, sortColumn, sortDirection);
            } else if (value0 != null && value1 != null && value2 == null && value3 != null && value4 == null && value5 == null) {
                result = findDomainByThreeColumn(domainName,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName3, value3, type3,
                        page, size, sortColumn, sortDirection);
            } else if (value0 != null && value1 != null && value2 == null && value3 == null && value4 != null && value5 == null) {
                result = findDomainByThreeColumn(domainName,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName4, value4, type4,
                        page, size, sortColumn, sortDirection);
            } else if (value0 != null && value1 != null && value2 == null && value3 == null && value4 == null && value5 != null) {
                result = findDomainByThreeColumn(domainName,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName5, value5, type5,
                        page, size, sortColumn, sortDirection);

            ////////////////////////////////////////////////////////////////////////////////////////////////////////////
            } else if (value0 != null && value1 == null && value2 != null && value3 != null && value4 == null && value5 == null) {
                result = findDomainByThreeColumn(domainName,
                        columnName0, value0, type0,
                        columnName2, value2, type2,
                        columnName3, value3, type3,
                        page, size, sortColumn, sortDirection);
            } else if (value0 != null && value1 == null && value2 != null && value3 == null && value4 != null && value5 == null) {
                result = findDomainByThreeColumn(domainName,
                        columnName0, value0, type0,
                        columnName2, value2, type2,
                        columnName4, value4, type4,
                        page, size, sortColumn, sortDirection);
            } else if (value0 != null && value1 == null && value2 == null && value3 != null && value4 != null && value5 == null) {
                result = findDomainByThreeColumn(domainName,
                        columnName0, value0, type0,
                        columnName3, value3, type3,
                        columnName4, value4, type4,
                        page, size, sortColumn, sortDirection);
            } else if (value0 != null && value1 == null && value2 == null && value3 != null && value4 == null && value5 != null) {
                result = findDomainByThreeColumn(domainName,
                        columnName0, value0, type0,
                        columnName3, value3, type3,
                        columnName5, value5, type5,
                        page, size, sortColumn, sortDirection);

            ////////////////////////////////////////////////////////////////////////////////////////////////////////////
            } else if (value0 != null && value1 != null && value2 != null && value3 != null && value4 == null && value5 == null) {
                result = findDomainByFourColumn(domainName,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName2, value2, type2,
                        columnName3, value3, type3,
                        page, size, sortColumn, sortDirection);
            } else if (value0 != null && value1 != null && value2 != null && value3 == null && value4 != null && value5 == null) {
                result = findDomainByFourColumn(domainName,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName2, value2, type2,
                        columnName4, value4, type4,
                        page, size, sortColumn, sortDirection);
            } else if (value0 != null && value1 != null && value2 != null && value3 == null && value4 == null && value5 != null) {
                result = findDomainByFourColumn(domainName,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName2, value2, type2,
                        columnName5, value5, type5,
                        page, size, sortColumn, sortDirection);
            } else if (value0 != null && value1 != null && value2 == null && value3 != null && value4 != null && value5 == null) {
                result = findDomainByFourColumn(domainName,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName3, value3, type3,
                        columnName4, value4, type4,
                        page, size, sortColumn, sortDirection);
            } else if (value0 != null && value1 != null && value2 == null && value3 != null && value4 == null && value5 != null) {
                result = findDomainByFourColumn(domainName,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName3, value3, type3,
                        columnName5, value5, type5,
                        page, size, sortColumn, sortDirection);

            } else if (value0 != null && value1 == null && value2 != null && value3 != null && value4 != null && value5 == null) {
                result = findDomainByFourColumn(domainName,
                        columnName0, value0, type0,
                        columnName2, value2, type2,
                        columnName3, value3, type3,
                        columnName4, value4, type4,
                        page, size, sortColumn, sortDirection);
            } else if (value0 != null && value1 == null && value2 != null && value3 != null && value4 == null && value5 != null) {
                result = findDomainByFourColumn(domainName,
                        columnName0, value0, type0,
                        columnName2, value2, type2,
                        columnName3, value3, type3,
                        columnName5, value5, type5,
                        page, size, sortColumn, sortDirection);
            } else if (value0 != null && value1 == null && value2 == null && value3 != null && value4 != null && value5 != null) {
                result = findDomainByFourColumn(domainName,
                        columnName0, value0, type0,
                        columnName3, value3, type3,
                        columnName4, value4, type4,
                        columnName5, value5, type5,
                        page, size, sortColumn, sortDirection);

            ////////////////////////////////////////////////////////////////////////////////////////////////////////////
            } else if (value0 != null && value1 != null && value2 != null && value3 != null && value4 != null && value5 == null) {
                result = findDomainByFiveColumn(domainName,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName2, value2, type2,
                        columnName3, value3, type3,
                        columnName4, value4, type4,
                        page, size, sortColumn, sortDirection);

            } else if (value0 != null && value1 != null && value2 == null && value3 != null && value4 != null && value5 != null) {
                result = findDomainByFiveColumn(domainName,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName3, value3, type3,
                        columnName4, value4, type4,
                        columnName5, value5, type5,
                        page, size, sortColumn, sortDirection);

            } else if (value0 != null && value1 != null && value2 != null && value3 != null && value4 == null && value5 != null) {
                result = findDomainByFiveColumn(domainName,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName2, value2, type2,
                        columnName3, value3, type3,
                        columnName5, value5, type5,
                        page, size, sortColumn, sortDirection);

            ////////////////////////////////////////////////////////////////////////////////////////////////////////////
            } else if (value0 != null && value1 != null && value2 != null && value3 != null && value4 != null && value5 != null) {
                result = findDomainBySixColumn(domainName,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName2, value2, type2,
                        columnName3, value3, type3,
                        columnName4, value4, type4,
                        columnName5, value5, type5,
                        page, size, sortColumn, sortDirection);

            } else {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR_MESSAGE);
            }
        }
        return result;
    }



    public Map<String, Object> findDomain( String domainName, String fieldName, String from, String to, String type,
                                           Integer page, Integer size , String sortColumn, String sortDirection,
                                           Object id,
                                           String columnName0, Object value0, String type0,
                                           String columnName1, Object value1, String type1,
                                           String columnName2, Object value2, String type2,
                                           String columnName3, Object value3, String type3,
                                           String columnName4, Object value4, String type4,
                                           String columnName5, Object value5, String type5 ) {

        Map<String, Object> result = new HashMap<>();
        if (id != null) {

            result = findDomainById(domainName, id);

        } else {

            if (page == null && size == null && value0 == null && value1 == null && value2 == null && value3 == null && value4 == null && value5 == null) {

                result = findAllDomain(domainName);

            ////////////////////////////////////////////////////////////////////////////////////////////////////////////
            } else if (page != null && size != null && value0 == null && value1 == null && value2 == null && value3 == null && value4 == null && value5 == null) {

                result = findAllDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection);

            ////////////////////////////////////////////////////////////////////////////////////////////////////////////
            } else if (page != null && size != null && value0 != null && value1 == null && value2 == null && value3 == null && value4 == null && value5 == null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                        columnName0, value0, type0);
            } else if (page != null && size != null && value0 == null && value1 != null && value2 == null && value3 == null && value4 == null && value5 == null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                        columnName1, value1, type1);
            } else if (page != null && size != null && value0 == null && value1 == null && value2 != null && value3 == null && value4 == null && value5 == null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                        columnName2, value2, type2);
            } else if (page != null && size != null && value0 == null && value1 == null && value2 == null && value3 != null && value4 == null && value5 == null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                        columnName3, value3, type3);
            } else if (page != null && size != null && value0 == null && value1 == null && value2 == null && value3 == null && value4 != null && value5 == null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                        columnName4, value4, type4);
            } else if (page != null && size != null && value0 == null && value1 == null && value2 == null && value3 == null && value4 == null && value5 != null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                        columnName5, value5, type5);

            ////////////////////////////////////////////////////////////////////////////////////////////////////////////
            } else if (value0 != null && value1 != null && value2 == null && value3 == null && value4 == null && value5 == null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                                    columnName0, value0, type0,
                                    columnName1, value1, type1);
            } else if (value0 != null && value1 == null && value2 != null && value3 == null && value4 == null && value5 == null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                        columnName0, value0, type0,
                        columnName2, value2, type2);
            } else if (value0 != null && value1 == null && value2 == null && value3 != null && value4 == null && value5 == null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                        columnName0, value0, type0,
                        columnName3, value3, type3);
            } else if (value0 != null && value1 == null && value2 == null && value3 == null && value4 != null && value5 == null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                        columnName0, value0, type0,
                        columnName4, value4, type4);
            } else if (value0 != null && value1 == null && value2 == null && value3 == null && value4 == null && value5 != null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                        columnName0, value0, type0,
                        columnName5, value5, type5);

            ////////////////////////////////////////////////////////////////////////////////////////////////////////////
            } else if (value0 != null && value1 != null && value2 != null && value3 == null && value4 == null && value5 == null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName2, value2, type2);
            } else if (value0 != null && value1 != null && value2 == null && value3 != null && value4 == null && value5 == null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName3, value3, type3);
            } else if (value0 != null && value1 != null && value2 == null && value3 == null && value4 != null && value5 == null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName4, value4, type4);
            } else if (value0 != null && value1 != null && value2 == null && value3 == null && value4 == null && value5 != null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName5, value5, type5);

            ////////////////////////////////////////////////////////////////////////////////////////////////////////////
            } else if (value0 != null && value1 == null && value2 != null && value3 != null && value4 == null && value5 == null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                        columnName0, value0, type0,
                        columnName2, value2, type2,
                        columnName3, value3, type3);
            } else if (value0 != null && value1 == null && value2 != null && value3 == null && value4 != null && value5 == null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                        columnName0, value0, type0,
                        columnName2, value2, type2,
                        columnName4, value4, type4);
            } else if (value0 != null && value1 == null && value2 == null && value3 != null && value4 != null && value5 == null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                        columnName0, value0, type0,
                        columnName3, value3, type3,
                        columnName4, value4, type4);
            } else if (value0 != null && value1 == null && value2 == null && value3 != null && value4 == null && value5 != null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                        columnName0, value0, type0,
                        columnName3, value3, type3,
                        columnName5, value5, type5);

            ////////////////////////////////////////////////////////////////////////////////////////////////////////////
            } else if (value0 != null && value1 != null && value2 != null && value3 != null && value4 == null && value5 == null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName2, value2, type2,
                        columnName3, value3, type3);
            } else if (value0 != null && value1 != null && value2 != null && value3 == null && value4 != null && value5 == null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName2, value2, type2,
                        columnName4, value4, type4);
            } else if (value0 != null && value1 != null && value2 != null && value3 == null && value4 == null && value5 != null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName2, value2, type2,
                        columnName5, value5, type5);
            } else if (value0 != null && value1 != null && value2 == null && value3 != null && value4 != null && value5 == null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName3, value3, type3,
                        columnName4, value4, type4);
            } else if (value0 != null && value1 != null && value2 == null && value3 != null && value4 == null && value5 != null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName3, value3, type3,
                        columnName5, value5, type5);

            } else if (value0 != null && value1 == null && value2 != null && value3 != null && value4 != null && value5 == null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                        columnName0, value0, type0,
                        columnName2, value2, type2,
                        columnName3, value3, type3,
                        columnName4, value4, type4);
            } else if (value0 != null && value1 == null && value2 != null && value3 != null && value4 == null && value5 != null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                        columnName0, value0, type0,
                        columnName2, value2, type2,
                        columnName3, value3, type3,
                        columnName5, value5, type5);
            } else if (value0 != null && value1 == null && value2 == null && value3 != null && value4 != null && value5 != null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                        columnName0, value0, type0,
                        columnName3, value3, type3,
                        columnName4, value4, type4,
                        columnName5, value5, type5);

            ////////////////////////////////////////////////////////////////////////////////////////////////////////////
            } else if (value0 != null && value1 != null && value2 != null && value3 != null && value4 != null && value5 == null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName2, value2, type2,
                        columnName3, value3, type3,
                        columnName4, value4, type4);

            } else if (value0 != null && value1 != null && value2 == null && value3 != null && value4 != null && value5 != null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName3, value3, type3,
                        columnName4, value4, type4,
                        columnName5, value5, type5);

            } else if (value0 != null && value1 != null && value2 != null && value3 != null && value4 == null && value5 != null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName2, value2, type2,
                        columnName3, value3, type3,
                        columnName5, value5, type5);

            ////////////////////////////////////////////////////////////////////////////////////////////////////////////
            } else if (value0 != null && value1 != null && value2 != null && value3 != null && value4 != null && value5 != null) {
                result = findDomain(domainName, fieldName, from, to, type, page, size, sortColumn, sortDirection,
                        columnName0, value0, type0,
                        columnName1, value1, type1,
                        columnName2, value2, type2,
                        columnName3, value3, type3,
                        columnName4, value4, type4,
                        columnName5, value5, type5);

            } else {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_REQUEST_DATA_ERROR_MESSAGE);
            }
        }
        return result;
    }

    public Map<String, Object> findDomain(String domainName, String columnName, String from, String to, String type, int page, int size, String sortColumn, String sortDirection,
                                          String columnName1, Object value1, String type1) {
        Map<String, Object> result = new HashMap<>();
        try {
//            domainName = domainName.substring(0,1).toUpperCase()+domainName.substring(1); // 첫글자 대문자
//            if(domainName.length()==domainName.lastIndexOf("s")+1)// 마지막 s 제거
//                domainName = domainName.substring(0,domainName.length()-1);
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicSelectService.class.getSimpleName()));
            result = externalHttpDynamicMethod.get( domainName,columnName,from,to,type,page,size,sortColumn,sortDirection,
                                                    columnName1,value1,type1);
        } catch (Exception e) {
            log.error("ConSerBridge findDomain ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> findDomain(String domainName, String columnName, String from, String to, String type, int page, int size, String sortColumn, String sortDirection,
                                          String columnName1, Object value1, String type1,
                                          String columnName2, Object value2, String type2) {
        Map<String, Object> result = new HashMap<>();
        try {
//            domainName = domainName.substring(0,1).toUpperCase()+domainName.substring(1); // 첫글자 대문자
//            if(domainName.length()==domainName.lastIndexOf("s")+1)// 마지막 s 제거
//                domainName = domainName.substring(0,domainName.length()-1);
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicSelectService.class.getSimpleName()));
            result = externalHttpDynamicMethod.get( domainName,columnName,from,to,type,page,size,sortColumn,sortDirection,
                                                    columnName1,value1,type1,
                                                    columnName2,value2,type2);
        } catch (Exception e) {
            log.error("ConSerBridge findDomain ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> findDomain(String domainName, String columnName, String from, String to, String type, int page, int size, String sortColumn, String sortDirection,
                                          String columnName1, Object value1, String type1,
                                          String columnName2, Object value2, String type2,
                                          String columnName3, Object value3, String type3) {
        Map<String, Object> result = new HashMap<>();
        try {
//            domainName = domainName.substring(0,1).toUpperCase()+domainName.substring(1); // 첫글자 대문자
//            if(domainName.length()==domainName.lastIndexOf("s")+1)// 마지막 s 제거
//                domainName = domainName.substring(0,domainName.length()-1);
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicSelectService.class.getSimpleName()));
            result = externalHttpDynamicMethod.get( domainName,columnName,from,to,type,page,size,sortColumn,sortDirection,
                                                    columnName1,value1,type1,
                                                    columnName2,value2,type2,
                                                    columnName3,value3,type3);
        } catch (Exception e) {
            log.error("ConSerBridge findDomain ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> findDomain(String domainName, String columnName, String from, String to, String type, int page, int size, String sortColumn, String sortDirection,
                                          String columnName1, Object value1, String type1,
                                          String columnName2, Object value2, String type2,
                                          String columnName3, Object value3, String type3,
                                          String columnName4, Object value4, String type4) {
        Map<String, Object> result = new HashMap<>();
        try {
//            domainName = domainName.substring(0,1).toUpperCase()+domainName.substring(1); // 첫글자 대문자
//            if(domainName.length()==domainName.lastIndexOf("s")+1)// 마지막 s 제거
//                domainName = domainName.substring(0,domainName.length()-1);
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicSelectService.class.getSimpleName()));
            result = externalHttpDynamicMethod.get( domainName,columnName,from,to,type,page,size,sortColumn,sortDirection,
                                                    columnName1,value1,type1,
                                                    columnName2,value2,type2,
                                                    columnName3,value3,type3,
                                                    columnName4,value4,type4);
        } catch (Exception e) {
            log.error("ConSerBridge findDomain ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> findDomain(String domainName, String columnName, String from, String to, String type, int page, int size, String sortColumn, String sortDirection,
                                          String columnName1, Object value1, String type1,
                                          String columnName2, Object value2, String type2,
                                          String columnName3, Object value3, String type3,
                                          String columnName4, Object value4, String type4,
                                          String columnName5, Object value5, String type5) {
        Map<String, Object> result = new HashMap<>();
        try {
//            domainName = domainName.substring(0,1).toUpperCase()+domainName.substring(1); // 첫글자 대문자
//            if(domainName.length()==domainName.lastIndexOf("s")+1)// 마지막 s 제거
//                domainName = domainName.substring(0,domainName.length()-1);
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicSelectService.class.getSimpleName()));
            result = externalHttpDynamicMethod.get( domainName,columnName,from,to,type,page,size,sortColumn,sortDirection,
                    columnName1,value1,type1,
                    columnName2,value2,type2,
                    columnName3,value3,type3,
                    columnName4,value4,type4,
                    columnName5,value5,type5);
        } catch (Exception e) {
            log.error("ConSerBridge findDomain ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> findDomain(String domainName, String columnName, String from, String to, String type, int page, int size, String sortColumn, String sortDirection,
                                          String columnName1, Object value1, String type1,
                                          String columnName2, Object value2, String type2,
                                          String columnName3, Object value3, String type3,
                                          String columnName4, Object value4, String type4,
                                          String columnName5, Object value5, String type5,
                                          String columnName6, Object value6, String type6) {
        Map<String, Object> result = new HashMap<>();
        try {
//            domainName = domainName.substring(0,1).toUpperCase()+domainName.substring(1); // 첫글자 대문자
//            if(domainName.length()==domainName.lastIndexOf("s")+1)// 마지막 s 제거
//                domainName = domainName.substring(0,domainName.length()-1);
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicSelectService.class.getSimpleName()));
            result = externalHttpDynamicMethod.get( domainName,columnName,from,to,type,page,size,sortColumn,sortDirection,
                                                    columnName1,value1,type1,
                                                    columnName2,value2,type2,
                                                    columnName3,value3,type3,
                                                    columnName4,value4,type4,
                                                    columnName5,value5,type5,
                                                    columnName6,value6,type6);
        } catch (Exception e) {
            log.error("ConSerBridge findDomain ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> saveDomain(String domainName, Boolean isCheckAllowedClassValue, JsonNode requestBody) {
        Map<String, Object> result = new HashMap<>();
        try {
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicInsertService.class.getSimpleName()));
            result = externalHttpDynamicMethod.post(domainName,isCheckAllowedClassValue,requestBody);
        } catch (Exception e) {
            log.error("ConSerBridge saveDomain ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String,Object> updateDomainById(String domainName, Boolean isCheckAllowedClassValue, JsonNode requestBody, Object id) {
        Map<String, Object> result = new HashMap<>();
        try {
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicUpdateService.class.getSimpleName()));
            result = externalHttpDynamicMethod.patch(domainName,isCheckAllowedClassValue,requestBody,id);
        } catch (DataIntegrityViolationException e) { // TODO DynamicUpdateService에서 catch가 안됨 ??????
            log.error("ConSerBridge updateDomainById ",e);
            Throwable t = e.getCause();
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_ERROR);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_DATA_ERROR_MESSAGE + " " + ExceptionMessage.getMessage(e));
        } catch (Exception e) {
            log.error("ConSerBridge updateDomainById ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> updateDomainByOneColumn(String domainName, Boolean isCheckAllowedClassValue, JsonNode requestBody, String columnName, Object value, String type) {
        Map<String, Object> result = new HashMap<>();
        try {
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicUpdateService.class.getSimpleName()));
            result = externalHttpDynamicMethod.patch(domainName,isCheckAllowedClassValue,requestBody,columnName,value,type);
        } catch (DataIntegrityViolationException e) {
            log.error("ConSerBridge updateDomainByOneColumn ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_ERROR);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_DATA_ERROR_MESSAGE + " " + ExceptionMessage.getMessage(e));
        } catch (Exception e) {
            log.error("ConSerBridge updateDomainByOneColumn ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> updateDomainByTwoColumn(String domainName, Boolean isCheckAllowedClassValue, JsonNode requestBody, String columnName1, Object value1, String type1, String columnName2, Object value2, String type2) {
        Map<String, Object> result = new HashMap<>();
        try {
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicUpdateService.class.getSimpleName()));
            result = externalHttpDynamicMethod.patch(domainName,isCheckAllowedClassValue,requestBody,columnName1,value1,type1,columnName2,value2,type2);
        } catch (DataIntegrityViolationException e) {
            log.error("ConSerBridge updateDomainByOneColumn ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_ERROR);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_DATA_ERROR_MESSAGE + " " + ExceptionMessage.getMessage(e));
        } catch (Exception e) {
            log.error("ConSerBridge updateDomainByTwoColumn ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> updateDomainByThreeColumn(String domainName, Boolean isCheckAllowedClassValue, JsonNode requestBody, String columnName1, Object value1, String type1, String columnName2, Object value2, String type2, String columnName3, Object value3, String type3) {
        Map<String, Object> result = new HashMap<>();
        try {
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicUpdateService.class.getSimpleName()));
            result = externalHttpDynamicMethod.patch(domainName,isCheckAllowedClassValue,requestBody,columnName1,value1,type1,columnName2,value2,type2,columnName3,value3,type3);
        } catch (DataIntegrityViolationException e) {
            log.error("ConSerBridge updateDomainByOneColumn ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_ERROR);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_DATA_ERROR_MESSAGE + " " + ExceptionMessage.getMessage(e));
        } catch (Exception e) {
            log.error("ConSerBridge updateDomainByThreeColumn ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> updateDomainByFourColumn(String domainName, Boolean isCheckAllowedClassValue, JsonNode requestBody, String columnName1, Object value1, String type1, String columnName2, Object value2, String type2, String columnName3, Object value3, String type3, String columnName4, Object value4, String type4) {
        Map<String, Object> result = new HashMap<>();
        try {
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicUpdateService.class.getSimpleName()));
            result = externalHttpDynamicMethod.patch(domainName,isCheckAllowedClassValue,requestBody,columnName1,value1,type1,columnName2,value2,type2,columnName3,value3,type3,columnName4,value4,type4);
        } catch (DataIntegrityViolationException e) {
            log.error("ConSerBridge updateDomainByOneColumn ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_ERROR);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_DATA_ERROR_MESSAGE + " " + ExceptionMessage.getMessage(e));
        } catch (Exception e) {
            log.error("ConSerBridge updateDomainByFourColumn ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> deleteDomain(String domainName, Object id) {
        Map<String, Object> result = new HashMap<>();
        try {
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicDeleteService.class.getSimpleName()));
            result = externalHttpDynamicMethod.delete(domainName,id);
        } catch (DataIntegrityViolationException e) {
            log.error("ConSerBridge deleteDomain ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_ERROR);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_DATA_ERROR_MESSAGE + " " + ExceptionMessage.getMessage(e));
        } catch (Exception e) {
            log.error("ConSerBridge deleteDomain ", e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> deleteDomain(String domainName, JsonNode requestBody) {
        Map<String, Object> result = new HashMap<>();
        try {
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicDeleteService.class.getSimpleName()));
            result = externalHttpDynamicMethod.delete(domainName,requestBody);
        } catch (Exception e) {
            log.error("ConSerBridge deleteDomain ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> deleteDomainByOneColumn(String domainName, String field, Object value, String type) {
        Map<String, Object> result = new HashMap<>();
        try {
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicDeleteService.class.getSimpleName()));
            result = externalHttpDynamicMethod.delete(domainName,field,value,type);
        } catch (DataIntegrityViolationException e) {
            log.error("ConSerBridge deleteDomainByOneColumn ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_ERROR);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_DATA_ERROR_MESSAGE + " " + ExceptionMessage.getMessage(e));
        } catch (Exception e) {
            log.error("ConSerBridge deleteDomainByOneColumn ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }


    public Map<String, Object> deleteDomainByTwoColumn(String domainName, String columnName1, Object value1, String type1, String columnName2, Object value2, String type2) {
        Map<String, Object> result = new HashMap<>();
        try {
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicDeleteService.class.getSimpleName()));
            result = externalHttpDynamicMethod.delete(domainName,columnName1,value1,type1,columnName2,value2,type2);
        } catch (DataIntegrityViolationException e) {
            log.error("ConSerBridge deleteDomainByTwoColumn ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_ERROR);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_DATA_ERROR_MESSAGE + " " + ExceptionMessage.getMessage(e));
        } catch (Exception e) {
            log.error("ConSerBridge deleteDomainByTwoColumn ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> deleteDomainByThreeColumn(String domainName, String columnName1, Object value1, String type1, String columnName2, Object value2, String type2, String columnName3, Object value3, String type3) {
        Map<String, Object> result = new HashMap<>();
        try {
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicDeleteService.class.getSimpleName()));
            result = externalHttpDynamicMethod.delete(domainName,columnName1,value1,type1,columnName2,value2,type2,columnName3,value3,type3);
        } catch (DataIntegrityViolationException e) {
            log.error("ConSerBridge deleteDomainByThreeColumn ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_ERROR);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_DATA_ERROR_MESSAGE + " " + ExceptionMessage.getMessage(e));
        } catch (Exception e) {
            log.error("ConSerBridge deleteDomainByThreeColumn ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> deleteDomainByFourColumn(String domainName, String columnName1, Object value1, String type1, String columnName2, Object value2, String type2, String columnName3, Object value3, String type3, String columnName4, Object value4, String type4) {
        Map<String, Object> result = new HashMap<>();
        try {
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicDeleteService.class.getSimpleName()));
            result = externalHttpDynamicMethod.delete(domainName,columnName1,value1,type1,columnName2,value2,type2,columnName3,value3,type3,columnName4,value4,type4);
        } catch (DataIntegrityViolationException e) {
            log.error("ConSerBridge deleteDomainByFourColumn ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_DATA_ERROR);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_DATA_ERROR_MESSAGE + " " + ExceptionMessage.getMessage(e));
        } catch (Exception e) {
            log.error("ConSerBridge deleteDomainByFourColumn ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> countDomainByOneColumnBetweenAndOneColumn(String domainName, String betweenFieldName, Object from, Object to, String type, String fieldName1, Object value1, String type1) {
        Map<String, Object> result = new HashMap<>();
        try {
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicStatisticsService.class.getSimpleName()));
            result = externalHttpDynamicMethod.countBetweenAndOneColumn(domainName,betweenFieldName,from,to,type,fieldName1,value1,type1);
        } catch (Exception e) {
            log.error("ConSerBridge countBetweenAndTwoColumn ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    public Map<String, Object> countDomainByOneColumnBetweenAndTwoColumn(String domainName, String betweenFieldName, Object from, Object to, String type, String fieldName1, Object value1, String type1, String fieldName2, Object value2, String type2) {
        Map<String, Object> result = new HashMap<>();
        try {
            domainName = replaceParamToClassName(domainName);
            ExternalHttpDynamicMethod externalHttpDynamicMethod = (ExternalHttpDynamicMethod) BeanUtil.getBeanByClass(Class.forName(ConstantsDynamic.SERVICE_DYNAMIC_BASE_PACKAGE+ DynamicStatisticsService.class.getSimpleName()));
            result = externalHttpDynamicMethod.countBetweenAndTwoColumn(domainName,betweenFieldName,from,to,type,fieldName1,value1,type1,fieldName2,value2,type2);
        } catch (Exception e) {
            log.error("ConSerBridge countBetweenAndTwoColumn ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }

    private String replaceParamToClassName(String paraClassName) {
        try {
            paraClassName = paraClassName.substring(0, 1).toUpperCase() + paraClassName.substring(1);
            do {
                String temp1 = paraClassName.substring(0, paraClassName.indexOf("-"));
                temp1 = temp1.substring(0, 1).toUpperCase() + temp1.substring(1);
                String temp2 = paraClassName.substring(paraClassName.indexOf("-") + 1, paraClassName.length());
                temp2 = temp2.substring(0, 1).toUpperCase() + temp2.substring(1);
                paraClassName = temp1 + temp2;
            } while (paraClassName.indexOf("-") != -1);
        }catch(StringIndexOutOfBoundsException e){
//            e.printStackTrace();
        }catch(Exception e){
            e.printStackTrace();
        }
        return paraClassName;
    }

    public Map<String, Object> processCustomDynamicServiceMethod(String servicePackage, String serviceClassName, String method, String serviceMethodName, Object... args) {
        Map<String, Object> result = new HashMap<>();
        try {
            serviceClassName = replaceParamToClassName(serviceClassName);
            CustomDynamicHttpService externalHttpServiceMethod = (CustomDynamicHttpService) BeanUtil.getBeanByClass(Class.forName(servicePackage+serviceClassName));
            if( method.equals("get") )
                result = externalHttpServiceMethod.get(serviceMethodName,args);
            else if( method.equals("post") )
                result = externalHttpServiceMethod.post(serviceMethodName,args);
            else if( method.equals("put") )
                result = externalHttpServiceMethod.put(serviceMethodName,args);
            else if( method.equals("patch") )
                result = externalHttpServiceMethod.patch(serviceMethodName,args);
            else if( method.equals("delete") )
                result = externalHttpServiceMethod.delete(serviceMethodName,args);
            else if( method.equals("process") )
                result = externalHttpServiceMethod.process(serviceMethodName,args);
            else {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE);
            }
        } catch (DataIntegrityViolationException e) {
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_INSERT_METHOD);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ExceptionMessage.getMessage(e));
        } catch (Exception e) {
            log.error("ConSerBridge processCustomDynamicServiceMethod ",e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
        }
        return result;
    }
}

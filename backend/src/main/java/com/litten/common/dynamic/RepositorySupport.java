package com.litten.common.dynamic;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.*;
import lombok.extern.log4j.Log4j2;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.support.DefaultListableBeanFactory;
import org.springframework.boot.web.servlet.context.AnnotationConfigServletWebServerApplicationContext;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.support.Repositories;
import org.springframework.stereotype.Service;

import jakarta.annotation.PostConstruct;
import jakarta.persistence.EntityManager;
import java.lang.reflect.Method;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.*;

@Log4j2
@Service
abstract public class RepositorySupport {

    @Autowired
    protected EntityManager entityManager;

    @Autowired
    private AnnotationConfigServletWebServerApplicationContext applicationContext;

    public static Map<String, Map<String, Object>> entityRepositoryMap = new HashMap<>(); // EntityName, [EntityClass, RepositoryClass]

    public RepositorySupport() {
    }

    @PostConstruct
    public void postConstruct() {
        DefaultListableBeanFactory defaultListableBeanFactory = applicationContext.getDefaultListableBeanFactory();
//        Repositories repositories = new Repositories(defaultListableBeanFactory);
        Repositories repositories = new Repositories(applicationContext.getBeanFactory());

        Iterator<Class<?>> it = repositories.iterator();
        while (it.hasNext()) {
            Class<?> domainClass = it.next();
            if (Arrays.asList(ConstantsDynamic.EXCLUDE_REPOSITORY_CLASS).contains(domainClass.getSimpleName())) {   // 제외클래스
                continue;
            }
//            RepositoryInformation repositoryInformation = repositories.getRepositoryInformationFor(domainClass).get();
//            JpaEntityInformation jpaEntityInformation = JpaEntityInformationSupport.getEntityInformation(domainClass, entityManager);
//            EntityInformation entityInformation = repositories.getEntityInformationFor(domainClass);
//            log.info("{} / {} / {} / {}",
//                     domainClass.getPackage(),
//                     jpaEntityInformation.getEntityName(),
//                     jpaEntityInformation.getIdAttributeNames(),
//                     jpaEntityInformation.getIdType().getName());

            Repository repository = (Repository) repositories.getRepositoryFor(domainClass).get();
            entityRepositoryMap.put(domainClass.getSimpleName(), new HashMap<String, Object>() {
    //            entityRepositoryMap.put(domainClass.getSimpleName().toLowerCase(), new HashMap<String, Object>() { // domain name을 모두 소문자로
                {
                    put(ConstantsDynamic.KEY_DOMAIN_CLASS, domainClass);
                    put(ConstantsDynamic.KEY_REPOSITORY_INSTANCE, repository);
                }
            });
        }
    }

    public Class findDomainClass(String entityName) {
        if(entityRepositoryMap.get(entityName)==null) {
            return null;
        }
        return (Class) entityRepositoryMap.get(entityName).get(ConstantsDynamic.KEY_DOMAIN_CLASS);
    }

    public JpaRepository findJpaRepository(String entityName) {
        if(entityRepositoryMap.get(entityName)==null) {
            return null;
        }
        return (JpaRepository)entityRepositoryMap.get(entityName).get(ConstantsDynamic.KEY_REPOSITORY_INSTANCE);
    }

    public <T> T executeMethod(Object instance, String name, Object... args) throws Exception {
        Class<?>[] params = new Class<?>[args.length];
        for (int i = 0; i < args.length; i++) {
            params[i] = args[i].getClass();
        }
        Method method = instance.getClass().getMethod(name, params);
        return (T) method.invoke(instance, args);
    }

    public Object executeSetMethod(Object instance, String name, Object... args) throws Exception {
        Class<?>[] params = new Class<?>[args.length];
        for (int i = 0; i < args.length; i++) {
            params[i] = args[i].getClass();
        }
        Method method = instance.getClass().getMethod(name, params);
        method.invoke(instance, args);
        return instance;
    }

    public void initInsertValue(List<BaseEntity> objects) {
        objects.forEach(o -> {
            initInsertValue((BaseEntity)o);
        });
    }

    public void initUpdateValue(List<BaseEntity> objects) {
        objects.forEach(o -> {
            initUpdateValue((BaseEntity) o);
        });
    }

    public void initInsertValue(BaseEntity d) {
        d.setInsertDateTime(LocalDateTime.now());
    }

    public void initUpdateValue(BaseEntity d) {
        d.setUpdateDateTime(LocalDateTime.now());
    }

    public Object castObject(Object fieldValue) {
        Object o = null;
        if(fieldValue instanceof TextNode) {
            o = ((TextNode)fieldValue).asText();
        } else if(fieldValue instanceof IntNode) {
            o = ((IntNode)fieldValue).asInt();
        } else if(fieldValue instanceof DoubleNode) {
            o = ((DoubleNode)fieldValue).asDouble();
        } else if(fieldValue instanceof FloatNode) {
            o = ((FloatNode)fieldValue).asDouble();
        } else if(fieldValue instanceof BooleanNode) {
            o = ((BooleanNode)fieldValue).asBoolean();
        } else if(fieldValue instanceof LongNode) {
            o = ((BooleanNode)fieldValue).asLong();
        } else {
        }
        return o;
    }

    public Object castObject(String type, Object fieldValue) {
        if( type==null )
            return null;
        Object o = null;
        if(type.equals("s"))
            o = (String)fieldValue;
        else if(type.equals("i")) {
            try {
                o = Integer.parseInt((String) fieldValue);
            } catch(ClassCastException e) {
                o = (Integer)fieldValue;
            }
        }
        else if(type.equals("d"))
            o = Double.parseDouble((String)fieldValue);
        else if(type.equals("f"))
            o = Float.parseFloat((String)fieldValue);
        else if(type.equals("b"))
            o = Boolean.parseBoolean((String)fieldValue);
        else if(type.equals("l")) {
            try {
                if(fieldValue instanceof String)
                    o = Long.parseLong((String) fieldValue);
                else if(fieldValue instanceof Long)
                    o = ((Long) fieldValue).longValue();
                else if(fieldValue instanceof Integer)
                    o = ((Integer)fieldValue).intValue();
            } catch(Exception e) {
                e.printStackTrace();
            }
        }
        else if(type.indexOf("yyyy")!=-1||type.indexOf(":")!=-1) {
            if( type.equals("yyyyMMdd") || type.equals("yyyy-MM-dd") )
                o = LocalDate.parse((String)fieldValue, DateTimeFormatter.ofPattern(type));
            else
                o = LocalDateTime.parse((String)fieldValue, DateTimeFormatter.ofPattern(type));
        } else
            ;
        return o;
    }

    public Object castObjectV2(String type, Object fieldValue) {
        Object o = null;
        if(type.equals(ConstantsDynamic.TYPE_OF_STRING))
            o = (String)fieldValue;
        else if(type.equals(ConstantsDynamic.TYPE_OF_INTEGER)) {
            try {
                o = Integer.parseInt((String) fieldValue);
            } catch(ClassCastException e) {
                o = (Integer)fieldValue;
            }
        }
        else if(type.equals(ConstantsDynamic.TYPE_OF_DOUBLE))
            o = Double.parseDouble((String)fieldValue);
        else if(type.equals(ConstantsDynamic.TYPE_OF_FLOAT))
            o = Float.parseFloat((String)fieldValue);
        else if(type.equals(ConstantsDynamic.TYPE_OF_BOOLEAN))
            o = Boolean.parseBoolean((String)fieldValue);
        else if(type.equals(ConstantsDynamic.TYPE_OF_LONG)) {
            try {
                if(fieldValue instanceof String)
                    o = Long.parseLong((String) fieldValue);
                else if(fieldValue instanceof Long)
                    o = ((Long) fieldValue).longValue();
                else if(fieldValue instanceof Integer)
                    o = ((Integer)fieldValue).intValue();
            } catch(Exception e) {
                e.printStackTrace();
            }
        } else if(type.equals(ConstantsDynamic.TYPE_OF_DATETIME)) {
            o = LocalDateTime.parse((String) fieldValue, DateTimeFormatter.ofPattern(type));
        } else if(type.equals(ConstantsDynamic.TYPE_OF_DATE)) {
            o = LocalDate.parse((String) fieldValue, DateTimeFormatter.ofPattern(type));
        } else if(type.equals(ConstantsDynamic.TYPE_OF_TIME)) {
            o = LocalTime.parse((String)fieldValue, DateTimeFormatter.ofPattern(type));
        } else {
            ;
        }
        return o;
    }

    public PageRequest toPageRequest(Integer page, Integer size, String column, String direction) {
        Sort sort = toSort(column,direction);                           // sort : 정렬방식(sort=ename, asc&sort=sal, desc)
        return PageRequest.of(page, size, sort);
    }

    public Sort toSort(String column, String direction) {
        List<Sort.Order> orderList = new ArrayList<>();
        orderList.add(new Sort.Order(direction.equalsIgnoreCase("ASC") ? Sort.Direction.ASC : Sort.Direction.DESC, column));
        return Sort.by(orderList);
    }

    public PageRequest toPageRequest(JsonNode jsonNode) {
        Integer page = jsonNode.get("page").asInt(0);            // page : 검색을 원하는 페이지 번호(0부터 시작)
        Integer size = jsonNode.get("size").asInt(Integer.MAX_VALUE);       // size : 한페이지 개수
        if (size == -1)
            size = Integer.MAX_VALUE;                                       // size -1 설정 시 1개 행 최대 값 조회 : 실제로는 페이지당 최대행 수가 Integer.MAX_VALUE로 동작
        Sort sort = toSort(jsonNode.get("sort"));                           // sort : 정렬방식(sort=ename, asc&sort=sal, desc)
        return PageRequest.of(page, size, sort);
    }

    /**
     * TODO sort 배열 처리
     "pageable": {
     "page":page,
     "size":size,
     "sort":[
     {
     "column":"id",
     "direction":"DESC"
     }
     ]
     }
     * @param jsonNode
     * @return
     */
    public Sort toSort(JsonNode jsonNode) {
        ArrayNode sortList = (ArrayNode) jsonNode;
        List<Sort.Order> orderList = new ArrayList<>();
        if (sortList != null) {
            sortList.forEach(sort -> {
                String column = sort.get("column").asText();
                String direction = sort.get("direction").asText("ASC");
                if (column != null) {
                    orderList.add(new Sort.Order(direction.equalsIgnoreCase("ASC") ? Sort.Direction.ASC : Sort.Direction.DESC, column));
                }
            });
        }
        if (orderList.size() == 0) {
            orderList.add(new Sort.Order(Sort.Direction.DESC, "insertDate"));
        }
        return Sort.by(orderList);
    }

    public String replaceParamToMenthod(String paraFieldName) {
        try {
            do {
                String temp1 = paraFieldName.substring(0, 1).toUpperCase() + paraFieldName.substring(1);
                paraFieldName = temp1;
                temp1 = temp1.substring(0, temp1.indexOf("-"));
                String temp2 = paraFieldName.substring(paraFieldName.indexOf("-") + 1, paraFieldName.length());
                temp2 = temp2.substring(0, 1).toUpperCase() + temp2.substring(1);
                paraFieldName = temp1 + temp2;
            } while (paraFieldName.indexOf("-") != -1);
        }catch(StringIndexOutOfBoundsException e){
//            e.printStackTrace();
        }catch(Exception e){
            e.printStackTrace();
        }
//        if( paraFieldName.lastIndexOf("RegistDt")!=-1 ||
//            paraFieldName.lastIndexOf("ChangDt")!=-1 ||
//            paraFieldName.lastIndexOf("InsertDateTime")!=-1 ||
//            paraFieldName.lastIndexOf("UpdateDateTime")!=-1 )
//            paraFieldName = paraFieldName + "Between";
        return paraFieldName;
    }

    public String replaceParamToMenthod2(String paraFieldName) {
        try {
            do {
                String temp1 = paraFieldName.substring(0, paraFieldName.indexOf("-"));
                temp1 = temp1.substring(0, 1).toUpperCase() + temp1.substring(1);
                String temp2 = paraFieldName.substring(paraFieldName.indexOf("-") + 1, paraFieldName.length());
                temp2 = temp2.substring(0, 1).toUpperCase() + temp2.substring(1);
                paraFieldName = temp1 + temp2;
            } while (paraFieldName.indexOf("-") != -1);
        }catch(StringIndexOutOfBoundsException e){
//            e.printStackTrace();
        }catch(Exception e){
            e.printStackTrace();
        }
        paraFieldName = paraFieldName.substring(0, 1).toLowerCase() + paraFieldName.substring(1);
        return paraFieldName;
    }

    private String getDomainName(String domainName) {
        String c1 = domainName.substring(0,1).toLowerCase();
        domainName = c1+domainName.substring(1,domainName.length());
        c1 = domainName.substring(domainName.length()-1,domainName.length());
        if(c1.equals("y"))
            domainName = domainName.substring(0,domainName.length()-1) + "ies";
        else
            domainName = domainName + "s";
        return domainName;
    }
}

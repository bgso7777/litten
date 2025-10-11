package com.litten.common.dynamic;

import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import lombok.extern.log4j.Log4j2;
import org.json.JSONException;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;

import jakarta.persistence.Tuple;
import jakarta.persistence.TupleElement;
import java.util.*;
import java.util.stream.Collectors;
import java.util.stream.Stream;

@Log4j2
public class ObjectUtil {

    public static Thread getThread(String threadName) {
        Map<Thread, StackTraceElement[]> threadMap = Thread.getAllStackTraces();
        for (Thread t : threadMap.keySet())
            if( threadName!=null && t!=null && threadName.equals(t.getName()) )
                return t;
        return null;
    }

    public static boolean isExistThread(String threadName) {
        Map<Thread, StackTraceElement[]> threadMap = Thread.getAllStackTraces();
        for (Thread t : threadMap.keySet())
            if( threadName!=null && t!=null && threadName.equals(t.getName()) )
                return true;
        return false;
    }

    public static Object copy(Object sourceObject, Class c) {
        Object retObject = null;
        try {
            ObjectMapper objectMapper = new ObjectMapper();
            objectMapper.registerModule(new JavaTimeModule());
            String contactResultJsonString = objectMapper.writeValueAsString(sourceObject);
            retObject = objectMapper.readValue(contactResultJsonString, c);
        } catch(Exception e) {
            log.error(e);
        }
        return retObject;
    }

    public static JsonNode getJsonNode(Object object) {
        JsonNode jsonNode = null;
        ObjectMapper objectMapper = new ObjectMapper();
        if( object instanceof JSONObject ) {
            jsonNode = objectMapper.convertValue((JSONObject)object, JsonNode.class);
        } else if( object instanceof HashMap) {
            try {
                String jsonString = objectMapper.writeValueAsString((HashMap) object);
                jsonNode = objectMapper.convertValue(jsonString, JsonNode.class);
            } catch(Exception e) {
                log.error(e);
            }
        } else if( object instanceof String) {
            jsonNode = objectMapper.convertValue((String)object, JsonNode.class);
        } else {
        }
        return jsonNode;
    }

    public static Object[] getObjects(JsonNode orgJsonNode, Class c) {
        ObjectMapper objectMapper = new ObjectMapper().configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);
        objectMapper.registerModule(new JavaTimeModule());
        Object[] objects = new Object[0];
        try {
            ArrayNode arrayNode = (ArrayNode) objectMapper.treeToValue(orgJsonNode, ArrayNode.class);
            objects = new Object[arrayNode.size()];
            int i=0;
            for (JsonNode jsonNode : orgJsonNode) {
//                ObjectNode objectNode = jsonNode.deepCopy();
                Object object = (Object) objectMapper.treeToValue(jsonNode, c);
                if (object != null)
                    objects[i] = object;
                i++;
            }
        } catch(Exception e) {
            log.error(e);
        }
        return objects;
    }

    public static List<Object> getList(JsonNode orgJsonNode, Class c) {
        ObjectMapper objectMapper = new ObjectMapper().configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);
        objectMapper.registerModule(new JavaTimeModule());
        List<Object> arrayListObject = new ArrayList<Object>();
        try {
//            ArrayNode arrayNode = (ArrayNode) objectMapper.treeToValue(orgJsonNode, ArrayNode.class);
            for (JsonNode jsonNode : orgJsonNode) {
//                ObjectNode objectNode = jsonNode.deepCopy();
                Object object = (Object) objectMapper.treeToValue(jsonNode, c);
                if (object != null)
                    arrayListObject.add(object);
            }
        } catch(Exception e) {
            log.error(e);
        }
        return arrayListObject;
    }

    public static List<Map<String, Object>> castStreamTupleToListMap(Stream<Tuple> streamTuple) {
        List<Map<String, Object>> data =  streamTuple.map(t -> {
                    Map<String,Object> map = new HashMap<String,Object>();
                    int i = 0;
                    for( TupleElement el : t.getElements()) {
                        map.put( el.getAlias(), t.get( el.getAlias() ) ) ;
                        i++;
                    };
                    return map;
                }
        ).collect(Collectors.toList());
        return data;
    }


    public static Map<String, Object> toMap(JSONObject object) throws JSONException {
        Map<String, Object> map = new HashMap<String, Object>();
        @SuppressWarnings("rawtypes")
        Set keys = object.keySet();
        @SuppressWarnings("unchecked")
        Iterator<String> keysItr = keys.iterator();
        while(keysItr.hasNext()) {
            String key = keysItr.next();
            Object value = object.get(key);

            if(value instanceof JSONArray) {
                value = toList((JSONArray) value);
            }

            else if(value instanceof JSONObject) {
                value = toMap((JSONObject) value);
            }
            map.put(key, value);
        }
        return map;
    }

    public static List<Object> toList(JSONArray array) throws JSONException {
        List<Object> list = new ArrayList<Object>();
        for(int i = 0; i < array.size(); i++) {
            Object value = array.get(i);
            if(value instanceof JSONArray) {
                value = toList((JSONArray) value);
            }
            else if(value instanceof JSONObject) {
                value = toMap((JSONObject) value);
            }
            list.add(value);
        }
        return list;
    }

}

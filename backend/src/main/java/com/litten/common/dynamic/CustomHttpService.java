package com.litten.common.dynamic;

import lombok.extern.log4j.Log4j2;
import org.springframework.stereotype.Service;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.HashMap;
import java.util.Map;

@Log4j2
@Service
public class CustomHttpService extends RepositorySupport implements CustomDynamicHttpService {

    @Override
    public Map<String, Object> get(String methodName, Object... args) {
        Map<String, Object> result = new HashMap<>();
        boolean isFindMethod = false;
        try {
            Method[] methods = this.getClass().getDeclaredMethods();
            for (Method method : methods) {
                if( methodName.equals(method.getName()) && method.getParameters().length==args.length ) {
                    // TODO this.getClass().newInstance() 대체해야 함.
                    result = (Map<String, Object>) method.invoke(this.getClass().newInstance(),args);
                    isFindMethod = true;
                    break;
                }
            }
            if( !isFindMethod ) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE);
            }
        } catch(InvocationTargetException e) {
            log.error("InvocationTargetException in get method [" + methodName + "]", e);
            log.error("Real cause: ", e.getCause());
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_FAIL_MESSAGE);
        } catch(Exception e) {
            log.error("Exception in get method [" + methodName + "]", e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_FAIL_MESSAGE);
        }
        return result;
    }

    @Override
    public Map<String, Object> post(String methodName, Object... args) {
        Map<String, Object> result = new HashMap<>();
        boolean isFindMethod = false;
        try {
            Method[] methods = this.getClass().getDeclaredMethods();
            for (Method method : methods) {
                if( methodName.equals(method.getName()) && method.getParameters().length==args.length ) {
                    // TODO this.getClass().newInstance() 대체해야 함.
                    result = (Map<String, Object>) method.invoke(this.getClass().newInstance(),args);
                    isFindMethod = true;
                    break;
                }
            }
            if( !isFindMethod ) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE);
            }
        } catch(InvocationTargetException e) {
            log.error("InvocationTargetException in post method [" + methodName + "]", e);
            log.error("Real cause: ", e.getCause());
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_FAIL_MESSAGE);
        } catch(Exception e) {
            log.error("Exception in post method [" + methodName + "]", e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_FAIL_MESSAGE);
        }
        return result;
    }

    @Override
    public Map<String, Object> put(String methodName, Object... args) {
        Map<String, Object> result = new HashMap<>();
        boolean isFindMethod = false;
        try {
            Method[] methods = this.getClass().getDeclaredMethods();
            for (Method method : methods) {
                if( methodName.equals(method.getName()) && method.getParameters().length==args.length ) {
                    // TODO this.getClass().newInstance() 대체해야 함.
                    result = (Map<String, Object>) method.invoke(this.getClass().newInstance(),args);
                    isFindMethod = true;
                    break;
                }
            }
            if( !isFindMethod ) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE);
            }
        } catch(InvocationTargetException e) {
            log.error("InvocationTargetException in put method [" + methodName + "]", e);
            log.error("Real cause: ", e.getCause());
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_FAIL_MESSAGE);
        } catch(Exception e) {
            log.error("Exception in put method [" + methodName + "]", e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_FAIL_MESSAGE);
        }
        return result;
    }

    @Override
    public Map<String, Object> patch(String methodName, Object... args) {

        // TODO DAO별 가능 메소드 처리


        Map<String, Object> result = new HashMap<>();
        boolean isFindMethod = false;
        try {
            Method[] methods = this.getClass().getDeclaredMethods();
            for (Method method : methods) {
                if( methodName.equals(method.getName()) && method.getParameters().length==args.length ) {
                    // TODO this.getClass().newInstance() 대체해야 함.
                    result = (Map<String, Object>) method.invoke(this.getClass().newInstance(),args);
                    isFindMethod = true;
                    break;
                }
            }
            if( !isFindMethod ) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE);
            }
        } catch(InvocationTargetException e) {
            log.error("InvocationTargetException in patch method [" + methodName + "]", e);
            log.error("Real cause: ", e.getCause());
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_FAIL_MESSAGE);
        } catch(Exception e) {
            log.error("Exception in patch method [" + methodName + "]", e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_FAIL_MESSAGE);
        }
        return result;
    }

    @Override
    public Map<String, Object> delete(String methodName, Object... args) {
        Map<String, Object> result = new HashMap<>();
        boolean isFindMethod = false;
        try {
            Method[] methods = this.getClass().getDeclaredMethods();
            for (Method method : methods) {
                if( methodName.equals(method.getName()) && method.getParameters().length==args.length ) {
                    // TODO this.getClass().newInstance() 대체해야 함.
                    result = (Map<String, Object>) method.invoke(this.getClass().newInstance(),args);
                    isFindMethod = true;
                    break;
                }
            }
            if( !isFindMethod ) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE);
            }
        } catch(InvocationTargetException e) {
            log.error("InvocationTargetException in delete method [" + methodName + "]", e);
            log.error("Real cause: ", e.getCause());
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_FAIL_MESSAGE);
        } catch(Exception e) {
            log.error("Exception in delete method [" + methodName + "]", e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_FAIL_MESSAGE);
        }
        return result;
    }

    @Override
    public Map<String, Object> count(String methodName, Object... args) {
        Map<String, Object> result = new HashMap<>();
        boolean isFindMethod = false;
        try {
            Method[] methods = this.getClass().getDeclaredMethods();
            for (Method method : methods) {
                if( methodName.equals(method.getName()) && method.getParameters().length==args.length ) {
                    // TODO this.getClass().newInstance() 대체해야 함.
                    result = (Map<String, Object>) method.invoke(this.getClass().newInstance(),args);
                    isFindMethod = true;
                    break;
                }
            }
            if( !isFindMethod ) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE);
            }
        } catch(InvocationTargetException e) {
            log.error("InvocationTargetException in count method [" + methodName + "]", e);
            log.error("Real cause: ", e.getCause());
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_FAIL_MESSAGE);
        } catch(Exception e) {
            log.error("Exception in count method [" + methodName + "]", e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_FAIL_MESSAGE);
        }
        return result;
    }

    @Override
    public Map<String, Object> process(String methodName, Object... args) {
        return reflextionCustomServiceClass(methodName, args);
    }


    private Map<String, Object> reflextionCustomServiceClass(String methodName, Object... args) {
        Map<String, Object> result = new HashMap<>();
        boolean isFindMethod = false;
        try {
            Method[] methods = this.getClass().getDeclaredMethods();
            for (Method method : methods) {
                if( methodName.equals(method.getName()) && method.getParameters().length==args.length ) {
                    // TODO this.getClass().newInstance() 대체해야 함.
                    result = (Map<String, Object>) method.invoke(this.getClass().newInstance(),args);
                    isFindMethod = true;
                    break;
                }
            }
            if( !isFindMethod ) {
                result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_NO_SUCH_METHOD);
                result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_NO_SUCH_METHOD_MESSAGE);
            }
        } catch(InvocationTargetException e) {
            log.error("InvocationTargetException in reflextionCustomServiceClass [" + methodName + "]", e);
            log.error("Real cause: ", e.getCause());
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_FAIL_MESSAGE);
        } catch(Exception e) {
            log.error("Exception in reflextionCustomServiceClass [" + methodName + "]", e);
            result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_FAIL);
            result.put(ConstantsDynamic.TAG_RESULT_MESSAGE, ConstantsDynamic.RESULT_FAIL_MESSAGE);
        }
        return result;
    }

}

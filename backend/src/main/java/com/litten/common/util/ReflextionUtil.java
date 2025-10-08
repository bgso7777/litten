package com.litten.common.util;

import java.lang.reflect.Method;

public class ReflextionUtil {

    public ReflextionUtil() {
    }

    public <T> T executeMethod(String packageClassName, String name, Object... args) throws Exception {
        Class c = Class.forName(packageClassName);
        Object instance = c.newInstance();
        Class<?>[] params = new Class<?>[args.length];
        for (int i = 0; i < args.length; i++) {
            params[i] = args[i].getClass();
        }
        Method method = instance.getClass().getMethod(name, params);
        return (T) method.invoke(instance, args);
    }

    public <T> T executeMethod(Object instance, String name, Object... args) throws Exception {
        Class<?>[] params = new Class<?>[args.length];
        for (int i = 0; i < args.length; i++) {
            params[i] = args[i].getClass();
        }
        Method method = instance.getClass().getMethod(name, params);
        return (T) method.invoke(instance, args);
    }
}

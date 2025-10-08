package com.litten.common.dynamic;

import org.springframework.context.ApplicationContext;

public class BeanUtil {
    public static Object getBean(String bean){
        ApplicationContext applicationContext = ApplicationContectProvider.getApplicationContext();
        return applicationContext.getBean(bean);
    }

    public static Object getBeanByClass(Class packageName){
        ApplicationContext applicationContext = ApplicationContectProvider.getApplicationContext();
        return applicationContext.getBean(packageName);
    }

    public static <T>T getBean2(Class<T> type) {
        ApplicationContext applicationContext = ApplicationContectProvider.getApplicationContext();
        return applicationContext.getBean(type);
    }
}

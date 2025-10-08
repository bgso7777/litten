package com.litten.common.dynamic;

import org.hibernate.exception.ConstraintViolationException;
import org.springframework.dao.DataIntegrityViolationException;

import java.lang.reflect.InvocationTargetException;
import java.sql.SQLException;
import java.sql.SQLIntegrityConstraintViolationException;

public class ExceptionMessage {

    public static String getMessage(Exception e) {
        String message = "";
        SQLException result = null;
        Throwable throwable = e;
        while (throwable != null && !(throwable instanceof SQLException)) {
            throwable = throwable.getCause();
        }
        if (throwable instanceof SQLException) {
            result = (SQLException) throwable;
            message = result.getMessage();
            if( message.indexOf("Cannot")!=-1 && message.indexOf("constraint")!=-1 && message.indexOf("fails")!=-1 )
                message =  "테이블 제약조건 확인. " + message;
            else if( message.indexOf("Unknown")!=-1 && message.indexOf("column")!=-1 )
                message =  "알 수 없는 컬럼명. 변수명 확인. " + message;
            return message;
        }
        return result.getCause().getMessage();
    }

    public static String getMessage(SQLIntegrityConstraintViolationException e) {
        String message = "";
        SQLException result = null;
        Throwable throwable = e;
        while (throwable != null && !(throwable instanceof SQLException)) {
            throwable = throwable.getCause();
        }
        if (throwable instanceof SQLException) {
            result = (SQLException) throwable;
            message = result.getMessage();
            if( message.indexOf("Cannot")!=-1 && message.indexOf("constraint")!=-1 && message.indexOf("fails")!=-1 )
                message =  "테이블 제약조건 확인. " + message;
            else if( message.indexOf("Unknown")!=-1 && message.indexOf("column")!=-1 )
                message =  "알 수 없는 컬럼명. 변수명 확인. " + message;
            return message;
        }
        return result.getCause().getMessage();
    }

    public static String getMessage(DataIntegrityViolationException e) {
        String message = "";
        SQLException result = null;
        Throwable throwable = e;
        while (throwable != null && !(throwable instanceof SQLException)) {
            throwable = throwable.getCause();
        }
        if (throwable instanceof SQLException) {
            result = (SQLException) throwable;
            message = result.getMessage();
            if( message.indexOf("Cannot")!=-1 && message.indexOf("constraint")!=-1 && message.indexOf("fails")!=-1 )
                message =  "테이블 제약조건 확인. " + message;
            else if( message.indexOf("Unknown")!=-1 && message.indexOf("column")!=-1 )
                message =  "알 수 없는 컬럼명. 변수명 확인. " + message;
            return message;
        }
        return result.getCause().getMessage();
    }

    public static String getMessage(ConstraintViolationException e) {
        SQLException result = null;
        Throwable throwable = e;
        while (throwable != null && !(throwable instanceof SQLException)) {
            throwable = throwable.getCause();
        }
        if (throwable instanceof SQLException) {
            result = (SQLException) throwable;
            return result.getMessage();
        }
        return result.getCause().getMessage();
    }

    public static String getMessage(InvocationTargetException e) {
        String message = "";
        SQLException result = null;
        Throwable throwable = e;
        while (throwable != null && !(throwable instanceof SQLException)) {
            throwable = throwable.getCause();
        }
        if (throwable instanceof SQLException) {
            result = (SQLException) throwable;
            message = result.getMessage();
            if( message.indexOf("Cannot")!=-1 && message.indexOf("constraint")!=-1 && message.indexOf("fails")!=-1 )
                message =  "테이블 제약조건 확인. " + message;
            else if( message.indexOf("Unknown")!=-1 && message.indexOf("column")!=-1 )
                message =  "알 수 없는 컬럼명. 변수명 확인. " + message;
            return message;
        }
        return result.getCause().getMessage();
    }

}

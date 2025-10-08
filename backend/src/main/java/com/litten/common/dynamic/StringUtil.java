package com.litten.common.dynamic;

public class StringUtil {

    public static String getPathNameToDomainName(String urlPath) {
        if( urlPath.lastIndexOf("s")!=-1 ) {
            urlPath = urlPath.substring(0, urlPath.length() - 1);
        } else if( urlPath.lastIndexOf("ies")!=-1 ) {
            urlPath = urlPath.substring(0, urlPath.length() - 3);
        }
        return  urlPath;
    }

    public static String getTypeFromColumnName(Object id, String columnName) {
        if( id instanceof String )
            return ConstantsDynamic.TYPE_OF_STRING;
        if( id instanceof Long )
            return ConstantsDynamic.TYPE_OF_LONG;
        else {
            if (columnName.equals("id")) {
                return ConstantsDynamic.TYPE_OF_LONG;
            } else if (columnName.lastIndexOf("-id") != -1) {
                return ConstantsDynamic.TYPE_OF_LONG;
            } else if (columnName.lastIndexOf("-seq") != -1) {
                return ConstantsDynamic.TYPE_OF_LONG;
            }
        }
        return ConstantsDynamic.TYPE_OF_STRING;
    }
}


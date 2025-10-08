package com.litten.common.util;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Random;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class StringUtil {

    public static String replaceParamToClassName(String paraClassName) {
        try {
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

    public static String replaceParamToClassName2(String paraClassName) {
        try {
            if(paraClassName.indexOf("-")!=-1) {
                do {
                    String temp1 = paraClassName.substring(0, paraClassName.indexOf("-"));
                    temp1 = temp1.substring(0, 1).toUpperCase() + temp1.substring(1);
                    String temp2 = paraClassName.substring(paraClassName.indexOf("-") + 1, paraClassName.length());
                    temp2 = temp2.substring(0, 1).toUpperCase() + temp2.substring(1);
                    paraClassName = temp1 + temp2;
                } while (paraClassName.indexOf("-") != -1);
            } else {
                paraClassName = paraClassName.substring(0, 1).toUpperCase() + paraClassName.substring(1);
            }
        }catch(StringIndexOutOfBoundsException e){
//            e.printStackTrace();
        }catch(Exception e){
            e.printStackTrace();
        }
        return paraClassName;
    }

    public static String replaceParamToMenthod(String paraFieldName) {
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
        return paraFieldName;
    }

    public static String replaceParamToMenthod2(String paraFieldName) {
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

    public static String replaceParamToMenthod3(String paraFieldName) {
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
        return paraFieldName;
    }

    public static Object castObject(Object fieldValue, String type) {
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
            o = LocalDateTime.parse((String)fieldValue, DateTimeFormatter.ofPattern(type));
        } else
            ;
        return o;
    }

//    public static String getSignupKeycode() {
//        String ret = "T";
//        Random random = new Random(10);
//        int r = random.nextInt();
//        if(r<0)
//            r*=-1;
//        return ret+=r;
//    }
    public static String getSignupKeycode() {
        int length = 10;
        StringBuffer buffer = new StringBuffer("T");
        Random random = new Random();
        String chars[] = "1,2,3,4,5,6,7,8,9,0".split(",");
        for (int i = 0; i < length; i++) buffer.append(chars[random.nextInt(chars.length)]);
        return buffer.toString();
    }

    public static String getRandomString(int length) {
        StringBuffer buffer = new StringBuffer();
        Random random = new Random();
        String chars[] = "1,2,3,4,5,6,7,8,9,0,A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z".split(",");
        for (int i = 0; i < length; i++) buffer.append(chars[random.nextInt(chars.length)]);
        return buffer.toString();
    }

    public static boolean isDigit(String string) {
        if (string.matches("\\d+"))
            return true;
        return false;
    }

    public static boolean isMobile(String mobile){
        if(mobile==null||mobile.equals(""))
            return false;
        Pattern pattern = Pattern.compile("^\\d{3}-\\d{3,4}-\\d{4}$");
        return Pattern.matches("^01([0|1|6|7|8|9])-?([0-9]{3,4})-?([0-9]{4})$", mobile);
    }

    public static boolean isEmail(String email){
        boolean validation = false;
        if(email==null||email.equals("")){
            return false;
        }
        String regex = "^[a-zA-Z0-9_+&*-]+(?:\\.[a-zA-Z0-9_+&*-]+)*@(?:[a-zA-Z0-9-]+\\.)+[a-zA-Z]{2,7}$";
        Pattern p = Pattern.compile(regex);
        Matcher m = p.matcher(email);
        if(m.matches()) {
            validation = true;
        }
        return validation;
    }

    public static String getEmail(String uuid) {
        String retUuid = uuid;
        if( uuid!=null && uuid.length()>15 ) {
            retUuid = uuid.substring(uuid.lastIndexOf("-")+1,uuid.length()) + "@ploonet.com";
        }
        return retUuid;
    }

    public static void main(String[] argv) {
//String domainName = "Members";
//if(domainName.length()==domainName.lastIndexOf("s")+1);
//    domainName = domainName.substring(0,domainName.length()-1);
//System.out.println(domainName);
//        System.out.println( getSignupKeycode() );

//        System.out.println(isDigit("0100123569"));

//        System.out.println(replaceParamToClassName("member-temporary"));

//        System.out.println(getSignupKeycode());

//        System.out.println(replaceParamToClassName2("member"));

        System.out.println(isEmail("ASDFab_c-d@go-abc.ai"));
    }

}

package com.litten.common.dynamic;

import java.util.HashMap;
import java.util.Map;

public class ConstantsDynamic {

    public static final String KEY_DOMAIN_CLASS = "domainClass";
    public static final String KEY_REPOSITORY_INSTANCE = "repositoryInstance";
    public static final String[] EXCLUDE_REPOSITORY_CLASS = {};
//    public static final String SERVICE_BASE_PACKAGE = "com.saltlux.aice_fe.pc.conf.service.";
//    public static final String SERVICE_BASE_PACKAGE_PRE = "com.saltlux.aice_fe.pc.";
//    public static final String SERVICE_BASE_PACKAGE_POS = ".service.";
    public static final String SERVICE_DYNAMIC_BASE_PACKAGE = "com.saltlux.aice_fe.dynamic.";

    public static final String TYPE_OF_STRING = "s";
    public static final String TYPE_OF_DOUBLE = "d";
    public static final String TYPE_OF_FLOAT = "f";
    public static final String TYPE_OF_BOOLEAN = "b";
    public static final String TYPE_OF_LONG = "l";
    public static final String TYPE_OF_INTEGER = "i";
    public static final String TYPE_OF_OBJECT = "o";
    public static final String TYPE_OF_DATETIME = "yyyy-MM-dd HH:mm:ss";
    public static final String TYPE_OF_DATE = "yyyy-MM-dd";
    public static final String TYPE_OF_TIME = "HH:mm:ss";

    public static final String CODE_LOG_INSERT_QUERY = "L1101"; // 테이블 row 추가 코드
    public static final String CODE_LOG_SELECT_QUERY = "L1102"; // 테이블 row 조회 코드
    public static final String CODE_LOG_UPDATE_QUERY = "L1103"; // 테이블 row 수정 코드
    public static final String CODE_LOG_DELETE_QUERY = "L1104"; // 테이블 row 삭제 코드

    public static final String TAG_SIZE = "size";
    public static final String TAG_PAGE = "page";
    public static final String ORDER_ASCENDING = "asc";
    public static final String ORDER_DESCENDING = "desc";

    public static final String TAG_PREFIX_PATH = "prefixPath";
    public static final String TAG_RESULT_SUCCESS_COUNT = "resultSuccessCount";
    // RDB 테이블 로그 유형

    public static final String TAG_COUNT = "count";
    public static final String TAG_TOTAL_PAGE_SIZE = "totalPageSize";
    public static final String TAG_TOTAL_ELEMENT_SIZE = "totalElementSize";


    public static final String TAG_VERSION = "version";

    public static final String TAG_RESULT_MESSAGE = "message";
    public static final String TAG_RESULT_MESSAGE2 = "message2";
    public static final String TAG_RESULT_MESSAGE3 = "message3";
    public static final String TAG_RESULT = "result";
    public static final String TAG_RESULT2 = "result2";
    public static final String TAG_RESULT3 = "result3";

    public static final int RESULT_NOT_FOUND = 0;
    public static final String RESULT_NOT_FOUND_MESSAGE = "찾을 수 없음";
    public static final int RESULT_SUCCESS = 1;
    public static final int RESULT_FAIL = -1;
    public static final int RESULT_ALEADY_EXIST = 2;
    public static final String RESULT_ALEADY_EXIST_MESSAGE = "이미 존재함.";
    public static final String RESULT_FAIL_MESSAGE = "알 수 없는 에러";
    public static final int RESULT_NOT_SUPPORT_SERVICE = -2;
    public static final String RESULT_NOT_SUPPORT_SERVICE_MESSAGE = "지원되지 않는 클래스";
    public static final int RESULT_NOT_FOUND_JPA_REPOSITORY = -3;
    public static final String RESULT_NOT_FOUND_JPA_REPOSITORY_MESSAGE= "리포지토리 객체를 찾을 수 없음";
    public static final int RESULT_NO_SUCH_METHOD = -4;
    public static final String RESULT_NO_SUCH_METHOD_MESSAGE = "메소드를 찾을 수 없음.";
    public static final int RESULT_DOMAIN_CAST_ERROR = -5;
    public static final int RESULT_INSERT_METHOD = -6;
    public static final int RESULT_UPDATE_METHOD = -7;
    public static final int RESULT_NOT_ALLOWED_INSERT_ERROR = -8;
    public static final String RESULT_NOT_ALLOWED_INSERT_ERROR_MESSAGE = "저장 허락되지 않은 클래스의 변수";
    public static final int RESULT_NOT_ALLOWED_UPDATE_ERROR = -9;
    public static final String RESULT_NOT_ALLOWED_UPDATE_ERROR_MESSAGE = "업데이트 허락되지 않은 클래스의 변수";
    public static final int RESULT_AUTH_TOKEN_ROLE_ERROR = -10;
    public static final int RESULT_DATA_DECRYPT_ERROR = -11;
    public static final int RESULT_OBJECT_TYPE_CAST_ERROR = -12;
    public static final int RESULT_DELETE_METHOD = -13;

    public static final int RESULT_GROUP_BY_ERROR = -11;
    public static final int RESULT_SOLUTION_TYPE_ERROR = -12;
    public static final int RESULT_STATUS_CODE_ERROR = -13;
    public static final int RESULT_FROM_FORMAT_ERROR = -14;
    public static final int RESULT_TO_FORMAT_ERROR = -15;
    public static final int RESULT_FROM_TO_RANGE_ERROR = -16;

    public static final int RESULT_REQUEST_DATA_ERROR = -21;
    public static final String RESULT_REQUEST_DATA_ERROR_MESSAGE = "요청 파라미터를 오류.";
    public static final int RESULT_FORMAT_ERROR = -22;
    public static final String RESULT_FORMAT_ERROR_MESSAGE = "포멧 오류.";
    public static final int RESULT_DATA_ERROR = -23;
    public static final String RESULT_DATA_ERROR_MESSAGE = "요청 데이터 오류.";
    public static final int RESULT_VOICEGATEWAY_ERROR = -24;
    public static final String RESULT_VOICEGATEWAY_ERROR_MESSAGE = "voicegateway에서 에러가 발생했습니다.";
    public static final int RESULT_DATA_SIZE_ERROR = -25;
    public static final String RESULT_DATA_SIZE_ERROR_MESSAGE = "요청 데이터 크기 오류 (row 사이즈 초과) ";
    public static final int RESULT_DAY_SIZE_ERROR = -26;
    public static final String RESULT_DAY_SIZE_ERROR_MESSAGE = "요청일 크기 오류 (요청일 초과) ";
    public static final int RESULT_DATE_SIZE_ERROR = -27;
    public static final String RESULT_DATE_SIZE_ERROR_MESSAGE = "일자 오류 ";
    public static final int RESULT_TARGET_LIST__ERROR = -28;
    public static final String RESULT_TARGET_LIST__ERROR_MESSAGE = "발송 대상 ";

    public static final String TAG_IDS = "ids";
    public static final String TAG_ARRAY_SIZE = "arraySize";
    public static final String TAG_RESULT_SUCCESS_SIZE = "resultSuccessSize";

    public static Map<String,String> NOT_ALLOWED_INSERT_DAO_CLASS_VALUE  = new HashMap<String,String>() {{
//        put(Campaign.class.getSimpleName(), "status");
//        put(Campaign.class.getSimpleName(), "action");
    }};
    public static Map<String,String> NOT_ALLOWED_UPDATE_DAO_CLASS_VALUE = new HashMap<String,String>() {{
//        put(Campaign.class.getSimpleName(), "status");
//        put(Campaign.class.getSimpleName(), "action");
    }};
}

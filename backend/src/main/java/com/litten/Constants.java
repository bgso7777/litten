package com.litten;

public class Constants {

    public static final String ACTIVATE_ON_PROFILE_LOCAL = "local";
    public static final String ACTIVATE_ON_PROFILE_DEV = "dev";
    public static final String ACTIVATE_ON_PROFILE_IDC = "idc";
    public static final String ACTIVATE_ON_PROFILE_PROD = "prod";

    public static final String KEY_DOMAIN_CLASS = "domainClass";
    public static final String KEY_REPOSITORY_INSTANCE = "repositoryInstance";
    public static final String[] LIST_EXCLUDE_ENTITY = {"LogEvent", "VIplist"};
    public static final String SERVICE_BASE_PACKAGE = "com.aice.account.service.";

    public static final String PATH_OF_ANONYMOUS_PREFIX = "/account/anon/";
    public static final String PATH_OF_CHANGE_PASSWORD_PATH = "/members/change-password2";
    public static final String PAGE_CHANGEPASSWORD_STEP1 = "changepassword1";
    public static final String PAGE_CHANGEPASSWORD_STEP2 = "changepassword2";
    public static final String PAGE_CHANGEPASSWORD_STEP3 = "changepassword3";

    public static final String KEY_OF_CHANGE_PASSWORD_MEMBER_ID = "ksielwksmemberlksjdfliid";

    public static final int CHANGE_PASSWORD_DUE_MINUTE = 600;

    public static final String TEMP_ADMIN_MEMBER_ID_PREFIX = "7a9kq1_"; // admin login 구분자 서버 내부에서 쓰임

    public static final String ANONYMOUS_MEMBER_ID_PREFIX = "anonymous_";
    public static final String ANONYMOUS_PLAIN_PASSWORD = "kslsie21!";
    public static final String ANONYMOUS_CRYPTO_PASSWORD = "{bcrypt}$2a$10$vob88ane4Mt0kh9sqY74vOVtWpUl3luzZp61OahOQOyxxp/X8Wt42";

    public static final String TAG_HTTP_HEADER_AUTH_TOKEN = "auth-token";
    public static final String TAG_HTTP_HEADER_TOKEN_EXPIRED_DATE = "token-expired-date";
    public static final String TAG_HTTP_HEADER_JSON_CONTENT_TYPE = "application/json;charset=utf-8";

    public static final String TAG_DATE_PATTERN_OF_BILLING_DATE_TIME = "yyyy-MM-dd";
    public static final String TAG_DATE_PATTERN_OF_ADMIN_DISPLAY = "yyyy-MM-dd hh:mm:ss";
    public static final String TAG_DATE_PATTERN_YYYY_MM_DD_T_HH_MM_SS_SSS_Z = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
    public static final String TAG_DATE_PATTERN_YYYY_MM_DD_T_HH_MM_SS_SSS = "yyyy-MM-dd HH:mm:ss.SSS";
    public static final String TAG_DATE_PATTERN_YYYY_MM_DD_T_HH_MM_SS = "yyyy-MM-dd HH:mm:ss";
    public static final String TAG_STATISTICS_FROM_TO_DATE_PATTERN = "yyyy-MM-dd";
    public static final String TAG_DATE_PATTERN_YYYYMMDDHHMMSS = "yyyyMMddHHmmss";
    public static final String TAG_DATE_PATTERN_YYYYMMDD = "yyyyMMdd";

    public static final int RESULT_NOT_FOUND = 0;
    public static final String RESULT_NOT_FOUND_MESSAGE = "찾을 수 없음.";
    public static final int RESULT_SUCCESS = 1;
    public static final int RESULT_ALEADY_EXIST = 2;
    public static final int RESULT_ALEADY_EXIST_STOP = 2;
    public static final String RESULT_ALEADY_EXIST_MESSAGE = "이미 존재함.";
    public static final int RESULT_BAD_CREDENTIALS = 3;
    public static final int RESULT_NOT_SUPPORT = 4;
    public static final int RESULT_DUPLICATED = 5;
    public static final int RESULT_UNKNOWN = 6;
    public static final int RESULT_NOT_ALLOWD_ROLE = 7;
    public static final int RESULT_DATA_TYPE = 8;
    public static final int RESULT_DATA_VALUE = 9;
    public static final int RESULT_MEMBER_OF_STUDIO_SIGN_UP = 11;

    public static final int RESULT_FAIL = -1;
    public static final String RESULT_FAIL_MESSAGE = "알 수 없는 에러";
    public static final int RESULT_NOT_SUPPORT_SERVICE = -2;
    public static final int RESULT_NOT_FOUND_JPA_REPOSITORY = -3;
    public static final int RESULT_NO_SUCH_METHOD = -4;
    public static final int RESULT_DOMAIN_CAST_ERROR = -5;
    public static final int RESULT_INSERT_METHOD = -6;
    public static final int RESULT_UPDATE_METHOD = -7;
    public static final int RESULT_AUTH_TOKEN_ERROR = -8;
    public static final int RESULT_API_GETEWAY_ERROR = -9;
    public static final int RESULT_AUTH_TOKEN_ROLE_ERROR = -10;
    public static final int RESULT_DATA_DECRYPT_ERROR = -11;

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

    public static final Integer TYPE_REQUEST_PASSWORD_CHANGE_URL = 1;
    public static final Integer TYPE_REQUEST_PASSWORD_CHANGE = 2;

    public static final String SEPARATER_IPS = ",";

    // 계정유형 (개인,기업)
    public static final String CODE_USER_TYPE_COMPANY = "B2001";
    public static final String CODE_USER_TYPE_INDIVIDUAL = "B2002";

    // 가입경로
    public static final String CODE_SIGN_UP_PATH_WORKCENTER = "A3010"; // 워크센터(기존 가입자)
    public static final String CODE_SIGN_UP_PATH_STUDIO = "A3020"; // 스튜디오(기존 가입자(이관)

    public static final String CODE_SIGN_UP_PATH_WORKCENTER_COMPANY = "A3011"; // 워크센터 기업(기업 회원 가입)
    public static final String CODE_SIGN_UP_PATH_WORKCENTER_INDIVIDUAL = "A3012"; // 워크센터 개인(개인 회원 가입)
    public static final String CODE_SIGN_UP_PATH_STUDIO_COMPANY = "A3021"; // 스튜디오 기업(기업 회원 가입)
    public static final String CODE_SIGN_UP_PATH_STUDIO_INDIVIDUAL = "A3022"; // 스튜디오 개인(개인 회원 가입)
    public static final String CODE_SIGN_UP_PATH_STUDIO_INDIVIDUAL2 = "A3041"; // 스튜디오 개인(통합 회원 가입)
    public static final String CODE_SIGN_UP_PATH_INTEGRATED_INDIVIDUAL = "A3051"; // 브랜드 개인 추가
    public static final String CODE_SIGN_UP_PATH_INTEGRATED_COMPANY = "A3052"; // 브랜드 기업 추가
    public static final String CODE_SIGN_UP_PATH_HANDY_SECRETARY_INDIVIDUAL = "A3061"; // 손비서 개인 추가
    public static final String CODE_SIGN_UP_PATH_HANDY_SECRETARY_COMPANY = "A3062"; // 손비서 기업 추가

    public static final String CODE_SIGN_UP_PATH_QUICKSTART_WORKCENTER_COMPANY = "A3102"; // Quick Start워크센터 기업
    public static final String CODE_SIGN_UP_PATH_QUICKSTART_WORKCENTER_INDIVIDUAL = "A3101"; // Quick Start워크센터 개인
    public static final String CODE_SIGN_UP_PATH_QUICKSTART_STUDIO_COMPANY = "A3202"; // Quick Start스튜디오 기업
    public static final String CODE_SIGN_UP_PATH_QUICKSTART_STUDIO_INDIVIDUAL = "A3201"; // Quick Start스튜디오 개인
    public static final String CODE_SIGN_UP_PATH_QUICKSTART_METAHUMAN_COMPANY = "A3302"; // Quick Start메타휴먼 기업
    public static final String CODE_SIGN_UP_PATH_QUICKSTART_METAHUMAN_INDIVIDUAL = "A3301"; // Quick Start메타휴먼 개인

    public static final String CODE_SIGN_UP_PATH_QUICKSTART_BRAND_COMPANY = "A3502"; // Quick Start브랜드 기업
    public static final String CODE_SIGN_UP_PATH_QUICKSTART_BRAND_INDIVIDUAL = "A3501"; // Quick Start브랜드 개인
    public static final String CODE_SIGN_UP_PATH_QUICKSTART_HANDY_COMPANY = "A3602"; // Quick Start손비서 기업
    public static final String CODE_SIGN_UP_PATH_QUICKSTART_HANDY_INDIVIDUAL = "A3601"; // Quick Start손비서 개인

    public static final String CODE_SIGN_UP_PATH_SIMPLE_HANDY_INDIVIDUAL = "A3702"; // Simple 손비서 개인
    public static final String CODE_SIGN_UP_PATH_SIMPLE_HANDY_COMPANY = "A3701"; // Simple 손비서 기업

    public static final String CODE_SIGN_UP_PATH_SIMPLE_PHONE_OF_PEOPLE_INDIVIDUAL = "A3801"; // 전화의 민족 기업
    public static final String CODE_SIGN_UP_PATH_SIMPLE_PHONE_OF_PEOPLE_COMPANY = "A3802"; // 전화의 민족 개인

    public static final String CODE_SIGN_UP_PATH_SIMPLE_MIMECON_INDIVIDUAL = "A3901"; // 미미콘 개인
    public static final String CODE_SIGN_UP_PATH_SIMPLE_MIMECON_COMPANY = "A3902"; // 미미콘 기업

    public static final String CODE_SIGN_UP_PATH_GENWAVE_INDIVIDUAL = "A3401"; // 젠웨이브 개인

    public static final String CODE_SIGN_UP_PATH_AI_BUSINESS_CARD_INDIVIDUAL = "A3501"; // AI명함

    public static final String MOBILE_CODE_SIGN_UP_PATH_SIMPLE_HANDY_INDIVIDUAL = "01900000000";

    // 서비스
    public static final String CODE_SOLUTION_TYPE_OF_WORKCENTER = "B11";//워크센터
    public static final String CODE_SOLUTION_TYPE_OF_METAHUMAN = "B12";//메타휴먼
    public static final String CODE_SOLUTION_TYPE_OF_STUDIO = "B13";//스튜디오
    public static final String CODE_SOLUTION_TYPE_OF_HANDY = "B14";//손비서
    public static final String CODE_SOLUTION_TYPE_OF_BRAND = "B15";//브랜드
    public static final String CODE_SOLUTION_TYPE_OF_PHONE_OF_PEOPLE = "B16";//전화의 민족
    public static final String CODE_SOLUTION_TYPE_OF_MIMECON = "B17";//미미콘
    public static final String CODE_SOLUTION_TYPE_OF_GENWAVE = "B18";//젠웨이브
    public static final String CODE_SOLUTION_TYPE_OF_AI_BUSINESS_CARD = "B19";//AI명함

    // 회사 상태
    public static final String CODE_COMPANY_STATUS_SIGNUP_REQUEST = "A1604";//가입 요청
    public static final String CODE_COMPANY_STATUS_NORMAL = "A1601";//정상
    public static final String CODE_COMPANY_STATUS_STOP = "A1602";//정지
    public static final String CODE_COMPANY_STATUS_WHTHDRAWAL_REQUEST = "A1606";//탈퇴 요청
    public static final String CODE_COMPANY_STATUS_DORMANT = "A1605";//휴면
    public static final String CODE_COMPANY_STATUS_WHTHDRAWAL = "A1603";//탈퇴

    // 직원 계정 상태(B)
    public static final String CODE_MEMBER_STATUS_SIGNUP_REQUEST = "A1104"; // 가입 요청
    public static final String CODE_MEMBER_STATUS_NORMAL = "A1101"; // 정상
    public static final String CODE_MEMBER_STATUS_STOP = "A1102"; // 정지
    public static final String CODE_MEMBER_STATUS_DORMANT = "A1105";// 휴면
    public static final String CODE_MEMBER_STATUS_WITHDRAWAL_REQUEST = "A1106"; // 탈퇴 요청
    public static final String CODE_MEMBER_STATUS_WITHDRAWAL = "A1103"; // 탈퇴

    // 직원 구분
    public static final String CODE_LEVEL_MASTER = "A1001"; // 마스터
    public static final String CODE_LEVEL_MANAGER = "A1002"; // 매니저
    public static final String CODE_LEVEL_ASSIGNER = "A1003"; // 담당자  // TODO DB정리 시점에 삭제해야 함.
    public static final String CODE_LEVEL_STAFF = "A1004"; // 일반직원

    // 직원 응답 상태
    public static final String CODE_MEMBER_RESPONSE_ONLINE = "A1201"; // 온라인
    public static final String CODE_MEMBER_RESPONSE_MEETING = "A1202"; // 회의중
    public static final String CODE_MEMBER_RESPONSE_MISSED = "A1203"; // 부재중 Missed
    public static final String CODE_MEMBER_RESPONSE_VACATION = "A1204"; // 휴가 vacation
    public static final String CODE_MEMBER_RESPONSE_DO_NOT_DISTURB = "A1205"; // 방해금지
    public static final String CODE_MEMBER_RESPONSE_OUTSIDE_WORKING = "A1206"; // 외근
    public static final String CODE_MEMBER_RESPONSE_OFFLINE = "A1207"; // 오프라인

    // 이용동의 약관
    public static final String CODE_AGREE_STUDIO_CODE = "A1908"; // 스튜디오 서비스 이용동의

    // RDB 테이블 로그 유형
    public static final String CODE_LOG_INSERT_QUERY = "L1101"; // 테이블 row 추가 코드
    public static final String CODE_LOG_SELECT_QUERY = "L1102"; // 테이블 row 조회 코드
    public static final String CODE_LOG_UPDATE_QUERY = "L1103"; // 테이블 row 수정 코드
    public static final String CODE_LOG_DELETE_QUERY = "L1104"; // 테이블 row 삭제 코드
//    public static final String CODE_LOG_UPDATE_QUERY_PLOONIAN_RECOVERY = "L1105"; // 테이블 row 수정 코드 향후 플루니안 복구용

    public static final String CODE_LOG_CERTIFICATION_QUERY = "L1203"; // 테이블 row 인증 수정 코드
    public static final String CODE_LOG_CERTIFICATION_SUPER_QUERY = "L1903"; // 테이블 row 수퍼 인증 수정 코드

    // 브랜드
    public static final String CODE_BRAND_COMPANY = "M03B0";
    public static final String CODE_BRAND_INDIVIDUAL = "M03A0";

    // 롤백
    public static final Integer TYPE_OF_SIGNUP_ROLLBACK = 1; // 1 : 회원 가입,
    public static final Integer TYPE_OF_MEMBER_UPDATE_ROLLBACK = 2; // 2 : 회원 정보 수정
    public static final Integer TYPE_OF_MEMBER_PASSWORD_CHANGE_ROLLBACK = 3; // 3 : 회원 비밀번호 변경
    public static final Integer TYPE_OF_COMPANY_UPDATE_ROLLBACK = 4; // 4 : 기업 정보 수정
    public static final Integer TYPE_OF_MEMBER_STATUS_ROLLBACK = 5; // 5 : 회원 정보 수정
    public static final Integer TYPE_OF_COMPANY_STATUS_ROLLBACK = 6; // 6 : 기업 정보 수정

    // 봇
    public static final String BOT_TYPE_QUICK_START = "quick";
    public static final String BOT_TYPE_NOT_QUICK_START = "";

    public static final String CODE_MASTER = "Y"; // 마스터

    public static final String STRING_TRUE = "Y";
    public static final String STRING_FALSE = "N";

    public static final String CHARACTER_TRUE = "Y";
    public static final String CHARACTER_FALSE = "N";

    public static final String TAG_AUTH_TOKEN = "authToken";
    public static final String TAG_TOKEN_EXPIRED_DATE = "tokenExpiredDate";
    public static final String TAG_ID = "id";
    public static final String TAG_VERSION = "version";
    public static final String TAG_RESULT = "result";
    public static final String TAG_RESULT1 = "result1";
    public static final String TAG_RESULT2 = "result2";
    public static final String TAG_ERROR = "error";
    public static final String TAG_SIZE = "size";
    public static final String TAG_TOTAL_SIZE = "totalSize";
    public static final String TAG_PAGE = "page";
    public static final String TAG_RESULT_MESSAGE = "message";
    public static final String TAG_RESULT1_MESSAGE = "message1";
    public static final String TAG_RESULT2_MESSAGE = "message2";
    public static final String TAG_TYPE = "type";
    public static final String TAG_SIGN_UP_PATH_CODE = "signUpPathCode";
    public static final String TAG_REQUEST_SOURCE = "requestSource";
    public static final String TAG_JWT_MEMBER_ID = "sub";
    public static final String TAG_JWT_MEMBER_NAME = "real_name";
    public static final String TAG_JWT_ROLE = "auth";
    public static final String TAG_JWT_EXPIRED_DATE = "exp";
    public static final String TAG_MEMBER_ID = "memberId";
    public static final String TAG_MEMBER_IDS = "memberIds";
    public static final String TAG_PASSWORD = "password";
    public static final String TAG_MEMBER_SEQ = "memberSeq";
    public static final String TAG_MEMBER_AI_SEQ = "memberAiSeq";
    public static final String TAG_COMPANY_SEQ = "companySeq";
    public static final String TAG_COMPANY_ID = "companyId";
    public static final String TAG_COMPANY_NAME = "companyName";
    public static final String TAG_IS_COMPANY_ID = "isCompanyId";
    public static final String TAG_EMAIL = "email";
    public static final String TAG_NAME = "name";
    public static final String TAG_MOBILE = "mobile";
    public static final String TAG_MEMBER_USER_TYPE = "userType";

    public static final String TAG_DUE_DATE_TIME = "dueDateTime";
    public static final String TAG_PLAIN_DUE_DATE_TIME = "plainDueDateTime";
    public static final String TAG_PLAIN_MEMBER_ID = "plainMemberId";
    public static final String TAG_PASSWORD2 = "password2";
    public static final String TAG_PREFIX_PATH = "prefixPath";
    public static final String TAG_CONTENT = "content";
    public static final String TAG_FAIL_COUNT = "failCount";
    public static final String TAG_DUPLICATED_MEMBER_IDS = "duplicatedMemberIds";
    public static final String TAG_DUPLICATED_MEMBER_SIZE = "duplicatedMemberSize";
    public static final String TAG_MOVE_FAIL_MEMBER_SIZE = "moveFailMemberSize";
    public static final String TAG_MOVE_MEMBER_SIZE = "moveMemberSize";
    public static final String TAG_MOVE_FAIL_PK_AND_MEMBER_IDS = "moveFailPkAndMemberIds";
    public static final String TAG_RESULT_SUCESS_COUNT = "resultSucessCount";
    public static final String TAG_IS_ADMIN = "isAdmin";
    public static final String TAG_IS_STUDIO_MIGRATION_MEMBER = "isStudioMigrationMember";
    public static final String TAG_IS_CHANGE_PASSWORD = "isChangePassword";
    public static final String TAG_CHANGE_PASSWORD_DATE = "changePasswordDate";
    public static final String TAG_UUID = "uuid";

    public static final String TAG_IS_BRAND = "isBrand";
    public static final String TAG_MEMBER_TYPE_CD = "memberTypeCd";
    public static final String TAG_TERMS_INSERT_RESULT = "termsInsertResult";
    public static final String TAG_TERMS_UPDATE_RESULT = "termsUpdateResult";
    public static final String TAG_PLOONIAN_UPDATE_RESULT = "ploonianUpdateResult";

    // 기본 플루니안 설정 값
    ///////////////////////////////////////////////////////////////////////////////
    public static final String DEFAULT_PLOONIAN_MODEL_ID = "ff01";//"facef01";
    public static final String DEFAULT_PLOONIAN_MODEL_NM = "앨리";//"앨리스1"
    public static final String DEFAULT_PLOONIAN_STYLE_ID = "fc01";//"warem03
    public static final String DEFAULT_PLOONIAN_STYLE_NM = "여자의상1";//여성의상3
    // 플루니안이 ff...(여자)일 때 : 20, 플루니안이 mf..(남자)일 때 : 5
    public static final String DEFAULT_PLOONIAN_VOICE_ID = "20";//7
    public static final String DEFAULT_PLOONIAN_VOICE_NM = "";//적극적인
    ///////////////////////////////////////////////////////////////////////////////

    public static final String TAG_PLOONIAN_SEQ = "ploonianSeq";

    public static final String TAG_ROLLBACK_COMPANY_LOG_IDS = "rollbackCompanyLogIds";
    public static final String TAG_ROLLBACK_MEMBER_LOG_IDS = "rollbackMemberLogIds";
    public static final String TAG_ROLLBACK_COMPANY_IDS = "rollbackCompanyIds";
    public static final String TAG_ROLLBACK_BRAND_TERMS_LOG_IDS = "rollbackBrandTermsLogIds";
    public static final String TAG_ROLLBACK_PLOONIAN_LOG_IDS = "rollbackPloonianLogIds";

    public static final String TAG_RESULT_CLEAR_COMPANY_PHONE_NUMBER = "resultClearCompanyPhoneNumber";
    public static final String TAG_STATUS_CODE = "statusCode";
    public static final String TAG_JOB_OBJECT_ID = "jobObjectId";
    public static final String TAG_JOB_OBJECT_NAME = "jobObjectName";
    public static final String TAG_DORMANT_DATE_TIME = "dormantDateTime";
    public static final String TAG_NORMAL_DATE_TIME = "normalDateTime";
    public static final String TAG_SET_STATUS_CODE = "setStatusCode";

    public static final Integer TYPE_OF_FIND_PLAN_ALL = 1;
    public static final Integer TYPE_OF_FIND_PLAN_PAY = 2;
    public static final Integer TYPE_OF_FIND_PLAN_PAY_STATUS_NORMAL = 21;
    public static final Integer TYPE_OF_FIND_PLAN_FREE = 3;
    public static final Integer TYPE_OF_FIND_PLAN_FREE_STATUS_NORMAL = 31;

    public static final Integer TAG_QUICK_START_STATUS_NOT = -1;
    public static final Integer TAG_QUICK_START_STATUS_MEMBER_CREATED = 1;
    public static final Integer TAG_QUICK_START_STATUS_RUN = 2;
    public static final Integer TAG_QUICK_START_STATUS_END = 3;
    public static final Integer TAG_QUICK_START_BOT_STATUS_NOT_CREATED = -1;
    public static final Integer TAG_QUICK_START_BOT_STATUS_CREATED = 1;
    public static final String TAG_QUICK_START_STATUS = "quickStartStatus";
    public static final String TAG_QUICK_START_BOT_STATUS = "quickStartBotStatus";
    public static final String TAG_DNIS_PHONE_NUMBER = "dnisPhoneNumber";
    public static final String TAG_IS_OJT_COMPLETE = "isOjtComplete";
    public static final String TAG_FULL_DNIS = "fullDnis";
    public static final String TAG_QUICK_START_FROM = "quickStartFrom";
    public static final String TAG_QUICK_START_TO = "quickStartTo";
    public static final String TAG_VALUE = "value";

    public static final Integer TYPE_OF_INTERFACE_SYSTEM_VGW = 1;
    public static final Integer TYPE_OF_INTERFACE_SYSTEM_TALKBOT = 2;
    public static final Integer TYPE_OF_INTERFACE_SYSTEM_BOT_DISPLAY = 3;
    public static final Integer TYPE_OF_CHANGE_QUICK_START = 1;
    public static final Integer TYPE_OF_CHANGE_QUICK_START_STOP_AND_OJT = 2;
    public static final String TAG_PLOONIAN = "ploonian";
    public static final String TAG_PLOONIANS = "ploonians";
    public static final String TAG_AIS = "ais";
    public static final String TAG_BOT_DISPLAY_YN = "botDisplayYn";
    public static final String TAG_STAFFS = "staffs";
    public static final String TAG_IS_MOBILE = "isMobile";
    public static final String TAG_IS_EMAIL = "isEmail";
    public static final String TAG_SOLUTION_TYPE = "solutionType";
    public static final String TAG_CODE = "signCode";

    public static final String STATUS_ONLINE = "ONLINE";
    public static final String STATUS_OFFLINE = "OFFLINE";
    public static final String MODE_AIHANDY_ONLINE = "AIHANDY_MODE_ONLINE";
    public static final String MODE_AIHANDY_OFFLINE = "AIHANDY_MODE_OFFLINE";

    public static final Integer CHECK_MONTH_AI_HANDY = 3;
    public static final String TAG_NEW_MEMBER_ID = "newMemberId";

    public static final String TAG_RESULT_SUCCESS_COUNT = "resultSucessCount";

    public static final String TAG_IS_ALLOWD = "isAllowd";
    public static final String TAG_SAFE_PHONE_NUMBER = "safePhoneNumber";
    public static final String TAG_SEQUENCE = "sequence";
}

package com.litten.common.dao;

import com.litten.common.domain.Member;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

public interface MemberRepository extends JpaRepository<Member,Long> {

    List<Member> findByStatusCodeNotAndLevelCode(String statusCode, String levelCode);
    List<Member> findByUuidAndStatusCodeNot(String uuid, String statusCode);
    List<Member> findByCiAndStatusCodeNot(String ci, String statusCode);
    List<Member> findByMobileAndStatusCodeNot(String ci, String statusCode);
    List<Member> findByEmailAndStatusCodeNot(String ci, String statusCode);
    List<Member> findByNameAndMobileAndStatusCodeNot(String name, String mobile, String statusCode);
    List<Member> findByNameAndMobileAndCiAndStatusCodeNot(String name, String mobile, String ci, String statusCode);
    List<Member> findByMobileAndSolutionTypeAndStatusCodeAndLevelCode(String mobile, String solutionType, String statusCode, String levelCode);

    List<Member> findById(String memberId);
    List<Member> findByIdAndStatusCodeNot(String memberId, String statusCode);
    List<Member> findByIdAndStatusCodeIn(String memberId, String[] statusCode);
    List<Member> findByIdAndStatusCodeInAndLevelCode(String memberId, String[] statusCode, String levelCode);

//    Member findByIdAndStatusCode(String memberId, String statusCode);
//    Member findByUuidAndStatusCode(String uuid, String statusCode);
//
//    List<Member> findByCompanySeqAndStatusCodeNot(Long companySeq, String statusCode);
//    List<Member> findByCompanySeqAndSolutionTypeAndAi(Long companySeq, String statusCode, String ai);
//    List<Member> findByCompanySeqAndStatusCode(Long companySeq, String statusCode);
//    List<Member> findByCompanySeqAndSignUpPathCode(Long companySeq, String signUpPathCode);
//
//    List<Member> findByCompanySeq(Long companySeq);
//    Member findByCompanySeqAndCompanyMaster(Long companySeq, String companyMaster);
//    List<Member> findByCompanySeqAndAi(Long companySeq, String ai);
//    List<Member> findByCompanySeqAndAiOrDefaultAi(Long companySeq, String ai, String defaultAi);

//    List<Member> findByQuickStartStatus(int quickStartStatus);
//    List<Member> findByStatusCodeAndQuickStartStatus(String statusCode, int quickStartStatus);
//    List<Member> findByStatusCodeAndQuickStartStatusAndQuickStartTo(String statusCode, int quickStartStatus, LocalDate quickStartTo);
//    List<Member> findByStatusCodeAndQuickStartStatusAndQuickStartToLessThan(String statusCode, int quickStartStatus, LocalDate quickStartTo);
//    List<Member> findByStatusCodeInAndQuickStartStatusAndQuickStartToLessThan(String statusCode[], int quickStartStatus, LocalDate quickStartTo);

//    @Override
//    List<Member> findAll();

    @Override
    Page<Member> findAll(Pageable pageable);

    @Transactional
    int deleteById(String memberId);

    @Transactional
    int deleteByCompanySeq(Long companySeq);

    @Override
    <S extends Member> S save(S s);

//    @Query( value="SELECT m.pk_company_staff as memberSeq, m.fd_staff_id as memberId " +
//                  "FROM tbl_company_staff as m " +
//                  "WHERE fd_staff_status_code!='A1103' ",
//            nativeQuery=true)
//    ArrayList<MemberTemporaryVerify> findByAllMemberTemporaryVerify();

    @Query( nativeQuery=true, value=""+
                                    "SELECT * " +
                                    "FROM " +
                                    "    ( " +
                                    "    SELECT " +
                                    "        s.pk_company_staff AS memberSeq /*'회원PK'*/ , " +
                                    "        s.fd_regdate AS insertDate /*'계정생성일'*/ , " +
                                    "        s.fd_staff_id AS memberId /*'아이디'*/ , " +
                                    "        s.fd_staff_name AS name /*'가입자명'*/ , " +
                                    "        s.fd_staff_mobile AS mobile /*'핸드폰'*/ , " +
                                    "        s.fd_staff_phone AS phone /*'전화번호'*/ , " +
                                    "        s.fd_staff_email AS email /*'이메일'*/ , " +
                                    "        s.fd_staff_duty AS duty /*'직책'*/ , " +
                                    "        s.dept_disp_name AS department /*'부서'*/ , " +
                                    "        s.user_type AS userType /*'회사개인구분코드'*/ , " +
//                                    "        CASE " +
//                                    "                WHEN s.user_type='B2001' THEN '회사' " +
//                                    "                WHEN s.user_type='B2002' THEN '개인' " +
//                                    "                END AS userTypeStr /*'회사개인구분'*/ , " +
                                    "        s.solution_type AS solutionType /*'솔루션타입코드'*/ , " +
//                                    "        CASE " +
//                                    "                WHEN s.solution_type='B11' THEN '워크센터' " +
//                                    "                WHEN s.solution_type='B12' THEN '메타휴먼' " +
//                                    "                WHEN s.solution_type='B13' THEN '스튜디오' " +
//                                    "                WHEN s.solution_type='B14' THEN '손비서' " +
//                                    "                WHEN s.solution_type='B15' THEN '브랜드' " +
//                                    "                END AS solutionTypeStr /*'솔루션타입'*/ , " +
                                    "        s.fd_staff_level_code AS levelCode /*'레벨코드'*/ , " +
//                                    "        CASE " +
//                                    "                WHEN s.fd_staff_level_code='A1001' THEN '마스터' " +
//                                    "                WHEN s.fd_staff_level_code='A1002' THEN '매니저' " +
//                                    "                WHEN s.fd_staff_level_code='A1003' THEN '담당자' " +
//                                    "                WHEN s.fd_staff_level_code='A1004' THEN '일반직원' " +
//                                    "                END AS levelCodeStr /*'레벨'*/ , " +
                                    "        s.fd_staff_status_code AS statusCode /*'상태코드'*/ , " +
//                                    "        CASE " +
//                                    "                WHEN s.fd_staff_status_code='A1101' THEN '정상' " +
//                                    "                WHEN s.fd_staff_status_code='A1102' THEN '정지' " +
//                                    "                WHEN s.fd_staff_status_code='A1103' THEN '탈퇴' " +
//                                    "                END AS statusCodeStr /*'상태'*/ , " +
                                    "        s.fd_sign_up_path_code AS signUpPathCode /*'가입경로코드'*/ , " +
//                                    "        CASE " +
//                                    "                WHEN s.fd_sign_up_path_code IS NULL THEN '' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3010' THEN '워크센터' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3011' THEN '워크센터 기업' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3012' THEN '워크센터 개인' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3013' THEN '워크센터 개인 추가' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3020' THEN '스튜디오' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3021' THEN '스튜디오 기업' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3022' THEN '스튜디오 개인' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3023' THEN '스튜디오 개인 추가' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3030' THEN '워크센터 직원' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3031' THEN '워크센터 스튜디오 동시 사용' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3040' THEN '스튜디오 직원' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3041' THEN '스튜디오 워크센터 동시 사용' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3051' THEN '브랜드 통합 개인회원 가입' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3052' THEN '브랜드 통합 기업회원 가입' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3061' THEN '손비서 통합 개인회원 가입' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3062' THEN '손비서 통합 통합회원 가입' " +
//                                    "                END AS signUpPathCodeStr /*'가입경로'*/ , " +
                                    "        wp.free_yn AS freeYn, " +
//                                    "        CASE " +
//                                    "                WHEN wp.free_yn='Y' THEN '유료' " +
//                                    "                WHEN wp.free_yn='N' THEN '무료' " +
//                                    "                END AS freeYnStr /*'유무료'*/ , " +
                                    "        c.pk_company AS companySeq /*'회사PK'*/ , " +
                                    "        s.fd_regdate AS companyInsertDate /*'회사생성일'*/, " +
//                                    "        c.fd_regdate AS company_fd_regdate , " +
                                    "        c.fd_company_name AS companyName /*'회사명'*/ , " +
                                    "        c.fd_company_id AS companyId /*'회사아이디'*/ , " +
                                    "        (ROW_NUMBER() OVER(PARTITION BY c.pk_company, s.pk_company_staff ORDER BY wl.fd_regdate DESC)) AS rowNumber " +
                                    "    FROM " +
                                    "    tbl_company c " +
                                    "    LEFT JOIN " +
                                    "    tbl_company_staff s " +
                                    "    ON c.pk_company=s.fk_company " +
                                    "    LEFT JOIN " +
                                    "    tbl_wallet_pp_card wl " +
                                    "    ON c.pk_company=wl.fk_company " +
                                    "    LEFT JOIN " +
                                    "    tbl_wallet_policy_pp_card wp " +
                                    "    ON wl.pp_card_cd=wp.pp_card_cd " +
                                    "    WHERE 1=1 " +
                                    "          AND s.fd_default_ai='N' " +
                                    "          AND s.fd_regdate BETWEEN ? AND ? " +
//                                    "          ORDER BY c.pk_company DESC, s.pk_company_staff DESC " +
                                    "   ) r1 " +
                                    "WHERE 1=1 " +
                                    "    AND r1.rowNumber=1 " +
                                    "    GROUP BY memberSeq ",
                                countQuery=
                                    "SELECT COUNT(s.pk_company_staff) " +
                                    "FROM " +
                                    "    tbl_company c " +
                                    "    LEFT JOIN " +
                                    "    tbl_company_staff s " +
                                    "    ON c.pk_company=s.fk_company " +
                                    "    LEFT JOIN " +
                                    "    tbl_wallet_pp_card wl " +
                                    "    ON c.pk_company=wl.fk_company " +
                                    "    LEFT JOIN " +
                                    "    tbl_wallet_policy_pp_card wp " +
                                    "    ON wl.pp_card_cd=wp.pp_card_cd " +
                                    "WHERE 1=1 " +
                                    "    AND s.fd_default_ai='N' " +
                                    "    AND s.fd_regdate BETWEEN ? AND ? " )
    Page<List<Map<String, Object>>> findMemberAllPlan(LocalDateTime from, LocalDateTime to, Pageable pageable);


    @Query( nativeQuery=true, value=""+
                                    "SELECT * " +
                                    "FROM " +
                                    "    ( " +
                                    "    SELECT " +
                                    "        s.pk_company_staff AS memberSeq /*'회원PK'*/ , " +
                                    "        s.fd_regdate AS insertDate /*'계정생성일'*/ , " +
                                    "        s.fd_staff_id AS memberId /*'아이디'*/ , " +
                                    "        s.fd_staff_name AS name /*'가입자명'*/ , " +
                                    "        s.fd_staff_mobile AS mobile /*'핸드폰'*/ , " +
                                    "        s.fd_staff_phone AS phone /*'전화번호'*/ , " +
                                    "        s.fd_staff_email AS email /*'이메일'*/ , " +
                                    "        s.fd_staff_duty AS duty /*'직책'*/ , " +
                                    "        s.dept_disp_name AS department /*'부서'*/ , " +
                                    "        s.user_type AS userType /*'회사개인구분코드'*/ , " +
//                                    "        CASE " +
//                                    "                WHEN s.user_type='B2001' THEN '회사' " +
//                                    "                WHEN s.user_type='B2002' THEN '개인' " +
//                                    "                END AS userTypeStr /*'회사개인구분'*/ , " +
                                    "        s.solution_type AS solutionType /*'솔루션타입코드'*/ , " +
//                                    "        CASE " +
//                                    "                WHEN s.solution_type='B11' THEN '워크센터' " +
//                                    "                WHEN s.solution_type='B12' THEN '메타휴먼' " +
//                                    "                WHEN s.solution_type='B13' THEN '스튜디오' " +
//                                    "                WHEN s.solution_type='B14' THEN '손비서' " +
//                                    "                WHEN s.solution_type='B15' THEN '브랜드' " +
//                                    "                END AS solutionTypeStr /*'솔루션타입'*/ , " +
                                    "        s.fd_staff_level_code AS levelCode /*'레벨코드'*/ , " +
//                                    "        CASE " +
//                                    "                WHEN s.fd_staff_level_code='A1001' THEN '마스터' " +
//                                    "                WHEN s.fd_staff_level_code='A1002' THEN '매니저' " +
//                                    "                WHEN s.fd_staff_level_code='A1003' THEN '담당자' " +
//                                    "                WHEN s.fd_staff_level_code='A1004' THEN '일반직원' " +
//                                    "                END AS levelCodeStr /*'레벨'*/ , " +
                                    "        s.fd_staff_status_code AS statusCode /*'상태코드'*/ , " +
//                                    "        CASE " +
//                                    "                WHEN s.fd_staff_status_code='A1101' THEN '정상' " +
//                                    "                WHEN s.fd_staff_status_code='A1102' THEN '정지' " +
//                                    "                WHEN s.fd_staff_status_code='A1103' THEN '탈퇴' " +
//                                    "                END AS statusCodeStr /*'상태'*/ , " +
                                    "        s.fd_sign_up_path_code AS signUpPathCode /*'가입경로코드'*/ , " +
//                                    "        CASE " +
//                                    "                WHEN s.fd_sign_up_path_code IS NULL THEN '' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3010' THEN '워크센터' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3011' THEN '워크센터 기업' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3012' THEN '워크센터 개인' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3013' THEN '워크센터 개인 추가' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3020' THEN '스튜디오' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3021' THEN '스튜디오 기업' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3022' THEN '스튜디오 개인' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3023' THEN '스튜디오 개인 추가' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3030' THEN '워크센터 직원' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3031' THEN '워크센터 스튜디오 동시 사용' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3040' THEN '스튜디오 직원' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3041' THEN '스튜디오 워크센터 동시 사용' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3051' THEN '브랜드 통합 개인회원 가입' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3052' THEN '브랜드 통합 기업회원 가입' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3061' THEN '손비서 통합 개인회원 가입' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3062' THEN '손비서 통합 통합회원 가입' " +
//                                    "                END AS signUpPathCodeStr /*'가입경로'*/ , " +
                                    "        wp.free_yn AS freeYn, " +
//                                    "        CASE " +
//                                    "                WHEN wp.free_yn='Y' THEN '유료' " +
//                                    "                WHEN wp.free_yn='N' THEN '무료' " +
//                                    "                END AS freeYnStr /*'유무료'*/ , " +
                                    "        c.pk_company AS companySeq /*'회사PK'*/ , " +
                                    "        s.fd_regdate AS companyInsertDate /*'회사생성일'*/, " +
//                                    "        c.fd_regdate AS company_fd_regdate , " +
                                    "        c.fd_company_name AS companyName /*'회사명'*/ , " +
                                    "        c.fd_company_id AS companyId /*'회사아이디'*/ , " +
                                    "        (ROW_NUMBER() OVER(PARTITION BY c.pk_company, s.pk_company_staff ORDER BY wl.fd_regdate DESC)) AS rowNumber " +
                                    "    FROM " +
                                    "    tbl_company c " +
                                    "    LEFT JOIN " +
                                    "    tbl_company_staff s " +
                                    "    ON c.pk_company=s.fk_company " +
                                    "    LEFT JOIN " +
                                    "    tbl_wallet_pp_card wl " +
                                    "    ON c.pk_company=wl.fk_company " +
                                    "    LEFT JOIN " +
                                    "    tbl_wallet_policy_pp_card wp " +
                                    "    ON wl.pp_card_cd=wp.pp_card_cd " +
                                    "    WHERE 1=1 " +
                                    "          AND s.fd_default_ai='N' " +
                                    "          AND wp.free_yn=? " +
                                    "          AND s.fd_regdate BETWEEN ? AND ? " +
//                                    "          ORDER BY c.pk_company DESC, s.pk_company_staff DESC " +
                                    "   ) r1 " +
                                    "WHERE 1=1 " +
                                    "    AND r1.rowNumber=1 " +
                                    "    GROUP BY memberSeq ",
                                    countQuery=
                                                "SELECT COUNT(s.pk_company_staff) " +
                                                "FROM " +
                                                "    tbl_company c " +
                                                "    LEFT JOIN " +
                                                "    tbl_company_staff s " +
                                                "    ON c.pk_company=s.fk_company " +
                                                "    LEFT JOIN " +
                                                "    tbl_wallet_pp_card wl " +
                                                "    ON c.pk_company=wl.fk_company " +
                                                "    LEFT JOIN " +
                                                "    tbl_wallet_policy_pp_card wp " +
                                                "    ON wl.pp_card_cd=wp.pp_card_cd " +
                                                "WHERE 1=1 " +
                                                "    AND s.fd_default_ai='N' " +
                                                "    AND wp.free_yn=? " +
                                                "    AND s.fd_regdate BETWEEN ? AND ? " )
    Page<List<Map<String, Object>>> findMemberFreeYN(String freeYN, LocalDateTime from, LocalDateTime to, Pageable pageable);


    @Query( nativeQuery=true, value=""+
                                    "SELECT * " +
                                    "FROM " +
                                    "    ( " +
                                    "    SELECT " +
                                    "        s.pk_company_staff AS memberSeq /*'회원PK'*/ , " +
                                    "        s.fd_regdate AS insertDate /*'계정생성일'*/ , " +
                                    "        s.fd_staff_id AS memberId /*'아이디'*/ , " +
                                    "        s.fd_staff_name AS name /*'가입자명'*/ , " +
                                    "        s.fd_staff_mobile AS mobile /*'핸드폰'*/ , " +
                                    "        s.fd_staff_phone AS phone /*'전화번호'*/ , " +
                                    "        s.fd_staff_email AS email /*'이메일'*/ , " +
                                    "        s.fd_staff_duty AS duty /*'직책'*/ , " +
                                    "        s.dept_disp_name AS department /*'부서'*/ , " +
                                    "        s.user_type AS userType /*'회사개인구분코드'*/ , " +
//                                    "        CASE " +
//                                    "                WHEN s.user_type='B2001' THEN '회사' " +
//                                    "                WHEN s.user_type='B2002' THEN '개인' " +
//                                    "                END AS userTypeStr /*'회사개인구분'*/ , " +
                                    "        s.solution_type AS solutionType /*'솔루션타입코드'*/ , " +
//                                    "        CASE " +
//                                    "                WHEN s.solution_type='B11' THEN '워크센터' " +
//                                    "                WHEN s.solution_type='B12' THEN '메타휴먼' " +
//                                    "                WHEN s.solution_type='B13' THEN '스튜디오' " +
//                                    "                WHEN s.solution_type='B14' THEN '손비서' " +
//                                    "                WHEN s.solution_type='B15' THEN '브랜드' " +
//                                    "                END AS solutionTypeStr /*'솔루션타입'*/ , " +
                                    "        s.fd_staff_level_code AS levelCode /*'레벨코드'*/ , " +
//                                    "        CASE " +
//                                    "                WHEN s.fd_staff_level_code='A1001' THEN '마스터' " +
//                                    "                WHEN s.fd_staff_level_code='A1002' THEN '매니저' " +
//                                    "                WHEN s.fd_staff_level_code='A1003' THEN '담당자' " +
//                                    "                WHEN s.fd_staff_level_code='A1004' THEN '일반직원' " +
//                                    "                END AS levelCodeStr /*'레벨'*/ , " +
                                    "        s.fd_staff_status_code AS statusCode /*'상태코드'*/ , " +
//                                    "        CASE " +
//                                    "                WHEN s.fd_staff_status_code='A1101' THEN '정상' " +
//                                    "                WHEN s.fd_staff_status_code='A1102' THEN '정지' " +
//                                    "                WHEN s.fd_staff_status_code='A1103' THEN '탈퇴' " +
//                                    "                END AS statusCodeStr /*'상태'*/ , " +
                                    "        s.fd_sign_up_path_code AS signUpPathCode /*'가입경로코드'*/ , " +
//                                    "        CASE " +
//                                    "                WHEN s.fd_sign_up_path_code IS NULL THEN '' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3010' THEN '워크센터' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3011' THEN '워크센터 기업' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3012' THEN '워크센터 개인' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3013' THEN '워크센터 개인 추가' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3020' THEN '스튜디오' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3021' THEN '스튜디오 기업' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3022' THEN '스튜디오 개인' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3023' THEN '스튜디오 개인 추가' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3030' THEN '워크센터 직원' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3031' THEN '워크센터 스튜디오 동시 사용' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3040' THEN '스튜디오 직원' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3041' THEN '스튜디오 워크센터 동시 사용' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3051' THEN '브랜드 통합 개인회원 가입' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3052' THEN '브랜드 통합 기업회원 가입' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3061' THEN '손비서 통합 개인회원 가입' " +
//                                    "                WHEN s.fd_sign_up_path_code='A3062' THEN '손비서 통합 통합회원 가입' " +
//                                    "                END AS signUpPathCodeStr /*'가입경로'*/ , " +
                                    "        wp.free_yn AS freeYn, " +
//                                    "        CASE " +
//                                    "                WHEN wp.free_yn='Y' THEN '유료' " +
//                                    "                WHEN wp.free_yn='N' THEN '무료' " +
//                                    "                END AS freeYnStr /*'유무료'*/ , " +
                                    "        c.pk_company AS companySeq /*'회사PK'*/ , " +
                                    "        s.fd_regdate AS companyInsertDate /*'회사생성일'*/, " +
//                                    "        c.fd_regdate AS company_fd_regdate , " +
                                    "        c.fd_company_name AS companyName /*'회사명'*/ , " +
                                    "        c.fd_company_id AS companyId /*'회사아이디'*/ , " +
                                    "        (ROW_NUMBER() OVER(PARTITION BY c.pk_company, s.pk_company_staff ORDER BY wl.fd_regdate DESC)) AS rowNumber " +
                                    "    FROM " +
                                    "    tbl_company c " +
                                    "    LEFT JOIN " +
                                    "    tbl_company_staff s " +
                                    "    ON c.pk_company=s.fk_company " +
                                    "    LEFT JOIN " +
                                    "    tbl_wallet_pp_card wl " +
                                    "    ON c.pk_company=wl.fk_company " +
                                    "    LEFT JOIN " +
                                    "    tbl_wallet_policy_pp_card wp " +
                                    "    ON wl.pp_card_cd=wp.pp_card_cd " +
                                    "    WHERE 1=1 " +
                                    "          AND s.fd_default_ai='N' " +
                                    "          AND wp.free_yn=? " +
                                    "          AND fd_staff_status_code=? " +
                                    "          AND s.fd_regdate BETWEEN ? AND ? " +
//                                    "          ORDER BY c.pk_company DESC, s.pk_company_staff DESC " +
                                    "   ) r1 " +
                                    "WHERE 1=1 " +
                                    "    AND r1.rowNumber=1 " +
                                    "    GROUP BY memberSeq ",
                                    countQuery=
                                                "SELECT COUNT(s.pk_company_staff) " +
                                                "FROM " +
                                                "    tbl_company c " +
                                                "    LEFT JOIN " +
                                                "    tbl_company_staff s " +
                                                "    ON c.pk_company=s.fk_company " +
                                                "    LEFT JOIN " +
                                                "    tbl_wallet_pp_card wl " +
                                                "    ON c.pk_company=wl.fk_company " +
                                                "    LEFT JOIN " +
                                                "    tbl_wallet_policy_pp_card wp " +
                                                "    ON wl.pp_card_cd=wp.pp_card_cd " +
                                                "WHERE 1=1 " +
                                                "    AND s.fd_default_ai='N' " +
                                                "    AND wp.free_yn=? " +
                                                "    AND fd_staff_status_code=? " +
                                                "    AND s.fd_regdate BETWEEN ? AND ? " )
    Page<List<Map<String, Object>>> findMemberFreeYNAndStatus(String freeYN, String status, LocalDateTime from, LocalDateTime to, Pageable pageable);

    @Query( value=  "SELECT * " +
                    "FROM tbl_company_staff " +
                    "WHERE fd_company_master_yn='Y' AND fd_staff_status_code='A1101' AND (fd_sign_up_path_code='A3020' OR fd_sign_up_path_code='A3021' OR fd_sign_up_path_code='A3022' OR fd_sign_up_path_code='A3023') ",
                    nativeQuery=true)
    List<Member> findByStudioMember();


    @Query( value=  "SELECT m.member_snum as memberSeq, m.member_uuid as uuid, member_email as memberId, member_nick_nm as name, join_service_cd as solutionType, mobile_telno as mobile, member_state_cd as statusCode " +
                    "FROM tb_member as m " +
                    "WHERE member_email=? ",
                    nativeQuery=true)
    List<Member> findBrandMemberById(String memberId);

    @Query( value=  "SELECT m.member_snum as memberSeq, m.member_uuid as uuid, member_email as memberId, member_nick_nm as name, join_service_cd as solutionType, mobile_telno as mobile, member_state_cd as statusCode " +
            "FROM tb_member as m " +
            "WHERE mobile_telno=? ",
            nativeQuery=true)
    List<Member> findBrandMemberByMobile(String mmobile);

    List<Member> findByCompanyMasterAndStatusCodeAndLevelCodeAndPasswordNotLike(String companyMaster, String statusCode, String levelCode, String password);
}

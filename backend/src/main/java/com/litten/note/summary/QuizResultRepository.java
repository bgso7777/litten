package com.litten.note.summary;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Repository
public interface QuizResultRepository extends JpaRepository<QuizResult, Long> {

    /** 요약 결과 ID로 퀴즈 항목 전체 조회 (그룹순 → 항목순) */
    List<QuizResult> findBySummaryResultIdAndIsDeletedFalseOrderByGroupOrderAscSortOrderAsc(
            Long summaryResultId);

    /** 요약 결과 ID의 퀴즈 전체 삭제 (재생성 시 사용) */
    void deleteBySummaryResultId(Long summaryResultId);

    /** 회원 탈퇴 — 회원(memberUuid)의 요약에 속한 퀴즈 전체 삭제 */
    @Modifying
    @Transactional
    @Query("DELETE FROM QuizResult q WHERE q.summaryResultId IN (SELECT s.id FROM SummaryResult s WHERE s.memberUuid = :memberUuid)")
    void deleteByMemberUuidViaSummary(@Param("memberUuid") String memberUuid);
}

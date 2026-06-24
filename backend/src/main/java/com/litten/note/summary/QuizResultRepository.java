package com.litten.note.summary;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface RemindResultRepository extends JpaRepository<RemindResult, Long> {

    /** 요약 결과 ID로 리마인드 항목 전체 조회 (그룹순 → 항목순) */
    List<RemindResult> findBySummaryResultIdAndIsDeletedFalseOrderByGroupOrderAscSortOrderAsc(
            Long summaryResultId);

    /** 요약 결과 ID의 리마인드 전체 삭제 (재생성 시 사용) */
    void deleteBySummaryResultId(Long summaryResultId);
}

package com.litten.note.summary;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface SummaryConfigRepository extends JpaRepository<SummaryConfig, Long> {

    /** 파일 유형 + 요약 수준으로 활성 설정 조회 */
    Optional<SummaryConfig> findByFileTypeAndSummaryLevelAndIsActiveTrue(
            String fileType, int summaryLevel);

    /** 파일 유형으로 기본(level=3) 설정 조회 (fallback) */
    Optional<SummaryConfig> findByFileTypeAndSummaryLevelAndIsActiveTrueAndSummaryLevelIs(
            String fileType, int summaryLevel, int defaultLevel);
}

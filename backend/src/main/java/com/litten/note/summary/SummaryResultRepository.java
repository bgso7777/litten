package com.litten.note.summary;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface SummaryResultRepository extends JpaRepository<SummaryResult, Long> {

    /** YouTube 영상 ID + level 로 공통 결과 조회 */
    Optional<SummaryResult> findByYoutubeVideoIdAndSummaryLevelAndIsDeletedFalse(
            String youtubeVideoId, int summaryLevel);

    /** 개인 파일 UUID + 회원 UUID + level 로 결과 조회 */
    Optional<SummaryResult> findByFileUuidAndMemberUuidAndSummaryLevelAndIsDeletedFalse(
            String fileUuid, String memberUuid, int summaryLevel);

    /** YouTube level 무관 최신 결과 조회 (level 미지정 시 fallback) */
    Optional<SummaryResult> findTopByYoutubeVideoIdAndIsDeletedFalseOrderBySummaryLevelDesc(
            String youtubeVideoId);

    /** 개인 파일 level 무관 최신 결과 조회 (level 미지정 시 fallback) */
    Optional<SummaryResult> findTopByFileUuidAndMemberUuidAndIsDeletedFalseOrderBySummaryLevelDesc(
            String fileUuid, String memberUuid);
}

package com.litten.note.summary;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

@Repository
public interface SummaryResultRepository extends JpaRepository<SummaryResult, Long> {

    /** YouTube 영상 ID + level 로 공통 결과 조회 */
    Optional<SummaryResult> findByYoutubeVideoIdAndSummaryLevelAndIsDeletedFalse(
            String youtubeVideoId, int summaryLevel);

    /** YouTube level 무관 최신 결과 조회 */
    Optional<SummaryResult> findTopByYoutubeVideoIdAndIsDeletedFalseOrderBySummaryLevelDesc(
            String youtubeVideoId);

    /**
     * 개인 파일 UUID + 회원 UUID + level 조회 (NULL-safe).
     * memberUuid가 null이면 IS NULL 조건, 아니면 = 조건으로 분기.
     */
    @Query("SELECT r FROM SummaryResult r WHERE r.fileUuid = :fileUuid " +
           "AND r.summaryLevel = :level AND r.isDeleted = false " +
           "AND ((:memberUuid IS NULL AND r.memberUuid IS NULL) OR r.memberUuid = :memberUuid)")
    Optional<SummaryResult> findByFileUuidAndMemberUuidAndSummaryLevelAndIsDeletedFalse(
            @Param("fileUuid") String fileUuid,
            @Param("memberUuid") String memberUuid,
            @Param("level") int level);

    /**
     * 개인 파일 level 무관 최신 결과 조회 (NULL-safe).
     */
    @Query("SELECT r FROM SummaryResult r WHERE r.fileUuid = :fileUuid " +
           "AND r.isDeleted = false " +
           "AND ((:memberUuid IS NULL AND r.memberUuid IS NULL) OR r.memberUuid = :memberUuid) " +
           "ORDER BY r.summaryLevel DESC")
    Optional<SummaryResult> findTopByFileUuidAndMemberUuidAndIsDeletedFalseOrderBySummaryLevelDesc(
            @Param("fileUuid") String fileUuid,
            @Param("memberUuid") String memberUuid);

    /**
     * 프리미엄 전환 시 deviceUuid → memberUuid 일괄 이관.
     * note_summary_result.member_uuid = deviceUuid 인 행을 memberUuid로 업데이트.
     */
    @Modifying
    @Transactional
    @Query("UPDATE SummaryResult r SET r.memberUuid = :memberUuid WHERE r.memberUuid = :deviceUuid")
    int migrateMemberUuid(@Param("deviceUuid") String deviceUuid,
                          @Param("memberUuid") String memberUuid);
}

package com.litten.note.summary;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface SummaryResultRepository extends JpaRepository<SummaryResult, Long> {

    /** YouTube 영상 ID로 공통 결과 조회 (없으면 생성 필요) */
    Optional<SummaryResult> findByYoutubeVideoIdAndIsDeletedFalse(String youtubeVideoId);

    /** 개인 파일 UUID + 회원 UUID로 결과 조회 */
    Optional<SummaryResult> findByFileUuidAndMemberUuidAndIsDeletedFalse(
            String fileUuid, String memberUuid);

    /** 파일 UUID만으로 조회 (member_uuid 무관) */
    Optional<SummaryResult> findByFileUuidAndIsDeletedFalse(String fileUuid);
}

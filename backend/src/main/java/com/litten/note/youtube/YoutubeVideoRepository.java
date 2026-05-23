package com.litten.note.youtube;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface YoutubeVideoRepository extends JpaRepository<YoutubeVideo, Long> {

    boolean existsByVideoId(String videoId);

    Optional<YoutubeVideo> findByVideoId(String videoId);

    // transcriptText(LONGTEXT) 전체 로딩 없이 필요한 필드만 조회.
    // hasTranscript는 DB에서 null/empty 여부를 계산해서 반환.
    @Query("SELECT new com.litten.note.youtube.YoutubeVideoSummaryDto(" +
           "v.id, v.channelId, v.videoId, v.title, v.publishedAt, v.status, " +
           "CASE WHEN v.transcriptText IS NOT NULL AND v.transcriptText <> '' THEN true ELSE false END) " +
           "FROM YoutubeVideo v WHERE v.channelId = :channelId ORDER BY v.publishedAt DESC")
    Page<YoutubeVideoSummaryDto> findSummariesByChannelId(@Param("channelId") String channelId, Pageable pageable);

    Page<YoutubeVideo> findByStatus(String status, Pageable pageable);
}

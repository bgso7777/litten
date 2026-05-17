package com.litten.note.youtube;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface YoutubeVideoRepository extends JpaRepository<YoutubeVideo, Long> {

    boolean existsByVideoId(String videoId);

    Optional<YoutubeVideo> findByVideoId(String videoId);

    List<YoutubeVideo> findByChannelIdOrderByPublishedAtDesc(String channelId);

    Page<YoutubeVideo> findByChannelIdOrderByPublishedAtDesc(String channelId, Pageable pageable);

    List<YoutubeVideo> findByStatusOrderByInsertDateTimeDesc(String status);
}

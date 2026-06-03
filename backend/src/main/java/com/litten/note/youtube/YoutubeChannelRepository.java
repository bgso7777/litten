package com.litten.note.youtube;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface YoutubeChannelRepository extends JpaRepository<YoutubeChannel, Long> {

    Optional<YoutubeChannel> findByChannelId(String channelId);

    boolean existsByChannelId(String channelId);

    /** 활성 구독자가 1명 이상인 채널만 페이징 조회 (스케줄러 폴링용) */
    @Query("SELECT c FROM YoutubeChannel c WHERE EXISTS " +
           "(SELECT m FROM MemberYoutubeChannel m WHERE m.channelId = c.channelId AND m.isActive = true)")
    Page<YoutubeChannel> findChannelsWithActiveSubscribers(Pageable pageable);
}

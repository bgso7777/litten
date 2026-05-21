package com.litten.note.youtube;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface YoutubeChannelRepository extends JpaRepository<YoutubeChannel, Long> {

    List<YoutubeChannel> findByMemberIdAndIsActiveTrue(String memberId);

    Page<YoutubeChannel> findByIsActiveTrue(Pageable pageable);

    Optional<YoutubeChannel> findByMemberIdAndChannelId(String memberId, String channelId);

    boolean existsByMemberIdAndChannelId(String memberId, String channelId);
}

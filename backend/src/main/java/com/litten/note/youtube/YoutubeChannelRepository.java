package com.litten.note.youtube;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface YoutubeChannelRepository extends JpaRepository<YoutubeChannel, Long> {

    List<YoutubeChannel> findByMemberIdAndIsActiveTrue(String memberId);

    List<YoutubeChannel> findByIsActiveTrue();

    Optional<YoutubeChannel> findByMemberIdAndChannelId(String memberId, String channelId);

    boolean existsByMemberIdAndChannelId(String memberId, String channelId);
}

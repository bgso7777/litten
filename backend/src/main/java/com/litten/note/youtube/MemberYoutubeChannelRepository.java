package com.litten.note.youtube;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface MemberYoutubeChannelRepository extends JpaRepository<MemberYoutubeChannel, Long> {

    List<MemberYoutubeChannel> findByMemberIdAndIsActiveTrue(String memberId);

    Optional<MemberYoutubeChannel> findByMemberIdAndChannelId(String memberId, String channelId);

    boolean existsByMemberIdAndChannelId(String memberId, String channelId);

    /** 특정 채널에 활성 구독자가 존재하는지 확인 (폴링 대상 채널 판단용) */
    boolean existsByChannelIdAndIsActiveTrue(String channelId);
}

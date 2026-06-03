package com.litten.note.youtube;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Repository
public interface MemberYoutubeChannelRepository extends JpaRepository<MemberYoutubeChannel, Long> {

    List<MemberYoutubeChannel> findByMemberIdAndIsActiveTrue(String memberId);

    Optional<MemberYoutubeChannel> findByMemberIdAndChannelId(String memberId, String channelId);

    boolean existsByMemberIdAndChannelId(String memberId, String channelId);

    /** 특정 채널에 활성 구독자가 존재하는지 확인 (폴링 대상 채널 판단용) */
    boolean existsByChannelIdAndIsActiveTrue(String channelId);

    /** 게스트(또는 멤버)의 활성 구독 채널 수 (플랜별 채널 수 제한 검증용) */
    long countByMemberIdAndIsActiveTrue(String memberId);

    /**
     * 프리미엄 전환 시 게스트 구독을 회원 ID로 이관.
     * 동일 채널을 회원이 이미 구독 중이면 충돌하므로, 호출 전 중복 채널은 제외해야 한다.
     */
    @Modifying
    @Transactional
    @Query("UPDATE MemberYoutubeChannel m SET m.memberId = :memberId " +
           "WHERE m.memberId = :guestId AND m.channelId NOT IN " +
           "(SELECT e.channelId FROM MemberYoutubeChannel e WHERE e.memberId = :memberId)")
    int migrateGuestToMember(@Param("guestId") String guestId, @Param("memberId") String memberId);

    /** 이관 후 남은 게스트 중복 구독 정리 (회원이 이미 구독 중인 채널) */
    @Modifying
    @Transactional
    @Query("DELETE FROM MemberYoutubeChannel m WHERE m.memberId = :guestId")
    int deleteByMemberId(@Param("guestId") String guestId);
}

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
public interface ChannelWatchStateRepository extends JpaRepository<ChannelWatchState, Long> {

    List<ChannelWatchState> findByMemberId(String memberId);

    Optional<ChannelWatchState> findByMemberIdAndChannelId(String memberId, String channelId);

    /**
     * 프리미엄 전환 시 게스트 확인 상태를 회원 ID로 이관.
     * 회원이 이미 가진 채널 상태는 제외 (충돌 방지).
     */
    @Modifying
    @Transactional
    @Query("UPDATE ChannelWatchState w SET w.memberId = :memberId " +
           "WHERE w.memberId = :guestId AND w.channelId NOT IN " +
           "(SELECT e.channelId FROM ChannelWatchState e WHERE e.memberId = :memberId)")
    int migrateGuestToMember(@Param("guestId") String guestId, @Param("memberId") String memberId);

    /** 이관 후 남은 게스트 행 정리 */
    @Modifying
    @Transactional
    @Query("DELETE FROM ChannelWatchState w WHERE w.memberId = :guestId")
    int deleteByMemberId(@Param("guestId") String guestId);
}

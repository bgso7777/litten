package com.litten.note.hiddenroom;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface HiddenRoomRepository extends JpaRepository<HiddenRoom, Long> {

    List<HiddenRoom> findByMemberId(String memberId);

    Optional<HiddenRoom> findByMemberIdAndConvKey(String memberId, String convKey);
}

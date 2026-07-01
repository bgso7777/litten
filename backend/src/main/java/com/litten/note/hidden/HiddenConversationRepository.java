package com.litten.note.hidden;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface HiddenConversationRepository extends JpaRepository<HiddenConversation, Long> {

    List<HiddenConversation> findByMemberId(String memberId);

    Optional<HiddenConversation> findByMemberIdAndConvKey(String memberId, String convKey);
}

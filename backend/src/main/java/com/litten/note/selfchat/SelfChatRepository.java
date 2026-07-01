package com.litten.note.selfchat;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface SelfChatRepository extends JpaRepository<SelfChat, Long> {

    List<SelfChat> findByMemberIdAndIsDeletedFalseOrderByIdAsc(String memberId);

    Optional<SelfChat> findByMemberIdAndClientId(String memberId, String clientId);
}

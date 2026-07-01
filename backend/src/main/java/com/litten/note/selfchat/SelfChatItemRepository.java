package com.litten.note.selfchat;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface SelfChatItemRepository extends JpaRepository<SelfChatItem, Long> {

    List<SelfChatItem> findBySelfChatIdAndIsDeletedFalseOrderByIdAsc(Long selfChatId);
}

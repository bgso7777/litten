package com.litten.note.message;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface NoteMessageRepository extends JpaRepository<NoteMessage, Long> {

    // 내가 보낸 메시지 (최신순)
    List<NoteMessage> findBySenderMemberIdAndIsDeletedFalseOrderByIdDesc(String senderMemberId);
}

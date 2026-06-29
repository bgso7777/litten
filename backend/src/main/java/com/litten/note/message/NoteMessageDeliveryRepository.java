package com.litten.note.message;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface NoteMessageDeliveryRepository extends JpaRepository<NoteMessageDelivery, Long> {

    // 내가 받은 전달 (최신순)
    List<NoteMessageDelivery> findByRecipientMemberIdAndIsDeletedFalseOrderByIdDesc(String recipientMemberId);

    // 특정 메시지의 전달들 (보낸 목록의 수신자 요약용)
    List<NoteMessageDelivery> findByMessageIdAndIsDeletedFalse(Long messageId);
}

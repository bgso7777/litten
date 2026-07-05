package com.litten.note.studyroom.message;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface RoomMessageDeliveryRepository extends JpaRepository<RoomMessageDelivery, Long> {

    // 내가 받은 전달 (최신순)
    List<RoomMessageDelivery> findByRecipientMemberIdAndIsDeletedFalseOrderByIdDesc(String recipientMemberId);

    // 특정 메시지의 전달들 (보낸 목록의 수신자 요약용)
    List<RoomMessageDelivery> findByMessageIdAndIsDeletedFalse(Long messageId);
}

package com.litten.note.studyroom;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface RoomShareDeliveryRepository extends JpaRepository<RoomShareDelivery, Long> {

    // 내가 받은 전달 (최신순)
    List<RoomShareDelivery> findByRecipientMemberIdAndIsDeletedFalseOrderByIdDesc(String recipientMemberId);

    // 특정 공유의 전달들 (보낸 목록의 상태 요약/취소 시 사용)
    List<RoomShareDelivery> findByShareIdAndIsDeletedFalse(Long shareId);
}

package com.litten.note.share;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface FileShareDeliveryRepository extends JpaRepository<FileShareDelivery, Long> {

    // 내가 받은 전달 (최신순)
    List<FileShareDelivery> findByRecipientMemberIdAndIsDeletedFalseOrderByIdDesc(String recipientMemberId);

    // 특정 공유의 전달들 (보낸 목록의 상태 요약/취소 시 사용)
    List<FileShareDelivery> findByShareIdAndIsDeletedFalse(Long shareId);
}

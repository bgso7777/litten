package com.litten.note.selfroom;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface SelfStudyRoomItemRepository extends JpaRepository<SelfStudyRoomItem, Long> {

    List<SelfStudyRoomItem> findByRoomIdAndIsDeletedFalseOrderByIdAsc(Long roomId);
    // 회원 탈퇴 — 회원의 나만의 스터디룸 항목 전체 삭제
    @org.springframework.transaction.annotation.Transactional
    void deleteByMemberId(String memberId);
}

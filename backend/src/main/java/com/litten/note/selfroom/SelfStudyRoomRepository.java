package com.litten.note.selfroom;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface SelfStudyRoomRepository extends JpaRepository<SelfStudyRoom, Long> {

    List<SelfStudyRoom> findByMemberIdAndIsDeletedFalseOrderByIdAsc(String memberId);

    List<SelfStudyRoom> findByMemberIdAndIsDeletedTrue(String memberId);

    Optional<SelfStudyRoom> findByMemberIdAndClientId(String memberId, String clientId);
    // 회원 탈퇴 — 회원의 나만의 스터디룸 전체 삭제
    @org.springframework.transaction.annotation.Transactional
    void deleteByMemberId(String memberId);
}

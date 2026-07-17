package com.litten.note.studyroom;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface StudyRoomMemberRepository extends JpaRepository<StudyRoomMember, Long> {

    List<StudyRoomMember> findByRoomIdAndIsDeletedFalseOrderByIdAsc(Long roomId);

    Optional<StudyRoomMember> findByRoomIdAndMemberId(Long roomId, String memberId);
    // 회원 탈퇴 — 회원의 룸 멤버십 전체 삭제
    @org.springframework.transaction.annotation.Transactional
    void deleteByMemberId(String memberId);

    // 회원 탈퇴(방장) — 삭제되는 룸의 멤버십 전체 삭제
    @org.springframework.transaction.annotation.Transactional
    void deleteByRoomId(Long roomId);
}

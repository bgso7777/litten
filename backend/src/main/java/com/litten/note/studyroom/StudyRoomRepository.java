package com.litten.note.studyroom;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface StudyRoomRepository extends JpaRepository<StudyRoom, Long> {

    List<StudyRoom> findByOwnerMemberIdAndIsDeletedFalseOrderByIdDesc(String ownerMemberId);

    // 회원 탈퇴 — 내가 방장인 그룹 스터디룸 조회 및 삭제(룸 삭제 정책)
    List<StudyRoom> findByOwnerMemberId(String ownerMemberId);

    @org.springframework.transaction.annotation.Transactional
    void deleteByOwnerMemberId(String ownerMemberId);
}

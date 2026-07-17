package com.litten.note.sync;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface NoteScheduleRepository extends JpaRepository<NoteSchedule, Long> {

    /** 회원의 전체 일정 (삭제 tombstone 포함) — 다른 기기에 삭제 전파용 */
    List<NoteSchedule> findByMemberId(String memberId);

    Optional<NoteSchedule> findByMemberIdAndLittenId(String memberId, String littenId);
    // 회원 탈퇴 — 회원의 일정 전체 삭제
    @org.springframework.transaction.annotation.Transactional
    void deleteByMemberId(String memberId);
}

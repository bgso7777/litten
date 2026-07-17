package com.litten.note.sync;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface LittenRepository extends JpaRepository<Litten, Long> {

    /** 회원의 삭제되지 않은 리튼 목록 */
    List<Litten> findByMemberIdAndIsDeletedFalse(String memberId);

    /** 회원의 전체 리튼 목록 (삭제 tombstone 포함) — 다른 기기에 삭제를 전파하기 위함 */
    List<Litten> findByMemberId(String memberId);

    Optional<Litten> findByMemberIdAndLittenId(String memberId, String littenId);
    // 회원 탈퇴 — 회원의 리튼 메타 전체 삭제
    @org.springframework.transaction.annotation.Transactional
    void deleteByMemberId(String memberId);
}

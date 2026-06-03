package com.litten.note.sync;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface LittenRepository extends JpaRepository<Litten, Long> {

    /** 회원의 삭제되지 않은 리튼 목록 */
    List<Litten> findByMemberIdAndIsDeletedFalse(String memberId);

    Optional<Litten> findByMemberIdAndLittenId(String memberId, String littenId);
}

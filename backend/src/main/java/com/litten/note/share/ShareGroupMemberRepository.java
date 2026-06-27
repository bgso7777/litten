package com.litten.note.share;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface ShareGroupMemberRepository extends JpaRepository<ShareGroupMember, Long> {

    List<ShareGroupMember> findByGroupIdAndIsDeletedFalseOrderByIdAsc(Long groupId);

    Optional<ShareGroupMember> findByGroupIdAndMemberId(Long groupId, String memberId);
}

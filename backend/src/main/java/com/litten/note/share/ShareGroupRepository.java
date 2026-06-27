package com.litten.note.share;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface ShareGroupRepository extends JpaRepository<ShareGroup, Long> {

    List<ShareGroup> findByOwnerMemberIdAndIsDeletedFalseOrderByIdDesc(String ownerMemberId);
}

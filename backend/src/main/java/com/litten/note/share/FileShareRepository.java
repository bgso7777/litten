package com.litten.note.share;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface FileShareRepository extends JpaRepository<FileShare, Long> {

    List<FileShare> findBySenderMemberIdAndIsDeletedFalseOrderByIdDesc(String senderMemberId);
}

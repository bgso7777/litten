package com.litten.note.sync;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface CloudFileRepository extends JpaRepository<CloudFile, Long> {

    List<CloudFile> findByMemberIdAndIsDeletedFalse(String memberId, Pageable pageable);

    List<CloudFile> findByMemberIdAndIsDeletedFalseAndUpdateDateTimeAfter(String memberId, LocalDateTime since, Pageable pageable);

    Optional<CloudFile> findByMemberIdAndLocalIdAndIsDeletedFalse(String memberId, String localId);
}

package com.litten.note.sync;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface CloudFileBackupRepository extends JpaRepository<CloudFileBackup, Long> {

    List<CloudFileBackup> findByCloudFileIdOrderByBackedUpAtDesc(Long cloudFileId);
}

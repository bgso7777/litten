package com.litten.note.sync;

import org.springframework.data.jpa.repository.JpaRepository;

public interface CloudFileBackupRepository extends JpaRepository<CloudFileBackup, Long> {
}

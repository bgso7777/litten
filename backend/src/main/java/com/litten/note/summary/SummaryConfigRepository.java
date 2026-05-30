package com.litten.note.summary;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface SummaryConfigRepository extends JpaRepository<SummaryConfig, Long> {

    /** 파일 유형으로 활성 설정 조회 */
    Optional<SummaryConfig> findByFileTypeAndIsActiveTrue(String fileType);
}

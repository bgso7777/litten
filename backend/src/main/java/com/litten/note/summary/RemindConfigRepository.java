package com.litten.note.summary;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface RemindConfigRepository extends JpaRepository<RemindConfig, Long> {

    /** 파일 유형으로 활성 리마인드 설정 조회 */
    Optional<RemindConfig> findByFileTypeAndIsActiveTrue(String fileType);
}

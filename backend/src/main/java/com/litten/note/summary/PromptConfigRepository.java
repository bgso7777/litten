package com.litten.note.summary;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface PromptConfigRepository extends JpaRepository<PromptConfig, Long> {

    /** type + file_type + level 조합으로 활성 설정 조회 (통합 단일 쿼리) */
    Optional<PromptConfig> findByTypeAndFileTypeAndLevelAndIsActiveTrue(
            String type, String fileType, Integer level);
}

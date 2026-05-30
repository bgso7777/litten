package com.litten.note.summary;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface PromptConfigRepository extends JpaRepository<PromptConfig, Long> {

    /**
     * type + prompt_role + file_type + summary_level 조합으로 조회.
     * summary system: findBy("summary", "system", "youtube", 3)
     * remind  system: findBy("remind",  "system", "youtube", null)
     */
    Optional<PromptConfig> findByTypeAndPromptRoleAndFileTypeAndSummaryLevelAndIsActiveTrue(
            String type, String promptRole, String fileType, Integer summaryLevel);

    /** summary_level이 NULL인 경우 (remind용) */
    Optional<PromptConfig> findByTypeAndPromptRoleAndFileTypeAndSummaryLevelIsNullAndIsActiveTrue(
            String type, String promptRole, String fileType);
}

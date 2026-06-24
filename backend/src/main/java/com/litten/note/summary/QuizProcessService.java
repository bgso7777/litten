package com.litten.note.summary;

import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;

/**
 * 리마인드 처리 오케스트레이션 서비스.
 *
 * 처리 흐름:
 *   1) summaryResultId 로 note_summary_result 조회 → sourceText 획득
 *   2) 캐시 확인 (forceRegenerate=false & 기존 remind 존재 → 바로 반환)
 *   3) note_prompt_config 에서 (type=remind, fileType, level) 기준 설정+프롬프트 단일 조회
 *   4) RemindService.generate() 호출 (AI 실행)
 *   5) note_remind_result 저장
 *   6) note_summary_result.total_remind_count 업데이트
 */
@Log4j2
@Service
@RequiredArgsConstructor
public class RemindProcessService {

    private static final int DEFAULT_REMIND_LEVEL = 3;

    private final SummaryResultRepository summaryResultRepository;
    private final RemindResultRepository  remindResultRepository;
    private final PromptConfigRepository  promptConfigRepository;
    private final RemindService           remindService;

    // ── 공개 메서드 ──────────────────────────────────────────────────────────

    @Transactional
    public RemindResponseVo process(RemindProcessRequestVo req) {
        log.debug("[RemindProcessService] process() - summaryResultId: {}, remindLevel: {}, forceRegenerate: {}",
                req.getSummaryResultId(), req.getRemindLevel(), req.isForceRegenerate());

        if (req.getSummaryResultId() == null) {
            return RemindResponseVo.fail("summaryResultId는 필수입니다.");
        }

        // 1) 요약 결과 조회
        SummaryResult summaryResult = summaryResultRepository.findById(req.getSummaryResultId()).orElse(null);
        if (summaryResult == null || !"done".equals(summaryResult.getStatus())) {
            log.warn("[RemindProcessService] 요약 결과 없음 또는 미완료 - summaryResultId: {}", req.getSummaryResultId());
            return RemindResponseVo.fail("요약 결과를 찾을 수 없거나 아직 처리 중입니다.");
        }

        String sourceText = summaryResult.getSourceText();
        if (sourceText == null || sourceText.isBlank()) {
            log.warn("[RemindProcessService] sourceText 없음 - summaryResultId: {}", req.getSummaryResultId());
            return RemindResponseVo.fail("원본 텍스트가 저장되어 있지 않아 리마인드를 생성할 수 없습니다.");
        }

        // 2) 캐시 확인
        if (!req.isForceRegenerate()) {
            List<RemindResult> cached = remindResultRepository
                    .findBySummaryResultIdAndIsDeletedFalseOrderByGroupOrderAscSortOrderAsc(req.getSummaryResultId());
            if (!cached.isEmpty()) {
                log.info("[RemindProcessService] 리마인드 캐시 히트 - summaryResultId: {}, count: {}",
                        req.getSummaryResultId(), cached.size());
                return toResponseVo(cached, summaryResult.getTotalRemindCount());
            }
        }

        // 3) note_prompt_config 에서 설정+프롬프트 단일 조회
        String fileType   = summaryResult.getFileType() != null ? summaryResult.getFileType() : "text";
        int remindLevel   = req.getRemindLevel() > 0 ? req.getRemindLevel() : DEFAULT_REMIND_LEVEL;
        String outputLang = req.getSummaryLanguage();

        PromptConfig config = promptConfigRepository
                .findByTypeAndFileTypeAndLevelAndIsActiveTrue("remind", fileType, remindLevel)
                .orElseGet(() -> defaultConfig(fileType, remindLevel));

        if (Boolean.FALSE.equals(config.getIsActive())) {
            return RemindResponseVo.fail("이 파일 유형은 리마인드 생성이 비활성화되어 있습니다.");
        }

        // CUSTOM count override
        Integer maxCount  = req.getRemindCustomCount() != null && req.getRemindCustomCount() > 0
                ? req.getRemindCustomCount() : config.getRemindMaxCount();
        Integer maxGroup  = config.getRemindMaxGroup();
        String typeFilter = config.getRemindTypeFilter();

        // 프롬프트 플레이스홀더 치환
        String systemPrompt = applyPlaceholders(config.getPrompt(), outputLang, maxCount, maxGroup, typeFilter);

        log.info("[RemindProcessService] 리마인드 생성 시작 - summaryResultId: {}, fileType: {}, level: {}, maxCount: {}, dbPrompt: {}",
                req.getSummaryResultId(), fileType, remindLevel, maxCount, systemPrompt != null);

        // 4) AI 호출
        RemindResponseVo aiResp = remindService.generate(
                sourceText, fileType, outputLang, systemPrompt, maxCount, maxGroup, typeFilter);
        if (!aiResp.isSuccess()) {
            log.error("[RemindProcessService] AI 리마인드 생성 실패: {}", aiResp.getError());
            return aiResp;
        }

        // 5) 기존 remind 삭제 후 저장
        remindResultRepository.deleteBySummaryResultId(req.getSummaryResultId());
        saveRemindResults(req.getSummaryResultId(), aiResp.getReminds());

        // 6) totalRemindCount 업데이트
        summaryResult.setTotalRemindCount(aiResp.getTotalRemindCount());
        summaryResultRepository.save(summaryResult);

        log.info("[RemindProcessService] 리마인드 처리 완료 - summaryResultId: {}, count: {}",
                req.getSummaryResultId(), aiResp.getTotalRemindCount());
        return aiResp;
    }

    public RemindResponseVo getRemind(Long summaryResultId) {
        log.debug("[RemindProcessService] getRemind() - summaryResultId: {}", summaryResultId);
        List<RemindResult> rows = remindResultRepository
                .findBySummaryResultIdAndIsDeletedFalseOrderByGroupOrderAscSortOrderAsc(summaryResultId);
        if (rows.isEmpty()) return null;

        SummaryResult summaryResult = summaryResultRepository.findById(summaryResultId).orElse(null);
        int total = summaryResult != null ? summaryResult.getTotalRemindCount() : rows.size();
        return toResponseVo(rows, total);
    }

    // ── 내부: 저장 ───────────────────────────────────────────────────────────

    private void saveRemindResults(Long summaryResultId, List<RemindGroup> groups) {
        if (groups == null || groups.isEmpty()) {
            log.debug("[RemindProcessService] 저장할 리마인드 항목 없음 - summaryResultId: {}", summaryResultId);
            return;
        }
        List<RemindResult> rows = new ArrayList<>();
        int groupOrder = 0;
        for (RemindGroup group : groups) {
            int sortOrder = 0;
            for (RemindItem item : group.getItems()) {
                RemindResult row = new RemindResult();
                row.setSummaryResultId(summaryResultId);
                row.setGroupName(group.getGroupName());
                row.setGroupOrder(groupOrder);
                row.setItemType(item.getType() != null ? item.getType() : "기타");
                row.setItemContent(item.getContent() != null ? item.getContent() : "");
                row.setAssignee(item.getAssignee());
                row.setDeadline(item.getDeadline());
                row.setDetailText(item.getDetails() != null ? String.join("\n", item.getDetails()) : null);
                row.setSortOrder(sortOrder);
                rows.add(row);
                sortOrder++;
            }
            groupOrder++;
        }
        remindResultRepository.saveAll(rows);
        log.info("[RemindProcessService] note_remind_result 저장 - {}행", rows.size());
    }

    // ── 내부: 변환 ───────────────────────────────────────────────────────────

    private RemindResponseVo toResponseVo(List<RemindResult> rows, int total) {
        List<RemindGroup> groups = new ArrayList<>();
        RemindGroup currentGroup = null;
        for (RemindResult row : rows) {
            if (currentGroup == null || !currentGroup.getGroupName().equals(row.getGroupName())) {
                currentGroup = new RemindGroup();
                currentGroup.setGroupName(row.getGroupName());
                groups.add(currentGroup);
            }
            RemindItem item = new RemindItem();
            item.setType(row.getItemType());
            item.setContent(row.getItemContent());
            item.setAssignee(row.getAssignee());
            item.setDeadline(row.getDeadline());
            if (row.getDetailText() != null && !row.getDetailText().isBlank()) {
                item.setDetails(List.of(row.getDetailText().split("\n")));
            }
            currentGroup.getItems().add(item);
        }
        RemindResponseVo vo = RemindResponseVo.ok(groups);
        vo.setTotalRemindCount(total);
        return vo;
    }

    // ── 내부: 플레이스홀더 치환 ──────────────────────────────────────────────

    private String applyPlaceholders(String prompt, String outputLang,
                                     Integer maxCount, Integer maxGroup, String typeFilter) {
        if (prompt == null || prompt.isBlank()) return null;
        String lang          = outputLang != null && !outputLang.isBlank() ? outputLang : "ko";
        String maxCountStr   = maxCount   != null ? String.valueOf(maxCount)  : "제한 없음";
        String maxGroupStr   = maxGroup   != null ? String.valueOf(maxGroup)  : "2~5";
        String typeFilterStr = typeFilter != null && !typeFilter.isBlank() ? typeFilter : "전체";

        return prompt
                .replace("{{OUTPUT_LANG}}", lang)
                .replace("{{MAX_COUNT}}", maxCountStr)
                .replace("{{MAX_GROUP}}", maxGroupStr)
                .replace("{{TYPE_FILTER}}", typeFilterStr);
    }

    // ── 내부: 기본값 ─────────────────────────────────────────────────────────

    private PromptConfig defaultConfig(String fileType, int remindLevel) {
        log.warn("[RemindProcessService] PromptConfig 없음 - fileType: {}, level: {} → 기본값 사용", fileType, remindLevel);
        PromptConfig c = new PromptConfig();
        c.setType("remind");
        c.setFileType(fileType);
        c.setLevel(remindLevel);
        c.setIsActive(true);
        c.setRemindMaxCount(defaultMaxCount(remindLevel));
        c.setRemindMaxGroup(3);
        return c;
    }

    private int defaultMaxCount(int level) {
        return switch (level) {
            case 1 -> 1;
            case 2 -> 3;
            case 3 -> 5;
            case 4 -> 10;
            case 5 -> 20;
            default -> 5;
        };
    }
}

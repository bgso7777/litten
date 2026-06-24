package com.litten.note.summary;

import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;

/**
 * 퀴즈 처리 오케스트레이션 서비스.
 *
 * 처리 흐름:
 *   1) summaryResultId 로 note_summary_result 조회 → sourceText 획득
 *   2) 캐시 확인 (forceRegenerate=false & 기존 quiz 존재 → 바로 반환)
 *   3) note_prompt_config 에서 (type=quiz, fileType, level) 기준 설정+프롬프트 단일 조회
 *   4) QuizService.generate() 호출 (AI 실행)
 *   5) note_quiz_result 저장
 *   6) note_summary_result.total_quiz_count 업데이트
 */
@Log4j2
@Service
@RequiredArgsConstructor
public class QuizProcessService {

    private static final int DEFAULT_QUIZ_LEVEL = 3;

    private final SummaryResultRepository summaryResultRepository;
    private final QuizResultRepository  quizResultRepository;
    private final PromptConfigRepository  promptConfigRepository;
    private final QuizService           quizService;

    // ── 공개 메서드 ──────────────────────────────────────────────────────────

    @Transactional
    public QuizResponseVo process(QuizProcessRequestVo req) {
        log.debug("[QuizProcessService] process() - summaryResultId: {}, quizLevel: {}, forceRegenerate: {}",
                req.getSummaryResultId(), req.getQuizLevel(), req.isForceRegenerate());

        if (req.getSummaryResultId() == null) {
            return QuizResponseVo.fail("summaryResultId는 필수입니다.");
        }

        // 1) 요약 결과 조회
        SummaryResult summaryResult = summaryResultRepository.findById(req.getSummaryResultId()).orElse(null);
        if (summaryResult == null || !"done".equals(summaryResult.getStatus())) {
            log.warn("[QuizProcessService] 요약 결과 없음 또는 미완료 - summaryResultId: {}", req.getSummaryResultId());
            return QuizResponseVo.fail("요약 결과를 찾을 수 없거나 아직 처리 중입니다.");
        }

        String sourceText = summaryResult.getSourceText();
        if (sourceText == null || sourceText.isBlank()) {
            log.warn("[QuizProcessService] sourceText 없음 - summaryResultId: {}", req.getSummaryResultId());
            return QuizResponseVo.fail("원본 텍스트가 저장되어 있지 않아 퀴즈를 생성할 수 없습니다.");
        }

        // 2) 캐시 확인
        if (!req.isForceRegenerate()) {
            List<QuizResult> cached = quizResultRepository
                    .findBySummaryResultIdAndIsDeletedFalseOrderByGroupOrderAscSortOrderAsc(req.getSummaryResultId());
            if (!cached.isEmpty()) {
                log.info("[QuizProcessService] 퀴즈 캐시 히트 - summaryResultId: {}, count: {}",
                        req.getSummaryResultId(), cached.size());
                return toResponseVo(cached, summaryResult.getTotalQuizCount());
            }
        }

        // 3) note_prompt_config 에서 설정+프롬프트 단일 조회
        String fileType   = summaryResult.getFileType() != null ? summaryResult.getFileType() : "text";
        int quizLevel   = req.getQuizLevel() > 0 ? req.getQuizLevel() : DEFAULT_QUIZ_LEVEL;
        String outputLang = req.getSummaryLanguage();

        PromptConfig config = promptConfigRepository
                .findByTypeAndFileTypeAndLevelAndIsActiveTrue("quiz", fileType, quizLevel)
                .orElseGet(() -> defaultConfig(fileType, quizLevel));

        if (Boolean.FALSE.equals(config.getIsActive())) {
            return QuizResponseVo.fail("이 파일 유형은 퀴즈 생성이 비활성화되어 있습니다.");
        }

        // CUSTOM count override
        Integer maxCount  = req.getQuizCustomCount() != null && req.getQuizCustomCount() > 0
                ? req.getQuizCustomCount() : config.getQuizMaxCount();
        Integer maxGroup  = config.getQuizMaxGroup();
        String typeFilter = config.getQuizTypeFilter();

        // 프롬프트 플레이스홀더 치환
        String systemPrompt = applyPlaceholders(config.getPrompt(), outputLang, maxCount, maxGroup, typeFilter);

        log.info("[QuizProcessService] 퀴즈 생성 시작 - summaryResultId: {}, fileType: {}, level: {}, maxCount: {}, dbPrompt: {}",
                req.getSummaryResultId(), fileType, quizLevel, maxCount, systemPrompt != null);

        // 4) AI 호출
        QuizResponseVo aiResp = quizService.generate(
                sourceText, fileType, outputLang, systemPrompt, maxCount, maxGroup, typeFilter);
        if (!aiResp.isSuccess()) {
            log.error("[QuizProcessService] AI 퀴즈 생성 실패: {}", aiResp.getError());
            return aiResp;
        }

        // 5) 기존 quiz 삭제 후 저장
        quizResultRepository.deleteBySummaryResultId(req.getSummaryResultId());
        saveQuizResults(req.getSummaryResultId(), aiResp.getQuizzes());

        // 6) totalQuizCount 업데이트
        summaryResult.setTotalQuizCount(aiResp.getTotalQuizCount());
        summaryResultRepository.save(summaryResult);

        log.info("[QuizProcessService] 퀴즈 처리 완료 - summaryResultId: {}, count: {}",
                req.getSummaryResultId(), aiResp.getTotalQuizCount());
        return aiResp;
    }

    public QuizResponseVo getQuiz(Long summaryResultId) {
        log.debug("[QuizProcessService] getQuiz() - summaryResultId: {}", summaryResultId);
        List<QuizResult> rows = quizResultRepository
                .findBySummaryResultIdAndIsDeletedFalseOrderByGroupOrderAscSortOrderAsc(summaryResultId);
        if (rows.isEmpty()) return null;

        SummaryResult summaryResult = summaryResultRepository.findById(summaryResultId).orElse(null);
        int total = summaryResult != null ? summaryResult.getTotalQuizCount() : rows.size();
        return toResponseVo(rows, total);
    }

    // ── 내부: 저장 ───────────────────────────────────────────────────────────

    private void saveQuizResults(Long summaryResultId, List<QuizGroup> groups) {
        if (groups == null || groups.isEmpty()) {
            log.debug("[QuizProcessService] 저장할 퀴즈 항목 없음 - summaryResultId: {}", summaryResultId);
            return;
        }
        List<QuizResult> rows = new ArrayList<>();
        int groupOrder = 0;
        for (QuizGroup group : groups) {
            int sortOrder = 0;
            for (QuizItem item : group.getItems()) {
                QuizResult row = new QuizResult();
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
        quizResultRepository.saveAll(rows);
        log.info("[QuizProcessService] note_quiz_result 저장 - {}행", rows.size());
    }

    // ── 내부: 변환 ───────────────────────────────────────────────────────────

    private QuizResponseVo toResponseVo(List<QuizResult> rows, int total) {
        List<QuizGroup> groups = new ArrayList<>();
        QuizGroup currentGroup = null;
        for (QuizResult row : rows) {
            if (currentGroup == null || !currentGroup.getGroupName().equals(row.getGroupName())) {
                currentGroup = new QuizGroup();
                currentGroup.setGroupName(row.getGroupName());
                groups.add(currentGroup);
            }
            QuizItem item = new QuizItem();
            item.setType(row.getItemType());
            item.setContent(row.getItemContent());
            item.setAssignee(row.getAssignee());
            item.setDeadline(row.getDeadline());
            if (row.getDetailText() != null && !row.getDetailText().isBlank()) {
                item.setDetails(List.of(row.getDetailText().split("\n")));
            }
            currentGroup.getItems().add(item);
        }
        QuizResponseVo vo = QuizResponseVo.ok(groups);
        vo.setTotalQuizCount(total);
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

    private PromptConfig defaultConfig(String fileType, int quizLevel) {
        log.warn("[QuizProcessService] PromptConfig 없음 - fileType: {}, level: {} → 기본값 사용", fileType, quizLevel);
        PromptConfig c = new PromptConfig();
        c.setType("quiz");
        c.setFileType(fileType);
        c.setLevel(quizLevel);
        c.setIsActive(true);
        c.setQuizMaxCount(defaultMaxCount(quizLevel));
        c.setQuizMaxGroup(3);
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

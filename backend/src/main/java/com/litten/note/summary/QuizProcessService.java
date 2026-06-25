package com.litten.note.summary;

import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
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
        log.debug("[QuizProcessService] process() - summaryResultId: {}, youtubeVideoId: {}, quizLevel: {}, forceRegenerate: {}",
                req.getSummaryResultId(), req.getYoutubeVideoId(), req.getQuizLevel(), req.isForceRegenerate());

        // 1) 요약 결과 확보 (summaryResultId 없으면 youtubeVideoId+sourceText로 자막 전용 레코드 확보 = 요약 없이 퀴즈)
        SummaryResult summaryResult = resolveSummaryResult(req);
        if (summaryResult == null) {
            return QuizResponseVo.fail("퀴즈를 생성할 요약 결과 또는 원본 텍스트를 찾을 수 없습니다.");
        }
        final Long sid = summaryResult.getSequence();

        String sourceText = summaryResult.getSourceText();
        if (sourceText == null || sourceText.isBlank()) {
            log.warn("[QuizProcessService] sourceText 없음 - summaryResultId: {}", sid);
            return QuizResponseVo.fail("원본 텍스트가 저장되어 있지 않아 퀴즈를 생성할 수 없습니다.");
        }

        // 2) 캐시 확인
        if (!req.isForceRegenerate()) {
            List<QuizResult> cached = quizResultRepository
                    .findBySummaryResultIdAndIsDeletedFalseOrderByGroupOrderAscSortOrderAsc(sid);
            if (!cached.isEmpty()) {
                log.info("[QuizProcessService] 퀴즈 캐시 히트 - summaryResultId: {}, count: {}", sid, cached.size());
                QuizResponseVo cachedVo = toResponseVo(cached, summaryResult.getTotalQuizCount());
                cachedVo.setSummaryResultId(sid);
                return cachedVo;
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
                sid, fileType, quizLevel, maxCount, systemPrompt != null);

        // 4) AI 호출
        QuizResponseVo aiResp = quizService.generate(
                sourceText, fileType, outputLang, systemPrompt, maxCount, maxGroup, typeFilter);
        if (!aiResp.isSuccess()) {
            log.error("[QuizProcessService] AI 퀴즈 생성 실패: {}", aiResp.getError());
            return aiResp;
        }

        // 5) 기존 quiz 삭제 후 저장
        quizResultRepository.deleteBySummaryResultId(sid);
        saveQuizResults(sid, aiResp.getQuizzes());

        // 6) totalQuizCount 업데이트
        summaryResult.setTotalQuizCount(aiResp.getTotalQuizCount());
        summaryResultRepository.save(summaryResult);

        aiResp.setSummaryResultId(sid);
        log.info("[QuizProcessService] 퀴즈 처리 완료 - summaryResultId: {}, count: {}", sid, aiResp.getTotalQuizCount());
        return aiResp;
    }

    /**
     * 퀴즈를 생성할 SummaryResult를 확보한다.
     * - summaryResultId가 있으면 해당 레코드(done 상태)를 반환.
     * - 없으면 youtubeVideoId로 기존 레코드를 찾고(요약/자막 전용), 없으면 sourceText로 자막 전용 레코드를 생성한다.
     */
    private SummaryResult resolveSummaryResult(QuizProcessRequestVo req) {
        if (req.getSummaryResultId() != null) {
            SummaryResult sr = summaryResultRepository.findById(req.getSummaryResultId()).orElse(null);
            if (sr == null || !"done".equals(sr.getStatus())) {
                log.warn("[QuizProcessService] 요약 결과 없음/미완료 - summaryResultId: {}", req.getSummaryResultId());
                return null;
            }
            return sr;
        }

        // 요약 없이 퀴즈 생성 — youtubeVideoId 필수
        String videoId = req.getYoutubeVideoId();
        if (videoId == null || videoId.isBlank()) {
            log.warn("[QuizProcessService] summaryResultId/youtubeVideoId 모두 없음");
            return null;
        }
        String src = req.getSourceText();

        // 기존 영상 레코드(요약 또는 자막 전용) 재사용
        SummaryResult existing = summaryResultRepository
                .findTopByYoutubeVideoIdAndIsDeletedFalseOrderBySummaryLevelDesc(videoId)
                .orElse(null);
        if (existing != null) {
            if ((existing.getSourceText() == null || existing.getSourceText().isBlank())
                    && src != null && !src.isBlank()) {
                existing.setSourceText(src);
                summaryResultRepository.save(existing);
            }
            return existing;
        }

        // 자막 전용 레코드 신규 생성 (요약 본문 없이 sourceText만)
        if (src == null || src.isBlank()) {
            log.warn("[QuizProcessService] 자막(sourceText) 없음 - videoId: {}", videoId);
            return null;
        }
        SummaryResult created = new SummaryResult();
        created.setFileType(req.getFileType() != null && !req.getFileType().isBlank() ? req.getFileType() : "youtube");
        created.setYoutubeVideoId(videoId);
        created.setSourceText(src);
        created.setIsShared(true);
        created.setSummaryLevel(req.getQuizLevel() > 0 ? req.getQuizLevel() : DEFAULT_QUIZ_LEVEL);
        created.setStatus("done");
        created.setProcessedAt(LocalDateTime.now());
        SummaryResult saved = summaryResultRepository.save(created);
        log.info("[QuizProcessService] 자막 전용 요약 레코드 생성 - summaryResultId: {}, videoId: {}", saved.getSequence(), videoId);
        return saved;
    }

    public QuizResponseVo getQuiz(Long summaryResultId) {
        log.debug("[QuizProcessService] getQuiz() - summaryResultId: {}", summaryResultId);
        List<QuizResult> rows = quizResultRepository
                .findBySummaryResultIdAndIsDeletedFalseOrderByGroupOrderAscSortOrderAsc(summaryResultId);
        if (rows.isEmpty()) return null;

        SummaryResult summaryResult = summaryResultRepository.findById(summaryResultId).orElse(null);
        int total = summaryResult != null ? summaryResult.getTotalQuizCount() : rows.size();
        QuizResponseVo vo = toResponseVo(rows, total);
        vo.setSummaryResultId(summaryResultId);
        return vo;
    }

    /** 영상 ID로 저장된 퀴즈 조회 (요약 선행 없이 만든 퀴즈 포함). 없으면 null. */
    public QuizResponseVo getQuizByVideoId(String youtubeVideoId) {
        log.debug("[QuizProcessService] getQuizByVideoId() - videoId: {}", youtubeVideoId);
        SummaryResult sr = summaryResultRepository
                .findTopByYoutubeVideoIdAndIsDeletedFalseOrderBySummaryLevelDesc(youtubeVideoId)
                .orElse(null);
        if (sr == null) return null;
        return getQuiz(sr.getSequence());
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

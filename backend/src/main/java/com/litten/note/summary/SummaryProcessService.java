package com.litten.note.summary;

import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Optional;

/**
 * 요약 처리 서비스.
 *
 * 처리 흐름:
 *   1) note_prompt_config 에서 (type=summary, fileType, level) 기준 설정+프롬프트 조회
 *   2) YouTube/개인 파일: DB 캐시 조회 → 있으면 반환
 *   3) AI 요약 생성 (SummaryService)
 *   4) 요약 → note_summary_result 저장
 *
 * 리마인드는 RemindProcessService 에서 별도 처리.
 */
@Log4j2
@Service
@RequiredArgsConstructor
public class SummaryProcessService {

    private static final int DEFAULT_SUMMARY_LEVEL = 3;

    private final PromptConfigRepository   promptConfigRepository;
    private final SummaryResultRepository  resultRepository;
    private final SummaryService           summaryService;

    // ── 공개 메서드 ──────────────────────────────────────────────────────────

    @Transactional
    public SummaryResponseVo process(SummaryProcessRequestVo req) {
        log.debug("[SummaryProcessService] process() - fileType: {}, videoId: {}, fileUuid: {}",
                req.getFileType(), req.getYoutubeVideoId(), req.getFileUuid());

        int level = req.getSummaryLevel() > 0 ? req.getSummaryLevel() : DEFAULT_SUMMARY_LEVEL;
        String fileType = req.getFileType();

        // 1) note_prompt_config 에서 설정+프롬프트 단일 조회
        PromptConfig config = promptConfigRepository
                .findByTypeAndFileTypeAndLevelAndIsActiveTrue("summary", fileType, level)
                .orElseGet(() -> defaultConfig(fileType, level));

        // 2) 캐시 조회 (YouTube / 개인 파일)
        if (!req.isForceRegenerate()) {
            Optional<SummaryResult> cached = findCached(req, level);
            if (cached.isPresent() && "done".equals(cached.get().getStatus())) {
                log.info("[SummaryProcessService] 캐시 히트 - fileType: {}", fileType);
                return toResponseVo(cached.get());
            }
        }

        // 3) AI 요약 생성
        SummaryRequestVo aiReq = buildAiRequest(req, config, level);
        log.info("[SummaryProcessService] AI 요약 요청 - provider: {}, level: {}",
                config.getAiProvider(), level);

        SummaryResponseVo aiResp = summaryService.summarize(aiReq);
        if (!aiResp.isSuccess()) {
            log.error("[SummaryProcessService] AI 요약 실패: {}", aiResp.getError());
            saveErrorResult(req, config, aiResp.getError());
            return aiResp;
        }

        aiResp.setSummaryLevel(level);

        // 4) 요약 결과 → note_summary_result 저장
        SummaryResult saved = saveSummaryResult(req, config, aiReq, aiResp);
        aiResp.setSummaryResultId(saved.getSequence());

        log.info("[SummaryProcessService] 처리 완료 - summaryResultId: {}", saved.getSequence());
        return aiResp;
    }

    public SummaryResponseVo getYoutubeSummary(String youtubeVideoId, int summaryLevel) {
        log.debug("[SummaryProcessService] getYoutubeSummary() - videoId: {}, level: {}", youtubeVideoId, summaryLevel);
        Optional<SummaryResult> result = summaryLevel > 0
                ? resultRepository.findByYoutubeVideoIdAndSummaryLevelAndIsDeletedFalse(youtubeVideoId, summaryLevel)
                : resultRepository.findTopByYoutubeVideoIdAndIsDeletedFalseOrderBySummaryLevelDesc(youtubeVideoId);
        return result.filter(r -> "done".equals(r.getStatus())).map(this::toResponseVo).orElse(null);
    }

    public SummaryResponseVo getFileSummary(String fileUuid, String memberUuid, int summaryLevel) {
        log.debug("[SummaryProcessService] getFileSummary() - fileUuid: {}, level: {}", fileUuid, summaryLevel);
        Optional<SummaryResult> result = summaryLevel > 0
                ? resultRepository.findByFileUuidAndMemberUuidAndSummaryLevelAndIsDeletedFalse(fileUuid, memberUuid, summaryLevel)
                : resultRepository.findTopByFileUuidAndMemberUuidAndIsDeletedFalseOrderBySummaryLevelDesc(fileUuid, memberUuid);
        return result.filter(r -> "done".equals(r.getStatus())).map(this::toResponseVo).orElse(null);
    }

    // ── 내부: 저장 ───────────────────────────────────────────────────────────

    private SummaryResult saveSummaryResult(SummaryProcessRequestVo req,
                                            PromptConfig config,
                                            SummaryRequestVo aiReq,
                                            SummaryResponseVo resp) {
        SummaryResult entity = findOrCreate(req, aiReq.getSummaryLevel());
        if (config.getSequence() != null && config.getSequence() > 0) {
            entity.setConfigId(config.getSequence());
        }
        entity.setFileType(req.getFileType());
        entity.setSourceText(req.getText());
        entity.setSummaryLevel(aiReq.getSummaryLevel());
        entity.setSummaryFull(resp.getSummary());
        entity.setSummaryOnly(resp.getSummaryOnly());
        entity.setTotalRemindCount(resp.getTotalRemindCount());
        entity.setStatus("done");
        entity.setProcessedAt(LocalDateTime.now());
        entity.setErrorMessage(null);

        SummaryResult saved = resultRepository.save(entity);
        log.info("[SummaryProcessService] note_summary_result 저장 - sequence: {}", saved.getSequence());
        return saved;
    }

    private void saveErrorResult(SummaryProcessRequestVo req, PromptConfig config, String errorMsg) {
        SummaryResult entity = findOrCreate(req, req.getSummaryLevel() > 0 ? req.getSummaryLevel() : DEFAULT_SUMMARY_LEVEL);
        if (config.getSequence() != null && config.getSequence() > 0) {
            entity.setConfigId(config.getSequence());
        }
        entity.setFileType(req.getFileType());
        entity.setStatus("error");
        entity.setErrorMessage(errorMsg);
        entity.setProcessedAt(LocalDateTime.now());
        resultRepository.save(entity);
    }

    // ── 내부: 조회/변환 ──────────────────────────────────────────────────────

    private Optional<SummaryResult> findCached(SummaryProcessRequestVo req, int level) {
        if ("youtube".equalsIgnoreCase(req.getFileType()) && req.getYoutubeVideoId() != null) {
            return resultRepository.findByYoutubeVideoIdAndSummaryLevelAndIsDeletedFalse(
                    req.getYoutubeVideoId(), level);
        }
        if (req.getFileUuid() != null) {
            return resultRepository.findByFileUuidAndMemberUuidAndSummaryLevelAndIsDeletedFalse(
                    req.getFileUuid(), req.getMemberUuid(), level);
        }
        return Optional.empty();
    }

    private SummaryResult findOrCreate(SummaryProcessRequestVo req, int level) {
        if ("youtube".equalsIgnoreCase(req.getFileType()) && req.getYoutubeVideoId() != null) {
            return resultRepository.findByYoutubeVideoIdAndSummaryLevelAndIsDeletedFalse(
                            req.getYoutubeVideoId(), level)
                    .orElseGet(() -> {
                        SummaryResult r = new SummaryResult();
                        r.setYoutubeVideoId(req.getYoutubeVideoId());
                        r.setIsShared(true);
                        return r;
                    });
        }
        if (req.getFileUuid() != null) {
            return resultRepository.findByFileUuidAndMemberUuidAndSummaryLevelAndIsDeletedFalse(
                            req.getFileUuid(), req.getMemberUuid(), level)
                    .orElseGet(() -> {
                        SummaryResult r = new SummaryResult();
                        r.setFileUuid(req.getFileUuid());
                        r.setMemberUuid(req.getMemberUuid());
                        r.setIsShared(false);
                        return r;
                    });
        }
        return new SummaryResult();
    }

    private SummaryResponseVo toResponseVo(SummaryResult entity) {
        SummaryResponseVo vo = SummaryResponseVo.ok(
                entity.getSummaryFull() != null ? entity.getSummaryFull() : "",
                entity.getSummaryLevel() != null ? entity.getSummaryLevel() : 0);
        vo.setSummaryResultId(entity.getSequence());
        vo.setTotalRemindCount(entity.getTotalRemindCount());
        return vo;
    }

    // ── 내부: 요청 빌드 ──────────────────────────────────────────────────────

    private SummaryRequestVo buildAiRequest(SummaryProcessRequestVo req,
                                            PromptConfig config, int level) {
        SummaryRequestVo ar = new SummaryRequestVo();
        ar.setText(req.getText());
        ar.setFileId(req.getFileUuid() != null ? req.getFileUuid() : req.getYoutubeVideoId());
        ar.setSummaryLevel(level);

        String sourceLang = isBlank(req.getTextLanguage()) ? "ko" : req.getTextLanguage();
        String outputLang = isBlank(req.getSummaryLanguage()) ? sourceLang : req.getSummaryLanguage();
        ar.setTextLanguage(sourceLang);
        ar.setSummaryLanguage(outputLang);

        // 프롬프트가 있으면 플레이스홀더 치환 후 적용
        if (!isBlank(config.getPrompt())) {
            String prompt = config.getPrompt()
                    .replace("{{SOURCE_LANG}}", sourceLang)
                    .replace("{{OUTPUT_LANG}}", outputLang);
            ar.setSystemPrompt(prompt);
            log.info("[SummaryProcessService] DB 프롬프트 적용 - 길이: {}", config.getPrompt().length());
        } else {
            log.debug("[SummaryProcessService] DB 프롬프트 없음 - 코드 fallback 사용");
        }

        return ar;
    }

    // ── 내부: 기본값 ─────────────────────────────────────────────────────────

    private PromptConfig defaultConfig(String fileType, int level) {
        log.warn("[SummaryProcessService] PromptConfig 없음 - fileType: {}, level: {} → 기본값 사용", fileType, level);
        PromptConfig c = new PromptConfig();
        c.setSequence(0L);
        c.setType("summary");
        c.setFileType(fileType);
        c.setLevel(level);
        c.setAiProvider("openai");
        return c;
    }

    private boolean isBlank(String s) {
        return s == null || s.isBlank();
    }
}

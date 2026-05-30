package com.litten.note.summary;

import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * 요약/리마인드 처리 통합 서비스.
 *
 * 처리 흐름:
 *   1) note_summary_config 에서 fileType 기준 파라미터 조회
 *   2) YouTube/개인 파일: DB 캐시 조회 → 있으면 반환
 *   3) AI 요약 생성 (SummaryService)
 *   4) 요약 → note_summary_result 저장
 *   5) 리마인드 항목 → note_remind_result 에 행별 저장
 */
@Log4j2
@Service
@RequiredArgsConstructor
public class SummaryProcessService {

    private final SummaryConfigRepository  configRepository;
    private final SummaryResultRepository  resultRepository;
    private final RemindResultRepository   remindResultRepository;
    private final SummaryService           summaryService;

    // ── 공개 메서드 ──────────────────────────────────────────────────────────

    @Transactional
    public SummaryResponseVo process(SummaryProcessRequestVo req) {
        log.debug("[SummaryProcessService] process() - fileType: {}, videoId: {}, fileUuid: {}",
                req.getFileType(), req.getYoutubeVideoId(), req.getFileUuid());

        // 1) 파라미터 설정 조회
        SummaryConfig config = configRepository
                .findByFileTypeAndIsActiveTrue(req.getFileType())
                .orElseGet(() -> defaultConfig(req.getFileType()));

        // 2) 캐시 조회 (YouTube / 개인 파일)
        if (!req.isForceRegenerate()) {
            Optional<SummaryResult> cached = findCached(req);
            if (cached.isPresent() && "done".equals(cached.get().getStatus())) {
                log.info("[SummaryProcessService] 캐시 히트 - fileType: {}", req.getFileType());
                return toResponseVo(cached.get());
            }
        }

        // 3) AI 요약 생성
        SummaryRequestVo aiReq = buildAiRequest(req, config);
        log.info("[SummaryProcessService] AI 요약 요청 - provider: {}, level: {}",
                config.getAiProvider(), aiReq.getSummaryLevel());

        SummaryResponseVo aiResp = summaryService.summarize(aiReq);

        if (!aiResp.isSuccess()) {
            log.error("[SummaryProcessService] AI 요약 실패: {}", aiResp.getError());
            saveErrorResult(req, config, aiResp.getError());
            return aiResp;
        }

        // 4) 요약 결과 → note_summary_result 저장
        SummaryResult saved = saveSummaryResult(req, config, aiResp);

        // 5) 리마인드 항목 → note_remind_result 행별 저장
        saveRemindResults(saved.getSequence(), aiResp.getReminds());

        log.info("[SummaryProcessService] 처리 완료 - summaryResultId: {}, remindCount: {}",
                saved.getSequence(), aiResp.getTotalRemindCount());

        return aiResp;
    }

    public SummaryResponseVo getYoutubeSummary(String youtubeVideoId) {
        log.debug("[SummaryProcessService] getYoutubeSummary() - videoId: {}", youtubeVideoId);
        return resultRepository.findByYoutubeVideoIdAndIsDeletedFalse(youtubeVideoId)
                .filter(r -> "done".equals(r.getStatus()))
                .map(this::toResponseVo)
                .orElse(null);
    }

    public SummaryResponseVo getFileSummary(String fileUuid, String memberUuid) {
        log.debug("[SummaryProcessService] getFileSummary() - fileUuid: {}", fileUuid);
        return resultRepository.findByFileUuidAndMemberUuidAndIsDeletedFalse(fileUuid, memberUuid)
                .filter(r -> "done".equals(r.getStatus()))
                .map(this::toResponseVo)
                .orElse(null);
    }

    // ── 내부: 저장 ───────────────────────────────────────────────────────────

    private SummaryResult saveSummaryResult(SummaryProcessRequestVo req,
                                            SummaryConfig config,
                                            SummaryResponseVo resp) {
        SummaryResult entity = findOrCreate(req);
        entity.setConfigId(config.getSequence());
        entity.setFileType(req.getFileType());
        entity.setSourceText(req.getText());
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

    /**
     * 리마인드 그룹/항목을 note_remind_result 에 행별로 저장.
     * 재생성 시 기존 항목 삭제 후 재삽입.
     */
    private void saveRemindResults(Long summaryResultId, List<RemindGroup> groups) {
        if (groups == null || groups.isEmpty()) {
            log.debug("[SummaryProcessService] 리마인드 항목 없음 - summaryResultId: {}", summaryResultId);
            return;
        }

        // 기존 항목 삭제 (재생성 대비)
        remindResultRepository.deleteBySummaryResultId(summaryResultId);

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
                row.setDetailText(item.getDetails() != null
                        ? String.join("\n", item.getDetails()) : null);
                row.setSortOrder(sortOrder);
                rows.add(row);
                sortOrder++;
            }
            groupOrder++;
        }

        remindResultRepository.saveAll(rows);
        log.info("[SummaryProcessService] note_remind_result 저장 - {}행", rows.size());
    }

    private void saveErrorResult(SummaryProcessRequestVo req, SummaryConfig config, String errorMsg) {
        SummaryResult entity = findOrCreate(req);
        entity.setConfigId(config.getSequence());
        entity.setFileType(req.getFileType());
        entity.setStatus("error");
        entity.setErrorMessage(errorMsg);
        entity.setProcessedAt(LocalDateTime.now());
        resultRepository.save(entity);
    }

    // ── 내부: 조회/변환 ──────────────────────────────────────────────────────

    private Optional<SummaryResult> findCached(SummaryProcessRequestVo req) {
        if ("youtube".equalsIgnoreCase(req.getFileType()) && req.getYoutubeVideoId() != null) {
            return resultRepository.findByYoutubeVideoIdAndIsDeletedFalse(req.getYoutubeVideoId());
        }
        if (req.getFileUuid() != null) {
            return resultRepository.findByFileUuidAndMemberUuidAndIsDeletedFalse(
                    req.getFileUuid(), req.getMemberUuid());
        }
        return Optional.empty();
    }

    private SummaryResult findOrCreate(SummaryProcessRequestVo req) {
        if ("youtube".equalsIgnoreCase(req.getFileType()) && req.getYoutubeVideoId() != null) {
            return resultRepository.findByYoutubeVideoIdAndIsDeletedFalse(req.getYoutubeVideoId())
                    .orElseGet(() -> {
                        SummaryResult r = new SummaryResult();
                        r.setYoutubeVideoId(req.getYoutubeVideoId());
                        r.setIsShared(true);
                        return r;
                    });
        }
        if (req.getFileUuid() != null) {
            return resultRepository.findByFileUuidAndMemberUuidAndIsDeletedFalse(
                            req.getFileUuid(), req.getMemberUuid())
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

    /**
     * DB 결과를 응답 VO로 변환.
     * 리마인드 항목은 note_remind_result 에서 조회하여 구조화.
     */
    private SummaryResponseVo toResponseVo(SummaryResult entity) {
        // 요약 텍스트 기반 파싱 (섹션 구조화)
        SummaryResponseVo vo = SummaryResponseVo.ok(
                entity.getSummaryFull() != null ? entity.getSummaryFull() : "");

        // 리마인드 항목 DB 조회로 재구성
        List<RemindResult> rows = remindResultRepository
                .findBySummaryResultIdAndIsDeletedFalseOrderByGroupOrderAscSortOrderAsc(
                        entity.getSequence());

        if (!rows.isEmpty()) {
            vo.setReminds(toRemindGroups(rows));
            vo.setTotalRemindCount(entity.getTotalRemindCount());
        }

        return vo;
    }

    private List<RemindGroup> toRemindGroups(List<RemindResult> rows) {
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
        return groups;
    }

    // ── 내부: 기본값 ─────────────────────────────────────────────────────────

    private SummaryRequestVo buildAiRequest(SummaryProcessRequestVo req, SummaryConfig config) {
        SummaryRequestVo ar = new SummaryRequestVo();
        ar.setText(req.getText());
        ar.setFileId(req.getFileUuid() != null ? req.getFileUuid() : req.getYoutubeVideoId());
        ar.setSummaryLevel(req.getSummaryLevel() > 0
                ? req.getSummaryLevel() : config.getSummaryLevel());
        ar.setTextLanguage(isBlank(req.getTextLanguage())
                ? config.getTextLanguage() : req.getTextLanguage());
        ar.setSummaryLanguage(isBlank(req.getSummaryLanguage())
                ? config.getSummaryLanguage() : req.getSummaryLanguage());
        return ar;
    }

    private SummaryConfig defaultConfig(String fileType) {
        log.warn("[SummaryProcessService] fileType={} config 없음 - 기본값 사용", fileType);
        SummaryConfig c = new SummaryConfig();
        c.setSequence(0L);
        c.setFileType(fileType);
        c.setAiProvider("openai");
        c.setSummaryLevel(3);
        c.setTextLanguage("ko");
        c.setSummaryLanguage("ko");
        return c;
    }

    private boolean isBlank(String s) {
        return s == null || s.isBlank();
    }
}

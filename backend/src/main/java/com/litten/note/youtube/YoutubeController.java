package com.litten.note.youtube;

import com.litten.common.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.data.domain.Page;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Log4j2
@RestController
@RequiredArgsConstructor
public class YoutubeController {

    private final YoutubeService youtubeService;

    // ── 채널 구독 목록 조회 ────────────────────────────────────────────────────

    @GetMapping("/note/v1/youtube/channels")
    public ResponseEntity<Map<String, Object>> getChannels() {
        log.debug("[YoutubeController] GET /note/v1/youtube/channels 진입");
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();

        List<YoutubeChannel> channels = youtubeService.getSubscribedChannels(memberId);
        log.info("[YoutubeController] 채널 목록 조회 - memberId: {}, count: {}", memberId, channels.size());
        return ok(Map.of("channels", channels));
    }

    // ── 채널 구독 등록 ─────────────────────────────────────────────────────────

    @PostMapping("/note/v1/youtube/channels")
    public ResponseEntity<Map<String, Object>> subscribe(@RequestBody Map<String, Object> body) {
        log.debug("[YoutubeController] POST /note/v1/youtube/channels 진입");
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();

        String channelId = asString(body.get("channelId"));
        String channelName = asString(body.get("channelName"));
        String channelThumbnail = asString(body.getOrDefault("channelThumbnail", ""));
        Boolean autoTitle = asBool(body.get("autoTitle"), true);
        Boolean autoMemo = asBool(body.get("autoMemo"), false);
        Boolean autoSummary = asBool(body.get("autoSummary"), false);
        Boolean autoRemind = asBool(body.get("autoRemind"), false);
        String summaryType = asString(body.get("summaryType"));
        String remindType  = asString(body.get("remindType"));
        Integer remindCustomCount = asInt(body.get("remindCustomCount"));

        if (channelId == null || channelId.isBlank()) {
            return badRequest("channelId는 필수입니다.");
        }

        log.info("[YoutubeController] 채널 구독 요청 - memberId: {}, channelId: {}, autoTitle: {}, autoMemo: {}, autoSummary: {} ({}), autoRemind: {} ({}{})",
                memberId, channelId, autoTitle, autoMemo, autoSummary, summaryType, autoRemind, remindType,
                "CUSTOM".equals(remindType) && remindCustomCount != null ? "=" + remindCustomCount : "");
        YoutubeChannel channel = youtubeService.subscribe(memberId, channelId, channelName, channelThumbnail,
                autoTitle, autoMemo, autoSummary, autoRemind, summaryType, remindType, remindCustomCount);
        return ok(Map.of("channel", channel));
    }

    // ── 채널 자동화 설정 업데이트 ──────────────────────────────────────────────

    @PatchMapping("/note/v1/youtube/channels/{id}")
    public ResponseEntity<Map<String, Object>> updateSettings(
            @PathVariable Long id, @RequestBody Map<String, Object> body) {
        log.debug("[YoutubeController] PATCH /note/v1/youtube/channels/{} 진입", id);
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();

        Boolean autoTitle   = body.get("autoTitle")   instanceof Boolean b ? b : null;
        Boolean autoMemo    = body.get("autoMemo")    instanceof Boolean b ? b : null;
        Boolean autoSummary = body.get("autoSummary") instanceof Boolean b ? b : null;
        Boolean autoRemind  = body.get("autoRemind")  instanceof Boolean b ? b : null;
        String  summaryType = body.containsKey("summaryType") ? asString(body.get("summaryType")) : null;
        String  remindType  = body.containsKey("remindType")  ? asString(body.get("remindType"))  : null;
        Integer remindCustomCount = body.containsKey("remindCustomCount") ? asInt(body.get("remindCustomCount")) : null;
        boolean clearSummaryType = body.containsKey("summaryType") && body.get("summaryType") == null;
        boolean clearRemindType  = body.containsKey("remindType")  && body.get("remindType")  == null;
        boolean clearRemindCustomCount = body.containsKey("remindCustomCount") && body.get("remindCustomCount") == null;

        log.info("[YoutubeController] 설정 업데이트 - memberId: {}, channelPk: {}, autoTitle: {}, autoMemo: {}, autoSummary: {} ({}), autoRemind: {} ({}{})",
                memberId, id, autoTitle, autoMemo, autoSummary, summaryType, autoRemind, remindType,
                "CUSTOM".equals(remindType) && remindCustomCount != null ? "=" + remindCustomCount : "");
        boolean updated = youtubeService.updateSettings(memberId, id, autoTitle, autoMemo, autoSummary, autoRemind,
                summaryType, clearSummaryType, remindType, clearRemindType, remindCustomCount, clearRemindCustomCount);
        if (!updated) return badRequest("채널을 찾을 수 없습니다.");
        return ok(Map.of("message", "설정 업데이트 완료"));
    }

    private String asString(Object v) {
        return v == null ? null : v.toString();
    }

    private Boolean asBool(Object v, boolean defaultValue) {
        if (v == null) return defaultValue;
        if (v instanceof Boolean b) return b;
        return Boolean.parseBoolean(v.toString());
    }

    private Integer asInt(Object v) {
        if (v == null) return null;
        if (v instanceof Number n) return n.intValue();
        try {
            return Integer.parseInt(v.toString());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    // ── 채널 구독 해제 ─────────────────────────────────────────────────────────

    @DeleteMapping("/note/v1/youtube/channels/{id}")
    public ResponseEntity<Map<String, Object>> unsubscribe(@PathVariable Long id) {
        log.debug("[YoutubeController] DELETE /note/v1/youtube/channels/{} 진입", id);
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();

        youtubeService.unsubscribe(memberId, id);
        log.info("[YoutubeController] 채널 구독 해제 완료 - memberId: {}, channelPk: {}", memberId, id);
        return ok(Map.of("message", "구독 해제 완료"));
    }

    // ── 채널 정보 조회 (구독 전 채널 ID 검증) ─────────────────────────────────

    @GetMapping("/note/v1/youtube/channels/info")
    public ResponseEntity<Map<String, Object>> getChannelInfo(@RequestParam String channelId) {
        log.debug("[YoutubeController] GET /note/v1/youtube/channels/info - channelId: {}", channelId);
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();

        Map<String, String> info = youtubeService.fetchChannelInfo(channelId);
        if (info == null) {
            return badRequest("채널을 찾을 수 없거나 공개 채널이 아닙니다.");
        }
        return ok(Map.of("channel", info));
    }

    // ── 채널별 영상 목록 조회 (제목만, 페이징) ───────────────────────────────

    @GetMapping("/note/v1/youtube/channels/{channelId}/videos")
    public ResponseEntity<Map<String, Object>> getVideos(
            @PathVariable String channelId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "3") int size) {
        log.debug("[YoutubeController] GET /note/v1/youtube/channels/{}/videos - page: {}, size: {}", channelId, page, size);
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();

        Page<YoutubeVideoSummaryDto> videoPage = youtubeService.getChannelVideoSummaries(channelId, page, size);
        log.info("[YoutubeController] 영상 목록 조회 - channelId: {}, page: {}, totalPages: {}, count: {}",
                channelId, page, videoPage.getTotalPages(), videoPage.getContent().size());
        return ok(Map.of(
                "videos", videoPage.getContent(),
                "totalPages", videoPage.getTotalPages(),
                "totalElements", videoPage.getTotalElements()
        ));
    }

    // ── 영상 상세 조회 (자막/요약 포함) ───────────────────────────────────────

    @GetMapping("/note/v1/youtube/videos/{id}")
    public ResponseEntity<Map<String, Object>> getVideoDetail(@PathVariable Long id) {
        log.debug("[YoutubeController] GET /note/v1/youtube/videos/{} 진입", id);
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();

        return youtubeService.findVideoById(id)
                .map(v -> {
                    log.info("[YoutubeController] 영상 상세 조회 - id: {}, title: {}", v.getId(), v.getTitle());
                    return ok(Map.of("video", v));
                })
                .orElse(badRequest("영상을 찾을 수 없습니다."));
    }

    // ── 헬퍼 ──────────────────────────────────────────────────────────────────

    private ResponseEntity<Map<String, Object>> ok(Map<String, Object> data) {
        Map<String, Object> result = new HashMap<>(data);
        result.put("success", true);
        return ResponseEntity.ok(result);
    }

    private ResponseEntity<Map<String, Object>> unauthorized() {
        log.warn("[YoutubeController] 인증되지 않은 요청");
        return ResponseEntity.status(401).body(Map.of("success", false, "message", "로그인이 필요합니다."));
    }

    private ResponseEntity<Map<String, Object>> badRequest(String message) {
        return ResponseEntity.badRequest().body(Map.of("success", false, "message", message));
    }
}

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

        List<YoutubeSubscriptionDto> channels = youtubeService.getSubscribedChannels(memberId);
        log.info("[YoutubeController] 채널 목록 조회 - memberId: {}, count: {}", memberId, channels.size());
        return ok(Map.of("channels", channels));
    }

    // ── 채널 구독 등록 ─────────────────────────────────────────────────────────

    @PostMapping("/note/v1/youtube/channels")
    public ResponseEntity<Map<String, Object>> subscribe(@RequestBody Map<String, Object> body) {
        log.debug("[YoutubeController] POST /note/v1/youtube/channels 진입");
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();

        String channelId        = asString(body.get("channelId"));
        String channelName      = asString(body.get("channelName"));
        String channelThumbnail = asString(body.getOrDefault("channelThumbnail", ""));
        Boolean autoTitle       = asBool(body.get("autoTitle"), true);
        Boolean autoMemo        = asBool(body.get("autoMemo"), false);
        Boolean autoSummary     = asBool(body.get("autoSummary"), false);
        Boolean autoQuiz      = asBool(body.get("autoQuiz"), false);
        String summaryType      = asString(body.get("summaryType"));
        String quizType       = asString(body.get("quizType"));
        Integer quizCustomCount = asInt(body.get("quizCustomCount"));

        if (channelId == null || channelId.isBlank()) {
            return badRequest("channelId는 필수입니다.");
        }

        log.info("[YoutubeController] 채널 구독 요청 - memberId: {}, channelId: {}, autoSummary: {} ({}), autoQuiz: {} ({}{})",
                memberId, channelId, autoSummary, summaryType, autoQuiz, quizType,
                "CUSTOM".equals(quizType) && quizCustomCount != null ? "=" + quizCustomCount : "");

        MemberYoutubeChannel sub = youtubeService.subscribe(memberId, channelId, channelName, channelThumbnail,
                autoTitle, autoMemo, autoSummary, autoQuiz, summaryType, quizType, quizCustomCount);
        return ok(Map.of("channel", YoutubeSubscriptionDto.of(sub)));
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
        Boolean autoQuiz  = body.get("autoQuiz")  instanceof Boolean b ? b : null;
        String  summaryType = body.containsKey("summaryType") ? asString(body.get("summaryType")) : null;
        String  quizType  = body.containsKey("quizType")  ? asString(body.get("quizType"))  : null;
        Integer quizCustomCount     = body.containsKey("quizCustomCount") ? asInt(body.get("quizCustomCount")) : null;
        boolean clearSummaryType      = body.containsKey("summaryType") && body.get("summaryType") == null;
        boolean clearQuizType       = body.containsKey("quizType")  && body.get("quizType")  == null;
        boolean clearQuizCustomCount = body.containsKey("quizCustomCount") && body.get("quizCustomCount") == null;

        log.info("[YoutubeController] 설정 업데이트 - memberId: {}, subscriptionId: {}", memberId, id);
        boolean updated = youtubeService.updateSettings(memberId, id, autoTitle, autoMemo, autoSummary, autoQuiz,
                summaryType, clearSummaryType, quizType, clearQuizType, quizCustomCount, clearQuizCustomCount);
        if (!updated) return badRequest("구독 정보를 찾을 수 없습니다.");
        return ok(Map.of("message", "설정 업데이트 완료"));
    }

    // ── 채널 구독 해제 ─────────────────────────────────────────────────────────

    @DeleteMapping("/note/v1/youtube/channels/{id}")
    public ResponseEntity<Map<String, Object>> unsubscribe(@PathVariable Long id) {
        log.debug("[YoutubeController] DELETE /note/v1/youtube/channels/{} 진입", id);
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();

        youtubeService.unsubscribe(memberId, id);
        log.info("[YoutubeController] 채널 구독 해제 완료 - memberId: {}, subscriptionId: {}", memberId, id);
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

    // ── 채널별 영상 목록 조회 (페이징) ───────────────────────────────────────

    @GetMapping("/note/v1/youtube/channels/{channelId}/videos")
    public ResponseEntity<Map<String, Object>> getVideos(
            @PathVariable String channelId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "3") int size) {
        log.debug("[YoutubeController] GET /note/v1/youtube/channels/{}/videos - page: {}, size: {}", channelId, page, size);
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();

        Page<YoutubeVideoSummaryDto> videoPage = youtubeService.getChannelVideoSummaries(channelId, page, size);
        log.info("[YoutubeController] 영상 목록 조회 - channelId: {}, totalElements: {}", channelId, videoPage.getTotalElements());
        return ok(Map.of(
                "videos", videoPage.getContent(),
                "totalPages", videoPage.getTotalPages(),
                "totalElements", videoPage.getTotalElements()
        ));
    }

    // ── 영상 상세 조회 ─────────────────────────────────────────────────────────

    @GetMapping("/note/v1/youtube/videos/{id}")
    public ResponseEntity<Map<String, Object>> getVideoDetail(@PathVariable Long id) {
        log.debug("[YoutubeController] GET /note/v1/youtube/videos/{} 진입", id);
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();

        return youtubeService.findVideoById(id)
                .map(v -> ok(Map.of("video", v)))
                .orElse(badRequest("영상을 찾을 수 없습니다."));
    }

    // ── 자막 저장 ──────────────────────────────────────────────────────────────

    @PostMapping("/note/v1/youtube/videos/{videoId}/transcript")
    public ResponseEntity<Map<String, Object>> saveTranscript(
            @PathVariable String videoId, @RequestBody Map<String, Object> body) {
        log.debug("[YoutubeController] POST /note/v1/youtube/videos/{}/transcript 진입", videoId);
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();

        String transcript = asString(body.get("transcript"));
        if (transcript == null || transcript.isBlank()) return badRequest("transcript는 필수입니다.");

        log.info("[YoutubeController] 자막 저장 요청 - videoId: {}, length: {}", videoId, transcript.length());
        boolean saved = youtubeService.saveTranscript(videoId, transcript);
        if (!saved) return badRequest("영상을 찾을 수 없습니다. videoId: " + videoId);
        return ok(Map.of("message", "자막 저장 완료"));
    }

    // ── yt-dlp 자막 추출 ──────────────────────────────────────────────────────

    @PostMapping("/note/v1/youtube/videos/{videoId}/transcript-ytdlp")
    public ResponseEntity<Map<String, Object>> extractTranscriptYtDlp(@PathVariable String videoId) {
        log.debug("[YoutubeController] POST /note/v1/youtube/videos/{}/transcript-ytdlp 진입", videoId);
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();

        log.info("[YoutubeController] 자막 추출 요청 (yt-dlp/Supadata) - videoId: {}", videoId);
        String transcript = youtubeService.extractTranscriptAuto(videoId);
        if (transcript == null || transcript.isBlank()) {
            log.warn("[YoutubeController] 자막 추출 실패 - videoId: {}", videoId);
            return badRequest("자막을 가져올 수 없습니다.");
        }

        youtubeService.saveTranscript(videoId, transcript);
        log.info("[YoutubeController] 자막 추출 성공 및 저장 - videoId: {}, length: {}", videoId, transcript.length());
        return ok(Map.of("transcript", transcript));
    }

    // ── 채널 확인 상태(new 표시) 동기화 — 프리미엄 전용 ───────────────────────

    /**
     * GET /note/v1/youtube/watch-states
     * 회원의 전체 채널 확인 상태 목록 조회.
     * Response: { success, watchStates: [ { channelId, lastSeenAt, lastSeenVideoId, updatedAt }, ... ] }
     */
    @GetMapping("/note/v1/youtube/watch-states")
    public ResponseEntity<Map<String, Object>> getWatchStates() {
        log.debug("[YoutubeController] GET /note/v1/youtube/watch-states 진입");
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();

        List<ChannelWatchStateDto> states = youtubeService.getWatchStates(memberId);
        log.info("[YoutubeController] 확인 상태 조회 - memberId: {}, count: {}", memberId, states.size());
        return ok(Map.of("watchStates", states));
    }

    /**
     * PUT /note/v1/youtube/watch-states
     * 채널 확인 상태 upsert (단건). 프론트 markSeen 시 호출.
     * Request Body: { channelId, lastSeenAt, lastSeenVideoId, updatedAt }
     */
    @PutMapping("/note/v1/youtube/watch-states")
    public ResponseEntity<Map<String, Object>> upsertWatchState(@RequestBody ChannelWatchStateDto request) {
        log.debug("[YoutubeController] PUT /note/v1/youtube/watch-states 진입 - channelId: {}", request.getChannelId());
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        if (request.getChannelId() == null || request.getChannelId().isBlank()) {
            return badRequest("channelId는 필수입니다.");
        }

        ChannelWatchStateDto saved = youtubeService.upsertWatchState(memberId, request);
        return ok(Map.of("watchState", saved));
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

    private String asString(Object v) { return v == null ? null : v.toString(); }

    private Boolean asBool(Object v, boolean defaultValue) {
        if (v == null) return defaultValue;
        if (v instanceof Boolean b) return b;
        return Boolean.parseBoolean(v.toString());
    }

    private Integer asInt(Object v) {
        if (v == null) return null;
        if (v instanceof Number n) return n.intValue();
        try { return Integer.parseInt(v.toString()); } catch (NumberFormatException e) { return null; }
    }
}

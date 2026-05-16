package com.litten.note.youtube;

import com.litten.common.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
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
    public ResponseEntity<Map<String, Object>> subscribe(@RequestBody Map<String, String> body) {
        log.debug("[YoutubeController] POST /note/v1/youtube/channels 진입");
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();

        String channelId = body.get("channelId");
        String channelName = body.get("channelName");
        String channelThumbnail = body.getOrDefault("channelThumbnail", "");
        Boolean autoTitle = Boolean.parseBoolean(body.getOrDefault("autoTitle", "true"));
        Boolean autoMemo = Boolean.parseBoolean(body.getOrDefault("autoMemo", "false"));
        Boolean autoSummary = Boolean.parseBoolean(body.getOrDefault("autoSummary", "false"));
        Boolean autoRemind = Boolean.parseBoolean(body.getOrDefault("autoRemind", "false"));

        if (channelId == null || channelId.isBlank()) {
            return badRequest("channelId는 필수입니다.");
        }

        log.info("[YoutubeController] 채널 구독 요청 - memberId: {}, channelId: {}, autoTitle: {}, autoMemo: {}, autoSummary: {}, autoRemind: {}",
                memberId, channelId, autoTitle, autoMemo, autoSummary, autoRemind);
        YoutubeChannel channel = youtubeService.subscribe(memberId, channelId, channelName, channelThumbnail, autoTitle, autoMemo, autoSummary, autoRemind);
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

        log.info("[YoutubeController] 설정 업데이트 - memberId: {}, channelPk: {}, autoTitle: {}, autoMemo: {}, autoSummary: {}, autoRemind: {}",
                memberId, id, autoTitle, autoMemo, autoSummary, autoRemind);
        boolean updated = youtubeService.updateSettings(memberId, id, autoTitle, autoMemo, autoSummary, autoRemind);
        if (!updated) return badRequest("채널을 찾을 수 없습니다.");
        return ok(Map.of("message", "설정 업데이트 완료"));
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

    // ── 채널별 영상 요약 목록 조회 ────────────────────────────────────────────

    @GetMapping("/note/v1/youtube/channels/{channelId}/videos")
    public ResponseEntity<Map<String, Object>> getVideos(@PathVariable String channelId) {
        log.debug("[YoutubeController] GET /note/v1/youtube/channels/{}/videos 진입", channelId);
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();

        List<YoutubeVideo> videos = youtubeService.getChannelVideos(channelId);
        log.info("[YoutubeController] 영상 목록 조회 - channelId: {}, count: {}", channelId, videos.size());
        return ok(Map.of("videos", videos));
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

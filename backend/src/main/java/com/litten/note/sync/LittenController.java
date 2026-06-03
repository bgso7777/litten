package com.litten.note.sync;

import com.litten.common.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 리튼(노트 공간) 메타 동기화 API. 프리미엄(JWT) 전용.
 *
 * ┌──────────────────────────────────────────────────────────┐
 * │ GET    /note/v1/littens             회원 리튼 목록 (pull) │
 * │ POST   /note/v1/littens             리튼 업서트 (id 기준) │
 * │ DELETE /note/v1/littens/{littenId}  리튼 삭제             │
 * └──────────────────────────────────────────────────────────┘
 * 게스트(guest:)는 권한이 없어 차단됨 (SecurityConfiguration).
 */
@Log4j2
@RestController
@RequiredArgsConstructor
public class LittenController {

    private final LittenService littenService;

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @GetMapping("/note/v1/littens")
    public ResponseEntity<Map<String, Object>> getLittens() {
        log.debug("[LittenController] GET /note/v1/littens 진입");
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();

        List<Map<String, Object>> littens = littenService.getLittens(memberId);
        log.info("[LittenController] 리튼 목록 조회 - memberId: {}, count: {}", memberId, littens.size());
        return ok(Map.of("littens", littens));
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @PostMapping("/note/v1/littens")
    public ResponseEntity<Map<String, Object>> upsertLitten(@RequestBody Map<String, Object> body) {
        log.debug("[LittenController] POST /note/v1/littens 진입 - id: {}", body.get("id"));
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();

        try {
            Map<String, Object> saved = littenService.upsert(memberId, body);
            return ok(Map.of("litten", saved));
        } catch (IllegalArgumentException e) {
            return badRequest(e.getMessage());
        }
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @DeleteMapping("/note/v1/littens/{littenId}")
    public ResponseEntity<Map<String, Object>> deleteLitten(@PathVariable String littenId) {
        log.debug("[LittenController] DELETE /note/v1/littens/{} 진입", littenId);
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();

        boolean deleted = littenService.delete(memberId, littenId);
        if (!deleted) return badRequest("리튼을 찾을 수 없습니다.");
        return ok(Map.of("message", "삭제 완료"));
    }

    // ── 헬퍼 ──────────────────────────────────────────────────────────────────

    private ResponseEntity<Map<String, Object>> ok(Map<String, Object> data) {
        Map<String, Object> result = new HashMap<>(data);
        result.put("success", true);
        return ResponseEntity.ok(result);
    }

    private ResponseEntity<Map<String, Object>> unauthorized() {
        log.warn("[LittenController] 인증되지 않은 요청");
        return ResponseEntity.status(401).body(Map.of("success", false, "message", "로그인이 필요합니다."));
    }

    private ResponseEntity<Map<String, Object>> badRequest(String message) {
        return ResponseEntity.badRequest().body(Map.of("success", false, "message", message));
    }
}

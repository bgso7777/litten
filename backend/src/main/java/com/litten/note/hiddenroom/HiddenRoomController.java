package com.litten.note.hiddenroom;

import com.litten.common.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 스터디룸 대화 숨김('방 나가기') API. 로그인 회원 전용. 다기기 동기화용.
 *  GET    /note/v1/hidden-rooms                   내 숨김 목록 [{convKey, hiddenAt}]
 *  POST   /note/v1/hidden-rooms                   숨김 {convKey}
 *  DELETE /note/v1/hidden-rooms?convKey=          숨김 해제
 * (구경로 /note/v1/hidden-conversations 병행 노출 — 구버전 앱 호환)
 */
@Log4j2
@RestController
@RequiredArgsConstructor
public class HiddenRoomController {

    private final HiddenRoomService service;

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @GetMapping({"/note/v1/hidden-rooms", "/note/v1/hidden-conversations"})
    public ResponseEntity<Map<String, Object>> list() {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        List<Map<String, Object>> items = service.list(memberId);
        return ok(Map.of("hidden", items));
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @PostMapping({"/note/v1/hidden-rooms", "/note/v1/hidden-conversations"})
    public ResponseEntity<Map<String, Object>> hide(@RequestBody Map<String, Object> body) {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        String convKey = body.get("convKey") != null ? body.get("convKey").toString() : null;
        if (convKey == null || convKey.isBlank()) return badRequest("convKey가 필요합니다.");
        return ok(Map.of("hidden", service.hide(memberId, convKey)));
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @DeleteMapping({"/note/v1/hidden-rooms", "/note/v1/hidden-conversations"})
    public ResponseEntity<Map<String, Object>> unhide(@RequestParam("convKey") String convKey) {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        service.unhide(memberId, convKey);
        return ok(Map.of("message", "해제 완료"));
    }

    // ── 헬퍼 ──
    private ResponseEntity<Map<String, Object>> ok(Map<String, Object> data) {
        Map<String, Object> result = new HashMap<>(data);
        result.put("success", true);
        return ResponseEntity.ok(result);
    }

    private ResponseEntity<Map<String, Object>> unauthorized() {
        return ResponseEntity.status(401).body(Map.of("success", false, "message", "로그인이 필요합니다."));
    }

    private ResponseEntity<Map<String, Object>> badRequest(String message) {
        return ResponseEntity.badRequest().body(Map.of("success", false, "message", message));
    }
}

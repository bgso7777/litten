package com.litten.note.aichat;

import com.litten.common.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 'AI 셀' API. 로그인 회원 전용. 주제를 정하고 그 안에서 AI와 대화하며, 재방문 시 과거 대화를 이어간다.
 *  GET    /note/v1/ai-chat                  내 AI 셀 목록
 *  POST   /note/v1/ai-chat                  AI 셀 생성 {topic, clientId?}
 *  GET    /note/v1/ai-chat/{id}/messages    방의 전체 메시지
 *  POST   /note/v1/ai-chat/{id}/message     사용자 메시지 전송 → AI 응답 {text}
 *  PATCH  /note/v1/ai-chat/{id}             표시 이름 변경 {title}
 *  DELETE /note/v1/ai-chat/{id}             방 삭제
 */
@Log4j2
@RestController
@RequestMapping("/note/v1/ai-chat")
@RequiredArgsConstructor
public class AiChatController {

    private final AiChatService service;

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @GetMapping
    public ResponseEntity<Map<String, Object>> list() {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        return ok(Map.of("chats", service.list(memberId)));
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @PostMapping
    public ResponseEntity<Map<String, Object>> create(@RequestBody Map<String, Object> body) {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        String topic = str(body.get("topic"));
        String clientId = str(body.get("clientId"));
        if (topic == null || topic.isBlank()) return badRequest("주제(topic)는 필수입니다.");
        return ok(Map.of("chat", service.create(memberId, topic, clientId)));
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @GetMapping("/{id}/messages")
    public ResponseEntity<Map<String, Object>> messages(@PathVariable Long id) {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        List<Map<String, Object>> msgs = service.messages(memberId, id);
        if (msgs == null) return badRequest("방을 찾을 수 없습니다.");
        return ok(Map.of("messages", msgs));
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @PostMapping("/{id}/message")
    public ResponseEntity<Map<String, Object>> send(@PathVariable Long id,
                                                    @RequestBody Map<String, Object> body) {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        String text = str(body.get("text"));
        if (text == null || text.isBlank()) return badRequest("메시지(text)는 필수입니다.");
        Map<String, Object> result = service.sendMessage(memberId, id, text);
        if (result == null) return badRequest("방을 찾을 수 없거나 빈 메시지입니다.");
        return ok(result);
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @PatchMapping("/{id}")
    public ResponseEntity<Map<String, Object>> rename(@PathVariable Long id,
                                                      @RequestBody Map<String, Object> body) {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        String title = str(body.get("title"));
        if (!service.rename(memberId, id, title)) return badRequest("이름 변경 실패(방 없음/빈 이름).");
        return ok(Map.of("message", "변경 완료"));
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, Object>> delete(@PathVariable Long id) {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        if (!service.delete(memberId, id)) return badRequest("방을 찾을 수 없습니다.");
        return ok(Map.of("message", "삭제 완료"));
    }

    // ── 헬퍼 ──
    private String str(Object o) { return o == null ? null : o.toString(); }

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

package com.litten.note.studyroom.message;

import com.fasterxml.jackson.databind.JsonNode;
import com.litten.common.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 스터디룸 메시지 API. 로그인 회원 전용(anyRequest authenticated).
 *  POST /note/v1/room-messages            메시지 전송 (JSON: targetType, recipientKey?, groupId?, content)
 *  GET  /note/v1/room-messages/received   받은 메시지 목록
 *  GET  /note/v1/room-messages/sent       보낸 메시지 목록
 * (구경로 /note/v1/messages 병행 노출 — 구버전 앱 호환)
 */
@Log4j2
@RestController
@RequiredArgsConstructor
public class RoomMessageController {

    private final RoomMessageService messageService;

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @PostMapping({"/note/v1/room-messages", "/note/v1/messages"})
    public ResponseEntity<Map<String, Object>> send(@RequestBody JsonNode body) {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        String targetType = body.has("targetType") ? body.get("targetType").asText() : "user";
        String recipientKey = (body.has("recipientKey") && !body.get("recipientKey").isNull())
                ? body.get("recipientKey").asText() : null;
        Long groupId = (body.has("groupId") && !body.get("groupId").isNull())
                ? body.get("groupId").asLong() : null;
        String content = (body.has("content") && !body.get("content").isNull())
                ? body.get("content").asText() : null;
        return ResponseEntity.ok(messageService.send(memberId, targetType, recipientKey, groupId, content));
    }

    /** 메시지 삭제 — 보낸 사람만. 삭제하면 수신자 화면에서도 사라진다. */
    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @DeleteMapping({"/note/v1/room-messages/{messageId}", "/note/v1/messages/{messageId}"})
    public ResponseEntity<Map<String, Object>> delete(@PathVariable Long messageId) {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        boolean done = messageService.delete(memberId, messageId);
        if (!done) {
            return ResponseEntity.badRequest()
                    .body(Map.of("success", false, "message", "메시지를 찾을 수 없거나 보낸 사람만 삭제할 수 있습니다."));
        }
        return ok(Map.of("message", "삭제되었습니다."));
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @GetMapping({"/note/v1/room-messages/received", "/note/v1/messages/received"})
    public ResponseEntity<Map<String, Object>> received() {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        List<Map<String, Object>> list = messageService.received(memberId);
        return ok(Map.of("messages", list));
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @GetMapping({"/note/v1/room-messages/sent", "/note/v1/messages/sent"})
    public ResponseEntity<Map<String, Object>> sent() {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        List<Map<String, Object>> list = messageService.sent(memberId);
        return ok(Map.of("messages", list));
    }

    private ResponseEntity<Map<String, Object>> ok(Map<String, Object> data) {
        Map<String, Object> result = new HashMap<>(data);
        result.put("success", true);
        return ResponseEntity.ok(result);
    }

    private ResponseEntity<Map<String, Object>> unauthorized() {
        return ResponseEntity.status(401).body(Map.of("success", false, "message", "로그인이 필요합니다."));
    }
}

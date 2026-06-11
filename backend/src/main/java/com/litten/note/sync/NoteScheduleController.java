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
 * 캘린더 일정 동기화 API. 로그인 회원 전용.
 *
 * ┌──────────────────────────────────────────────────────────────┐
 * │ GET    /note/v1/schedules             회원 일정 목록 (pull)   │
 * │ POST   /note/v1/schedules             일정 업서트 (littenId)  │
 * │ DELETE /note/v1/schedules/{littenId}  일정 삭제               │
 * └──────────────────────────────────────────────────────────────┘
 * 게스트(guest:)는 권한이 없어 차단됨 (SecurityConfiguration).
 */
@Log4j2
@RestController
@RequiredArgsConstructor
public class NoteScheduleController {

    private final NoteScheduleService scheduleService;

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @GetMapping("/note/v1/schedules")
    public ResponseEntity<Map<String, Object>> getSchedules() {
        log.debug("[NoteScheduleController] GET /note/v1/schedules 진입");
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();

        List<Map<String, Object>> schedules = scheduleService.getSchedules(memberId);
        log.info("[NoteScheduleController] 일정 목록 조회 - memberId: {}, count: {}", memberId, schedules.size());
        return ok(Map.of("schedules", schedules));
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @PostMapping("/note/v1/schedules")
    public ResponseEntity<Map<String, Object>> upsertSchedule(@RequestBody Map<String, Object> body) {
        log.debug("[NoteScheduleController] POST /note/v1/schedules 진입 - littenId: {}", body.get("littenId"));
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();

        try {
            Map<String, Object> saved = scheduleService.upsert(memberId, body);
            return ok(Map.of("schedule", saved));
        } catch (IllegalArgumentException e) {
            return badRequest(e.getMessage());
        }
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @DeleteMapping("/note/v1/schedules/{littenId}")
    public ResponseEntity<Map<String, Object>> deleteSchedule(@PathVariable String littenId) {
        log.debug("[NoteScheduleController] DELETE /note/v1/schedules/{} 진입", littenId);
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();

        boolean deleted = scheduleService.delete(memberId, littenId);
        if (!deleted) return badRequest("일정을 찾을 수 없습니다.");
        return ok(Map.of("message", "삭제 완료"));
    }

    // ── 헬퍼 ──────────────────────────────────────────────────────────────────

    private ResponseEntity<Map<String, Object>> ok(Map<String, Object> data) {
        Map<String, Object> result = new HashMap<>(data);
        result.put("success", true);
        return ResponseEntity.ok(result);
    }

    private ResponseEntity<Map<String, Object>> unauthorized() {
        log.warn("[NoteScheduleController] 인증되지 않은 요청");
        return ResponseEntity.status(401).body(Map.of("success", false, "message", "로그인이 필요합니다."));
    }

    private ResponseEntity<Map<String, Object>> badRequest(String message) {
        return ResponseEntity.badRequest().body(Map.of("success", false, "message", message));
    }
}

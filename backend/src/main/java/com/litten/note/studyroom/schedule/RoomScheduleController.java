package com.litten.note.studyroom.schedule;

import com.litten.common.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 셀(스터디룸) 일정 API. 로그인 회원 전용.
 *  GET    /note/v1/room-schedules                내가 속한 모든 셀(그룹/나만의/1:1)의 일정
 *  POST   /note/v1/room-schedules                일정 생성
 *      {targetType, title, date, endDate, startTime, endTime, notes} + 종류별 키
 *      targetType=group → roomId / self → selfRoomId / user → peerKey(이메일·닉네임)
 *      targetType 생략 시 group 으로 간주(구버전 호환)
 *  PATCH  /note/v1/room-schedules/{scheduleId}   일정 수정 (작성자 또는 방장)
 *  DELETE /note/v1/room-schedules/{scheduleId}   일정 삭제 (작성자 또는 방장)
 *
 * 개인 일정(/note/v1/schedules)과는 별개 테이블이다. 프론트 캘린더가 두 소스를 합쳐 표시한다.
 */
@Log4j2
@RestController
@RequiredArgsConstructor
public class RoomScheduleController {

    private final RoomScheduleService scheduleService;

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @GetMapping("/note/v1/room-schedules")
    public ResponseEntity<Map<String, Object>> list() {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        List<Map<String, Object>> schedules = scheduleService.listMine(memberId);
        return ok(Map.of("schedules", schedules));
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @PostMapping("/note/v1/room-schedules")
    public ResponseEntity<Map<String, Object>> create(@RequestBody Map<String, Object> body) {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        try {
            // targetType 생략 시 group — 구버전 앱(roomId만 보냄) 호환
            Map<String, Object> s = scheduleService.create(memberId,
                    asString(body.get("targetType")),
                    asLong(body.get("roomId")),
                    asLong(body.get("selfRoomId")),
                    asString(body.get("peerKey")),
                    asString(body.get("title")),
                    asDate(body.get("date")), asDate(body.get("endDate")),
                    asTime(body.get("startTime")), asTime(body.get("endTime")),
                    asString(body.get("notes")),
                    asString(body.get("notificationRules")),
                    asTime(body.get("notificationStartTime")),
                    asTime(body.get("notificationEndTime")),
                    asInt(body.get("colorIndex")));
            return ok(Map.of("schedule", s));
        } catch (IllegalArgumentException e) {
            return badRequest(e.getMessage());
        }
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @PatchMapping("/note/v1/room-schedules/{scheduleId}")
    public ResponseEntity<Map<String, Object>> update(@PathVariable Long scheduleId,
                                                     @RequestBody Map<String, Object> body) {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        try {
            Map<String, Object> s = scheduleService.update(memberId, scheduleId,
                    asString(body.get("title")),
                    asDate(body.get("date")), asDate(body.get("endDate")),
                    asTime(body.get("startTime")), asTime(body.get("endTime")),
                    asString(body.get("notes")),
                    asString(body.get("notificationRules")),
                    asTime(body.get("notificationStartTime")),
                    asTime(body.get("notificationEndTime")),
                    asInt(body.get("colorIndex")));
            if (s == null) return badRequest("일정을 찾을 수 없거나 권한이 없습니다.");
            return ok(Map.of("schedule", s));
        } catch (IllegalArgumentException e) {
            return badRequest(e.getMessage());
        }
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @DeleteMapping("/note/v1/room-schedules/{scheduleId}")
    public ResponseEntity<Map<String, Object>> delete(@PathVariable Long scheduleId) {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        boolean done = scheduleService.delete(memberId, scheduleId);
        if (!done) return badRequest("일정을 찾을 수 없거나 권한이 없습니다.");
        return ok(Map.of("message", "삭제되었습니다."));
    }

    private String asString(Object v) {
        return v != null ? v.toString() : null;
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

    private Long asLong(Object v) {
        if (v == null) return null;
        if (v instanceof Number n) return n.longValue();
        try {
            return Long.parseLong(v.toString());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    /** "yyyy-MM-dd" — 프론트 LittenSchedule.toJson 과 같은 형식. */
    private LocalDate asDate(Object v) {
        if (v == null || v.toString().isBlank()) return null;
        try {
            return LocalDate.parse(v.toString());
        } catch (Exception e) {
            throw new IllegalArgumentException("날짜 형식이 올바르지 않습니다: " + v);
        }
    }

    /** "HH:mm" 또는 "HH:mm:ss". */
    private LocalTime asTime(Object v) {
        if (v == null || v.toString().isBlank()) return null;
        try {
            return LocalTime.parse(v.toString());
        } catch (Exception e) {
            throw new IllegalArgumentException("시간 형식이 올바르지 않습니다: " + v);
        }
    }

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

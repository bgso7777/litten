package com.litten.note.sync;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 캘린더 일정 동기화 서비스.
 *
 * 프론트 페이로드(LittenSchedule.toJson + 메타)를 note_schedule 컬럼에 펼쳐 저장하고,
 * pull 시 동일 구조로 재조립해 반환한다. 충돌 해결은 client_updated_at(=리튼 updatedAt)
 * 기준 LWW. 삭제는 tombstone 으로 다른 기기에 전파.
 *
 * 페이로드 형식:
 *   { littenId, title, updatedAt, notificationCount,
 *     schedule: { version, date, endDate, startTime, endTime, notes,
 *                 notificationRules, notificationStartTime, notificationEndTime } }
 */
@Log4j2
@Service
@RequiredArgsConstructor
public class NoteScheduleService {

    private final NoteScheduleRepository scheduleRepository;
    private final ObjectMapper objectMapper = new ObjectMapper();

    /**
     * 회원의 일정 목록.
     * 살아있는 일정은 페이로드 구조로, 삭제된 일정은 tombstone
     * ({littenId, _deleted:true, deletedAt, updatedAt})으로 내려 삭제를 전파한다.
     */
    public List<Map<String, Object>> getSchedules(String memberId) {
        List<NoteSchedule> rows = scheduleRepository.findByMemberId(memberId);
        List<Map<String, Object>> result = new ArrayList<>();
        for (NoteSchedule e : rows) {
            if (Boolean.TRUE.equals(e.getIsDeleted())) {
                Map<String, Object> tombstone = new HashMap<>();
                tombstone.put("littenId", e.getLittenId());
                tombstone.put("_deleted", true);
                tombstone.put("deletedAt", e.getDeletedAt() != null ? e.getDeletedAt().toString() : null);
                tombstone.put("updatedAt", e.getClientUpdatedAt() != null ? e.getClientUpdatedAt().toString() : null);
                result.add(tombstone);
            } else {
                result.add(toPayload(e));
            }
        }
        log.info("[NoteScheduleService] getSchedules - memberId: {}, count: {}", memberId, result.size());
        return result;
    }

    /**
     * 일정 업서트. littenId 기준.
     * @return 저장된 일정 페이로드 (서버가 더 최신이면 서버 값)
     */
    @Transactional
    @SuppressWarnings("unchecked")
    public Map<String, Object> upsert(String memberId, Map<String, Object> body) {
        String littenId = (String) body.get("littenId");
        if (littenId == null || littenId.isBlank()) {
            throw new IllegalArgumentException("littenId는 필수입니다.");
        }
        Object scheduleObj = body.get("schedule");
        if (!(scheduleObj instanceof Map)) {
            throw new IllegalArgumentException("schedule은 필수입니다.");
        }
        Map<String, Object> schedule = (Map<String, Object>) scheduleObj;

        LocalDateTime incomingUpdatedAt = parseDateTime(body.get("updatedAt"));

        NoteSchedule entity = scheduleRepository.findByMemberIdAndLittenId(memberId, littenId)
                .orElseGet(() -> {
                    NoteSchedule e = new NoteSchedule();
                    e.setMemberId(memberId);
                    e.setLittenId(littenId);
                    return e;
                });

        // 충돌 해결: 서버가 더 최신이면 갱신 생략하고 서버 값 반환
        if (entity.getClientUpdatedAt() != null && incomingUpdatedAt != null
                && incomingUpdatedAt.isBefore(entity.getClientUpdatedAt())) {
            log.info("[NoteScheduleService] upsert - 서버 값이 더 최신, 갱신 생략 - littenId: {}", littenId);
            return toPayload(entity);
        }

        entity.setTitle(body.get("title") != null ? body.get("title").toString() : null);
        entity.setScheduleDate(parseDate(schedule.get("date")));
        entity.setEndDate(schedule.get("endDate") != null ? parseDate(schedule.get("endDate")) : null);
        entity.setStartTime(parseTime(schedule.get("startTime")));
        entity.setEndTime(parseTime(schedule.get("endTime")));
        entity.setNotes(schedule.get("notes") != null ? schedule.get("notes").toString() : null);
        entity.setNotificationRules(writeJson(schedule.get("notificationRules")));
        entity.setNotificationStartTime(schedule.get("notificationStartTime") != null
                ? parseTime(schedule.get("notificationStartTime")) : null);
        entity.setNotificationEndTime(schedule.get("notificationEndTime") != null
                ? parseTime(schedule.get("notificationEndTime")) : null);
        entity.setSchemaVersion(toInt(schedule.get("version"), 2));
        entity.setNotificationCount(toInt(body.get("notificationCount"), 0));
        entity.setClientUpdatedAt(incomingUpdatedAt != null ? incomingUpdatedAt : LocalDateTime.now());
        entity.setIsDeleted(false);
        entity.setDeletedAt(null);

        scheduleRepository.save(entity);
        log.info("[NoteScheduleService] upsert 완료 - memberId: {}, littenId: {}", memberId, littenId);
        return toPayload(entity);
    }

    /** 일정 삭제 (soft delete) */
    @Transactional
    public boolean delete(String memberId, String littenId) {
        return scheduleRepository.findByMemberIdAndLittenId(memberId, littenId).map(e -> {
            e.setIsDeleted(true);
            e.setDeletedAt(LocalDateTime.now());
            scheduleRepository.save(e);
            log.info("[NoteScheduleService] delete 완료 - memberId: {}, littenId: {}", memberId, littenId);
            return true;
        }).orElse(false);
    }

    // ── 내부 ────────────────────────────────────────────────────────────────

    /** 엔티티 → 프론트 페이로드(LittenSchedule.toJson 구조 + 메타) */
    private Map<String, Object> toPayload(NoteSchedule e) {
        Map<String, Object> schedule = new HashMap<>();
        schedule.put("version", e.getSchemaVersion());
        schedule.put("date", e.getScheduleDate() != null ? e.getScheduleDate().toString() : null);
        schedule.put("endDate", e.getEndDate() != null ? e.getEndDate().toString() : null);
        schedule.put("startTime", fmtTime(e.getStartTime()));
        schedule.put("endTime", fmtTime(e.getEndTime()));
        schedule.put("notes", e.getNotes());
        schedule.put("notificationRules", parseJsonList(e.getNotificationRules()));
        schedule.put("notificationStartTime", fmtTime(e.getNotificationStartTime()));
        schedule.put("notificationEndTime", fmtTime(e.getNotificationEndTime()));

        Map<String, Object> out = new HashMap<>();
        out.put("littenId", e.getLittenId());
        out.put("title", e.getTitle());
        out.put("updatedAt", e.getClientUpdatedAt() != null ? e.getClientUpdatedAt().toString() : null);
        out.put("notificationCount", e.getNotificationCount());
        out.put("schedule", schedule);
        return out;
    }

    /** "HH:mm" 또는 "HH:mm:ss" → LocalTime (비padding "H:m"도 허용) */
    private LocalTime parseTime(Object v) {
        if (v == null) return null;
        String[] parts = v.toString().split(":");
        int h = Integer.parseInt(parts[0].trim());
        int m = parts.length > 1 ? Integer.parseInt(parts[1].trim()) : 0;
        return LocalTime.of(h, m);
    }

    private LocalDate parseDate(Object v) {
        if (v == null) return null;
        // "yyyy-MM-dd" (ISO) 우선, 혹시 시간 포함 ISO면 앞 10자만
        String s = v.toString();
        if (s.length() >= 10) s = s.substring(0, 10);
        return LocalDate.parse(s);
    }

    private String fmtTime(LocalTime t) {
        if (t == null) return null;
        return String.format("%02d:%02d", t.getHour(), t.getMinute());
    }

    private int toInt(Object v, int def) {
        if (v == null) return def;
        if (v instanceof Number) return ((Number) v).intValue();
        try {
            return Integer.parseInt(v.toString());
        } catch (Exception ex) {
            return def;
        }
    }

    private LocalDateTime parseDateTime(Object v) {
        if (v == null) return null;
        try {
            // ISO8601 (예: 2026-06-11T10:30:00.000) — 오프셋/Z 제거 후 LocalDateTime 파싱
            String s = v.toString().replaceAll("\\+\\d{2}:\\d{2}$", "").replace("Z", "");
            return LocalDateTime.parse(s);
        } catch (Exception ex) {
            log.warn("[NoteScheduleService] 날짜 파싱 실패 - value: {}", v);
            return null;
        }
    }

    private String writeJson(Object v) {
        if (v == null) return null;
        try {
            return objectMapper.writeValueAsString(v);
        } catch (Exception ex) {
            log.error("[NoteScheduleService] JSON 직렬화 실패", ex);
            return null;
        }
    }

    private List<Object> parseJsonList(String json) {
        if (json == null || json.isBlank()) return new ArrayList<>();
        try {
            return objectMapper.readValue(json, new TypeReference<List<Object>>() {});
        } catch (Exception ex) {
            log.warn("[NoteScheduleService] notification_rules 파싱 실패: {}", ex.getMessage());
            return new ArrayList<>();
        }
    }
}

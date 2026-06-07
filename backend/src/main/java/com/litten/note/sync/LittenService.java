package com.litten.note.sync;

import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 리튼 메타 동기화 서비스.
 * 프론트 Litten.toJson 구조를 그대로 extra_json blob 에 보관/반환한다.
 * 충돌 해결: 요청 updatedAt 이 서버 client_updated_at 보다 최신일 때만 갱신 (LWW).
 */
@Log4j2
@Service
@RequiredArgsConstructor
public class LittenService {

    private final LittenRepository littenRepository;
    private final ObjectMapper objectMapper = new ObjectMapper();

    /**
     * 회원의 리튼 목록.
     * 살아있는 리튼은 프론트 Litten.toJson 그대로, 삭제된 리튼은 경량 tombstone
     * ({id, _deleted:true, deletedAt, updatedAt})으로 내려 다른 기기에 삭제를 전파한다.
     */
    public List<Map<String, Object>> getLittens(String memberId) {
        List<Litten> rows = littenRepository.findByMemberId(memberId);
        List<Map<String, Object>> result = new ArrayList<>();
        for (Litten e : rows) {
            if (Boolean.TRUE.equals(e.getIsDeleted())) {
                Map<String, Object> tombstone = new HashMap<>();
                tombstone.put("id", e.getLittenId());
                tombstone.put("_deleted", true);
                tombstone.put("deletedAt", e.getDeletedAt());
                tombstone.put("updatedAt", e.getClientUpdatedAt());
                result.add(tombstone);
            } else {
                Map<String, Object> json = parseExtraJson(e);
                if (json != null) result.add(json);
            }
        }
        log.info("[LittenService] getLittens - memberId: {}, count: {}", memberId, result.size());
        return result;
    }

    /**
     * 리튼 업서트. littenId(=json.id) 기준.
     * @return 저장된 리튼 JSON
     */
    @Transactional
    public Map<String, Object> upsert(String memberId, Map<String, Object> json) {
        String littenId = (String) json.get("id");
        if (littenId == null || littenId.isBlank()) {
            throw new IllegalArgumentException("id는 필수입니다.");
        }

        LocalDateTime incomingUpdatedAt = parseDateTime(json.get("updatedAt"));

        Litten entity = littenRepository.findByMemberIdAndLittenId(memberId, littenId)
                .orElseGet(() -> {
                    Litten e = new Litten();
                    e.setMemberId(memberId);
                    e.setLittenId(littenId);
                    return e;
                });

        // 충돌 해결: 서버가 더 최신이면 갱신 생략하고 서버 값 반환
        if (entity.getClientUpdatedAt() != null && incomingUpdatedAt != null
                && incomingUpdatedAt.isBefore(entity.getClientUpdatedAt())) {
            log.info("[LittenService] upsert - 서버 값이 더 최신, 갱신 생략 - littenId: {}", littenId);
            return parseExtraJson(entity);
        }

        entity.setTitle(json.get("title") != null ? json.get("title").toString() : "");
        entity.setDescription(json.get("description") != null ? json.get("description").toString() : null);
        entity.setClientCreatedAt(parseDateTime(json.get("createdAt")));
        entity.setClientUpdatedAt(incomingUpdatedAt != null ? incomingUpdatedAt : LocalDateTime.now());
        entity.setIsDeleted(false);
        entity.setDeletedAt(null);
        entity.setExtraJson(writeJson(json));

        littenRepository.save(entity);
        log.info("[LittenService] upsert 완료 - memberId: {}, littenId: {}", memberId, littenId);
        return json;
    }

    /** 리튼 삭제 (soft delete) */
    @Transactional
    public boolean delete(String memberId, String littenId) {
        return littenRepository.findByMemberIdAndLittenId(memberId, littenId).map(e -> {
            e.setIsDeleted(true);
            e.setDeletedAt(LocalDateTime.now());
            littenRepository.save(e);
            log.info("[LittenService] delete 완료 - memberId: {}, littenId: {}", memberId, littenId);
            return true;
        }).orElse(false);
    }

    // ── 내부 ────────────────────────────────────────────────────────────────

    @SuppressWarnings("unchecked")
    private Map<String, Object> parseExtraJson(Litten e) {
        if (e.getExtraJson() == null) return null;
        try {
            return objectMapper.readValue(e.getExtraJson(), Map.class);
        } catch (Exception ex) {
            log.warn("[LittenService] extra_json 파싱 실패 - littenId: {}, error: {}", e.getLittenId(), ex.getMessage());
            return null;
        }
    }

    private String writeJson(Map<String, Object> json) {
        try {
            return objectMapper.writeValueAsString(json);
        } catch (Exception ex) {
            log.error("[LittenService] JSON 직렬화 실패", ex);
            return null;
        }
    }

    private LocalDateTime parseDateTime(Object v) {
        if (v == null) return null;
        try {
            // ISO8601 (예: 2026-06-03T10:30:00.000) — 오프셋/Z 제거 후 LocalDateTime 파싱
            String s = v.toString().replaceAll("\\+\\d{2}:\\d{2}$", "").replace("Z", "");
            return LocalDateTime.parse(s);
        } catch (Exception ex) {
            log.warn("[LittenService] 날짜 파싱 실패 - value: {}", v);
            return null;
        }
    }
}

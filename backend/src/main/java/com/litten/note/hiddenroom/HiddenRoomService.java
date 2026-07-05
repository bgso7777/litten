package com.litten.note.hiddenroom;

import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/** 스터디룸 대화 숨김('방 나가기') 상태 저장/조회 — 회원별 다기기 동기화용. */
@Log4j2
@Service
@RequiredArgsConstructor
public class HiddenRoomService {

    private final HiddenRoomRepository repository;

    /** 내 숨김 대화 목록. 반환: [{convKey, hiddenAt}]. */
    public List<Map<String, Object>> list(String memberId) {
        List<Map<String, Object>> result = new ArrayList<>();
        for (HiddenRoom h : repository.findByMemberId(memberId)) {
            Map<String, Object> m = new java.util.HashMap<>();
            m.put("convKey", h.getConvKey());
            m.put("hiddenAt", h.getHiddenAt());
            result.add(m);
        }
        return result;
    }

    /** 대화를 숨김(방 나가기). hidden_at은 서버 시각으로 갱신(upsert). */
    @Transactional
    public Map<String, Object> hide(String memberId, String convKey) {
        LocalDateTime now = LocalDateTime.now();
        Optional<HiddenRoom> opt = repository.findByMemberIdAndConvKey(memberId, convKey);
        HiddenRoom h = opt.orElseGet(HiddenRoom::new);
        h.setMemberId(memberId);
        h.setConvKey(convKey);
        h.setHiddenAt(now);
        if (h.getInsertDateTime() == null) h.setInsertDateTime(now);
        h.setUpdateDateTime(now);
        repository.save(h);
        log.info("[HiddenRoomService] 대화 숨김 - member: {}, convKey: {}", memberId, convKey);
        Map<String, Object> m = new java.util.HashMap<>();
        m.put("convKey", convKey);
        m.put("hiddenAt", now);
        return m;
    }

    /** 숨김 해제(선택적). */
    @Transactional
    public boolean unhide(String memberId, String convKey) {
        Optional<HiddenRoom> opt = repository.findByMemberIdAndConvKey(memberId, convKey);
        if (opt.isEmpty()) return false;
        repository.delete(opt.get());
        return true;
    }
}

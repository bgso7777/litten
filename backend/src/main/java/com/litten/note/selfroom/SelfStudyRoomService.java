package com.litten.note.selfroom;

import com.litten.note.sync.LocalStorageService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/** '나만의 스터디룸'(1인 룸) — 방/항목(텍스트·파일) 저장·조회, 기기 간 동기화용. */
@Slf4j
@Service
@RequiredArgsConstructor
public class SelfStudyRoomService {

    private final SelfStudyRoomRepository roomRepository;
    private final SelfStudyRoomItemRepository itemRepository;
    private final LocalStorageService localStorageService;

    /** 내 나만의 스터디룸 방+항목 전체 조회. 반환: [{id, clientId, name, items:[...]}]. */
    public List<Map<String, Object>> list(String memberId) {
        List<Map<String, Object>> result = new ArrayList<>();
        for (SelfStudyRoom c : roomRepository.findByMemberIdAndIsDeletedFalseOrderByIdAsc(memberId)) {
            Map<String, Object> m = new HashMap<>();
            m.put("id", c.getId());
            m.put("clientId", c.getClientId());
            m.put("name", c.getName());
            List<Map<String, Object>> items = new ArrayList<>();
            for (SelfStudyRoomItem it : itemRepository.findByRoomIdAndIsDeletedFalseOrderByIdAsc(c.getId())) {
                items.add(toItemMap(it));
            }
            m.put("items", items);
            result.add(m);
        }
        return result;
    }

    /** 다른 기기에서 삭제된 방의 clientId 목록(삭제 전파용). */
    public List<String> deletedClientIds(String memberId) {
        List<String> ids = new ArrayList<>();
        for (SelfStudyRoom c : roomRepository.findByMemberIdAndIsDeletedTrue(memberId)) {
            if (c.getClientId() != null && !c.getClientId().isBlank()) {
                ids.add(c.getClientId());
            }
        }
        return ids;
    }

    /** 방 생성(clientId 있으면 upsert). 반환: {id, clientId, name}. */
    @Transactional
    public Map<String, Object> create(String memberId, String name, String clientId) {
        SelfStudyRoom c = null;
        if (clientId != null && !clientId.isBlank()) {
            c = roomRepository.findByMemberIdAndClientId(memberId, clientId).orElse(null);
        }
        if (c == null) {
            c = new SelfStudyRoom();
            c.setMemberId(memberId);
            c.setClientId(clientId);
            c.setInsertDateTime(LocalDateTime.now());
        }
        c.setName(name != null ? name : "나만의 스터디룸");
        c.setIsDeleted(false);
        c.setUpdateDateTime(LocalDateTime.now());
        roomRepository.save(c);
        Map<String, Object> m = new HashMap<>();
        m.put("id", c.getId());
        m.put("clientId", c.getClientId());
        m.put("name", c.getName());
        return m;
    }

    @Transactional
    public boolean delete(String memberId, Long chatId) {
        Optional<SelfStudyRoom> opt = roomRepository.findById(chatId);
        if (opt.isEmpty() || !opt.get().getMemberId().equals(memberId)) return false;
        SelfStudyRoom c = opt.get();
        c.setIsDeleted(true);
        c.setDeletedAt(LocalDateTime.now());
        roomRepository.save(c);
        for (SelfStudyRoomItem it : itemRepository.findByRoomIdAndIsDeletedFalseOrderByIdAsc(chatId)) {
            it.setIsDeleted(true);
            itemRepository.save(it);
            if (it.getStoredPath() != null) {
                try { localStorageService.delete(it.getStoredPath()); } catch (Exception ignore) {}
            }
        }
        return true;
    }

    /** 항목 1건 삭제(본인 것만). 저장된 파일도 함께 지운다. */
    @Transactional
    public boolean deleteItem(String memberId, Long itemId) {
        Optional<SelfStudyRoomItem> opt = itemRepository.findById(itemId);
        if (opt.isEmpty() || !opt.get().getMemberId().equals(memberId)
                || Boolean.TRUE.equals(opt.get().getIsDeleted())) {
            return false;
        }
        SelfStudyRoomItem it = opt.get();
        it.setIsDeleted(true);
        it.setUpdateDateTime(LocalDateTime.now());
        itemRepository.save(it);
        if (it.getStoredPath() != null) {
            try {
                localStorageService.delete(it.getStoredPath());
            } catch (Exception e) {
                log.warn("[SelfStudyRoomService] 항목 파일 삭제 실패(DB 삭제는 완료) - itemId: {}, error: {}",
                        itemId, e.getMessage());
            }
        }
        log.info("[SelfStudyRoomService] 항목 삭제 - memberId: {}, itemId: {}", memberId, itemId);
        return true;
    }

    /** 텍스트 항목 추가. */
    @Transactional
    public Map<String, Object> addText(String memberId, Long chatId, String content) {
        Optional<SelfStudyRoom> opt = roomRepository.findById(chatId);
        if (opt.isEmpty() || !opt.get().getMemberId().equals(memberId)) return null;
        SelfStudyRoomItem it = new SelfStudyRoomItem();
        it.setRoomId(chatId);
        it.setMemberId(memberId);
        it.setItemType("text");
        it.setContent(content);
        it.setIsDeleted(false);
        it.setInsertDateTime(LocalDateTime.now());
        it.setUpdateDateTime(LocalDateTime.now());
        itemRepository.save(it);
        return toItemMap(it);
    }

    /** 파일 항목 추가. */
    @Transactional
    public Map<String, Object> addFile(String memberId, Long chatId, String fileType,
                                       String fileName, String contentType, MultipartFile file) {
        Optional<SelfStudyRoom> opt = roomRepository.findById(chatId);
        if (opt.isEmpty() || !opt.get().getMemberId().equals(memberId)) return null;
        String storedPath;
        try {
            String uuid = UUID.randomUUID().toString();
            String target = "_selfchat" + File.separator + uuid + File.separator + fileName;
            storedPath = localStorageService.save(file, target);
        } catch (Exception e) {
            log.error("[SelfStudyRoomService] 파일 저장 실패", e);
            return null;
        }
        SelfStudyRoomItem it = new SelfStudyRoomItem();
        it.setRoomId(chatId);
        it.setMemberId(memberId);
        it.setItemType("file");
        it.setFileType(fileType);
        it.setFileName(fileName);
        it.setContentType(contentType != null ? contentType : file.getContentType());
        it.setFileSize(file.getSize());
        it.setStoredPath(storedPath);
        it.setIsDeleted(false);
        it.setInsertDateTime(LocalDateTime.now());
        it.setUpdateDateTime(LocalDateTime.now());
        itemRepository.save(it);
        return toItemMap(it);
    }

    /** 파일 항목 다운로드용 리소스. */
    public SelfStudyRoomItem getFileItem(String memberId, Long itemId) {
        Optional<SelfStudyRoomItem> opt = itemRepository.findById(itemId);
        if (opt.isEmpty()) return null;
        SelfStudyRoomItem it = opt.get();
        if (!it.getMemberId().equals(memberId) || !"file".equals(it.getItemType())) return null;
        return it;
    }

    public Resource loadResource(String storedPath) {
        try {
            return localStorageService.loadAsResource(storedPath);
        } catch (Exception e) {
            log.error("[SelfStudyRoomService] 파일 로드 실패: {}", storedPath, e);
            return null;
        }
    }

    private Map<String, Object> toItemMap(SelfStudyRoomItem it) {
        Map<String, Object> m = new HashMap<>();
        m.put("itemId", it.getId());
        m.put("itemType", it.getItemType());
        m.put("content", it.getContent());
        m.put("fileName", it.getFileName());
        m.put("fileType", it.getFileType());
        m.put("contentType", it.getContentType());
        m.put("fileSize", it.getFileSize());
        m.put("createdAt", it.getInsertDateTime());
        return m;
    }
}

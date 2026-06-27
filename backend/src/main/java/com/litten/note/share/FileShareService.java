package com.litten.note.share;

import com.litten.note.NoteMember;
import com.litten.note.NoteMemberRepository;
import com.litten.note.sync.LocalStorageService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.Resource;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

/** 사용자 간 파일 공유 — 생성(개인/그룹 fan-out), 받은/보낸 목록, 수락/거절/취소, 다운로드. */
@Slf4j
@Service
@RequiredArgsConstructor
public class FileShareService {

    private final FileShareRepository shareRepository;
    private final FileShareDeliveryRepository deliveryRepository;
    private final ShareGroupRepository groupRepository;
    private final ShareGroupMemberRepository groupMemberRepository;
    private final NoteMemberRepository noteMemberRepository;
    private final LocalStorageService localStorageService;

    private NoteMember resolveMember(String key) {
        if (key == null) return null;
        String k = key.trim();
        if (k.isEmpty()) return null;
        NoteMember m = noteMemberRepository.findFirstByEmail(k);
        if (m == null) m = noteMemberRepository.findFirstByName(k);
        return m;
    }

    /** 수신자 조회(이메일/닉네임) — 보내기 전 확인용. 반환: {found, name?}. */
    public Map<String, Object> lookupRecipient(String key) {
        Map<String, Object> r = new HashMap<>();
        NoteMember m = resolveMember(key);
        if (m == null) {
            r.put("found", false);
            return r;
        }
        r.put("found", true);
        r.put("name", m.getName() != null ? m.getName() : m.getEmail());
        return r;
    }

    private String resolveName(String memberId) {
        return noteMemberRepository.findById(memberId)
                .map(m -> m.getName() != null ? m.getName() : m.getEmail())
                .orElse(memberId);
    }

    /**
     * 파일 공유 생성. targetType=user면 recipientKey(이메일/이름)로 1명, group이면 groupId 멤버 전원에게 fan-out.
     * 본문은 공유 저장소(_shares/{uuid}/{fileName})에 저장한다.
     */
    @Transactional
    public Map<String, Object> createShare(String senderId, String targetType, String recipientKey, Long groupId,
                                           String littenTitle, String fileType, String fileName, String contentType,
                                           String message, MultipartFile file) {
        Map<String, Object> result = new HashMap<>();

        // 1) 수신자 목록 결정
        Set<String> recipientIds = new LinkedHashSet<>();
        String groupName = null;
        if ("group".equals(targetType)) {
            Optional<ShareGroup> gOpt = groupRepository.findById(groupId == null ? -1L : groupId);
            if (gOpt.isEmpty() || !gOpt.get().getOwnerMemberId().equals(senderId)
                    || Boolean.TRUE.equals(gOpt.get().getIsDeleted())) {
                result.put("success", false);
                result.put("message", "그룹을 찾을 수 없습니다.");
                return result;
            }
            groupName = gOpt.get().getName();
            for (ShareGroupMember gm : groupMemberRepository.findByGroupIdAndIsDeletedFalseOrderByIdAsc(groupId)) {
                recipientIds.add(gm.getMemberId());
            }
            if (recipientIds.isEmpty()) {
                result.put("success", false);
                result.put("message", "그룹에 멤버가 없습니다.");
                return result;
            }
        } else {
            NoteMember m = resolveMember(recipientKey);
            if (m == null) {
                result.put("success", false);
                result.put("message", "수신자를 찾을 수 없습니다.");
                return result;
            }
            recipientIds.add(m.getId());
        }

        // 2) 본문 저장
        String storedPath;
        try {
            String uuid = UUID.randomUUID().toString();
            String target = "_shares" + File.separator + uuid + File.separator + fileName;
            storedPath = localStorageService.save(file, target);
        } catch (Exception e) {
            log.error("[FileShareService] 공유 파일 저장 실패", e);
            result.put("success", false);
            result.put("message", "파일 저장 실패: " + e.getMessage());
            return result;
        }

        // 3) 공유 레코드
        FileShare share = new FileShare();
        share.setSenderMemberId(senderId);
        share.setSenderName(resolveName(senderId));
        share.setTargetType("group".equals(targetType) ? "group" : "user");
        share.setGroupId("group".equals(targetType) ? groupId : null);
        share.setGroupName(groupName);
        share.setLittenTitle(littenTitle);
        share.setFileType(fileType);
        share.setFileName(fileName);
        share.setContentType(contentType != null ? contentType : file.getContentType());
        share.setFileSize(file.getSize());
        share.setStoredPath(storedPath);
        share.setMessage(message);
        share.setIsDeleted(false);
        share.setInsertDateTime(LocalDateTime.now());
        share.setUpdateDateTime(LocalDateTime.now());
        shareRepository.save(share);

        // 4) 전달(수신자별)
        for (String rid : recipientIds) {
            FileShareDelivery d = new FileShareDelivery();
            d.setShareId(share.getId());
            d.setRecipientMemberId(rid);
            d.setStatus(FileShareDelivery.STATUS_PENDING);
            d.setIsDeleted(false);
            d.setInsertDateTime(LocalDateTime.now());
            d.setUpdateDateTime(LocalDateTime.now());
            deliveryRepository.save(d);
        }

        log.info("[FileShareService] 공유 생성 - sender: {}, target: {}, recipients: {}, shareId: {}",
                senderId, targetType, recipientIds.size(), share.getId());
        result.put("success", true);
        result.put("shareId", share.getId());
        result.put("recipientCount", recipientIds.size());
        return result;
    }

    /** 내가 받은 공유 목록 (전달 기준). */
    public List<Map<String, Object>> received(String memberId) {
        List<Map<String, Object>> list = new ArrayList<>();
        for (FileShareDelivery d : deliveryRepository.findByRecipientMemberIdAndIsDeletedFalseOrderByIdDesc(memberId)) {
            Optional<FileShare> sOpt = shareRepository.findById(d.getShareId());
            if (sOpt.isEmpty() || Boolean.TRUE.equals(sOpt.get().getIsDeleted())) continue;
            FileShare s = sOpt.get();
            Map<String, Object> m = new HashMap<>();
            m.put("deliveryId", d.getId());
            m.put("shareId", s.getId());
            m.put("status", d.getStatus());
            m.put("senderName", s.getSenderName());
            m.put("senderMemberId", s.getSenderMemberId());
            m.put("fileType", s.getFileType());
            m.put("fileName", s.getFileName());
            m.put("fileSize", s.getFileSize());
            m.put("contentType", s.getContentType());
            m.put("message", s.getMessage());
            m.put("littenTitle", s.getLittenTitle());
            m.put("groupName", s.getGroupName());
            m.put("sharedAt", s.getInsertDateTime());
            m.put("respondedAt", d.getRespondedAt());
            list.add(m);
        }
        return list;
    }

    /** 내가 보낸 공유 목록 (공유 기준 + 전달 상태 요약). */
    public List<Map<String, Object>> sent(String memberId) {
        List<Map<String, Object>> list = new ArrayList<>();
        for (FileShare s : shareRepository.findBySenderMemberIdAndIsDeletedFalseOrderByIdDesc(memberId)) {
            List<FileShareDelivery> deliveries = deliveryRepository.findByShareIdAndIsDeletedFalse(s.getId());
            int pending = 0, accepted = 0, rejected = 0;
            List<Map<String, Object>> recips = new ArrayList<>();
            for (FileShareDelivery d : deliveries) {
                if (FileShareDelivery.STATUS_ACCEPTED.equals(d.getStatus())) accepted++;
                else if (FileShareDelivery.STATUS_REJECTED.equals(d.getStatus())) rejected++;
                else pending++;
                Map<String, Object> r = new HashMap<>();
                r.put("memberId", d.getRecipientMemberId());
                r.put("status", d.getStatus());
                recips.add(r);
            }
            Map<String, Object> m = new HashMap<>();
            m.put("shareId", s.getId());
            m.put("targetType", s.getTargetType());
            m.put("groupName", s.getGroupName());
            m.put("fileType", s.getFileType());
            m.put("fileName", s.getFileName());
            m.put("message", s.getMessage());
            m.put("littenTitle", s.getLittenTitle());
            m.put("sharedAt", s.getInsertDateTime());
            m.put("recipients", recips);
            m.put("pendingCount", pending);
            m.put("acceptedCount", accepted);
            m.put("rejectedCount", rejected);
            m.put("totalCount", deliveries.size());
            list.add(m);
        }
        return list;
    }

    @Transactional
    public Map<String, Object> respond(String memberId, Long deliveryId, boolean accept) {
        Map<String, Object> result = new HashMap<>();
        Optional<FileShareDelivery> dOpt = deliveryRepository.findById(deliveryId);
        if (dOpt.isEmpty() || !dOpt.get().getRecipientMemberId().equals(memberId)
                || Boolean.TRUE.equals(dOpt.get().getIsDeleted())) {
            result.put("success", false);
            result.put("message", "공유를 찾을 수 없습니다.");
            return result;
        }
        FileShareDelivery d = dOpt.get();
        d.setStatus(accept ? FileShareDelivery.STATUS_ACCEPTED : FileShareDelivery.STATUS_REJECTED);
        d.setRespondedAt(LocalDateTime.now());
        d.setUpdateDateTime(LocalDateTime.now());
        deliveryRepository.save(d);
        log.info("[FileShareService] 공유 응답 - memberId: {}, deliveryId: {}, accept: {}", memberId, deliveryId, accept);
        result.put("success", true);
        result.put("deliveryId", deliveryId);
        result.put("shareId", d.getShareId());
        result.put("status", d.getStatus());
        return result;
    }

    /** 발신자가 공유 취소(회수) — 공유 + 전달 soft delete + 본문 삭제. */
    @Transactional
    public Map<String, Object> cancel(String memberId, Long shareId) {
        Map<String, Object> result = new HashMap<>();
        Optional<FileShare> sOpt = shareRepository.findById(shareId);
        if (sOpt.isEmpty() || !sOpt.get().getSenderMemberId().equals(memberId)) {
            result.put("success", false);
            result.put("message", "공유를 찾을 수 없습니다.");
            return result;
        }
        FileShare s = sOpt.get();
        s.setIsDeleted(true);
        s.setDeletedAt(LocalDateTime.now());
        s.setUpdateDateTime(LocalDateTime.now());
        shareRepository.save(s);
        for (FileShareDelivery d : deliveryRepository.findByShareIdAndIsDeletedFalse(shareId)) {
            d.setIsDeleted(true);
            d.setUpdateDateTime(LocalDateTime.now());
            deliveryRepository.save(d);
        }
        if (s.getStoredPath() != null) {
            try {
                localStorageService.delete(s.getStoredPath());
            } catch (Exception e) {
                log.warn("[FileShareService] 공유 본문 삭제 실패(DB 취소는 완료) - shareId: {}, error: {}", shareId, e.getMessage());
            }
        }
        log.info("[FileShareService] 공유 취소 - memberId: {}, shareId: {}", memberId, shareId);
        result.put("success", true);
        result.put("shareId", shareId);
        return result;
    }

    /** 수락한 수신자가 본문 다운로드. */
    public ResponseEntity<Resource> download(String memberId, Long shareId) {
        Optional<FileShare> sOpt = shareRepository.findById(shareId);
        if (sOpt.isEmpty() || Boolean.TRUE.equals(sOpt.get().getIsDeleted())) {
            return ResponseEntity.notFound().build();
        }
        // 수락한 전달이 있어야 다운로드 허용
        boolean allowed = deliveryRepository.findByShareIdAndIsDeletedFalse(shareId).stream()
                .anyMatch(d -> d.getRecipientMemberId().equals(memberId)
                        && FileShareDelivery.STATUS_ACCEPTED.equals(d.getStatus()));
        if (!allowed) return ResponseEntity.status(403).build();

        try {
            FileShare s = sOpt.get();
            Resource resource = localStorageService.loadAsResource(s.getStoredPath());
            ContentDisposition cd = ContentDisposition.attachment()
                    .filename(s.getFileName(), StandardCharsets.UTF_8).build();
            return ResponseEntity.ok()
                    .header(HttpHeaders.CONTENT_DISPOSITION, cd.toString())
                    .contentType(s.getContentType() != null
                            ? MediaType.parseMediaType(s.getContentType())
                            : MediaType.APPLICATION_OCTET_STREAM)
                    .contentLength(resource.contentLength())
                    .body(resource);
        } catch (Exception e) {
            log.error("[FileShareService] 공유 다운로드 실패 - shareId: {}", shareId, e);
            return ResponseEntity.internalServerError().build();
        }
    }
}

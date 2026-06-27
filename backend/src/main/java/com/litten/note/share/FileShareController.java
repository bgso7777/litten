package com.litten.note.share;

import com.litten.common.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.core.io.Resource;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 사용자 간 파일 공유 API. 로그인 회원 전용.
 *  POST   /note/v1/shares                          공유 생성 (multipart)
 *  GET    /note/v1/shares/received                 받은 공유 목록
 *  GET    /note/v1/shares/sent                     보낸 공유 목록
 *  POST   /note/v1/shares/deliveries/{id}/accept   수락
 *  POST   /note/v1/shares/deliveries/{id}/reject   거절
 *  DELETE /note/v1/shares/{shareId}                취소(발신자 회수)
 *  GET    /note/v1/shares/{shareId}/download       다운로드(수락자)
 */
@Log4j2
@RestController
@RequiredArgsConstructor
public class FileShareController {

    private final FileShareService shareService;

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @PostMapping("/note/v1/shares")
    public ResponseEntity<Map<String, Object>> createShare(
            @RequestParam("targetType") String targetType,
            @RequestParam(value = "recipientKey", required = false) String recipientKey,
            @RequestParam(value = "groupId", required = false) Long groupId,
            @RequestParam(value = "littenTitle", required = false) String littenTitle,
            @RequestParam("fileType") String fileType,
            @RequestParam("fileName") String fileName,
            @RequestParam(value = "contentType", required = false) String contentType,
            @RequestParam(value = "message", required = false) String message,
            @RequestParam("file") MultipartFile file) {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();

        Map<String, Object> result = shareService.createShare(memberId, targetType, recipientKey, groupId,
                littenTitle, fileType, fileName, contentType, message, file);
        return ResponseEntity.ok(result);
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @GetMapping("/note/v1/shares/lookup")
    public ResponseEntity<Map<String, Object>> lookup(@RequestParam("key") String key) {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        return ResponseEntity.ok(shareService.lookupRecipient(key));
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @GetMapping("/note/v1/shares/received")
    public ResponseEntity<Map<String, Object>> received() {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        List<Map<String, Object>> list = shareService.received(memberId);
        return ok(Map.of("shares", list));
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @GetMapping("/note/v1/shares/sent")
    public ResponseEntity<Map<String, Object>> sent() {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        List<Map<String, Object>> list = shareService.sent(memberId);
        return ok(Map.of("shares", list));
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @PostMapping("/note/v1/shares/deliveries/{deliveryId}/accept")
    public ResponseEntity<Map<String, Object>> accept(@PathVariable Long deliveryId) {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        return ResponseEntity.ok(shareService.respond(memberId, deliveryId, true));
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @PostMapping("/note/v1/shares/deliveries/{deliveryId}/reject")
    public ResponseEntity<Map<String, Object>> reject(@PathVariable Long deliveryId) {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        return ResponseEntity.ok(shareService.respond(memberId, deliveryId, false));
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @DeleteMapping("/note/v1/shares/{shareId}")
    public ResponseEntity<Map<String, Object>> cancel(@PathVariable Long shareId) {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        return ResponseEntity.ok(shareService.cancel(memberId, shareId));
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @GetMapping("/note/v1/shares/{shareId}/download")
    public ResponseEntity<Resource> download(@PathVariable Long shareId) {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return ResponseEntity.status(401).build();
        return shareService.download(memberId, shareId);
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
}

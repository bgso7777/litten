package com.litten.note.selfroom;

import com.litten.common.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.core.io.Resource;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * '나만의 스터디룸'(1인 룸) API. 로그인 회원 전용. 기기 간 동기화용.
 *  GET    /note/v1/my-study-rooms                         내 방+항목 전체
 *  POST   /note/v1/my-study-rooms                         방 생성/업서트 {name, clientId?}
 *  DELETE /note/v1/my-study-rooms/{id}                    방 삭제
 *  POST   /note/v1/my-study-rooms/{id}/messages           텍스트 추가 {content}
 *  POST   /note/v1/my-study-rooms/{id}/files              파일 추가 (multipart: file, fileType, fileName, contentType)
 *  GET    /note/v1/my-study-rooms/items/{itemId}/download 파일 다운로드
 * (구경로 /note/v1/self-chats 병행 노출 — 구버전 앱 호환)
 */
@Log4j2
@RestController
@RequiredArgsConstructor
public class SelfStudyRoomController {

    private final SelfStudyRoomService service;

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @GetMapping({"/note/v1/my-study-rooms", "/note/v1/self-chats"})
    public ResponseEntity<Map<String, Object>> list() {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        return ok(Map.of(
                "selfChats", service.list(memberId),
                "deletedClientIds", service.deletedClientIds(memberId)));
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @PostMapping({"/note/v1/my-study-rooms", "/note/v1/self-chats"})
    public ResponseEntity<Map<String, Object>> create(@RequestBody Map<String, Object> body) {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        String name = body.get("name") != null ? body.get("name").toString() : null;
        String clientId = body.get("clientId") != null ? body.get("clientId").toString() : null;
        return ok(Map.of("selfChat", service.create(memberId, name, clientId)));
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @DeleteMapping({"/note/v1/my-study-rooms/{id}", "/note/v1/self-chats/{id}"})
    public ResponseEntity<Map<String, Object>> delete(@PathVariable Long id) {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        if (!service.delete(memberId, id)) return badRequest("방을 찾을 수 없습니다.");
        return ok(Map.of("message", "삭제 완료"));
    }

    /** 항목(자료) 1건 삭제 — 나만의 룸이라 본인 것만 지운다. */
    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @DeleteMapping({"/note/v1/my-study-rooms/items/{itemId}", "/note/v1/self-chats/items/{itemId}"})
    public ResponseEntity<Map<String, Object>> deleteItem(@PathVariable Long itemId) {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        if (!service.deleteItem(memberId, itemId)) return badRequest("항목을 찾을 수 없습니다.");
        return ok(Map.of("message", "삭제 완료"));
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @PostMapping({"/note/v1/my-study-rooms/{id}/messages", "/note/v1/self-chats/{id}/messages"})
    public ResponseEntity<Map<String, Object>> addText(@PathVariable Long id,
                                                       @RequestBody Map<String, Object> body) {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        String content = body.get("content") != null ? body.get("content").toString() : "";
        Map<String, Object> item = service.addText(memberId, id, content);
        if (item == null) return badRequest("방을 찾을 수 없습니다.");
        return ok(Map.of("item", item));
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @PostMapping({"/note/v1/my-study-rooms/{id}/files", "/note/v1/self-chats/{id}/files"})
    public ResponseEntity<Map<String, Object>> addFile(
            @PathVariable Long id,
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "fileType", required = false) String fileType,
            @RequestParam(value = "fileName", required = false) String fileName,
            @RequestParam(value = "contentType", required = false) String contentType) {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        String name = (fileName != null && !fileName.isBlank()) ? fileName : file.getOriginalFilename();
        Map<String, Object> item = service.addFile(memberId, id, fileType, name, contentType, file);
        if (item == null) return badRequest("파일 저장 실패 또는 방 없음");
        return ok(Map.of("item", item));
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @GetMapping({"/note/v1/my-study-rooms/items/{itemId}/download", "/note/v1/self-chats/items/{itemId}/download"})
    public ResponseEntity<Resource> download(@PathVariable Long itemId) {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return ResponseEntity.status(401).build();
        SelfStudyRoomItem it = service.getFileItem(memberId, itemId);
        if (it == null || it.getStoredPath() == null) return ResponseEntity.notFound().build();
        Resource res = service.loadResource(it.getStoredPath());
        if (res == null) return ResponseEntity.notFound().build();
        String fn = it.getFileName() != null ? it.getFileName() : "file";
        String ct = it.getContentType() != null ? it.getContentType() : MediaType.APPLICATION_OCTET_STREAM_VALUE;
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        ContentDisposition.attachment()
                                .filename(fn, StandardCharsets.UTF_8).build().toString())
                .contentType(MediaType.parseMediaType(ct))
                .body(res);
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

    private ResponseEntity<Map<String, Object>> badRequest(String message) {
        return ResponseEntity.badRequest().body(Map.of("success", false, "message", message));
    }
}

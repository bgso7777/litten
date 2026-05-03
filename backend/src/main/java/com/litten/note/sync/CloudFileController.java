package com.litten.note.sync;

import com.litten.Constants;
import com.litten.common.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.HashMap;
import java.util.Map;

@Slf4j
@RestController
@RequiredArgsConstructor
public class CloudFileController {

    private final CloudFileService cloudFileService;

    private String getCurrentMemberId() {
        return SecurityUtils.getCurrentUserLogin().orElse(null);
    }

    private ResponseEntity<Map<String, Object>> unauthorizedResponse() {
        Map<String, Object> result = new HashMap<>();
        result.put(Constants.TAG_RESULT, Constants.RESULT_NOT_FOUND);
        result.put(Constants.TAG_RESULT_MESSAGE, "인증 정보가 없습니다.");
        return ResponseEntity.ok(result);
    }

    // 파일 메타데이터 전체 목록 조회
    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @GetMapping("/note/v1/files")
    public ResponseEntity<Map<String, Object>> getFiles(
            @RequestParam(value = "since", required = false) String since) {
        log.debug("[CloudFileController] GET /note/v1/files 진입 - since: {}", since);
        String memberId = getCurrentMemberId();
        if (memberId == null) return unauthorizedResponse();

        Map<String, Object> result = since != null
                ? cloudFileService.getChangedFiles(memberId, since)
                : cloudFileService.getFileList(memberId);
        return ResponseEntity.ok(result);
    }

    // 파일 업로드 (신규)
    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @PostMapping("/note/v1/files")
    public ResponseEntity<Map<String, Object>> uploadFile(
            @RequestParam("littenId") String littenId,
            @RequestParam("localId") String localId,
            @RequestParam("fileType") String fileType,
            @RequestParam("fileName") String fileName,
            @RequestParam("localUpdatedAt") String localUpdatedAt,
            @RequestParam("file") MultipartFile file) {
        log.debug("[CloudFileController] POST /note/v1/files 진입 - littenId: {}, localId: {}, fileType: {}", littenId, localId, fileType);
        String memberId = getCurrentMemberId();
        if (memberId == null) return unauthorizedResponse();

        Map<String, Object> result = cloudFileService.uploadFile(memberId, littenId, localId, fileType, fileName, localUpdatedAt, file);
        return ResponseEntity.ok(result);
    }

    // 파일 수정 (업데이트 + 이전 파일 백업)
    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @PutMapping("/note/v1/files/{cloudId}")
    public ResponseEntity<Map<String, Object>> updateFile(
            @PathVariable Long cloudId,
            @RequestParam("localUpdatedAt") String localUpdatedAt,
            @RequestParam("file") MultipartFile file) {
        log.debug("[CloudFileController] PUT /note/v1/files/{} 진입", cloudId);
        String memberId = getCurrentMemberId();
        if (memberId == null) return unauthorizedResponse();

        Map<String, Object> result = cloudFileService.updateFile(cloudId, localUpdatedAt, file, memberId);
        return ResponseEntity.ok(result);
    }

    // 파일 소프트 삭제
    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @DeleteMapping("/note/v1/files/{cloudId}")
    public ResponseEntity<Map<String, Object>> deleteFile(@PathVariable Long cloudId) {
        log.debug("[CloudFileController] DELETE /note/v1/files/{} 진입", cloudId);
        String memberId = getCurrentMemberId();
        if (memberId == null) return unauthorizedResponse();

        Map<String, Object> result = cloudFileService.deleteFile(cloudId, memberId);
        return ResponseEntity.ok(result);
    }

    // 파일 다운로드
    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @GetMapping("/note/v1/files/{cloudId}/download")
    public ResponseEntity<?> downloadFile(@PathVariable Long cloudId) {
        log.debug("[CloudFileController] GET /note/v1/files/{}/download 진입", cloudId);
        String memberId = getCurrentMemberId();
        if (memberId == null) return unauthorizedResponse();

        return cloudFileService.downloadFile(cloudId, memberId);
    }
}

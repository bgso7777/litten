package com.litten.note.sync;

import com.litten.Constants;
import com.litten.common.security.SecurityUtils;
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

import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class CloudFileService {

    private static final int MAX_SYNC_FILES = 5000;

    private final CloudFileRepository cloudFileRepository;
    private final CloudFileBackupRepository cloudFileBackupRepository;
    private final LocalStorageService localStorageService;

    public Map<String, Object> getFileList(String memberId) {
        log.debug("[CloudFileService] getFileList 진입 - memberId: {}", memberId);

        PageRequest pageRequest = PageRequest.of(0, MAX_SYNC_FILES, Sort.by("updateDateTime").descending());
        // 삭제 tombstone 포함 — 다른 기기에서 삭제한 파일을 이 기기에 전파하기 위함
        List<CloudFile> files = cloudFileRepository.findByMemberId(memberId, pageRequest);
        List<Map<String, Object>> fileList = files.stream()
                .map(this::toMetaMap)
                .collect(Collectors.toList());

        log.info("[CloudFileService] getFileList - memberId: {}, count: {}", memberId, fileList.size());
        Map<String, Object> result = new HashMap<>();
        result.put(Constants.TAG_RESULT, Constants.RESULT_SUCCESS);
        result.put("files", fileList);
        result.put(Constants.TAG_SIZE, fileList.size());
        return result;
    }

    public Map<String, Object> getChangedFiles(String memberId, String since) {
        log.debug("[CloudFileService] getChangedFiles 진입 - memberId: {}, since: {}", memberId, since);

        LocalDateTime sinceTime = LocalDateTime.parse(since.replace(" ", "T"));
        PageRequest pageRequest = PageRequest.of(0, MAX_SYNC_FILES, Sort.by("updateDateTime").descending());
        // 삭제 tombstone 포함 — since 이후 삭제된 파일도 내려줘 다른 기기에 삭제를 전파
        List<CloudFile> files = cloudFileRepository
                .findByMemberIdAndUpdateDateTimeAfter(memberId, sinceTime, pageRequest);
        List<Map<String, Object>> fileList = files.stream()
                .map(this::toMetaMap)
                .collect(Collectors.toList());

        log.info("[CloudFileService] getChangedFiles - memberId: {}, since: {}, count: {}", memberId, since, fileList.size());
        Map<String, Object> result = new HashMap<>();
        result.put(Constants.TAG_RESULT, Constants.RESULT_SUCCESS);
        result.put("files", fileList);
        result.put(Constants.TAG_SIZE, fileList.size());
        return result;
    }

    @Transactional
    public Map<String, Object> uploadFile(String memberId, String littenId, String localId,
                                          String fileType, String fileName, String localUpdatedAt,
                                          MultipartFile file) {
        log.debug("[CloudFileService] uploadFile 진입 - memberId: {}, localId: {}, fileType: {}", memberId, localId, fileType);

        Map<String, Object> result = new HashMap<>();

        try {
            // 기존 파일이 있으면 업데이트, 없으면 신규 생성 (삭제된 행도 조회 → 수정 우선 재활성화)
            Optional<CloudFile> existing = cloudFileRepository.findByMemberIdAndLocalId(memberId, localId);

            if (existing.isPresent()) {
                result = updateFileInternal(existing.get(), file, localUpdatedAt, fileName);
            } else {
                String filePath = localStorageService.buildFilePath(memberId, fileType, fileName);
                String savedPath = localStorageService.save(file, filePath);

                CloudFile cloudFile = new CloudFile();
                cloudFile.setMemberId(memberId);
                cloudFile.setLittenId(littenId);
                cloudFile.setLocalId(localId);
                cloudFile.setFileType(fileType);
                cloudFile.setFileName(fileName);
                cloudFile.setFilePath(savedPath);
                cloudFile.setFileSize(file.getSize());
                cloudFile.setContentType(file.getContentType());
                cloudFile.setIsDeleted(false);
                cloudFile.setLocalUpdatedAt(LocalDateTime.parse(localUpdatedAt.replace(" ", "T")));
                cloudFileRepository.save(cloudFile);

                log.info("[CloudFileService] 신규 파일 업로드 완료 - localId: {}, path: {}", localId, savedPath);
                result.put(Constants.TAG_RESULT, Constants.RESULT_SUCCESS);
                result.put("cloudId", cloudFile.getId());
                result.put("localId", localId);
            }
        } catch (Exception e) {
            log.error("[CloudFileService] 파일 업로드 실패 - localId: {}", localId, e);
            result.put(Constants.TAG_RESULT, Constants.RESULT_FAIL);
            result.put(Constants.TAG_RESULT_MESSAGE, "파일 업로드 실패: " + e.getMessage());
        }

        return result;
    }

    @Transactional
    public Map<String, Object> updateFile(Long cloudId, String localUpdatedAt, MultipartFile file, String memberId, String fileName) {
        log.debug("[CloudFileService] updateFile 진입 - cloudId: {}, memberId: {}, fileName: {}", cloudId, memberId, fileName);

        Map<String, Object> result = new HashMap<>();

        Optional<CloudFile> optFile = cloudFileRepository.findById(cloudId);
        if (optFile.isEmpty() || !optFile.get().getMemberId().equals(memberId)) {
            log.warn("[CloudFileService] updateFile - 파일 없음 또는 권한 없음: cloudId={}", cloudId);
            result.put(Constants.TAG_RESULT, Constants.RESULT_NOT_FOUND);
            result.put(Constants.TAG_RESULT_MESSAGE, "파일을 찾을 수 없습니다.");
            return result;
        }

        return updateFileInternal(optFile.get(), file, localUpdatedAt, fileName);
    }

    // newFileName: 제목 변경 전파용(텍스트). null/blank면 기존 fileName 유지.
    private Map<String, Object> updateFileInternal(CloudFile cloudFile, MultipartFile file, String localUpdatedAt, String newFileName) {
        Map<String, Object> result = new HashMap<>();
        try {
            // 제목 변경 시 fileName 갱신 → 저장 경로도 새 이름으로 생성됨
            if (newFileName != null && !newFileName.isBlank()) {
                cloudFile.setFileName(newFileName);
            }
            // 이전 파일 백업
            if (cloudFile.getFilePath() != null) {
                String backupPath = localStorageService.backup(cloudFile.getFilePath());
                if (backupPath != null) {
                    CloudFileBackup backup = new CloudFileBackup();
                    backup.setCloudFileId(cloudFile.getId());
                    backup.setBackupPath(backupPath);
                    backup.setFileSize(cloudFile.getFileSize());
                    backup.setBackedUpAt(LocalDateTime.now());
                    cloudFileBackupRepository.save(backup);
                    log.info("[CloudFileService] 백업 생성 완료 - cloudId: {}, backupPath: {}", cloudFile.getId(), backupPath);
                }
            }

            // 신규 파일 저장
            String savedPath = localStorageService.save(file,
                    localStorageService.buildFilePath(cloudFile.getMemberId(),
                            cloudFile.getFileType(), cloudFile.getFileName()));
            cloudFile.setFilePath(savedPath);
            cloudFile.setFileSize(file.getSize());
            cloudFile.setLocalUpdatedAt(LocalDateTime.parse(localUpdatedAt.replace(" ", "T")));
            cloudFile.setUpdateDateTime(LocalDateTime.now());
            // 수정 우선(삭제 취소): 삭제된 파일에 수정이 들어오면 재활성화한다.
            if (Boolean.TRUE.equals(cloudFile.getIsDeleted())) {
                cloudFile.setIsDeleted(false);
                cloudFile.setDeletedAt(null);
                log.info("[CloudFileService] 삭제된 파일 재활성화(수정 우선) - cloudId: {}", cloudFile.getId());
            }
            cloudFileRepository.save(cloudFile);

            log.info("[CloudFileService] 파일 수정 완료 - cloudId: {}", cloudFile.getId());
            result.put(Constants.TAG_RESULT, Constants.RESULT_SUCCESS);
            result.put("cloudId", cloudFile.getId());
            result.put("localId", cloudFile.getLocalId());
        } catch (Exception e) {
            log.error("[CloudFileService] 파일 수정 실패 - cloudId: {}", cloudFile.getId(), e);
            result.put(Constants.TAG_RESULT, Constants.RESULT_FAIL);
            result.put(Constants.TAG_RESULT_MESSAGE, "파일 수정 실패: " + e.getMessage());
        }
        return result;
    }

    @Transactional
    public Map<String, Object> deleteFile(Long cloudId, String memberId) {
        log.debug("[CloudFileService] deleteFile 진입 - cloudId: {}, memberId: {}", cloudId, memberId);

        Map<String, Object> result = new HashMap<>();
        Optional<CloudFile> optFile = cloudFileRepository.findById(cloudId);

        if (optFile.isEmpty() || !optFile.get().getMemberId().equals(memberId)) {
            log.warn("[CloudFileService] deleteFile - 파일 없음 또는 권한 없음: cloudId={}", cloudId);
            result.put(Constants.TAG_RESULT, Constants.RESULT_NOT_FOUND);
            result.put(Constants.TAG_RESULT_MESSAGE, "파일을 찾을 수 없습니다.");
            return result;
        }

        CloudFile cloudFile = optFile.get();
        cloudFile.setIsDeleted(true);
        cloudFile.setDeletedAt(LocalDateTime.now());
        cloudFile.setUpdateDateTime(LocalDateTime.now());
        cloudFileRepository.save(cloudFile);

        // 실제 파일도 디스크에서 삭제
        if (cloudFile.getFilePath() != null) {
            try {
                localStorageService.delete(cloudFile.getFilePath());
            } catch (Exception e) {
                log.warn("[CloudFileService] 물리 파일 삭제 실패 (DB 삭제는 완료) - cloudId: {}, path: {}, error: {}",
                        cloudId, cloudFile.getFilePath(), e.getMessage());
            }
        }

        log.info("[CloudFileService] 파일 삭제 완료 - cloudId: {}", cloudId);
        result.put(Constants.TAG_RESULT, Constants.RESULT_SUCCESS);
        result.put("cloudId", cloudId);
        return result;
    }

    public ResponseEntity<Resource> downloadFile(Long cloudId, String memberId) {
        log.debug("[CloudFileService] downloadFile 진입 - cloudId: {}, memberId: {}", cloudId, memberId);

        Optional<CloudFile> optFile = cloudFileRepository.findById(cloudId);
        if (optFile.isEmpty() || !optFile.get().getMemberId().equals(memberId) || optFile.get().getIsDeleted()) {
            log.warn("[CloudFileService] downloadFile - 파일 없음 또는 권한 없음: cloudId={}", cloudId);
            return ResponseEntity.notFound().build();
        }

        try {
            CloudFile cloudFile = optFile.get();
            Resource resource = localStorageService.loadAsResource(cloudFile.getFilePath());
            long contentLength = resource.contentLength();
            log.info("[CloudFileService] 파일 다운로드 시작 - cloudId: {}, size: {}", cloudId, contentLength);

            // 한글 등 비-ASCII 파일명은 HTTP 헤더(ISO-8859-1)에 직접 넣을 수 없으므로
            // RFC 5987 방식(filename*=UTF-8'')으로 인코딩한다. ContentDisposition 빌더가 처리.
            ContentDisposition contentDisposition = ContentDisposition.attachment()
                    .filename(cloudFile.getFileName(), java.nio.charset.StandardCharsets.UTF_8)
                    .build();

            return ResponseEntity.ok()
                    .header(HttpHeaders.CONTENT_DISPOSITION, contentDisposition.toString())
                    .contentType(cloudFile.getContentType() != null
                            ? MediaType.parseMediaType(cloudFile.getContentType())
                            : MediaType.APPLICATION_OCTET_STREAM)
                    .contentLength(contentLength)
                    .body(resource);
        } catch (Exception e) {
            log.error("[CloudFileService] 파일 다운로드 실패 - cloudId: {}", cloudId, e);
            return ResponseEntity.internalServerError().build();
        }
    }

    private Map<String, Object> toMetaMap(CloudFile f) {
        Map<String, Object> m = new HashMap<>();
        m.put("cloudId", f.getId());
        m.put("localId", f.getLocalId());
        m.put("littenId", f.getLittenId());
        m.put("fileType", f.getFileType());
        m.put("fileName", f.getFileName());
        m.put("fileSize", f.getFileSize());
        m.put("localUpdatedAt", f.getLocalUpdatedAt());
        m.put("updatedAt", f.getUpdateDateTime());
        m.put("isDeleted", Boolean.TRUE.equals(f.getIsDeleted()));
        m.put("deletedAt", f.getDeletedAt());
        return m;
    }
}

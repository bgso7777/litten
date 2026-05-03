package com.litten.note.sync;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

@Slf4j
@Service
public class LocalStorageService implements StorageService {

    @Value("${file.storage.base-path:/data/litten/files}")
    private String basePath;

    @Value("${file.storage.backup-path:/data/litten/backups}")
    private String backupPath;

    @Override
    public String save(MultipartFile file, String targetPath) throws Exception {
        log.debug("[LocalStorageService] save 진입 - targetPath: {}", targetPath);

        Path fullPath = Paths.get(basePath, targetPath);
        Files.createDirectories(fullPath.getParent());
        Files.copy(file.getInputStream(), fullPath, StandardCopyOption.REPLACE_EXISTING);

        log.info("[LocalStorageService] 파일 저장 완료 - path: {}, size: {}", fullPath, file.getSize());
        return fullPath.toString();
    }

    @Override
    public byte[] load(String filePath) throws Exception {
        log.debug("[LocalStorageService] load 진입 - filePath: {}", filePath);

        Path path = Paths.get(filePath);
        if (!Files.exists(path)) {
            log.warn("[LocalStorageService] 파일 없음 - path: {}", filePath);
            throw new IOException("파일을 찾을 수 없습니다: " + filePath);
        }

        byte[] data = Files.readAllBytes(path);
        log.info("[LocalStorageService] 파일 로드 완료 - path: {}, size: {}", filePath, data.length);
        return data;
    }

    @Override
    public void delete(String filePath) throws Exception {
        log.debug("[LocalStorageService] delete 진입 - filePath: {}", filePath);

        Path path = Paths.get(filePath);
        if (Files.exists(path)) {
            Files.delete(path);
            log.info("[LocalStorageService] 파일 삭제 완료 - path: {}", filePath);
        } else {
            log.warn("[LocalStorageService] 삭제 대상 파일 없음 - path: {}", filePath);
        }
    }

    @Override
    public String backup(String sourcePath) throws Exception {
        log.debug("[LocalStorageService] backup 진입 - sourcePath: {}", sourcePath);

        Path source = Paths.get(sourcePath);
        if (!Files.exists(source)) {
            log.warn("[LocalStorageService] 백업 원본 파일 없음 - path: {}", sourcePath);
            return null;
        }

        String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMddHHmmss"));
        String fileName = source.getFileName().toString();
        String backupFileName = fileName + "." + timestamp + ".bak";

        Path backupDir = Paths.get(backupPath, source.getParent().toString().replace(basePath, ""));
        Files.createDirectories(backupDir);
        Path backupFilePath = backupDir.resolve(backupFileName);

        Files.copy(source, backupFilePath, StandardCopyOption.REPLACE_EXISTING);
        log.info("[LocalStorageService] 백업 완료 - source: {}, backup: {}", sourcePath, backupFilePath);

        return backupFilePath.toString();
    }

    public String buildFilePath(String memberId, String littenId, String fileType, String fileName) {
        return memberId + File.separator + littenId + File.separator + fileType + File.separator + fileName;
    }
}

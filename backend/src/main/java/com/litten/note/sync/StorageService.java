package com.litten.note.sync;

import org.springframework.core.io.Resource;
import org.springframework.web.multipart.MultipartFile;

public interface StorageService {

    String save(MultipartFile file, String targetPath) throws Exception;

    // 파일을 byte[]로 메모리에 로드하지 않고 Resource로 반환 — Spring이 OutputStream으로 스트리밍.
    Resource loadAsResource(String filePath) throws Exception;

    void delete(String filePath) throws Exception;

    String backup(String sourcePath) throws Exception;
}

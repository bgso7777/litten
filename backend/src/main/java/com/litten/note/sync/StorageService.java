package com.litten.note.sync;

import org.springframework.web.multipart.MultipartFile;

public interface StorageService {

    String save(MultipartFile file, String targetPath) throws Exception;

    byte[] load(String filePath) throws Exception;

    void delete(String filePath) throws Exception;

    String backup(String sourcePath) throws Exception;
}

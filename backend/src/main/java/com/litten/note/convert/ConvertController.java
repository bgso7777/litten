package com.litten.note.convert;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.nio.file.Files;
import java.util.Set;

@Slf4j
@RestController
@RequiredArgsConstructor
public class ConvertController {

    private final ConvertService convertService;

    // LibreOffice headless가 지원하는 파일 포맷
    private static final Set<String> SUPPORTED_EXTENSIONS = Set.of(
        "doc", "docx",           // Word
        "xls", "xlsx",           // Excel
        "ppt", "pptx",           // PowerPoint
        "odt", "ods", "odp",     // OpenDocument
        "rtf",                   // Rich Text
        "csv"                    // CSV
    );

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @PostMapping("/note/v1/convert/to-pdf")
    public ResponseEntity<?> convertToPdf(@RequestParam("file") MultipartFile file) {
        String fileName = file.getOriginalFilename();
        log.debug("[ConvertController] POST /note/v1/convert/to-pdf 진입 - fileName: {}", fileName);

        if (fileName == null || !fileName.contains(".")) {
            log.warn("[ConvertController] 파일명 오류 - fileName: {}", fileName);
            return ResponseEntity.badRequest().body("파일명이 올바르지 않습니다.");
        }

        String ext = fileName.substring(fileName.lastIndexOf('.') + 1).toLowerCase();
        if (!SUPPORTED_EXTENSIONS.contains(ext)) {
            log.warn("[ConvertController] 지원하지 않는 포맷 - ext: {}", ext);
            return ResponseEntity.badRequest().body("지원하지 않는 파일 형식입니다: " + ext);
        }

        ConvertService.ConvertResult result;
        try {
            result = convertService.convertToPdf(file);
        } catch (Exception e) {
            log.error("[ConvertController] 변환 실패 - fileName: {}, error: {}", fileName, e.getMessage(), e);
            return ResponseEntity.internalServerError().body("PDF 변환에 실패했습니다: " + e.getMessage());
        }

        String pdfName = fileName.substring(0, fileName.lastIndexOf('.')) + ".pdf";
        log.info("[ConvertController] 변환 성공 - pdfName: {}, size: {}", pdfName, result.size);

        byte[] pdfBytes;
        try {
            pdfBytes = Files.readAllBytes(result.pdfFile);
        } catch (Exception e) {
            log.error("[ConvertController] PDF 파일 읽기 실패 - pdfName: {}, error: {}", pdfName, e.getMessage(), e);
            return ResponseEntity.internalServerError().body(("PDF 파일 읽기 실패: " + e.getMessage()).getBytes());
        } finally {
            ConvertService.cleanup(result.tempDir);
        }

        return ResponseEntity.ok()
            .contentType(MediaType.APPLICATION_PDF)
            .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + pdfName + "\"")
            .body(pdfBytes);
    }
}

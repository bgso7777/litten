package com.litten.note.convert;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Comparator;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

@Slf4j
@Service
public class ConvertService {

    private static final String LIBREOFFICE_CMD = "libreoffice";
    private static final int TIMEOUT_SECONDS = 300;

    public byte[] convertToPdf(MultipartFile file) throws Exception {
        String originalFilename = file.getOriginalFilename();
        log.debug("[ConvertService] convertToPdf 진입 - fileName: {}", originalFilename);

        Path tempDir = Files.createTempDirectory("litten-convert-" + UUID.randomUUID());
        Path inputFile = tempDir.resolve(originalFilename);
        Files.write(inputFile, file.getBytes());
        log.info("[ConvertService] 임시 파일 저장 - path: {}", inputFile);

        try {
            ProcessBuilder pb = new ProcessBuilder(
                LIBREOFFICE_CMD,
                "--headless",
                "--norestore",
                "--nofirststartwizard",
                "--convert-to", "pdf",
                "--outdir", tempDir.toString(),
                inputFile.toString()
            );
            pb.redirectErrorStream(true);

            log.debug("[ConvertService] LibreOffice 실행 - command: {}", pb.command());
            Process process = pb.start();

            String output = new String(process.getInputStream().readAllBytes());
            boolean finished = process.waitFor(TIMEOUT_SECONDS, TimeUnit.SECONDS);

            if (!finished) {
                process.destroyForcibly();
                log.error("[ConvertService] LibreOffice 타임아웃 - {}초 초과", TIMEOUT_SECONDS);
                throw new RuntimeException("PDF 변환 타임아웃 (" + TIMEOUT_SECONDS + "초 초과)");
            }

            int exitCode = process.exitValue();
            log.info("[ConvertService] LibreOffice 완료 - exitCode: {}, output: {}", exitCode, output);

            if (exitCode != 0) {
                log.error("[ConvertService] LibreOffice 실패 - output: {}", output);
                throw new RuntimeException("PDF 변환 실패 (exitCode=" + exitCode + "): " + output);
            }

            String nameWithoutExt = originalFilename.substring(0, originalFilename.lastIndexOf('.'));
            Path pdfFile = tempDir.resolve(nameWithoutExt + ".pdf");

            if (!Files.exists(pdfFile)) {
                log.error("[ConvertService] PDF 파일 없음 - expected: {}", pdfFile);
                throw new RuntimeException("변환된 PDF 파일을 찾을 수 없습니다: " + pdfFile.getFileName());
            }

            byte[] pdfBytes = Files.readAllBytes(pdfFile);
            log.info("[ConvertService] PDF 변환 완료 - size: {} bytes", pdfBytes.length);
            return pdfBytes;

        } finally {
            try {
                Files.walk(tempDir)
                    .sorted(Comparator.reverseOrder())
                    .map(Path::toFile)
                    .forEach(File::delete);
                log.debug("[ConvertService] 임시 파일 정리 완료 - dir: {}", tempDir);
            } catch (IOException e) {
                log.warn("[ConvertService] 임시 파일 정리 실패: {}", e.getMessage());
            }
        }
    }
}

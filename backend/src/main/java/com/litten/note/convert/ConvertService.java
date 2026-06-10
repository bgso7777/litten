package com.litten.note.convert;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStreamReader;
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

    // 변환 결과를 byte[]로 메모리에 올리지 않고 임시 파일 Path를 반환. 호출자는 사용 후 cleanup(tempDir)을 호출해야 함.
    public ConvertResult convertToPdf(MultipartFile file) throws Exception {
        String originalFilename = file.getOriginalFilename();
        log.debug("[ConvertService] convertToPdf 진입 - fileName: {}", originalFilename);

        Path tempDir = Files.createTempDirectory("litten-convert-" + UUID.randomUUID());
        try {
            Path inputFile = tempDir.resolve(originalFilename);
            // MultipartFile.transferTo로 스트리밍 저장 — file.getBytes()로 전체 메모리 로드 회피.
            file.transferTo(inputFile);
            log.info("[ConvertService] 임시 파일 저장 - path: {}", inputFile);

            // 요청마다 고유 사용자 프로필 디렉토리를 지정한다.
            // 기본 공유 프로필(~/.config/libreoffice)을 쓰면 변환이 반복/동시 실행될 때
            // 프로필 락 때문에 두 번째 이후 인스턴스가 기존 인스턴스로 핸드오프되며 멈춰(타임아웃) 버린다.
            // UserInstallation을 요청별 임시 디렉토리로 분리하면 각 변환이 독립적으로 실행된다.
            Path profileDir = tempDir.resolve("lo_profile");
            ProcessBuilder pb = new ProcessBuilder(
                LIBREOFFICE_CMD,
                "-env:UserInstallation=file://" + profileDir.toString(),
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

            // LibreOffice 출력은 진단용 — 4KB까지만 읽고 버림. readAllBytes로 전체 메모리에 모으지 않음.
            StringBuilder output = new StringBuilder();
            try (BufferedReader br = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                char[] buf = new char[1024];
                int read;
                while ((read = br.read(buf)) != -1 && output.length() < 4096) {
                    output.append(buf, 0, Math.min(read, 4096 - output.length()));
                }
            }

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

            long size = Files.size(pdfFile);
            log.info("[ConvertService] PDF 변환 완료 - size: {} bytes", size);
            return new ConvertResult(pdfFile, tempDir, size);

        } catch (Exception e) {
            // 변환 실패 시 즉시 임시 디렉토리 정리. 성공 시는 호출자가 응답 전송 후 cleanup 책임.
            cleanup(tempDir);
            throw e;
        }
    }

    public static void cleanup(Path tempDir) {
        if (tempDir == null) return;
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

    public static class ConvertResult {
        public final Path pdfFile;
        public final Path tempDir;
        public final long size;

        public ConvertResult(Path pdfFile, Path tempDir, long size) {
            this.pdfFile = pdfFile;
            this.tempDir = tempDir;
            this.size = size;
        }
    }
}

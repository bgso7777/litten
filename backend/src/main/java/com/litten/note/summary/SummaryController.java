package com.litten.note.summary;

import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/**
 * 요약/퀴즈 API 컨트롤러.
 *
 * ┌──────────────────────────────────────────────────────────┐
 * │  POST /note/v1/summary/process                           │
 * │    · fileType 기준으로 note_summary_config 파라미터 조회 │
 * │    · YouTube: DB 캐시 먼저 조회, 없으면 AI 생성 → 저장  │
 * │    · 개인 파일: AI 생성 → note_summary_result 저장      │
 * │                                                          │
 * │  POST /note/v1/summary          (기존 API 유지)         │
 * │    · 직접 텍스트 전달 → AI 요약, DB 저장 없음           │
 * │                                                          │
 * │  GET  /note/v1/summary/youtube/{videoId}                 │
 * │    · YouTube 영상 요약 DB 조회 (없으면 404)             │
 * │                                                          │
 * │  GET  /note/v1/summary/file/{fileUuid}                   │
 * │    · 개인 파일 요약 DB 조회 (memberUuid 쿼리 파라미터)  │
 * └──────────────────────────────────────────────────────────┘
 */
@Log4j2
@RestController
@RequestMapping("/note/v1/summary")
@RequiredArgsConstructor
public class SummaryController {

    private final SummaryService        summaryService;
    private final SummaryProcessService processService;

    // ────────────────────────────────────────────────────────────────────────
    // 1. 통합 처리 API (프론트엔드 메인 호출)
    //    - note_summary_config 파라미터 사용
    //    - YouTube: DB 캐시 체크 후 없으면 AI 생성 → note_summary_result 저장
    //    - 개인 파일: AI 생성 → note_summary_result 저장
    // ────────────────────────────────────────────────────────────────────────
    /**
     * POST /note/v1/summary/process
     *
     * Request Body (JSON):
     * {
     *   "fileType"        : "youtube",            // 필수
     *   "youtubeVideoId"  : "dQw4w9WgXcQ",        // YouTube용
     *   "fileUuid"        : "uuid-...",            // 개인 파일용
     *   "memberUuid"      : "member-uuid-...",     // 개인 파일용
     *   "text"            : "요약할 원본 텍스트",
     *   "summaryLevel"    : 3,                     // 0이면 config 기본값
     *   "textLanguage"    : "ko",                  // null이면 config 기본값
     *   "summaryLanguage" : "ko",
     *   "forceRegenerate" : false                  // true면 캐시 무시 재생성
     * }
     *
     * Response Body:
     * {
     *   "success"        : true,
     *   "summary"        : "전체 AI 응답 텍스트...",
     *   "summaryOnly"    : "순수 요약 텍스트...",
     *   "summarySections": [ { "sectionTitle": "전체 목적", "sectionContent": "..." }, ... ],
     *   "quizzes"        : [ { "groupName": "...", "items": [...] }, ... ],
     *   "totalQuizCount": 5,
     *   "error"          : null
     * }
     */
    @PostMapping("/process")
    public ResponseEntity<SummaryResponseVo> process(
            @RequestBody SummaryProcessRequestVo request) {

        log.debug("[SummaryController] POST /note/v1/summary/process 진입 - fileType: {}, videoId: {}, fileUuid: {}",
                request.getFileType(), request.getYoutubeVideoId(), request.getFileUuid());

        if (request.getFileType() == null || request.getFileType().isBlank()) {
            log.warn("[SummaryController] fileType 누락");
            return ResponseEntity.badRequest()
                    .body(SummaryResponseVo.fail("fileType 은 필수 파라미터입니다."));
        }

        SummaryResponseVo response = processService.process(request);
        log.info("[SummaryController] process 완료 - success: {}", response.isSuccess());
        return ResponseEntity.ok(response);
    }

    // ────────────────────────────────────────────────────────────────────────
    // 2. YouTube 요약 조회
    //    - DB에 done 상태 결과가 있으면 반환, 없으면 404
    //    - 없을 경우 프론트에서 POST /process 로 생성 요청
    // ────────────────────────────────────────────────────────────────────────
    /**
     * GET /note/v1/summary/youtube/{videoId}
     */
    @GetMapping("/youtube/{videoId}")
    public ResponseEntity<SummaryResponseVo> getYoutubeSummary(
            @PathVariable String videoId,
            @RequestParam(defaultValue = "0") int summaryLevel) {

        log.debug("[SummaryController] GET /note/v1/summary/youtube/{} level: {}", videoId, summaryLevel);

        SummaryResponseVo result = processService.getYoutubeSummary(videoId, summaryLevel);
        if (result == null) {
            log.info("[SummaryController] YouTube 요약 없음 - videoId: {}", videoId);
            return ResponseEntity.notFound().build();
        }

        log.info("[SummaryController] YouTube 요약 반환 - videoId: {}", videoId);
        return ResponseEntity.ok(result);
    }

    // ────────────────────────────────────────────────────────────────────────
    // 3. 개인 파일 요약 조회
    // ────────────────────────────────────────────────────────────────────────
    /**
     * GET /note/v1/summary/file/{fileUuid}?memberUuid=xxx
     */
    @GetMapping("/file/{fileUuid}")
    public ResponseEntity<SummaryResponseVo> getFileSummary(
            @PathVariable String fileUuid,
            @RequestParam(required = false) String memberUuid,
            @RequestParam(defaultValue = "0") int summaryLevel) {

        log.debug("[SummaryController] GET /note/v1/summary/file/{} memberUuid: {}, level: {}", fileUuid, memberUuid, summaryLevel);

        SummaryResponseVo result = processService.getFileSummary(fileUuid, memberUuid, summaryLevel);
        if (result == null) {
            log.info("[SummaryController] 파일 요약 없음 - fileUuid: {}", fileUuid);
            return ResponseEntity.notFound().build();
        }

        log.info("[SummaryController] 파일 요약 반환 - fileUuid: {}", fileUuid);
        return ResponseEntity.ok(result);
    }

    // ────────────────────────────────────────────────────────────────────────
    // 4. 기존 API 유지 (DB 저장 없이 직접 AI 호출)
    // ────────────────────────────────────────────────────────────────────────
    /**
     * POST /note/v1/summary
     * 기존 호환용 — DB 저장 없이 텍스트 직접 전달하여 AI 요약만 반환.
     */
    @PostMapping
    public ResponseEntity<SummaryResponseVo> summarize(
            @RequestBody SummaryRequestVo request) {

        log.debug("[SummaryController] POST /note/v1/summary 진입 - fileId: {}", request.getFileId());

        SummaryResponseVo response = summaryService.summarize(request);
        log.info("[SummaryController] 요약 결과 - success: {}", response.isSuccess());
        return ResponseEntity.ok(response);
    }
}

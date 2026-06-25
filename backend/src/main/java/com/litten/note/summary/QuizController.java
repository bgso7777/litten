package com.litten.note.summary;

import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/**
 * 퀴즈 API 컨트롤러.
 *
 * ┌──────────────────────────────────────────────────────────────┐
 * │  POST /note/v1/quiz/process                                │
 * │    · summaryResultId 로 원본 텍스트 조회 → AI 퀴즈 생성  │
 * │    · 기존 quiz 있으면 캐시 반환 (forceRegenerate=false)    │
 * │                                                              │
 * │  GET  /note/v1/quiz/{summaryResultId}                      │
 * │    · DB 저장된 퀴즈 조회 (없으면 404)                    │
 * └──────────────────────────────────────────────────────────────┘
 */
@Log4j2
@RestController
@RequestMapping("/note/v1/quiz")
@RequiredArgsConstructor
public class QuizController {

    private final QuizProcessService quizProcessService;

    /**
     * POST /note/v1/quiz/process
     *
     * Request Body (JSON):
     * {
     *   "summaryResultId"  : 123,    // 필수
     *   "quizLevel"      : 3,      // 선택 (1~5, 0이면 기본값=3)
     *                                //   1=핵심1개, 2=간단3개, 3=일반5개, 4=상세10개, 5=전체20개
     *   "quizCustomCount": 7,      // 선택 — CUSTOM 시 개수 직접 지정 (quizLevel 우선)
     *   "summaryLanguage"  : "ko",   // 선택 (null=ko)
     *   "forceRegenerate"  : false   // 선택
     * }
     *
     * Response Body:
     * {
     *   "success"         : true,
     *   "quizzes"         : [ { "groupName": "...", "items": [...] }, ... ],
     *   "totalQuizCount": 5,
     *   "error"           : null
     * }
     */
    @PostMapping("/process")
    public ResponseEntity<QuizResponseVo> process(@RequestBody QuizProcessRequestVo request) {
        log.debug("[QuizController] POST /note/v1/quiz/process 진입 - summaryResultId: {}",
                request.getSummaryResultId());

        if (request.getSummaryResultId() == null
                && (request.getYoutubeVideoId() == null || request.getYoutubeVideoId().isBlank())) {
            log.warn("[QuizController] summaryResultId/youtubeVideoId 모두 누락");
            return ResponseEntity.badRequest()
                    .body(QuizResponseVo.fail("summaryResultId 또는 youtubeVideoId가 필요합니다."));
        }

        QuizResponseVo response = quizProcessService.process(request);
        log.info("[QuizController] process 완료 - success: {}, count: {}",
                response.isSuccess(), response.getTotalQuizCount());
        return ResponseEntity.ok(response);
    }

    /**
     * GET /note/v1/quiz/{summaryResultId}
     * DB에 저장된 퀴즈 조회. 없으면 404.
     */
    @GetMapping("/{summaryResultId}")
    public ResponseEntity<QuizResponseVo> getQuiz(@PathVariable Long summaryResultId) {
        log.debug("[QuizController] GET /note/v1/quiz/{} 진입", summaryResultId);

        QuizResponseVo result = quizProcessService.getQuiz(summaryResultId);
        if (result == null) {
            log.info("[QuizController] 퀴즈 없음 - summaryResultId: {}", summaryResultId);
            return ResponseEntity.notFound().build();
        }

        log.info("[QuizController] 퀴즈 반환 - summaryResultId: {}, count: {}",
                summaryResultId, result.getTotalQuizCount());
        return ResponseEntity.ok(result);
    }

    /**
     * GET /note/v1/quiz/youtube/{videoId}
     * 영상 ID로 저장된 퀴즈 조회 (요약 선행 없이 만든 퀴즈 포함). 없으면 404.
     */
    @GetMapping("/youtube/{videoId}")
    public ResponseEntity<QuizResponseVo> getQuizByVideo(@PathVariable String videoId) {
        log.debug("[QuizController] GET /note/v1/quiz/youtube/{} 진입", videoId);

        QuizResponseVo result = quizProcessService.getQuizByVideoId(videoId);
        if (result == null) {
            log.info("[QuizController] 영상 퀴즈 없음 - videoId: {}", videoId);
            return ResponseEntity.notFound().build();
        }

        log.info("[QuizController] 영상 퀴즈 반환 - videoId: {}, count: {}",
                videoId, result.getTotalQuizCount());
        return ResponseEntity.ok(result);
    }
}

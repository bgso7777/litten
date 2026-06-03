package com.litten.note.summary;

import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/**
 * 리마인드 API 컨트롤러.
 *
 * ┌──────────────────────────────────────────────────────────────┐
 * │  POST /note/v1/remind/process                                │
 * │    · summaryResultId 로 원본 텍스트 조회 → AI 리마인드 생성  │
 * │    · 기존 remind 있으면 캐시 반환 (forceRegenerate=false)    │
 * │                                                              │
 * │  GET  /note/v1/remind/{summaryResultId}                      │
 * │    · DB 저장된 리마인드 조회 (없으면 404)                    │
 * └──────────────────────────────────────────────────────────────┘
 */
@Log4j2
@RestController
@RequestMapping("/note/v1/remind")
@RequiredArgsConstructor
public class RemindController {

    private final RemindProcessService remindProcessService;

    /**
     * POST /note/v1/remind/process
     *
     * Request Body (JSON):
     * {
     *   "summaryResultId"  : 123,    // 필수
     *   "remindLevel"      : 3,      // 선택 (1~5, 0이면 기본값=3)
     *                                //   1=핵심1개, 2=간단3개, 3=일반5개, 4=상세10개, 5=전체20개
     *   "remindCustomCount": 7,      // 선택 — CUSTOM 시 개수 직접 지정 (remindLevel 우선)
     *   "summaryLanguage"  : "ko",   // 선택 (null=ko)
     *   "forceRegenerate"  : false   // 선택
     * }
     *
     * Response Body:
     * {
     *   "success"         : true,
     *   "reminds"         : [ { "groupName": "...", "items": [...] }, ... ],
     *   "totalRemindCount": 5,
     *   "error"           : null
     * }
     */
    @PostMapping("/process")
    public ResponseEntity<RemindResponseVo> process(@RequestBody RemindProcessRequestVo request) {
        log.debug("[RemindController] POST /note/v1/remind/process 진입 - summaryResultId: {}",
                request.getSummaryResultId());

        if (request.getSummaryResultId() == null) {
            log.warn("[RemindController] summaryResultId 누락");
            return ResponseEntity.badRequest().body(RemindResponseVo.fail("summaryResultId는 필수 파라미터입니다."));
        }

        RemindResponseVo response = remindProcessService.process(request);
        log.info("[RemindController] process 완료 - success: {}, count: {}",
                response.isSuccess(), response.getTotalRemindCount());
        return ResponseEntity.ok(response);
    }

    /**
     * GET /note/v1/remind/{summaryResultId}
     * DB에 저장된 리마인드 조회. 없으면 404.
     */
    @GetMapping("/{summaryResultId}")
    public ResponseEntity<RemindResponseVo> getRemind(@PathVariable Long summaryResultId) {
        log.debug("[RemindController] GET /note/v1/remind/{} 진입", summaryResultId);

        RemindResponseVo result = remindProcessService.getRemind(summaryResultId);
        if (result == null) {
            log.info("[RemindController] 리마인드 없음 - summaryResultId: {}", summaryResultId);
            return ResponseEntity.notFound().build();
        }

        log.info("[RemindController] 리마인드 반환 - summaryResultId: {}, count: {}",
                summaryResultId, result.getTotalRemindCount());
        return ResponseEntity.ok(result);
    }
}

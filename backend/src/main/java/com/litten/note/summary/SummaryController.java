package com.litten.note.summary;

import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@Log4j2
@RestController
@RequestMapping("/note/v1/summary")
@RequiredArgsConstructor
public class SummaryController {

    private final SummaryService summaryService;

    /**
     * 텍스트 요약 API
     * POST /litten/note/v1/summary
     *
     * Request Body:
     * {
     *   "text": "요약할 텍스트 (HTML 포함 가능)",
     *   "language": "ko",
     *   "fileId": "flutter_text_file_id"
     * }
     *
     * Response:
     * {
     *   "success": true,
     *   "summary": "요약 내용...",
     *   "error": null
     * }
     */
    @PostMapping
    public ResponseEntity<SummaryResponseVo> summarize(@RequestBody SummaryRequestVo request) {
        log.debug("[SummaryController] POST /note/v1/summary 진입 - fileId: {}", request.getFileId());

        SummaryResponseVo response = summaryService.summarize(request);

        log.info("[SummaryController] 요약 결과 - success: {}", response.isSuccess());
        return ResponseEntity.ok(response);
    }
}

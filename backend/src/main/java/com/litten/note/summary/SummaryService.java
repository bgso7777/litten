package com.litten.note.summary;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import lombok.extern.log4j.Log4j2;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

@Log4j2
@Service
public class SummaryService {

    private static final String CLAUDE_API_URL = "https://api.anthropic.com/v1/messages";
    private static final String ANTHROPIC_VERSION = "2023-06-01";

    @Value("${claude.api.key:}")
    private String apiKey;

    @Value("${claude.api.model:claude-haiku-4-5-20251001}")
    private String model;

    @Value("${claude.api.max-tokens:1024}")
    private int maxTokens;

    private final RestTemplate restTemplate = new RestTemplate();
    private final ObjectMapper objectMapper = new ObjectMapper();

    public SummaryResponseVo summarize(SummaryRequestVo request) {
        log.debug("[SummaryService] summarize() 진입 - fileId: {}", request.getFileId());

        if (apiKey == null || apiKey.isBlank()) {
            log.error("[SummaryService] Claude API 키가 설정되지 않음");
            return SummaryResponseVo.fail("Claude API 키가 설정되지 않았습니다.");
        }

        String plainText = stripHtml(request.getText());
        if (plainText.isBlank()) {
            log.info("[SummaryService] 요약할 텍스트 없음");
            return SummaryResponseVo.fail("요약할 텍스트가 없습니다.");
        }

        int ratio = normalizeRatio(request.getSummaryRatio());
        log.info("[SummaryService] 요약 요청 - 텍스트 길이: {}, 입력언어: {}, 요약언어: {}, 비율: {}",
                plainText.length(), request.getTextLanguage(), request.getSummaryLanguage(), ratio);

        try {
            String prompt = buildPrompt(plainText, request.getTextLanguage(), request.getSummaryLanguage(), ratio);
            String requestBody = buildRequestBody(prompt);

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.set("x-api-key", apiKey);
            headers.set("anthropic-version", ANTHROPIC_VERSION);

            HttpEntity<String> entity = new HttpEntity<>(requestBody, headers);

            log.debug("[SummaryService] Claude API 호출 시작 - model: {}", model);
            ResponseEntity<String> response = restTemplate.exchange(
                    CLAUDE_API_URL, HttpMethod.POST, entity, String.class);

            log.info("[SummaryService] Claude API 응답 - status: {}", response.getStatusCode());

            String summary = extractSummary(response.getBody());
            log.info("[SummaryService] 요약 완료 - 요약 길이: {}", summary.length());
            return SummaryResponseVo.ok(summary);

        } catch (HttpClientErrorException e) {
            log.error("[SummaryService] Claude API 클라이언트 오류 - status: {}, body: {}",
                    e.getStatusCode(), e.getResponseBodyAsString());
            if (e.getStatusCode() == HttpStatus.UNAUTHORIZED) {
                return SummaryResponseVo.fail("API 키가 유효하지 않습니다.");
            } else if (e.getStatusCode() == HttpStatus.TOO_MANY_REQUESTS) {
                return SummaryResponseVo.fail("API 요청 한도를 초과했습니다. 잠시 후 다시 시도해주세요.");
            }
            return SummaryResponseVo.fail("API 오류: " + e.getStatusCode());
        } catch (Exception e) {
            log.error("[SummaryService] 요약 처리 중 오류 발생", e);
            return SummaryResponseVo.fail("요약 처리 중 오류가 발생했습니다.");
        }
    }

    // ratio 10~90 → 포인트 수 1~9개, 길이 지침 매핑
    private int normalizeRatio(int ratio) {
        if (ratio < 10) return 50; // 기본값
        int clamped = Math.max(10, Math.min(90, ratio));
        return (clamped / 10) * 10; // 10단위 정규화
    }

    private String buildPrompt(String text, String textLanguage, String summaryLanguage, int ratio) {
        String inputLang = (textLanguage == null || textLanguage.isBlank()) ? "ko" : textLanguage;
        String outputLang = (summaryLanguage == null || summaryLanguage.isBlank()) ? "ko" : summaryLanguage;

        int points = ratio / 10; // 10→1개, 50→5개, 90→9개
        String detailLevel = ratio <= 20 ? "매우 간략하게 핵심만"
                           : ratio <= 40 ? "간결하게"
                           : ratio <= 60 ? "적당한 수준으로"
                           : ratio <= 80 ? "상세하게"
                           :               "매우 상세하게 빠짐없이";

        String inputLangInstruction = "ko".equals(inputLang)
                ? "아래 텍스트는 한국어로 작성되었습니다."
                : "The following text is written in " + inputLang + ".";

        String outputLangInstruction = "ko".equals(outputLang)
                ? "요약은 반드시 한국어로 작성해주세요."
                : "Please write the summary in " + outputLang + ".";

        return inputLangInstruction + "\n"
                + outputLangInstruction + "\n\n"
                + detailLevel + " " + points + "개의 포인트로 요약해주세요. 각 포인트는 한 줄로 작성해주세요.\n\n"
                + "텍스트:\n" + text;
    }

    private String buildRequestBody(String prompt) throws Exception {
        ObjectNode root = objectMapper.createObjectNode();
        root.put("model", model);
        root.put("max_tokens", maxTokens);

        ArrayNode messages = root.putArray("messages");
        ObjectNode message = messages.addObject();
        message.put("role", "user");
        message.put("content", prompt);

        return objectMapper.writeValueAsString(root);
    }

    private String extractSummary(String responseBody) throws Exception {
        JsonNode root = objectMapper.readTree(responseBody);
        JsonNode content = root.path("content");
        if (content.isArray() && content.size() > 0) {
            return content.get(0).path("text").asText();
        }
        throw new RuntimeException("Claude API 응답에서 텍스트를 찾을 수 없음: " + responseBody);
    }

    private String stripHtml(String html) {
        if (html == null) return "";
        return html.replaceAll("<[^>]*>", " ")
                   .replaceAll("&nbsp;", " ")
                   .replaceAll("&amp;", "&")
                   .replaceAll("&lt;", "<")
                   .replaceAll("&gt;", ">")
                   .replaceAll("\\s+", " ")
                   .trim();
    }
}

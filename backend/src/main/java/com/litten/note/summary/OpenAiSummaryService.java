package com.litten.note.summary;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.litten.common.config.ApiKeyProperties;
import lombok.extern.log4j.Log4j2;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestTemplate;
import java.net.SocketTimeoutException;

@Log4j2
@Service
public class OpenAiSummaryService {

    private static final String OPENAI_API_URL = "https://api.openai.com/v1/chat/completions";

    @Autowired
    private ApiKeyProperties apiKeyProperties;

    @Value("${openai.api.model:gpt-4o-mini}")
    private String model;

    @Value("${openai.api.max-tokens:1024}")
    private int maxTokens;

    private final RestTemplate restTemplate = createRestTemplate();
    private final ObjectMapper objectMapper = new ObjectMapper();

    private static RestTemplate createRestTemplate() {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(30_000);   // 30초 (연결)
        factory.setReadTimeout(300_000);     // 5분 (응답 대기, 큰 출력 토큰 생성 대비)
        return new RestTemplate(factory);
    }

    public SummaryResponseVo summarize(SummaryRequestVo request) {
        log.debug("[OpenAiSummaryService] summarize() 진입 - fileId: {}", request.getFileId());

        String apiKey = apiKeyProperties.getOpenaiKey();
        if (apiKey == null || apiKey.isBlank()) {
            log.error("[OpenAiSummaryService] OpenAI API 키가 설정되지 않음");
            return SummaryResponseVo.fail("OpenAI API 키가 설정되지 않았습니다. 서버 환경변수 OPENAI_API_KEY를 확인하세요.");
        }

        String plainText = stripHtml(request.getText());
        if (plainText.isBlank()) {
            log.info("[OpenAiSummaryService] 요약할 텍스트 없음");
            return SummaryResponseVo.fail("요약할 텍스트가 없습니다.");
        }

        int level = normalizeLevel(request.getSummaryLevel());
        log.info("[OpenAiSummaryService] 요약 요청 - 텍스트 길이: {}, 입력언어: {}, 요약언어: {}, 수준: {}",
                plainText.length(), request.getTextLanguage(), request.getSummaryLanguage(), level);

        try {
            String systemPrompt = request.getSystemPrompt();
            if (isBlank(systemPrompt)) {
                log.error("[OpenAiSummaryService] 시스템 프롬프트 미설정 - note_prompt_config DB 확인 필요 (fileType, level: {})", level);
                return SummaryResponseVo.fail("시스템 프롬프트가 설정되지 않았습니다. 관리자에게 문의하세요.");
            }
            String userContent = buildUserContent(plainText, request.getTextLanguage(), request.getSummaryLanguage(), level);
            log.info("[OpenAiSummaryService] DB 프롬프트 적용");
            int computedMaxTokens = computeMaxTokens(plainText, level);
            log.info("[OpenAiSummaryService] max_tokens 계산 - 텍스트길이: {}, 수준: {}, tokens: {}",
                    plainText.length(), level, computedMaxTokens);
            String requestBody = buildRequestBody(systemPrompt, userContent, computedMaxTokens);

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.setBearerAuth(apiKey);

            HttpEntity<String> entity = new HttpEntity<>(requestBody, headers);

            log.debug("[OpenAiSummaryService] OpenAI API 호출 시작 - model: {}", model);
            ResponseEntity<String> response = restTemplate.exchange(
                    OPENAI_API_URL, HttpMethod.POST, entity, String.class);

            log.info("[OpenAiSummaryService] OpenAI API 응답 - status: {}", response.getStatusCode());

            String summary = extractSummary(response.getBody());
            log.info("[OpenAiSummaryService] 요약 완료 - 요약 길이: {}", summary.length());
            return SummaryResponseVo.ok(summary);

        } catch (HttpClientErrorException e) {
            log.error("[OpenAiSummaryService] OpenAI API 클라이언트 오류 - status: {}, body: {}",
                    e.getStatusCode(), e.getResponseBodyAsString());
            if (e.getStatusCode() == HttpStatus.UNAUTHORIZED) {
                return SummaryResponseVo.fail("OpenAI API 키가 유효하지 않습니다.");
            } else if (e.getStatusCode() == HttpStatus.TOO_MANY_REQUESTS) {
                return SummaryResponseVo.fail("OpenAI API 요청 한도를 초과했습니다. 잠시 후 다시 시도해주세요.");
            } else if (e.getStatusCode() == HttpStatus.BAD_REQUEST) {
                String body = e.getResponseBodyAsString();
                if (body != null && body.contains("context_length_exceeded")) {
                    return SummaryResponseVo.fail("입력 텍스트가 너무 길어 요약할 수 없습니다. 더 낮은 요약 수준을 선택하거나 텍스트를 줄여주세요.");
                }
                return SummaryResponseVo.fail("OpenAI API 요청 형식 오류: " + body);
            }
            return SummaryResponseVo.fail("OpenAI API 오류: " + e.getStatusCode());
        } catch (ResourceAccessException e) {
            // 네트워크/타임아웃 (SocketTimeoutException 포함)
            Throwable cause = e.getCause();
            if (cause instanceof SocketTimeoutException) {
                log.error("[OpenAiSummaryService] OpenAI API 응답 시간 초과 (5분)", e);
                return SummaryResponseVo.fail("응답 시간이 초과되었습니다. 텍스트를 줄이거나 더 낮은 요약 수준을 선택해주세요.");
            }
            log.error("[OpenAiSummaryService] OpenAI API 네트워크 오류", e);
            return SummaryResponseVo.fail("네트워크 오류가 발생했습니다. 잠시 후 다시 시도해주세요.");
        } catch (Exception e) {
            log.error("[OpenAiSummaryService] 요약 처리 중 오류 발생", e);
            return SummaryResponseVo.fail("요약 처리 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    private int normalizeLevel(int level) {
        if (level < 1 || level > 5) return 3; // 기본값: 일반 요약
        return level;
    }

    // user 메시지: 콘텐츠만
    private String buildUserContent(String text, String textLanguage, String summaryLanguage, int level) {
        String sourceLang = (textLanguage == null || textLanguage.isBlank()) ? "ko" : textLanguage;
        String outputLang = (summaryLanguage == null || summaryLanguage.isBlank()) ? sourceLang : summaryLanguage;

        return "요약 수준: " + level + "\n"
                + "대상 언어: " + sourceLang + "\n"
                + "요약 언어: " + outputLang + "\n\n"
                + "콘텐츠:\n" + text;
    }

    private int computeMaxTokens(String text, int level) {
        // 한국어 평균 1.5자 ≈ 1토큰
        int estimatedInputTokens = text.length() * 2 / 3;
        double ratio = switch (level) {
            case 1 -> 0.15;
            case 2 -> 0.30;
            case 3 -> 0.55;
            case 4 -> 0.80;
            case 5 -> 1.10; // 거의 전체 (오버헤드 포함 여유)
            default -> 0.55;
        };
        int needed = (int)(estimatedInputTokens * ratio) + 800; // 포맷+리마인드 오버헤드

        // gpt-4o-mini 최대 출력 토큰 = 16384 (Lv.5의 경우 maxTokens(8192) 무시하고 16384까지 허용)
        int hardLimit = (level == 5) ? 16384 : maxTokens;
        return Math.min(hardLimit, Math.max(512, needed));
    }

    private String buildRequestBody(String systemPrompt, String userContent, int computedMaxTokens) throws Exception {
        ObjectNode root = objectMapper.createObjectNode();
        root.put("model", model);
        root.put("max_tokens", computedMaxTokens);

        ArrayNode messages = root.putArray("messages");

        ObjectNode systemMsg = messages.addObject();
        systemMsg.put("role", "system");
        systemMsg.put("content", systemPrompt);

        ObjectNode userMsg = messages.addObject();
        userMsg.put("role", "user");
        userMsg.put("content", userContent);

        return objectMapper.writeValueAsString(root);
    }

    private String extractSummary(String responseBody) throws Exception {
        JsonNode root = objectMapper.readTree(responseBody);
        JsonNode choices = root.path("choices");
        if (choices.isArray() && choices.size() > 0) {
            return choices.get(0).path("message").path("content").asText();
        }
        throw new RuntimeException("OpenAI API 응답에서 텍스트를 찾을 수 없음: " + responseBody);
    }

    private boolean isBlank(String s) {
        return s == null || s.isBlank();
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

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
public class OpenAiSummaryService {

    private static final String OPENAI_API_URL = "https://api.openai.com/v1/chat/completions";

    @Value("${openai.api.key:}")
    private String apiKey;

    @Value("${openai.api.model:gpt-4o-mini}")
    private String model;

    @Value("${openai.api.max-tokens:1024}")
    private int maxTokens;

    private final RestTemplate restTemplate = new RestTemplate();
    private final ObjectMapper objectMapper = new ObjectMapper();

    public SummaryResponseVo summarize(SummaryRequestVo request) {
        log.debug("[OpenAiSummaryService] summarize() 진입 - fileId: {}", request.getFileId());

        if (apiKey == null || apiKey.isBlank()) {
            log.error("[OpenAiSummaryService] OpenAI API 키가 설정되지 않음");
            return SummaryResponseVo.fail("OpenAI API 키가 설정되지 않았습니다. 서버 환경변수 OPENAI_API_KEY를 확인하세요.");
        }

        String plainText = stripHtml(request.getText());
        if (plainText.isBlank()) {
            log.info("[OpenAiSummaryService] 요약할 텍스트 없음");
            return SummaryResponseVo.fail("요약할 텍스트가 없습니다.");
        }

        int ratio = normalizeRatio(request.getSummaryRatio());
        log.info("[OpenAiSummaryService] 요약 요청 - 텍스트 길이: {}, 입력언어: {}, 요약언어: {}, 비율: {}",
                plainText.length(), request.getTextLanguage(), request.getSummaryLanguage(), ratio);

        try {
            String prompt = buildPrompt(plainText, request.getTextLanguage(), request.getSummaryLanguage(), ratio);
            String requestBody = buildRequestBody(prompt);

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
            }
            return SummaryResponseVo.fail("OpenAI API 오류: " + e.getStatusCode());
        } catch (Exception e) {
            log.error("[OpenAiSummaryService] 요약 처리 중 오류 발생", e);
            return SummaryResponseVo.fail("요약 처리 중 오류가 발생했습니다.");
        }
    }

    private int normalizeRatio(int ratio) {
        if (ratio < 10) return 20;
        int clamped = Math.max(10, Math.min(90, ratio));
        return (clamped / 10) * 10;
    }

    private String buildPrompt(String text, String textLanguage, String summaryLanguage, int ratio) {
        String inputLang = (textLanguage == null || textLanguage.isBlank()) ? "ko" : textLanguage;
        String outputLang = (summaryLanguage == null || summaryLanguage.isBlank()) ? "ko" : summaryLanguage;

        String inputLangInstruction = "ko".equals(inputLang)
                ? "아래 텍스트는 한국어로 작성되었습니다."
                : "The following text is written in " + inputLang + ".";

        String outputLangInstruction = "ko".equals(outputLang)
                ? "요약은 반드시 한국어로 작성해주세요."
                : "Please write the summary in " + outputLang + ".";

        // 비율별 요약 지침 (강의/회의 흐름 파악용)
        String summaryInstruction = switch (ratio) {
            case 10 -> "가장 핵심적인 주제만 간단히 요약해주세요. 전체 흐름 중 가장 중요한 내용만 목록화하여 작성해주세요.";
            case 20 -> "주요 주제 간략하게 요약해주세요. 강의/회의의 핵심 흐름을 파악할 수 있도록 목록화하여 작성해주세요.";
            case 30 -> "주요 주제를 요약해주세요. 강의/회의의 전개 흐름과 핵심 내용을 파악할 수 있도록 목록화하여 작성해주세요.";
            case 40 -> "주요 주제와 세부 내용을 포함하여 요약해주세요. 강의/회의의 전체 흐름과 중요 포인트를 파악할 수 있도록 목록화하여 작성해주세요.";
            case 50 -> "주요 주제, 세부 내용, 논의된 의견을 균형있게 요약해주세요. 강의/회의의 흐름과 핵심 내용을 충분히 파악할 수 있도록 목록화하여 작성해주세요.";
            case 60 -> "주요 주제, 세부 내용, 논의 과정을 상세히 요약해주세요. 강의/회의의 전개 과정과 주요 논점을 파악할 수 있도록 목록화하여 작성해주세요.";
            case 70 -> "모든 주제와 세부 논의 내용을 상세히 요약해주세요. 강의/회의의 전체 흐름, 주요 논점, 결론을 파악할 수 있도록 목록화하여 작성해주세요.";
            case 80 -> "모든 내용을 매우 상세히 요약해주세요. 강의/회의의 세부 흐름, 모든 논점, 의견, 질의응답까지 포함하여 목록화하여 작성해주세요.";
            case 90 -> "거의 모든 내용을 빠짐없이 요약해주세요. 강의/회의의 전체 흐름, 모든 논의 과정, 세부 의견, 결론까지 상세히 목록화하여 작성해주세요.";
            default -> "STT로 전사된 내용으로 단어나 맥락이 맞지 않을 수 있습니다. 주요 주제, 세부 내용, 논의된 의견을 균형있게 요약해주세요. 강의/회의의 흐름과 핵심 내용을 충분히 파악할 수 있도록 목록화하여 작성해주세요.";
        };

        return inputLangInstruction + "\n"
                + outputLangInstruction + "\n\n"
                + summaryInstruction + "\n\n"
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
        JsonNode choices = root.path("choices");
        if (choices.isArray() && choices.size() > 0) {
            return choices.get(0).path("message").path("content").asText();
        }
        throw new RuntimeException("OpenAI API 응답에서 텍스트를 찾을 수 없음: " + responseBody);
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

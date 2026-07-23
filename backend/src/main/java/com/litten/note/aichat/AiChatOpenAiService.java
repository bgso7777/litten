package com.litten.note.aichat;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.litten.common.config.ApiKeyProperties;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.List;

/**
 * 'AI 셀' 전용 OpenAI Chat Completions 호출.
 * 요약(OpenAiSummaryService)과 달리 <b>대화 히스토리 전체(system + user/assistant 배열)</b>를 보내
 * 문맥을 이어간다.
 *
 * 메시지 배열 구성은 {@link AiChatService}가 담당(하이브리드 메모리):
 *   [ system(주제 프롬프트 + 러닝요약) , ...최근 N턴(원문 user/assistant) , 새 user 메시지 ]
 */
@Slf4j
@Service
public class AiChatOpenAiService {

    private static final String OPENAI_API_URL = "https://api.openai.com/v1/chat/completions";

    @Autowired
    private ApiKeyProperties apiKeyProperties;

    @Value("${openai.api.model:gpt-4o-mini}")
    private String model;

    @Value("${openai.api.max-tokens:8192}")
    private int maxTokens;

    private final RestTemplate restTemplate = createRestTemplate();
    private final ObjectMapper objectMapper = new ObjectMapper();

    private static RestTemplate createRestTemplate() {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(30_000);
        factory.setReadTimeout(120_000); // 채팅 응답은 2분 상한
        return new RestTemplate(factory);
    }

    /** 대화용 메시지 1건(role: system|user|assistant). */
    public record Msg(String role, String content) {}

    /**
     * 대화 응답 생성. messages 를 그대로 OpenAI 에 전달하고 assistant 답변 텍스트를 반환.
     * 실패 시 사용자에게 보여줄 안내 문구를 반환(예외를 던지지 않아 대화 흐름을 끊지 않는다).
     */
    public String chat(List<Msg> messages) {
        String apiKey = apiKeyProperties.getOpenaiKey();
        if (apiKey == null || apiKey.isBlank()) {
            log.error("[AiChatOpenAiService] OpenAI API 키 미설정");
            return "(AI 설정 오류) 서버에 OpenAI API 키가 설정되지 않았습니다.";
        }
        try {
            String body = buildRequestBody(messages, Math.min(maxTokens, 1536));
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.setBearerAuth(apiKey);
            HttpEntity<String> entity = new HttpEntity<>(body, headers);

            log.debug("[AiChatOpenAiService] chat 호출 - model: {}, msgCount: {}", model, messages.size());
            ResponseEntity<String> response = restTemplate.exchange(
                    OPENAI_API_URL, HttpMethod.POST, entity, String.class);
            String reply = extractContent(response.getBody());
            log.info("[AiChatOpenAiService] chat 응답 - 길이: {}", reply == null ? 0 : reply.length());
            return (reply == null || reply.isBlank())
                    ? "(응답을 생성하지 못했습니다. 잠시 후 다시 시도해주세요.)"
                    : reply.trim();
        } catch (Exception e) {
            log.error("[AiChatOpenAiService] chat 처리 중 오류", e);
            return "(일시적인 오류로 답변하지 못했습니다. 잠시 후 다시 시도해주세요.)";
        }
    }

    /**
     * 오래된 대화를 러닝요약으로 압축. 기존 요약 + 접을 메시지들을 받아 갱신된 요약을 반환.
     * 실패 시 기존 요약(prevSummary)을 그대로 반환해 데이터 손실을 막는다.
     */
    public String summarizeFold(String prevSummary, List<Msg> toFold) {
        String apiKey = apiKeyProperties.getOpenaiKey();
        if (apiKey == null || apiKey.isBlank()) return prevSummary;
        try {
            StringBuilder conv = new StringBuilder();
            if (prevSummary != null && !prevSummary.isBlank()) {
                conv.append("[기존 요약]\n").append(prevSummary).append("\n\n");
            }
            conv.append("[이어지는 대화]\n");
            for (Msg m : toFold) {
                conv.append("user".equals(m.role()) ? "사용자: " : "AI: ")
                    .append(m.content()).append("\n");
            }
            String sys = "너는 대화 기록을 간결한 메모리로 압축하는 도우미다. "
                    + "아래 [기존 요약]과 [이어지는 대화]를 하나로 합쳐, 이후 대화를 이어가는 데 필요한 "
                    + "핵심 사실·맥락·사용자 선호·미해결 사항만 남긴 간결한 요약을 같은 언어로 작성하라. "
                    + "군더더기 없이 불릿 또는 짧은 문단으로. 새로운 사실을 지어내지 마라.";
            String body = buildRequestBody(List.of(new Msg("system", sys), new Msg("user", conv.toString())), 700);
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.setBearerAuth(apiKey);
            ResponseEntity<String> response = restTemplate.exchange(
                    OPENAI_API_URL, HttpMethod.POST, new HttpEntity<>(body, headers), String.class);
            String summary = extractContent(response.getBody());
            return (summary == null || summary.isBlank()) ? prevSummary : summary.trim();
        } catch (Exception e) {
            log.warn("[AiChatOpenAiService] 러닝요약 압축 실패(기존 요약 유지) - {}", e.getMessage());
            return prevSummary;
        }
    }

    private String buildRequestBody(List<Msg> messages, int maxTok) throws Exception {
        ObjectNode root = objectMapper.createObjectNode();
        root.put("model", model);
        root.put("max_tokens", maxTok);
        ArrayNode arr = root.putArray("messages");
        for (Msg m : messages) {
            ObjectNode o = arr.addObject();
            o.put("role", m.role());
            o.put("content", m.content());
        }
        return objectMapper.writeValueAsString(root);
    }

    private String extractContent(String responseBody) throws Exception {
        JsonNode root = objectMapper.readTree(responseBody);
        JsonNode choices = root.path("choices");
        if (choices.isArray() && choices.size() > 0) {
            return choices.get(0).path("message").path("content").asText();
        }
        throw new RuntimeException("OpenAI 응답에서 텍스트를 찾을 수 없음: " + responseBody);
    }
}

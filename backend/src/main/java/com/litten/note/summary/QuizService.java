package com.litten.note.summary;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.litten.common.config.ApiKeyProperties;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

import java.time.Duration;
import java.util.List;

/**
 * 리마인드 전용 AI 호출 서비스.
 *
 * note_remind_config 에서 읽은 파라미터와 note_prompt_config 의 DB 프롬프트를 조합하여
 * 독립적인 AI 호출로 리마인드만 생성한다.
 *
 * ai.provider=openai → OpenAiSummaryService.generateRemind() 위임
 * ai.provider=claude → Claude API 직접 호출 (DB 프롬프트 없을 때 하드코딩 fallback)
 */
@Log4j2
@Service
@RequiredArgsConstructor
public class RemindService {

    @Value("${ai.provider:openai}")
    private String aiProvider;

    @Value("${claude.api.model:claude-haiku-4-5-20251001}")
    private String claudeModel;

    @Value("${claude.api.max-tokens:1024}")
    private int maxTokens;

    private static final String CLAUDE_API_URL = "https://api.anthropic.com/v1/messages";
    private static final String ANTHROPIC_VERSION = "2023-06-01";

    private final ApiKeyProperties apiKeyProperties;
    private final OpenAiSummaryService openAiSummaryService;

    private final RestTemplate restTemplate = new RestTemplateBuilder()
            .setConnectTimeout(Duration.ofSeconds(10))
            .setReadTimeout(Duration.ofSeconds(120))
            .build();
    private final ObjectMapper objectMapper = new ObjectMapper();

    /**
     * 원본 텍스트에서 리마인드만 생성한다.
     *
     * @param sourceText    원본 자막/텍스트
     * @param fileType      파일 유형 — 로그용
     * @param outputLang    출력 언어 (null이면 "ko")
     * @param systemPrompt  DB에서 조회된 시스템 프롬프트 (null이면 하드코딩 fallback)
     * @param maxCount      최대 세부항목 수 (null=무제한)
     * @param maxGroup      최대 그룹 수 (null=무제한)
     * @param typeFilter    유형 필터, 쉼표 구분 (null=전체)
     */
    public RemindResponseVo generate(String sourceText, String fileType,
                                     String outputLang, String systemPrompt,
                                     Integer maxCount, Integer maxGroup, String typeFilter) {
        log.debug("[RemindService] generate() - provider: {}, fileType: {}, maxCount: {}, maxGroup: {}, dbPrompt: {}",
                aiProvider, fileType, maxCount, maxGroup, systemPrompt != null);

        if (sourceText == null || sourceText.isBlank()) {
            log.warn("[RemindService] 원본 텍스트 없음");
            return RemindResponseVo.fail("리마인드를 생성할 원본 텍스트가 없습니다.");
        }

        String lang = (outputLang == null || outputLang.isBlank()) ? "ko" : outputLang;

        if ("openai".equalsIgnoreCase(aiProvider)) {
            log.info("[RemindService] OpenAI로 리마인드 생성 위임");
            return generateViaOpenAi(sourceText, lang, systemPrompt, maxCount, maxGroup, typeFilter);
        }

        log.info("[RemindService] Claude로 리마인드 생성");
        return generateViaClaude(sourceText, lang, systemPrompt, maxCount, maxGroup, typeFilter);
    }

    // ── OpenAI 경로 ──────────────────────────────────────────────────────────

    private RemindResponseVo generateViaOpenAi(String sourceText, String lang,
                                               String systemPrompt, Integer maxCount,
                                               Integer maxGroup, String typeFilter) {
        if (systemPrompt == null || systemPrompt.isBlank()) {
            log.warn("[RemindService] OpenAI DB 프롬프트 없음 - Claude fallback 사용");
            return generateViaClaude(sourceText, lang, null, maxCount, maxGroup, typeFilter);
        }

        String userContent = buildUserContent(sourceText, lang, maxCount, maxGroup, typeFilter);
        log.info("[RemindService] OpenAI remind 호출 - systemPrompt 길이: {}, userContent 길이: {}",
                systemPrompt.length(), userContent.length());

        String rawResponse = openAiSummaryService.generateRemind(systemPrompt, userContent);
        if (rawResponse == null) {
            return RemindResponseVo.fail("리마인드 생성에 실패했습니다.");
        }
        return parseRemindResponse(rawResponse);
    }

    // ── Claude 경로 ──────────────────────────────────────────────────────────

    private RemindResponseVo generateViaClaude(String sourceText, String lang,
                                               String systemPrompt, Integer maxCount,
                                               Integer maxGroup, String typeFilter) {
        String apiKey = apiKeyProperties.getClaudeKey();
        if (apiKey == null || apiKey.isBlank()) {
            log.error("[RemindService] Claude API 키 미설정");
            return RemindResponseVo.fail("Claude API 키가 설정되지 않았습니다.");
        }

        try {
            // DB 프롬프트가 있으면 그것을 user 메시지의 prefix로 사용, 없으면 하드코딩 프롬프트
            String userContent = systemPrompt != null && !systemPrompt.isBlank()
                    ? systemPrompt + "\n\n" + buildUserContent(sourceText, lang, maxCount, maxGroup, typeFilter)
                    : buildFallbackPrompt(sourceText, lang, maxCount, maxGroup, typeFilter);

            int computedMaxTokens = computeMaxTokens(maxCount);
            log.info("[RemindService] Claude remind 호출 - content 길이: {}, max_tokens: {}",
                    userContent.length(), computedMaxTokens);

            ObjectNode root = objectMapper.createObjectNode();
            root.put("model", claudeModel);
            root.put("max_tokens", computedMaxTokens);
            ArrayNode messages = root.putArray("messages");
            ObjectNode msg = messages.addObject();
            msg.put("role", "user");
            msg.put("content", userContent);

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.set("x-api-key", apiKey);
            headers.set("anthropic-version", ANTHROPIC_VERSION);

            HttpEntity<String> entity = new HttpEntity<>(objectMapper.writeValueAsString(root), headers);
            ResponseEntity<String> response = restTemplate.exchange(CLAUDE_API_URL, HttpMethod.POST, entity, String.class);
            log.info("[RemindService] Claude API 응답 - status: {}", response.getStatusCode());

            JsonNode responseRoot = objectMapper.readTree(response.getBody());
            JsonNode content = responseRoot.path("content");
            if (!content.isArray() || content.size() == 0) {
                throw new RuntimeException("Claude 응답에서 텍스트를 찾을 수 없음");
            }
            return parseRemindResponse(content.get(0).path("text").asText());

        } catch (HttpClientErrorException e) {
            log.error("[RemindService] Claude API 오류 - status: {}, body: {}",
                    e.getStatusCode(), e.getResponseBodyAsString());
            return RemindResponseVo.fail("Claude API 오류: " + e.getStatusCode());
        } catch (Exception e) {
            log.error("[RemindService] 리마인드 생성 중 오류", e);
            return RemindResponseVo.fail("리마인드 생성 중 오류가 발생했습니다.");
        }
    }

    // ── 프롬프트 빌더 ────────────────────────────────────────────────────────

    /** DB 프롬프트가 있을 때 user 메시지 (콘텐츠 + 언어/제약만 포함) */
    private String buildUserContent(String text, String lang,
                                    Integer maxCount, Integer maxGroup, String typeFilter) {
        StringBuilder sb = new StringBuilder();
        sb.append("출력 언어: ").append(lang).append("\n");
        if (maxCount != null)  sb.append("최대 세부항목 수: ").append(maxCount).append("개\n");
        if (maxGroup != null)  sb.append("최대 그룹 수: ").append(maxGroup).append("개\n");
        if (typeFilter != null && !typeFilter.isBlank()) {
            sb.append("추출 유형 제한: ").append(typeFilter).append("\n");
        }
        sb.append("\n콘텐츠:\n").append(text);
        return sb.toString();
    }

    /** DB 프롬프트 없을 때 하드코딩 fallback 프롬프트 */
    private String buildFallbackPrompt(String text, String lang,
                                       Integer maxCount, Integer maxGroup, String typeFilter) {
        StringBuilder sb = new StringBuilder();
        sb.append("다음 콘텐츠에서 리마인드 항목을 추출해줘.\n\n");
        sb.append("출력 언어: ").append(lang).append("\n");
        if (maxCount != null) sb.append("최대 세부항목 수: ").append(maxCount).append("개\n");
        if (maxGroup != null) sb.append("최대 그룹 수: ").append(maxGroup).append("개\n");
        if (typeFilter != null && !typeFilter.isBlank()) {
            sb.append("추출 유형 (이 유형만): ").append(typeFilter).append("\n");
        }
        sb.append("콘텐츠:\n").append(text).append("\n\n");

        sb.append("────────────────────────────────────────\n");
        sb.append("[리마인드 3단 계층 구조]\n");
        sb.append("────────────────────────────────────────\n");
        sb.append("[1단: 항목 (Group)] - 주제·영역 단위 그룹, 짧은 명사구");
        if (maxGroup != null) sb.append(", 최대 ").append(maxGroup).append("개");
        sb.append("\n");
        sb.append("[2단: 세부항목 (Item)] - [유형] 내용 / 담당자 / 기한");
        if (maxCount != null) sb.append(" (전체 최대 ").append(maxCount).append("개)");
        sb.append("\n");
        if (typeFilter != null && !typeFilter.isBlank()) {
            sb.append("   유형: ").append(typeFilter).append("\n");
        } else {
            sb.append("   유형: 일정|액션|핵심개념|적용포인트|학습할것|외부대기|리스크|기타\n");
        }
        sb.append("[3단: 내용 (Detail)] - 부가 설명 (1~3줄, 단순 일정은 생략)\n\n");

        sb.append("[추출 기준]\n");
        sb.append("명시적 일정/기한, 약속, 핵심 개념/공식, 실행 포인트, 학습 항목, 리스크\n");
        sb.append("중요도 순 정렬: 기한 임박 → 외부 의존 → 리스크 → 핵심개념 → 일반 액션\n\n");

        sb.append("[출력 형식]\n");
        sb.append("─── 📌 리마인드 ───\n");
        sb.append("📂 [그룹명]\n");
        sb.append("   ▸ [유형] 세부항목 / 담당자 / 기한\n");
        sb.append("     └ 부가 설명\n");
        sb.append("리마인드 총 N개\n");

        return sb.toString();
    }

    // ── 파싱 ────────────────────────────────────────────────────────────────

    private RemindResponseVo parseRemindResponse(String rawResponse) {
        log.debug("[RemindService] AI 응답 파싱 - 길이: {}", rawResponse.length());
        RemindParser.ParseResult result = RemindParser.parse(rawResponse);
        List<RemindGroup> groups = result.getGroups();
        int total = groups.stream().mapToInt(g -> g.getItems().size()).sum();
        log.info("[RemindService] 파싱 완료 - 그룹: {}, 항목: {}", groups.size(), total);
        return RemindResponseVo.ok(groups);
    }

    // ── 유틸 ────────────────────────────────────────────────────────────────

    private int computeMaxTokens(Integer maxCount) {
        int base = 600;
        int perItem = 80;
        int itemBudget = maxCount != null ? maxCount * perItem : 800;
        return Math.min(maxTokens, Math.max(512, base + itemBudget));
    }
}

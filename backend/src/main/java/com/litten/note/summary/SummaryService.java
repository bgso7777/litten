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

@Log4j2
@Service
@RequiredArgsConstructor
public class SummaryService {

    // ai.provider: openai(기본) 또는 claude
    @Value("${ai.provider:openai}")
    private String aiProvider;

    private final OpenAiSummaryService openAiSummaryService;
    private final ApiKeyProperties apiKeyProperties;

    // ── Claude 전용 필드 (ai.provider=claude 일 때 사용) ──────────────
    private static final String CLAUDE_API_URL = "https://api.anthropic.com/v1/messages";
    private static final String ANTHROPIC_VERSION = "2023-06-01";

    @Value("${claude.api.model:claude-haiku-4-5-20251001}")
    private String model;

    @Value("${claude.api.max-tokens:1024}")
    private int maxTokens;

    private final RestTemplate restTemplate = new RestTemplateBuilder()
            .setConnectTimeout(Duration.ofSeconds(10))
            .setReadTimeout(Duration.ofSeconds(120))
            .build();
    private final ObjectMapper objectMapper = new ObjectMapper();

    public SummaryResponseVo summarize(SummaryRequestVo request) {
        log.debug("[SummaryService] summarize() 진입 - provider: {}, fileId: {}", aiProvider, request.getFileId());

        if ("openai".equalsIgnoreCase(aiProvider)) {
            log.info("[SummaryService] OpenAI로 요약 위임");
            return openAiSummaryService.summarize(request);
        }

        // provider=claude (기본 유지)
        log.info("[SummaryService] Claude로 요약 처리");

        String apiKey = apiKeyProperties.getClaudeKey();
        if (apiKey == null || apiKey.isBlank()) {
            log.error("[SummaryService] Claude API 키가 설정되지 않음");
            return SummaryResponseVo.fail("Claude API 키가 설정되지 않았습니다. 서버 환경변수 CLAUDE_API_KEY를 확인하세요.");
        }

        String plainText = stripHtml(request.getText());
        if (plainText.isBlank()) {
            log.info("[SummaryService] 요약할 텍스트 없음");
            return SummaryResponseVo.fail("요약할 텍스트가 없습니다.");
        }

        int level = normalizeLevel(request.getSummaryLevel());
        log.info("[SummaryService] 요약 요청 - 텍스트 길이: {}, 입력언어: {}, 요약언어: {}, 수준: {}",
                plainText.length(), request.getTextLanguage(), request.getSummaryLanguage(), level);

        try {
            String prompt = buildPrompt(plainText, request.getTextLanguage(), request.getSummaryLanguage(), level);
            int computedMaxTokens = computeMaxTokens(plainText, level);
            log.info("[SummaryService] max_tokens 계산 - 텍스트길이: {}, 수준: {}, tokens: {}",
                    plainText.length(), level, computedMaxTokens);
            String requestBody = buildRequestBody(prompt, computedMaxTokens);

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

    private int normalizeLevel(int level) {
        if (level < 1 || level > 5) return 3; // 기본값: 일반 요약
        return level;
    }

    private String buildPrompt(String text, String textLanguage, String summaryLanguage, int level) {
        String sourceLang = (textLanguage == null || textLanguage.isBlank()) ? "ko" : textLanguage;
        String outputLang = (summaryLanguage == null || summaryLanguage.isBlank()) ? sourceLang : summaryLanguage;

        StringBuilder sb = new StringBuilder();

        sb.append("다음 콘텐츠를 요약해줘.\n\n");
        sb.append("요약 수준: ").append(level).append("\n");
        sb.append("대상 언어: ").append(sourceLang).append("\n");
        sb.append("요약 언어: ").append(outputLang).append("\n");
        sb.append("콘텐츠 내용: ").append(text).append("\n\n");

        sb.append("────────────────────────────────────────\n");
        sb.append("[콘텐츠 유형 자동 판별]\n");
        sb.append("────────────────────────────────────────\n");
        sb.append("※ 콘텐츠 유형은 사용자가 지정하지 않는다.\n");
        sb.append("   원문을 분석해 가장 가까운 유형을 스스로 판별한 뒤,\n");
        sb.append("   해당 유형에 맞는 관점·구조·용어로 요약을 생성한다.\n\n");
        sb.append("1. 판별 단서\n");
        sb.append("   - 다중 화자 + 의사결정·합의 흐름 → 회의\n");
        sb.append("   - 단일 화자 + 학습 목표·개념 설명·예시·과제 → 강의 / 동영상강의\n");
        sb.append("   - 단일 화자 + 주장·근거·결론 + 청중 대상 → 발표\n");
        sb.append("   - 진행자 + 게스트의 Q&A 구조 → 인터뷰\n");
        sb.append("   - 2인 이상 자유 대담 + 화제 전환 → 팟캐스트\n");
        sb.append("   - 영상 화자의 권유·추천·정보 전달 톤 → 유튜브\n");
        sb.append("   - 위에 해당하지 않거나 혼합형 → 기타\n\n");
        sb.append("2. 판별이 애매한 경우\n");
        sb.append("   - 가장 가까운 유형 1개를 선택하되, 판별 결과를 출력 첫 줄에 표기한다.\n");
        sb.append("   - 형식: 콘텐츠 유형: [판별값] (자동 감지)\n\n");
        sb.append("3. 판별 결과는 다음에 영향을 준다.\n");
        sb.append("   - 요약 본문의 관점과 강조점\n");
        sb.append("   - 출력 형식의 섹션 명칭\n\n");

        sb.append("────────────────────────────────────────\n");
        sb.append("[콘텐츠 유형별 처리 관점]\n");
        sb.append("────────────────────────────────────────\n");
        sb.append("1. 회의 — 누가, 무엇을, 언제까지 / 결정·담당자·후속 액션\n");
        sb.append("2. 강의 / 동영상강의 — 무엇을 배우고 적용하는가 / 핵심 개념·정의·예시\n");
        sb.append("3. 발표 — 발표자의 핵심 메시지 / 주장·근거·데이터·결론\n");
        sb.append("4. 유튜브 — 시청자가 알아야 할 정보 / 주장·실천 포인트\n");
        sb.append("5. 인터뷰 — Q&A에서의 인사이트 / 인터뷰이의 발언·관점\n");
        sb.append("6. 팟캐스트 — 어떤 결론에 이르렀는가 / 핵심 논점·일화\n");
        sb.append("7. 기타 — 콘텐츠 성격 파악 후 가장 가까운 유형 적용\n\n");

        sb.append("────────────────────────────────────────\n");
        sb.append("[언어 처리 규칙]\n");
        sb.append("────────────────────────────────────────\n");
        sb.append("1. 대상 언어는 원문 기준이며, STT 보정·문맥 해석은 대상 언어 기준으로 수행한다.\n");
        sb.append("2. 모든 출력은 요약 언어로 작성한다.\n");
        sb.append("3. 대상 언어 ≠ 요약 언어인 경우\n");
        sb.append("   - 자연스러운 의역을 적용한다.\n");
        sb.append("   - 다음 항목은 원문 유지 또는 병기한다.\n");
        sb.append("     · 고유명사, 기능명, 시스템명, API명, 약어, 도서·강의 제목\n");
        sb.append("   - 병기 형식: 요약어(원문) — 예: \"결제 모듈(Payment Module)\"\n");
        sb.append("4. 요약 언어 미지정 시 대상 언어와 동일하게 처리한다.\n");
        sb.append("5. 코드, SQL, 명령어, 로그, 수식은 원문 그대로 유지한다.\n");
        sb.append("6. 날짜·시간은 요약 언어 관례를 따른다.\n");
        sb.append("   - 한국어: 2025년 12월 5일 (금)\n");
        sb.append("   - 영어: Dec 5, 2025 (Fri)\n");
        sb.append("   - 일본어: 2025年12月5日(金)\n\n");

        sb.append("────────────────────────────────────────\n");
        sb.append("[요약 수준]\n");
        sb.append("────────────────────────────────────────\n");
        sb.append("1. 한줄 요약    (VERY_SHORT, 약 10%) — 핵심 주제·결론만, 빠른 확인용\n");
        sb.append("2. 간단 요약    (SHORT, 약 25%) — 주요 포인트·구조 유지, 공유용\n");
        sb.append("3. 일반 요약    (MEDIUM, 약 40~50%) — 흐름과 의도 포함, 일반 공유 수준\n");
        sb.append("4. 상세 요약    (LONG, 약 70%) — 흐름 대부분 유지, 상세 검토용\n");
        sb.append("5. 전체 정제본  (FULL, 약 90%) — STT 오류만 제거, 복기 및 문서화용\n\n");

        sb.append("────────────────────────────────────────\n");
        sb.append("[STT 보정 규칙]\n");
        sb.append("────────────────────────────────────────\n");
        sb.append("1. STT 오인식으로 보이는 단어, 조사, 띄어쓰기는 대상 언어 문맥상 자연스럽게 보정한다.\n");
        sb.append("2. 단순 단어 오인식보다 전체 흐름과 의도를 우선해 해석한다.\n");
        sb.append("3. 반복 발화, 추임새, 끊긴 문장, 의미 없는 표현은 제거한다.\n");
        sb.append("4. 잘못 인식된 전문 용어/제품명/기능명/인명은 문맥상 자연스럽게 보정한다.\n");
        sb.append("5. 고유명사, 기능명, 개념어는 가능한 한 원문 그대로 유지한다.\n\n");

        sb.append("────────────────────────────────────────\n");
        sb.append("[작성 규칙]\n");
        sb.append("────────────────────────────────────────\n");
        sb.append("1. 기계적 압축이 아닌, 사람이 이해하기 쉬운 형태로 재구성한다.\n");
        sb.append("2. 추상적 표현 대신 실제 내용·사례·동작 흐름 중심으로 설명한다.\n");
        sb.append("3. 중요한 의도, 맥락, 배경은 최대한 유지한다.\n");
        sb.append("4. 원문에 없는 사실, 수치, 발언은 추가·추측하지 않는다.\n");
        sb.append("   - 의미 파악 불가 구간은 [불명확]으로 표시한다.\n");
        sb.append("5. 화자/발표자 정보는 원문에 있을 때만 유지한다.\n");
        sb.append("6. 개인정보(연락처, 주민번호 등)는 마스킹 처리한다.\n\n");

        sb.append("────────────────────────────────────────\n");
        sb.append("[출력 형식]\n");
        sb.append("────────────────────────────────────────\n");
        sb.append("※ 출력 첫 줄에 자동 판별된 콘텐츠 유형 표기.\n");
        sb.append("※ 모든 섹션 제목은 요약 언어로.\n\n");

        sb.append("■ 수준 1 (한줄 요약)\n");
        sb.append("   콘텐츠 유형: [판별값] (자동 감지)\n");
        sb.append("   - 한줄 결론\n\n");

        sb.append("■ 수준 2 (간단 요약)\n");
        sb.append("   콘텐츠 유형: [판별값] (자동 감지)\n");
        sb.append("   - 전체 목적 / 주제\n");
        sb.append("   - 핵심 내용\n");
        sb.append("   - 결론 / 핵심 메시지\n");
        sb.append("   - 한줄 결론\n\n");

        sb.append("■ 수준 3~5 (일반 / 상세 / 전체 정제본)\n");
        sb.append("   콘텐츠 유형: [판별값] (자동 감지)\n");
        sb.append("   - 전체 목적 / 주제\n");
        sb.append("   - 주요 내용\n");
        sb.append("   - 핵심 개념·구조·주장\n");
        sb.append("   - 쟁점 / 이슈 / Q&A\n");
        sb.append("   - 결정 사항 / 결론 / 핵심 메시지\n");
        sb.append("   - 후속 액션 / 적용 방법 / 다음 학습\n");
        sb.append("   - 한줄 결론\n");

        return sb.toString();
    }

    private int computeMaxTokens(String text, int level) {
        int estimatedInputTokens = text.length() * 2 / 3;
        double ratio = switch (level) {
            case 1 -> 0.15;
            case 2 -> 0.30;
            case 3 -> 0.55;
            case 4 -> 0.80;
            case 5 -> 1.00;
            default -> 0.55;
        };
        int needed = (int)(estimatedInputTokens * ratio) + 800;
        return Math.min(maxTokens, Math.max(512, needed));
    }

    private String buildRequestBody(String prompt, int computedMaxTokens) throws Exception {
        ObjectNode root = objectMapper.createObjectNode();
        root.put("model", model);
        root.put("max_tokens", computedMaxTokens);

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

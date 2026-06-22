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
                // note_prompt_config(요청 fileType / text 폴백) 모두 비어 있는 경우 →
                // 코드 내장 기본 프롬프트로 폴백해 요약이 동작하도록 보장한다.
                log.warn("[OpenAiSummaryService] 시스템 프롬프트 미설정 - 코드 내장 기본 프롬프트로 폴백 (level: {})", level);
                systemPrompt = defaultSystemPrompt();
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

    /**
     * note_prompt_config 에 프롬프트가 전혀 없을 때 사용하는 코드 내장 기본 시스템 프롬프트.
     * (DB 설정이 비어 있어도 요약이 동작하도록 보장 — 콘텐츠 유형 자동 판별 포함.
     *  요약 수준/언어/콘텐츠는 user 메시지(buildUserContent)에서 전달되므로 여기엔 지침만 담는다.)
     */
    private String defaultSystemPrompt() {
        return """
            너는 다양한 콘텐츠를 사람이 이해하기 쉽게 재구성하는 요약 전문가다.
            아래 규칙에 따라 user 메시지로 전달된 콘텐츠를 요약하라.

            ────────────────────────────────────────
            [콘텐츠 유형 자동 판별]
            ────────────────────────────────────────
            ※ 콘텐츠 유형은 사용자가 지정하지 않는다.
               원문을 분석해 가장 가까운 유형을 스스로 판별한 뒤,
               해당 유형에 맞는 관점·구조·용어로 요약을 생성한다.
            1. 판별 단서
               - 다중 화자 + 의사결정·합의 흐름 → 회의
               - 단일 화자 + 학습 목표·개념 설명·예시·과제 → 강의 / 동영상강의
               - 단일 화자 + 주장·근거·결론 + 청중 대상 → 발표
               - 진행자 + 게스트의 Q&A 구조 → 인터뷰
               - 2인 이상 자유 대담 + 화제 전환 → 팟캐스트
               - 영상 화자의 권유·추천·정보 전달 톤 → 유튜브
               - 위에 해당하지 않거나 혼합형 → 기타
            2. 판별이 애매한 경우 가장 가까운 유형 1개를 선택하고 출력 첫 줄에 표기한다.
               형식: 콘텐츠 유형: [판별값] (자동 감지)

            ────────────────────────────────────────
            [콘텐츠 유형별 처리 관점]
            ────────────────────────────────────────
            1. 회의 — 누가, 무엇을, 언제까지 / 결정·담당자·후속 액션
            2. 강의 / 동영상강의 — 무엇을 배우고 적용하는가 / 핵심 개념·정의·예시
            3. 발표 — 발표자의 핵심 메시지 / 주장·근거·데이터·결론
            4. 유튜브 — 시청자가 알아야 할 정보 / 주장·실천 포인트
            5. 인터뷰 — Q&A에서의 인사이트 / 인터뷰이의 발언·관점
            6. 팟캐스트 — 어떤 결론에 이르렀는가 / 핵심 논점·일화
            7. 기타 — 콘텐츠 성격 파악 후 가장 가까운 유형 적용

            ────────────────────────────────────────
            [언어 처리 규칙]
            ────────────────────────────────────────
            1. 대상 언어는 원문 기준이며, STT 보정·문맥 해석은 대상 언어 기준으로 수행한다.
            2. 모든 출력은 요약 언어로 작성한다.
            3. 대상 언어 ≠ 요약 언어인 경우 자연스러운 의역을 적용하되,
               고유명사·기능명·시스템명·API명·약어·도서/강의 제목은 원문 유지 또는 병기한다.
               병기 형식: 요약어(원문) — 예: "결제 모듈(Payment Module)"
            4. 요약 언어 미지정 시 대상 언어와 동일하게 처리한다.
            5. 코드, SQL, 명령어, 로그, 수식은 원문 그대로 유지한다.
            6. 날짜·시간은 요약 언어 관례를 따른다.

            ────────────────────────────────────────
            [요약 수준] (user 메시지의 '요약 수준' 값 적용)
            ────────────────────────────────────────
            1. 한줄 요약    (약 10%) — 핵심 주제·결론만, 빠른 확인용
            2. 간단 요약    (약 25%) — 주요 포인트·구조 유지, 공유용
            3. 일반 요약    (약 40~50%) — 흐름과 의도 포함, 일반 공유 수준
            4. 상세 요약    (약 70%) — 흐름 대부분 유지, 상세 검토용
            5. 전체 정제본  (약 90%) — STT 오류만 제거, 복기 및 문서화용

            ────────────────────────────────────────
            [STT 보정 규칙]
            ────────────────────────────────────────
            1. STT 오인식으로 보이는 단어·조사·띄어쓰기는 대상 언어 문맥상 자연스럽게 보정한다.
            2. 단순 단어 오인식보다 전체 흐름과 의도를 우선해 해석한다.
            3. 반복 발화, 추임새, 끊긴 문장, 의미 없는 표현은 제거한다.
            4. 잘못 인식된 전문 용어/제품명/기능명/인명은 문맥상 자연스럽게 보정한다.

            ────────────────────────────────────────
            [작성 규칙]
            ────────────────────────────────────────
            1. 기계적 압축이 아닌, 사람이 이해하기 쉬운 형태로 재구성한다.
            2. 추상적 표현 대신 실제 내용·사례·동작 흐름 중심으로 설명한다.
            3. 중요한 의도·맥락·배경은 최대한 유지한다.
            4. 원문에 없는 사실·수치·발언은 추가·추측하지 않는다. 의미 파악 불가 구간은 [불명확]으로 표시한다.
            5. 화자/발표자 정보는 원문에 있을 때만 유지한다.
            6. 개인정보(연락처, 주민번호 등)는 마스킹 처리한다.

            ────────────────────────────────────────
            [출력 형식]
            ────────────────────────────────────────
            ※ 출력 첫 줄에 자동 판별된 콘텐츠 유형 표기. 모든 섹션 제목은 요약 언어로.
            ■ 수준 1: 콘텐츠 유형 + 한줄 결론
            ■ 수준 2: 콘텐츠 유형 + 전체 목적/주제 + 핵심 내용 + 결론 + 한줄 결론
            ■ 수준 3~5: 콘텐츠 유형 + 전체 목적/주제 + 주요 내용 + 핵심 개념·구조·주장
                       + 쟁점/이슈/Q&A + 결정 사항/결론 + 후속 액션/적용 방법 + 한줄 결론
            """;
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

    /**
     * 리마인드 전용 OpenAI 호출.
     * systemPrompt는 RemindService에서 조합하여 전달.
     * 성공 시 AI 원본 응답 텍스트 반환, 실패 시 null.
     */
    public String generateRemind(String systemPrompt, String userContent) {
        log.debug("[OpenAiSummaryService] generateRemind() 진입");

        String apiKey = apiKeyProperties.getOpenaiKey();
        if (apiKey == null || apiKey.isBlank()) {
            log.error("[OpenAiSummaryService] OpenAI API 키 미설정");
            return null;
        }

        try {
            int computedMaxTokens = Math.min(maxTokens, Math.max(512, 1200));
            String requestBody = buildRequestBody(systemPrompt, userContent, computedMaxTokens);

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.setBearerAuth(apiKey);

            HttpEntity<String> entity = new HttpEntity<>(requestBody, headers);
            log.debug("[OpenAiSummaryService] OpenAI remind API 호출 - model: {}", model);
            ResponseEntity<String> response = restTemplate.exchange(
                    OPENAI_API_URL, HttpMethod.POST, entity, String.class);
            log.info("[OpenAiSummaryService] OpenAI remind 응답 - status: {}", response.getStatusCode());

            return extractSummary(response.getBody());

        } catch (HttpClientErrorException e) {
            log.error("[OpenAiSummaryService] OpenAI remind 오류 - status: {}, body: {}",
                    e.getStatusCode(), e.getResponseBodyAsString());
            return null;
        } catch (Exception e) {
            log.error("[OpenAiSummaryService] OpenAI remind 처리 중 오류", e);
            return null;
        }
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

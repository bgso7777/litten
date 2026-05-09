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

        int level = normalizeLevel(request.getSummaryLevel());
        log.info("[OpenAiSummaryService] 요약 요청 - 텍스트 길이: {}, 입력언어: {}, 요약언어: {}, 수준: {}",
                plainText.length(), request.getTextLanguage(), request.getSummaryLanguage(), level);

        try {
            String systemPrompt = buildSystemPrompt(request.getTextLanguage(), request.getSummaryLanguage(), level);
            String userContent  = buildUserContent(plainText, request.getTextLanguage(), request.getSummaryLanguage(), level);
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
            }
            return SummaryResponseVo.fail("OpenAI API 오류: " + e.getStatusCode());
        } catch (Exception e) {
            log.error("[OpenAiSummaryService] 요약 처리 중 오류 발생", e);
            return SummaryResponseVo.fail("요약 처리 중 오류가 발생했습니다.");
        }
    }

    private int normalizeLevel(int level) {
        if (level < 1 || level > 5) return 3; // 기본값: 일반 요약
        return level;
    }

    // system 메시지: 지침 전체 (콘텐츠 없음)
    private String buildSystemPrompt(String textLanguage, String summaryLanguage, int level) {
        String sourceLang = (textLanguage == null || textLanguage.isBlank()) ? "ko" : textLanguage;
        String outputLang = (summaryLanguage == null || summaryLanguage.isBlank()) ? sourceLang : summaryLanguage;

        String levelDetail = switch (level) {
            case 1 -> "1 (한줄 요약, VERY_SHORT) — 핵심 주제·결론 1~2문장. 최소 분량 유지.";
            case 2 -> "2 (간단 요약, SHORT) — 전체 목적·핵심 포인트·결론을 각 2~4문장으로 작성.";
            case 3 -> "3 (일반 요약, MEDIUM) — 각 섹션을 3~6문장의 실질적 내용으로 작성. 원본의 40~50% 분량 목표.";
            case 4 -> "4 (상세 요약, LONG) — 각 섹션을 5~10문장으로 상세히 작성. 원본의 70% 분량 목표.";
            case 5 -> "5 (전체 정제본, FULL) — STT 오류·추임새만 제거하고 거의 전체 내용 유지. 원본의 90% 분량 목표.";
            default -> "3 (일반 요약, MEDIUM) — 각 섹션을 3~6문장으로 작성. 원본의 40~50% 분량 목표.";
        };

        StringBuilder sb = new StringBuilder();
        sb.append("당신은 콘텐츠 요약 전문가입니다. 아래 규칙에 따라 사용자가 제공하는 콘텐츠를 요약하세요.\n\n");

        sb.append("적용 요약 수준: ").append(levelDetail).append("\n");
        sb.append("대상 언어: ").append(sourceLang).append("\n");
        sb.append("요약 언어: ").append(outputLang).append("\n\n");

        sb.append("⚠️ 분량 준수: 지정된 요약 수준에 맞는 분량을 반드시 채워야 합니다.\n");
        sb.append("   단순 키워드 나열이나 한두 줄 요약은 허용되지 않습니다.\n");
        sb.append("   각 섹션에 실제 내용을 구체적으로 서술하세요.\n\n");

        sb.append("────────────────────────────────────────\n");
        sb.append("[콘텐츠 유형 자동 판별]\n");
        sb.append("────────────────────────────────────────\n");
        sb.append("원문을 분석해 가장 가까운 유형을 판별 후 해당 관점으로 요약을 생성한다.\n");
        sb.append("- 다중 화자 + 의사결정·합의 흐름 → 회의\n");
        sb.append("- 단일 화자 + 학습 목표·개념 설명·예시·과제 → 강의 / 동영상강의\n");
        sb.append("- 단일 화자 + 주장·근거·결론 + 청중 대상 → 발표\n");
        sb.append("- 진행자 + 게스트의 Q&A 구조 → 인터뷰\n");
        sb.append("- 2인 이상 자유 대담 + 화제 전환 → 팟캐스트\n");
        sb.append("- 영상 화자의 권유·추천·정보 전달 톤 → 유튜브\n");
        sb.append("- 위에 해당하지 않거나 혼합형 → 기타\n\n");

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
        sb.append("3. 대상 언어 ≠ 요약 언어인 경우 자연스러운 의역을 적용하되,\n");
        sb.append("   고유명사·기능명·시스템명·API명·약어는 원문 유지 또는 병기한다.\n");
        sb.append("   병기 형식: 요약어(원문) — 예: \"결제 모듈(Payment Module)\"\n");
        sb.append("4. 코드, SQL, 명령어, 로그, 수식은 원문 그대로 유지한다.\n\n");

        sb.append("────────────────────────────────────────\n");
        sb.append("[STT 보정 규칙]\n");
        sb.append("────────────────────────────────────────\n");
        sb.append("1. STT 오인식으로 보이는 단어, 조사, 띄어쓰기는 문맥상 자연스럽게 보정한다.\n");
        sb.append("2. 전체 흐름과 의도를 우선해 해석한다.\n");
        sb.append("3. 반복 발화, 추임새, 끊긴 문장, 의미 없는 표현은 제거한다.\n");
        sb.append("4. 잘못 인식된 전문 용어/제품명/기능명/인명은 문맥상 보정한다.\n");
        sb.append("5. 고유명사, 기능명, 개념어는 가능한 한 원문 그대로 유지한다.\n\n");

        sb.append("────────────────────────────────────────\n");
        sb.append("[작성 규칙]\n");
        sb.append("────────────────────────────────────────\n");
        sb.append("1. 기계적 압축이 아닌, 사람이 이해하기 쉬운 형태로 재구성한다.\n");
        sb.append("2. 추상적 표현 대신 실제 내용·사례·동작 흐름 중심으로 설명한다.\n");
        sb.append("3. 중요한 의도, 맥락, 배경은 최대한 유지한다.\n");
        sb.append("4. 원문에 없는 사실, 수치, 발언은 추가·추측하지 않는다. 의미 파악 불가 구간은 [불명확]으로 표시한다.\n");
        sb.append("5. 화자/발표자 정보는 원문에 있을 때만 유지한다.\n");
        sb.append("6. 개인정보(연락처, 주민번호 등)는 마스킹 처리한다.\n\n");

        sb.append("────────────────────────────────────────\n");
        sb.append("[리마인드 3단 계층 구조]\n");
        sb.append("────────────────────────────────────────\n");
        sb.append("1단 항목(Group): 주제·영역 단위 카테고리 (2~5개 권장)\n");
        sb.append("2단 세부항목(Item): [유형] 내용 / 담당자 / 기한\n");
        sb.append("   유형: 일정|액션|핵심개념|적용포인트|학습할것|외부대기|리스크|기타\n");
        sb.append("3단 내용(Detail): 부가 설명·맥락·근거 (1~3줄, 단순 일정은 생략 가능)\n\n");
        sb.append("출력 포맷:\n");
        sb.append("📂 [항목명]\n");
        sb.append("   ▸ [유형] 세부항목 / 담당자 / 기한\n");
        sb.append("     └ 부가 설명\n\n");

        sb.append("────────────────────────────────────────\n");
        sb.append("[리마인드 추출 기준]\n");
        sb.append("────────────────────────────────────────\n");
        sb.append("- 명시적 일정/기한, 약속·확약, 핵심 개념·공식·정의\n");
        sb.append("- 실행·적용 권장 포인트, 추가 학습·확인 필요 항목\n");
        sb.append("- 외부 의존 항목, 리스크·주의사항, 강조 발언\n");
        sb.append("- 리마인드성 내용이 없으면 \"없음\" 표시\n");
        sb.append("- 마지막에 \"리마인드 총 N개\" 표기\n\n");

        sb.append("────────────────────────────────────────\n");
        sb.append("[출력 형식]\n");
        sb.append("────────────────────────────────────────\n");
        sb.append("첫 줄: 콘텐츠 유형: [판별값] (자동 감지)\n\n");

        if (level == 1) {
            sb.append("## 한줄 결론\n");
            sb.append("(핵심 주제와 결론을 1~2문장으로)\n\n");
        } else if (level == 2) {
            sb.append("## 전체 목적 / 주제\n");
            sb.append("(2~4문장)\n\n");
            sb.append("## 핵심 내용\n");
            sb.append("(주요 포인트를 2~4문장씩)\n\n");
            sb.append("## 결론 / 핵심 메시지\n");
            sb.append("(2~3문장)\n\n");
            sb.append("## 한줄 결론\n");
            sb.append("(1문장)\n\n");
        } else {
            sb.append("## 전체 목적 / 주제\n");
            sb.append("(3~6문장으로 구체적으로 서술)\n\n");
            sb.append("## 주요 내용\n");
            sb.append("(다뤄진 주제별로 각 3~6문장씩 상세히 서술)\n\n");
            sb.append("## 핵심 개념·구조·주장\n");
            sb.append("(구체적 내용 3~6문장)\n\n");
            sb.append("## 쟁점 / 이슈 / Q&A\n");
            sb.append("(제기된 문제와 논의 내용 3~6문장)\n\n");
            sb.append("## 결정 사항 / 결론 / 핵심 메시지\n");
            sb.append("(결정된 내용 2~4문장)\n\n");
            sb.append("## 후속 액션 / 적용 방법 / 다음 학습\n");
            sb.append("(다음 단계 2~4문장)\n\n");
            sb.append("## 한줄 결론\n");
            sb.append("(전체를 요약한 1문장)\n\n");
        }

        sb.append("─── 📌 리마인드 ───\n");
        sb.append("(3단 계층 구조로 출력)\n");
        sb.append("리마인드 총 N개");

        return sb.toString();
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
            case 5 -> 1.00;
            default -> 0.55;
        };
        int needed = (int)(estimatedInputTokens * ratio) + 800; // 포맷+리마인드 오버헤드
        return Math.min(maxTokens, Math.max(512, needed));
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

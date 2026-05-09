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
            String prompt = buildPrompt(plainText, request.getTextLanguage(), request.getSummaryLanguage(), level);
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
        sb.append("   - 출력 형식의 섹션 명칭\n");
        sb.append("   - 리마인드 추출 기준과 유형 라벨\n\n");

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
        sb.append("[요약과 리마인드의 구분]\n");
        sb.append("────────────────────────────────────────\n");
        sb.append("1. 요약 본문 — 서술형, \"다뤄진 내용\", 과거·현재 시점, 읽고 이해\n");
        sb.append("2. 리마인드 — 체크리스트형, \"앞으로 챙길 것\", 미래 시점, 등록·추적\n");
        sb.append("3. 본문 항목은 망라적, 리마인드는 선별적이며 같은 항목이 양쪽에 들어갈 수 있다.\n");
        sb.append("4. 리마인드 섹션 앞에는 구분선과 강조 표기를 둔다.\n\n");

        sb.append("────────────────────────────────────────\n");
        sb.append("[리마인드 3단 계층 구조]\n");
        sb.append("────────────────────────────────────────\n");
        sb.append("※ 리마인드는 다음 3단 계층으로 구성한다.\n\n");
        sb.append("[1단: 항목 (Group)]\n");
        sb.append("   - 의미: 리마인드를 묶는 큰 카테고리\n");
        sb.append("   - 작성 기준: 콘텐츠 내 주제·영역 단위로 그룹핑\n");
        sb.append("     · 회의: 안건별 (예: \"결제 모듈 설계\", \"운영 이슈\")\n");
        sb.append("     · 강의: 챕터·단원별 (예: \"정규화\", \"트랜잭션\")\n");
        sb.append("     · 발표: 주장 단위 (예: \"시간 관리 원칙\", \"실행 전략\")\n");
        sb.append("     · 유튜브/팟캐스트: 화제 단위\n");
        sb.append("     · 인터뷰: 질문 주제 단위\n");
        sb.append("   - 형식: 짧은 명사구 (5~15자 권장)\n");
        sb.append("   - 일반적으로 항목은 2~5개 사이가 적절하다.\n");
        sb.append("     억지로 그룹을 나누지 말고, 단일 그룹이 자연스러우면 1개도 가능하다.\n\n");
        sb.append("[2단: 세부항목 (Item)]\n");
        sb.append("   - 의미: 항목 내의 개별 리마인드 한 줄\n");
        sb.append("   - 형식: [유형] 내용 / 담당자(또는 관련자) / 기한\n");
        sb.append("   - 유형: 일정 | 액션 | 핵심개념 | 적용포인트 | 학습할것 | 외부대기 | 리스크 | 기타\n");
        sb.append("   - 담당자/기한이 원문에 없으면 \"미정\" 또는 \"-\"로 표시한다.\n");
        sb.append("   - 추측해서 만들어내지 않는다.\n\n");
        sb.append("[3단: 내용 (Detail)]\n");
        sb.append("   - 의미: 세부항목의 부가 설명·맥락·근거\n");
        sb.append("   - 작성 기준\n");
        sb.append("     · 왜 중요한지, 어떤 맥락에서 나왔는지\n");
        sb.append("     · 어떻게 실행/기억해야 하는지\n");
        sb.append("     · 관련 예시, 수치, 인용 발언\n");
        sb.append("   - 1~3줄 권장. 한 줄로 충분하면 한 줄만.\n");
        sb.append("   - 부가 설명이 불필요한 단순 일정·약속은 3단을 생략할 수 있다.\n\n");
        sb.append("[출력 포맷]\n");
        sb.append("   📂 [1단 항목명]\n");
        sb.append("      ▸ [유형] 세부항목 내용 / 담당자 / 기한\n");
        sb.append("        └ 부가 설명 줄 1\n");
        sb.append("        └ 부가 설명 줄 2\n\n");

        sb.append("────────────────────────────────────────\n");
        sb.append("[리마인드 추출 규칙]\n");
        sb.append("────────────────────────────────────────\n");
        sb.append("1. 다음에 해당하는 내용을 리마인드로 추출한다.\n");
        sb.append("   - 명시적 일정 / 기한\n");
        sb.append("   - 약속·확약 사항\n");
        sb.append("   - 반드시 기억해야 할 핵심 개념·공식·정의\n");
        sb.append("   - 실행·적용을 권장하는 포인트\n");
        sb.append("   - 추가 학습·확인이 필요한 항목\n");
        sb.append("   - 외부 의존 항목\n");
        sb.append("   - 리스크·주의사항\n");
        sb.append("   - \"꼭 기억하세요/중요합니다\" 수준의 강조 발언\n\n");
        sb.append("2. 추출 후 1단 항목으로 그룹핑한다.\n");
        sb.append("3. 각 그룹 내 세부항목은 중요도 순으로 정렬한다.\n");
        sb.append("   - 기한 임박 → 외부 의존 → 리스크 → 핵심개념·적용포인트 → 일반 액션·학습 항목\n");
        sb.append("4. 그룹 간 정렬도 동일 기준을 적용한다.\n");
        sb.append("5. 콘텐츠에 리마인드성 내용이 없으면 \"없음\"으로 표시한다.\n");
        sb.append("6. 출력 마지막에 전체 세부항목 총 개수를 표기한다.\n");
        sb.append("   - 형식: \"리마인드 총 N개\"\n");
        sb.append("7. 요약 언어가 다른 경우 유형 라벨도 요약 언어로 표기한다.\n");
        sb.append("   - 영어: [Schedule] | [Action] | [KeyConcept] | [Application] | [ToStudy] | [Waiting] | [Risk] | [Other]\n");
        sb.append("   - 일본어: [日程] | [アクション] | [重要概念] | [適用ポイント] | [学習事項] | [外部待ち] | [リスク] | [その他]\n\n");

        sb.append("────────────────────────────────────────\n");
        sb.append("[출력 형식]\n");
        sb.append("────────────────────────────────────────\n");
        sb.append("※ 출력 첫 줄에 자동 판별된 콘텐츠 유형 표기.\n");
        sb.append("※ 모든 섹션 제목은 요약 언어로.\n");
        sb.append("※ 리마인드 섹션은 3단 계층 구조로 출력하고, 마지막에 총 개수 표기.\n\n");

        sb.append("■ 수준 1 (한줄 요약)\n");
        sb.append("   콘텐츠 유형: [판별값] (자동 감지)\n");
        sb.append("   - 한줄 결론\n\n");
        sb.append("   ─── 📌 리마인드 ───\n");
        sb.append("   📂 [그룹명]\n");
        sb.append("      ▸ [유형] 세부항목 / 담당자 / 기한\n");
        sb.append("        └ (필요 시 부가 설명)\n");
        sb.append("   리마인드 총 N개\n\n");

        sb.append("■ 수준 2 (간단 요약)\n");
        sb.append("   콘텐츠 유형: [판별값] (자동 감지)\n");
        sb.append("   - 전체 목적 / 주제\n");
        sb.append("   - 핵심 내용\n");
        sb.append("   - 결론 / 핵심 메시지\n");
        sb.append("   - 한줄 결론\n\n");
        sb.append("   ─── 📌 리마인드 ───\n");
        sb.append("   📂 [그룹명]\n");
        sb.append("      ▸ [유형] 세부항목 / 담당자 / 기한\n");
        sb.append("        └ (부가 설명)\n");
        sb.append("   리마인드 총 N개\n\n");

        sb.append("■ 수준 3~5 (일반 / 상세 / 전체 정제본)\n");
        sb.append("   콘텐츠 유형: [판별값] (자동 감지)\n");
        sb.append("   - 전체 목적 / 주제\n");
        sb.append("   - 주요 내용\n");
        sb.append("   - 핵심 개념·구조·주장\n");
        sb.append("   - 쟁점 / 이슈 / Q&A\n");
        sb.append("   - 결정 사항 / 결론 / 핵심 메시지\n");
        sb.append("   - 후속 액션 / 적용 방법 / 다음 학습\n");
        sb.append("   - 한줄 결론\n\n");
        sb.append("   ─── 📌 리마인드 ───\n");
        sb.append("   📂 [그룹명]\n");
        sb.append("      ▸ [유형] 세부항목 / 담당자 / 기한\n");
        sb.append("        └ (부가 설명)\n");
        sb.append("   리마인드 총 N개\n");

        return sb.toString();
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

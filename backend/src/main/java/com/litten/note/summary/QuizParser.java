package com.litten.note.summary;

import lombok.Getter;
import lombok.extern.log4j.Log4j2;

import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;

/**
 * AI 응답 텍스트에서 퀴즈 섹션을 파싱하여 구조화된 데이터로 변환.
 *
 * AI 출력 포맷 기준:
 *   ─── 📌 퀴즈 ───
 *   📂 [그룹명]
 *      ▸ [유형] 세부항목 / 담당자 / 기한
 *        └ 부가 설명
 *   퀴즈 총 N개
 */
@Log4j2
public class QuizParser {

    // 📌 퀴즈 구분선 패턴 (앞뒤 공백, 대시 개수 무관하게 매칭)
    private static final Pattern QUIZ_SEPARATOR =
            Pattern.compile("─+\\s*📌\\s*퀴즈\\s*─+");

    // 1단 그룹 접두사
    private static final String GROUP_PREFIX = "📂";

    // 2단 세부항목 접두사 (U+25B8 ▸)
    private static final String ITEM_PREFIX = "▸";

    // 3단 부가설명 접두사
    private static final String DETAIL_PREFIX = "└";

    // 요약 섹션 헤더 패턴 ("## 제목" 형태)
    private static final Pattern SECTION_HEADER = Pattern.compile("^##\\s+(.+)$");

    @Getter
    public static class ParseResult {
        private final String summaryText;          // 퀴즈 섹션 제거된 순수 요약 텍스트
        private final String fullText;             // 원본 전체 텍스트
        private final List<SummarySection> sections; // 요약 섹션 구조화 목록
        private final List<QuizGroup> groups;    // 퀴즈 그룹 구조화 목록
        private final int totalCount;              // 퀴즈 총 세부항목 수

        ParseResult(String summaryText, String fullText,
                    List<SummarySection> sections,
                    List<QuizGroup> groups, int totalCount) {
            this.summaryText = summaryText;
            this.fullText    = fullText;
            this.sections    = sections;
            this.groups      = groups;
            this.totalCount  = totalCount;
        }
    }

    /**
     * AI 응답 전체 텍스트를 파싱한다.
     * 구분선이 없으면 요약 텍스트만 반환하고 퀴즈는 빈 리스트.
     */
    public static ParseResult parse(String fullText) {
        if (fullText == null || fullText.isBlank()) {
            return new ParseResult("", "", new ArrayList<>(), new ArrayList<>(), 0);
        }

        // 구분선 위치 탐색
        var matcher = QUIZ_SEPARATOR.matcher(fullText);
        if (!matcher.find()) {
            log.debug("[QuizParser] 퀴즈 구분선 없음 - 퀴즈 파싱 생략");
            List<SummarySection> sections = parseSummarySections(fullText.trim());
            return new ParseResult(fullText.trim(), fullText, sections, new ArrayList<>(), 0);
        }

        String summaryText = fullText.substring(0, matcher.start()).trim();
        String quizText  = fullText.substring(matcher.end()).trim();

        log.debug("[QuizParser] 구분선 발견 - 요약 길이: {}, 퀴즈 섹션 길이: {}",
                summaryText.length(), quizText.length());

        List<SummarySection> sections = parseSummarySections(summaryText);
        List<QuizGroup>    groups   = parseQuizSection(quizText);
        int totalCount = groups.stream().mapToInt(g -> g.getItems().size()).sum();

        log.info("[QuizParser] 파싱 완료 - 요약 섹션 수: {}, 그룹 수: {}, 총 세부항목 수: {}",
                sections.size(), groups.size(), totalCount);

        return new ParseResult(summaryText, fullText, sections, groups, totalCount);
    }

    /**
     * "## 제목\n내용\n" 형태의 요약 텍스트를 SummarySection 목록으로 파싱.
     * 첫 줄 "콘텐츠 유형: ..." 헤더는 별도 섹션으로 포함.
     */
    private static List<SummarySection> parseSummarySections(String summaryText) {
        List<SummarySection> sections = new ArrayList<>();
        if (summaryText.isBlank()) return sections;

        SummarySection current = null;
        StringBuilder  content = new StringBuilder();

        for (String line : summaryText.split("\n")) {
            var headerMatcher = SECTION_HEADER.matcher(line.trim());
            if (headerMatcher.matches()) {
                // 이전 섹션 저장
                if (current != null) {
                    current.setSectionContent(content.toString().trim());
                    sections.add(current);
                }
                current = new SummarySection();
                current.setSectionTitle(headerMatcher.group(1).trim());
                content = new StringBuilder();
            } else if (current != null) {
                content.append(line).append("\n");
            } else if (!line.isBlank()) {
                // ## 헤더 이전 텍스트 (콘텐츠 유형 라인 등) → 첫 섹션으로
                current = new SummarySection();
                current.setSectionTitle("콘텐츠 유형");
                content = new StringBuilder(line).append("\n");
            }
        }
        // 마지막 섹션 저장
        if (current != null) {
            current.setSectionContent(content.toString().trim());
            sections.add(current);
        }

        log.debug("[QuizParser] 요약 섹션 파싱 완료 - {}개", sections.size());
        return sections;
    }

    private static List<QuizGroup> parseQuizSection(String quizText) {
        List<QuizGroup> groups = new ArrayList<>();
        if (quizText.isBlank()) return groups;

        QuizGroup currentGroup = null;
        QuizItem  currentItem  = null;

        for (String raw : quizText.split("\n")) {
            String line = raw.stripLeading();  // 앞 공백만 제거 (들여쓰기 무시)

            if (line.startsWith(GROUP_PREFIX)) {
                // 1단: 새 그룹 시작
                currentGroup = new QuizGroup();
                currentGroup.setGroupName(extractGroupName(line));
                groups.add(currentGroup);
                currentItem = null;
                log.debug("[QuizParser] 그룹: {}", currentGroup.getGroupName());

            } else if (line.startsWith(ITEM_PREFIX)) {
                // 2단: 새 세부항목
                if (currentGroup == null) {
                    // 그룹 없이 항목이 나오면 기본 그룹 생성
                    currentGroup = new QuizGroup();
                    currentGroup.setGroupName("기타");
                    groups.add(currentGroup);
                }
                currentItem = parseItem(line);
                currentGroup.getItems().add(currentItem);
                log.debug("[QuizParser] 항목 - type: {}, content: {}",
                        currentItem.getType(), currentItem.getContent());

            } else if (line.startsWith(DETAIL_PREFIX) && currentItem != null) {
                // 3단: 부가 설명
                String detail = line.substring(DETAIL_PREFIX.length()).trim();
                if (!detail.isBlank()) {
                    currentItem.getDetails().add(detail);
                }

            } else if (line.contains("퀴즈 총")) {
                // "퀴즈 총 N개" 라인은 파싱에서 제외
                log.debug("[QuizParser] 총 개수 라인 스킵: {}", line.trim());
            }
            // 그 외 빈 줄이나 알 수 없는 라인은 무시
        }

        return groups;
    }

    private static String extractGroupName(String line) {
        // "📂 [그룹명]" → "그룹명"  /  "📂 그룹명" → "그룹명"
        String name = line.substring(GROUP_PREFIX.length()).trim();
        if (name.startsWith("[") && name.contains("]")) {
            name = name.substring(1, name.lastIndexOf(']')).trim();
        }
        return name;
    }

    private static QuizItem parseItem(String line) {
        QuizItem item = new QuizItem();
        // "▸ [유형] 내용 / 담당자 / 기한"
        String body = line.substring(ITEM_PREFIX.length()).trim();

        // 유형 추출
        if (body.startsWith("[")) {
            int close = body.indexOf(']');
            if (close > 0) {
                item.setType(body.substring(1, close).trim());
                body = body.substring(close + 1).trim();
            }
        }
        if (item.getType() == null || item.getType().isBlank()) {
            item.setType("기타");
        }

        // 내용 / 담당자 / 기한 분리
        String[] parts = body.split(" / ", 3);
        item.setContent(parts[0].trim());
        item.setAssignee(parts.length > 1 ? parts[1].trim() : "-");
        item.setDeadline(parts.length > 2 ? parts[2].trim() : "-");

        return item;
    }
}

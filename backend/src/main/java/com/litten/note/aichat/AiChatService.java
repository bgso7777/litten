package com.litten.note.aichat;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * 'AI 셀' 비즈니스 로직. 로그인 회원 전용.
 *
 * <h3>대화 이어가기(하이브리드 메모리) 전략 — 효율(비용) + 맥락유지</h3>
 * <ol>
 *   <li>최근 {@link #WINDOW}개 메시지는 원문 그대로 AI에 전달</li>
 *   <li>system 프롬프트에 주제 + running_summary(오래된 대화 요약)를 함께 전달</li>
 *   <li>미요약 메시지가 {@link #FOLD_THRESHOLD}개를 넘으면, 오래된 것들을 러닝요약에 접어넣어
 *       매 요청 토큰이 무한정 늘지 않도록 상한을 건다.</li>
 * </ol>
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AiChatService {

    /** 최근 몇 개 메시지를 원문으로 유지할지. */
    private static final int WINDOW = 16;
    /** 미요약 메시지가 이 수를 넘으면 오래된 것을 러닝요약으로 접는다. */
    private static final int FOLD_THRESHOLD = 24;

    private final AiChatRepository chatRepository;
    private final AiChatMessageRepository messageRepository;
    private final AiChatOpenAiService openAi;

    // ── 조회 ──────────────────────────────────────────────

    /** 내 AI 셀 목록(최근 대화 순). 반환: [{id, clientId, topic, title, updatedAt, lastMessage}]. */
    public List<Map<String, Object>> list(String memberId) {
        List<Map<String, Object>> result = new ArrayList<>();
        for (AiChat c : chatRepository.findByMemberIdAndIsDeletedFalseOrderByUpdateDateTimeDesc(memberId)) {
            Map<String, Object> m = new HashMap<>();
            m.put("id", c.getId());
            m.put("clientId", c.getClientId());
            m.put("topic", c.getTopic());
            m.put("title", c.getTitle());
            m.put("updatedAt", c.getUpdateDateTime());
            List<AiChatMessage> msgs = messageRepository.findByChatIdAndIsDeletedFalseOrderByIdAsc(c.getId());
            m.put("lastMessage", msgs.isEmpty() ? null : msgs.get(msgs.size() - 1).getContent());
            m.put("messageCount", msgs.size());
            result.add(m);
        }
        return result;
    }

    /** 방의 전체 메시지(화면 표시용). 소유자 아니면 null. */
    public List<Map<String, Object>> messages(String memberId, Long chatId) {
        AiChat c = owned(memberId, chatId);
        if (c == null) return null;
        List<Map<String, Object>> out = new ArrayList<>();
        for (AiChatMessage it : messageRepository.findByChatIdAndIsDeletedFalseOrderByIdAsc(chatId)) {
            out.add(toMsgMap(it));
        }
        return out;
    }

    // ── 생성/삭제 ─────────────────────────────────────────

    /** 주제로 AI 셀 생성(clientId 있으면 upsert). 반환: {id, clientId, topic, title}. */
    @Transactional
    public Map<String, Object> create(String memberId, String topic, String clientId) {
        String cleanTopic = (topic == null || topic.isBlank()) ? "자유 주제" : topic.trim();
        AiChat c = null;
        if (clientId != null && !clientId.isBlank()) {
            c = chatRepository.findByMemberIdAndClientId(memberId, clientId).orElse(null);
        }
        if (c == null) {
            c = new AiChat();
            c.setMemberId(memberId);
            c.setClientId(clientId);
            c.setInsertDateTime(LocalDateTime.now());
        }
        c.setTopic(cleanTopic);
        c.setTitle(makeTitle(cleanTopic));
        c.setSystemPrompt(buildSystemPrompt(cleanTopic));
        c.setIsDeleted(false);
        c.setUpdateDateTime(LocalDateTime.now());
        chatRepository.save(c);

        Map<String, Object> m = new HashMap<>();
        m.put("id", c.getId());
        m.put("clientId", c.getClientId());
        m.put("topic", c.getTopic());
        m.put("title", c.getTitle());
        return m;
    }

    /** 표시 이름 변경. */
    @Transactional
    public boolean rename(String memberId, Long chatId, String title) {
        AiChat c = owned(memberId, chatId);
        if (c == null || title == null || title.isBlank()) return false;
        c.setTitle(title.trim());
        c.setUpdateDateTime(LocalDateTime.now());
        chatRepository.save(c);
        return true;
    }

    @Transactional
    public boolean delete(String memberId, Long chatId) {
        AiChat c = owned(memberId, chatId);
        if (c == null) return false;
        c.setIsDeleted(true);
        c.setDeletedAt(LocalDateTime.now());
        c.setUpdateDateTime(LocalDateTime.now());
        chatRepository.save(c);
        for (AiChatMessage it : messageRepository.findByChatIdAndIsDeletedFalseOrderByIdAsc(chatId)) {
            it.setIsDeleted(true);
            messageRepository.save(it);
        }
        return true;
    }

    // ── 대화 ──────────────────────────────────────────────

    /**
     * 사용자 메시지를 저장하고 AI 응답을 생성·저장해 반환.
     * 반환: {userMessage:{...}, assistantMessage:{...}} 또는 null(소유자 아님/빈 입력).
     */
    @Transactional
    public Map<String, Object> sendMessage(String memberId, Long chatId, String userText) {
        AiChat c = owned(memberId, chatId);
        if (c == null || userText == null || userText.isBlank()) return null;

        // 1) 사용자 메시지 저장
        AiChatMessage userMsg = saveMessage(chatId, memberId, "user", userText.trim());

        // 2) AI 전송 메시지 구성 — system(주제+러닝요약) + 미요약 원문 윈도우(방금 저장한 user 포함)
        List<AiChatOpenAiService.Msg> payload = new ArrayList<>();
        payload.add(new AiChatOpenAiService.Msg("system", effectiveSystem(c)));
        List<AiChatMessage> window =
                messageRepository.findByChatIdAndIsDeletedFalseAndIdGreaterThanOrderByIdAsc(chatId, nz(c.getSummarizedMsgId()));
        for (AiChatMessage it : window) {
            payload.add(new AiChatOpenAiService.Msg(it.getRole(), it.getContent()));
        }

        // 3) AI 호출
        String reply = openAi.chat(payload);

        // 4) AI 응답 저장
        AiChatMessage aiMsg = saveMessage(chatId, memberId, "assistant", reply);

        // 5) 방 갱신 시각
        c.setUpdateDateTime(LocalDateTime.now());
        chatRepository.save(c);

        // 6) 하이브리드 메모리 — 미요약 메시지가 임계 초과면 오래된 것을 러닝요약으로 접는다
        compressIfNeeded(c);

        Map<String, Object> out = new HashMap<>();
        out.put("userMessage", toMsgMap(userMsg));
        out.put("assistantMessage", toMsgMap(aiMsg));
        return out;
    }

    // ── 내부 ──────────────────────────────────────────────

    /** 미요약 메시지 수가 임계를 넘으면 오래된 것을 러닝요약에 접어 토큰 상한을 유지. */
    private void compressIfNeeded(AiChat c) {
        List<AiChatMessage> unsummarized =
                messageRepository.findByChatIdAndIsDeletedFalseAndIdGreaterThanOrderByIdAsc(c.getId(), nz(c.getSummarizedMsgId()));
        if (unsummarized.size() <= FOLD_THRESHOLD) return;

        int foldCount = unsummarized.size() - WINDOW; // 최근 WINDOW개는 남기고 나머지 접기
        List<AiChatMessage> toFold = unsummarized.subList(0, foldCount);
        List<AiChatOpenAiService.Msg> foldMsgs = new ArrayList<>();
        for (AiChatMessage it : toFold) {
            foldMsgs.add(new AiChatOpenAiService.Msg(it.getRole(), it.getContent()));
        }
        String newSummary = openAi.summarizeFold(c.getRunningSummary(), foldMsgs);
        c.setRunningSummary(newSummary);
        c.setSummarizedMsgId(toFold.get(foldCount - 1).getId());
        chatRepository.save(c);
        log.info("[AiChatService] 러닝요약 갱신 - chatId: {}, 접은 메시지: {}, summarizedMsgId: {}",
                c.getId(), foldCount, c.getSummarizedMsgId());
    }

    private String effectiveSystem(AiChat c) {
        // 저장된 system_prompt(생성 시점 값) 대신 항상 현재 규칙으로 재생성한다 →
        // 프롬프트 개선(주제 이탈 제한 등)이 기존 대화방에도 즉시 적용된다.
        String base = buildSystemPrompt(c.getTopic());
        if (c.getRunningSummary() != null && !c.getRunningSummary().isBlank()) {
            return base + "\n\n[지금까지의 대화 요약 — 기억해서 이어가라]\n" + c.getRunningSummary();
        }
        return base;
    }

    private String buildSystemPrompt(String topic) {
        return "당신은 '" + topic + "' 주제 전용 AI 도우미입니다. "
                + "이 대화방의 맥락을 기억하고 일관되게 이어가세요. "
                + "사용자가 사용하는 언어로 자연스럽고 도움이 되게 답하세요. "
                + "모르는 것은 모른다고 말하고, 사실을 지어내지 마세요.\n"
                + "【중요 규칙】 오직 '" + topic + "' 주제와 직접 관련된 질문에만 답하세요. "
                + "주제와 무관한 질문(다른 분야·잡담·일반 상식 등)에는 절대 답을 제공하지 말고, "
                + "'이 대화방은 \"" + topic + "\" 주제 전용이에요. 그 주제로 질문해 주세요.' 처럼 "
                + "한두 문장으로 정중히 안내하며 주제로 돌아오도록 유도하세요. "
                + "주제와 관련이 있는지 애매하면, 그 주제의 관점에서 연결해 답하세요.";
    }

    private AiChatMessage saveMessage(Long chatId, String memberId, String role, String content) {
        AiChatMessage m = new AiChatMessage();
        m.setChatId(chatId);
        m.setMemberId(memberId);
        m.setRole(role);
        m.setContent(content);
        m.setIsDeleted(false);
        m.setInsertDateTime(LocalDateTime.now());
        m.setUpdateDateTime(LocalDateTime.now());
        messageRepository.save(m);
        return m;
    }

    private AiChat owned(String memberId, Long chatId) {
        if (chatId == null) return null;
        Optional<AiChat> opt = chatRepository.findById(chatId);
        if (opt.isEmpty()) return null;
        AiChat c = opt.get();
        if (!memberId.equals(c.getMemberId()) || Boolean.TRUE.equals(c.getIsDeleted())) return null;
        return c;
    }

    private Map<String, Object> toMsgMap(AiChatMessage it) {
        Map<String, Object> m = new HashMap<>();
        m.put("messageId", it.getId());
        m.put("role", it.getRole());
        m.put("content", it.getContent());
        m.put("createdAt", it.getInsertDateTime());
        return m;
    }

    private String makeTitle(String topic) {
        String t = topic.trim();
        return t.length() <= 40 ? t : t.substring(0, 40) + "…";
    }

    private long nz(Long v) {
        return v == null ? 0L : v;
    }
}

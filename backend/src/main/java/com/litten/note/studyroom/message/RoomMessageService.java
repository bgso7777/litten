package com.litten.note.studyroom.message;

import com.litten.note.NoteMember;
import com.litten.note.NoteMemberRepository;
import com.litten.note.studyroom.StudyRoom;
import com.litten.note.studyroom.StudyRoomMember;
import com.litten.note.studyroom.StudyRoomMemberRepository;
import com.litten.note.studyroom.StudyRoomRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

/** 스터디룸 메시지 — 전송(개인/룸 fan-out), 받은/보낸 목록. 공유(RoomShare) 구조를 본뜸. */
@Slf4j
@Service
@RequiredArgsConstructor
public class RoomMessageService {

    private final RoomMessageRepository messageRepository;
    private final RoomMessageDeliveryRepository deliveryRepository;
    private final StudyRoomRepository roomRepository;
    private final StudyRoomMemberRepository roomMemberRepository;
    private final NoteMemberRepository noteMemberRepository;

    private NoteMember resolveMember(String key) {
        if (key == null) return null;
        String k = key.trim();
        if (k.isEmpty()) return null;
        NoteMember m = noteMemberRepository.findFirstByEmail(k);
        if (m == null) m = noteMemberRepository.findFirstByEmail(k.toLowerCase());
        if (m == null) m = noteMemberRepository.findById(k).orElse(null);
        if (m == null) m = noteMemberRepository.findFirstByName(k);
        return m;
    }

    private String resolveName(String memberId) {
        return noteMemberRepository.findById(memberId)
                .map(m -> m.getName() != null ? m.getName() : m.getEmail())
                .orElse(memberId);
    }

    /** 메시지 전송. targetType=user면 recipientKey(이메일/닉네임) 1명, group이면 groupId 룸 멤버 전원. */
    @Transactional
    public Map<String, Object> send(String senderId, String targetType, String recipientKey,
                                    Long groupId, String content) {
        Map<String, Object> result = new HashMap<>();
        if (content == null || content.trim().isEmpty()) {
            result.put("success", false);
            result.put("message", "메시지 내용이 비어 있습니다.");
            return result;
        }

        Set<String> recipientIds = new LinkedHashSet<>();
        String groupName = null;
        if ("group".equals(targetType)) {
            Optional<StudyRoom> gOpt = roomRepository.findById(groupId == null ? -1L : groupId);
            if (gOpt.isEmpty() || Boolean.TRUE.equals(gOpt.get().getIsDeleted())) {
                result.put("success", false);
                result.put("message", "룸을 찾을 수 없습니다.");
                return result;
            }
            StudyRoom g = gOpt.get();
            // 소유자뿐 아니라 룸 멤버도 룸 대화에 메시지 가능
            boolean isOwner = g.getOwnerMemberId().equals(senderId);
            boolean isMember = roomMemberRepository.findByRoomIdAndMemberId(groupId, senderId).isPresent();
            if (!isOwner && !isMember) {
                result.put("success", false);
                result.put("message", "룸 멤버만 메시지를 보낼 수 있습니다.");
                return result;
            }
            // 방장이 '멤버 대화'를 잠근 룸에서는 방장만 메시지를 보낼 수 있다.
            // (구 데이터 NULL 은 허용으로 간주)
            if (!isOwner && Boolean.FALSE.equals(g.getAllowMemberChat())) {
                result.put("success", false);
                result.put("message", "이 룸은 방장만 대화할 수 있습니다.");
                return result;
            }
            groupName = g.getName();
            for (StudyRoomMember gm : roomMemberRepository.findByRoomIdAndIsDeletedFalseOrderByIdAsc(groupId)) {
                recipientIds.add(gm.getMemberId());
            }
            recipientIds.add(g.getOwnerMemberId()); // 소유자도 수신
        } else {
            NoteMember m = resolveMember(recipientKey);
            if (m == null) {
                result.put("success", false);
                result.put("message", "수신자를 찾을 수 없습니다.");
                return result;
            }
            recipientIds.add(m.getId());
        }
        // 발신자 본인은 수신 목록에서 제외(자기 자신에게 전달 안 함).
        // 단, 1:1에서 의도적으로 본인을 지정한 셀프 대화(개인 메모용)는 허용한다.
        boolean selfChat = !"group".equals(targetType)
                && recipientIds.size() == 1
                && recipientIds.contains(senderId);
        if (!selfChat) {
            recipientIds.remove(senderId);
        }
        if (recipientIds.isEmpty()) {
            result.put("success", false);
            result.put("message", "받을 사람이 없습니다.");
            return result;
        }

        RoomMessage msg = new RoomMessage();
        msg.setSenderMemberId(senderId);
        msg.setSenderName(resolveName(senderId));
        msg.setTargetType("group".equals(targetType) ? "group" : "user");
        msg.setRoomId("group".equals(targetType) ? groupId : null);
        msg.setGroupName(groupName);
        msg.setContent(content.trim());
        msg.setIsDeleted(false);
        msg.setInsertDateTime(LocalDateTime.now());
        msg.setUpdateDateTime(LocalDateTime.now());
        messageRepository.save(msg);

        for (String rid : recipientIds) {
            RoomMessageDelivery d = new RoomMessageDelivery();
            d.setMessageId(msg.getId());
            d.setRecipientMemberId(rid);
            d.setIsDeleted(false);
            d.setInsertDateTime(LocalDateTime.now());
            d.setUpdateDateTime(LocalDateTime.now());
            deliveryRepository.save(d);
        }

        log.info("[RoomMessageService] 메시지 전송 - sender: {}, target: {}, recipients: {}, msgId: {}",
                senderId, targetType, recipientIds.size(), msg.getId());
        result.put("success", true);
        result.put("messageId", msg.getId());
        result.put("recipientCount", recipientIds.size());
        return result;
    }

    /** 내가 받은 메시지 목록 (전달 기준). */
    /** 메시지 삭제(soft) — 보낸 사람만 가능. 삭제하면 모든 수신자 화면에서도 사라진다.
     *  성공 true / 없음·권한없음 false. */
    @Transactional
    public boolean delete(String memberId, Long messageId) {
        RoomMessage m = messageRepository.findById(messageId).orElse(null);
        if (m == null || Boolean.TRUE.equals(m.getIsDeleted())) {
            log.info("[RoomMessageService] 메시지 삭제 - 대상 없음: {}", messageId);
            return false;
        }
        if (!memberId.equals(m.getSenderMemberId())) {
            log.info("[RoomMessageService] 메시지 삭제 권한 없음 - messageId: {}, by: {}", messageId, memberId);
            return false;
        }
        m.setIsDeleted(true);
        m.setUpdateDateTime(LocalDateTime.now());
        messageRepository.save(m);
        log.info("[RoomMessageService] 메시지 삭제 - messageId: {}, by: {}", messageId, memberId);
        return true;
    }

    public List<Map<String, Object>> received(String memberId) {
        List<Map<String, Object>> list = new ArrayList<>();
        // 발신자 현재 닉네임 캐시 — 닉네임을 나중에 바꿔도 대화 이름이 최신으로 보이도록
        // 저장된 스냅샷(senderName) 대신 현재 회원 이름을 실시간 조회한다.
        Map<String, String> nameCache = new HashMap<>();
        for (RoomMessageDelivery d : deliveryRepository.findByRecipientMemberIdAndIsDeletedFalseOrderByIdDesc(memberId)) {
            Optional<RoomMessage> mOpt = messageRepository.findById(d.getMessageId());
            if (mOpt.isEmpty() || Boolean.TRUE.equals(mOpt.get().getIsDeleted())) continue;
            RoomMessage m = mOpt.get();
            Map<String, Object> map = new HashMap<>();
            map.put("messageId", m.getId());
            map.put("deliveryId", d.getId());
            map.put("senderName", nameCache.computeIfAbsent(m.getSenderMemberId(), this::resolveName));
            map.put("senderMemberId", m.getSenderMemberId());
            map.put("senderWithdrawn", Boolean.TRUE.equals(m.getSenderWithdrawn())); // 발신자 탈퇴 여부(수신자 표시용)
            map.put("groupName", m.getGroupName());
            // 수신자 측 룸 잠금용: 발신자 룸의 비밀번호(있으면)
            map.put("groupId", m.getRoomId());
            map.put("groupPassword", m.getRoomId() == null ? null
                    : roomRepository.findById(m.getRoomId()).map(StudyRoom::getPassword).orElse(null));
            // 받은 룸의 총 인원 산정용 — 오너 제외 멤버 수(프론트는 +1(오너)로 총원 계산)
            map.put("groupMemberCount", m.getRoomId() == null ? null
                    : roomMemberRepository.findByRoomIdAndIsDeletedFalseOrderByIdAsc(m.getRoomId()).size());
            map.put("content", m.getContent());
            map.put("sentAt", m.getInsertDateTime());
            list.add(map);
        }
        return list;
    }

    /** 내가 보낸 메시지 목록 (메시지 기준 + 수신자 요약). */
    public List<Map<String, Object>> sent(String memberId) {
        List<Map<String, Object>> list = new ArrayList<>();
        Map<String, String> nameCache = new HashMap<>(); // 수신자 현재 닉네임 캐시
        for (RoomMessage m : messageRepository.findBySenderMemberIdAndIsDeletedFalseOrderByIdDesc(memberId)) {
            List<Map<String, Object>> recips = new ArrayList<>();
            for (RoomMessageDelivery d : deliveryRepository.findByMessageIdAndIsDeletedFalse(m.getId())) {
                Map<String, Object> r = new HashMap<>();
                r.put("memberId", d.getRecipientMemberId());
                r.put("name", nameCache.computeIfAbsent(d.getRecipientMemberId(), this::resolveName));
                recips.add(r);
            }
            Map<String, Object> map = new HashMap<>();
            map.put("messageId", m.getId());
            map.put("targetType", m.getTargetType());
            map.put("groupName", m.getGroupName());
            map.put("content", m.getContent());
            map.put("sentAt", m.getInsertDateTime());
            map.put("recipients", recips);
            list.add(map);
        }
        return list;
    }
}

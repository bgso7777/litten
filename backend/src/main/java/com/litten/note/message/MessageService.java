package com.litten.note.message;

import com.litten.note.NoteMember;
import com.litten.note.NoteMemberRepository;
import com.litten.note.share.ShareGroup;
import com.litten.note.share.ShareGroupMember;
import com.litten.note.share.ShareGroupMemberRepository;
import com.litten.note.share.ShareGroupRepository;
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

/** 사용자 간 채팅 메시지 — 전송(개인/그룹 fan-out), 받은/보낸 목록. 공유(FileShare) 구조를 본뜸. */
@Slf4j
@Service
@RequiredArgsConstructor
public class MessageService {

    private final NoteMessageRepository messageRepository;
    private final NoteMessageDeliveryRepository deliveryRepository;
    private final ShareGroupRepository groupRepository;
    private final ShareGroupMemberRepository groupMemberRepository;
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

    /** 메시지 전송. targetType=user면 recipientKey(이메일/닉네임) 1명, group이면 groupId 멤버 전원. */
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
            Optional<ShareGroup> gOpt = groupRepository.findById(groupId == null ? -1L : groupId);
            if (gOpt.isEmpty() || Boolean.TRUE.equals(gOpt.get().getIsDeleted())) {
                result.put("success", false);
                result.put("message", "그룹을 찾을 수 없습니다.");
                return result;
            }
            ShareGroup g = gOpt.get();
            // 소유자뿐 아니라 그룹 멤버도 그룹 대화에 메시지 가능
            boolean isOwner = g.getOwnerMemberId().equals(senderId);
            boolean isMember = groupMemberRepository.findByGroupIdAndMemberId(groupId, senderId).isPresent();
            if (!isOwner && !isMember) {
                result.put("success", false);
                result.put("message", "그룹 멤버만 메시지를 보낼 수 있습니다.");
                return result;
            }
            groupName = g.getName();
            for (ShareGroupMember gm : groupMemberRepository.findByGroupIdAndIsDeletedFalseOrderByIdAsc(groupId)) {
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
        // 단, 1:1에서 의도적으로 본인을 지정한 셀프 채팅(개인 메모용)은 허용한다.
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

        NoteMessage msg = new NoteMessage();
        msg.setSenderMemberId(senderId);
        msg.setSenderName(resolveName(senderId));
        msg.setTargetType("group".equals(targetType) ? "group" : "user");
        msg.setGroupId("group".equals(targetType) ? groupId : null);
        msg.setGroupName(groupName);
        msg.setContent(content.trim());
        msg.setIsDeleted(false);
        msg.setInsertDateTime(LocalDateTime.now());
        msg.setUpdateDateTime(LocalDateTime.now());
        messageRepository.save(msg);

        for (String rid : recipientIds) {
            NoteMessageDelivery d = new NoteMessageDelivery();
            d.setMessageId(msg.getId());
            d.setRecipientMemberId(rid);
            d.setIsDeleted(false);
            d.setInsertDateTime(LocalDateTime.now());
            d.setUpdateDateTime(LocalDateTime.now());
            deliveryRepository.save(d);
        }

        log.info("[MessageService] 메시지 전송 - sender: {}, target: {}, recipients: {}, msgId: {}",
                senderId, targetType, recipientIds.size(), msg.getId());
        result.put("success", true);
        result.put("messageId", msg.getId());
        result.put("recipientCount", recipientIds.size());
        return result;
    }

    /** 내가 받은 메시지 목록 (전달 기준). */
    public List<Map<String, Object>> received(String memberId) {
        List<Map<String, Object>> list = new ArrayList<>();
        for (NoteMessageDelivery d : deliveryRepository.findByRecipientMemberIdAndIsDeletedFalseOrderByIdDesc(memberId)) {
            Optional<NoteMessage> mOpt = messageRepository.findById(d.getMessageId());
            if (mOpt.isEmpty() || Boolean.TRUE.equals(mOpt.get().getIsDeleted())) continue;
            NoteMessage m = mOpt.get();
            Map<String, Object> map = new HashMap<>();
            map.put("messageId", m.getId());
            map.put("deliveryId", d.getId());
            map.put("senderName", m.getSenderName());
            map.put("senderMemberId", m.getSenderMemberId());
            map.put("groupName", m.getGroupName());
            // 수신자 측 그룹 잠금용: 발신자 그룹의 비밀번호(있으면)
            map.put("groupId", m.getGroupId());
            map.put("groupPassword", m.getGroupId() == null ? null
                    : groupRepository.findById(m.getGroupId()).map(ShareGroup::getPassword).orElse(null));
            // 받은 그룹의 총 인원 산정용 — 오너 제외 멤버 수(프론트는 +1(오너)로 총원 계산)
            map.put("groupMemberCount", m.getGroupId() == null ? null
                    : groupMemberRepository.findByGroupIdAndIsDeletedFalseOrderByIdAsc(m.getGroupId()).size());
            map.put("content", m.getContent());
            map.put("sentAt", m.getInsertDateTime());
            list.add(map);
        }
        return list;
    }

    /** 내가 보낸 메시지 목록 (메시지 기준 + 수신자 요약). */
    public List<Map<String, Object>> sent(String memberId) {
        List<Map<String, Object>> list = new ArrayList<>();
        for (NoteMessage m : messageRepository.findBySenderMemberIdAndIsDeletedFalseOrderByIdDesc(memberId)) {
            List<Map<String, Object>> recips = new ArrayList<>();
            for (NoteMessageDelivery d : deliveryRepository.findByMessageIdAndIsDeletedFalse(m.getId())) {
                Map<String, Object> r = new HashMap<>();
                r.put("memberId", d.getRecipientMemberId());
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

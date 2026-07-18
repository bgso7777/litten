package com.litten.note.studyroom;

import com.litten.Constants;
import com.litten.note.NoteMember;
import com.litten.note.NoteMemberRepository;
import com.litten.note.studyroom.message.RoomMessageRepository;
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

/** 스터디룸 CRUD + 멤버 관리. 모두 소유자(로그인 회원) 단위. */
@Slf4j
@Service
@RequiredArgsConstructor
public class StudyRoomService {

    private final StudyRoomRepository roomRepository;
    private final StudyRoomMemberRepository memberRepository;
    private final NoteMemberRepository noteMemberRepository;
    private final RoomShareRepository roomShareRepository;
    private final RoomMessageRepository roomMessageRepository;

    /** 룸 이름 변경 — 소유자만. 룸명 + 과거 공유/메시지의 group_name 스냅샷까지 갱신해
     *  수신자·다기기에서 같은 대화로 묶여 새 이름으로 보이게 한다. 실패(없음/권한없음) 시 null. */
    @Transactional
    public Map<String, Object> renameGroup(String ownerId, Long roomId, String newName) {
        if (newName == null || newName.trim().isEmpty()) {
            throw new IllegalArgumentException("룸 이름을 입력하세요.");
        }
        String name = newName.trim();
        StudyRoom g = roomRepository.findById(roomId).orElse(null);
        if (g == null || Boolean.TRUE.equals(g.getIsDeleted())
                || !ownerId.equals(g.getOwnerMemberId())) {
            return null;
        }
        g.setName(name);
        g.setUpdateDateTime(LocalDateTime.now());
        roomRepository.save(g);
        int s = roomShareRepository.renameGroup(roomId, name);
        int m = roomMessageRepository.renameGroup(roomId, name);
        log.info("[StudyRoomService] 룸 이름변경 - roomId:{}, name:{}, shares:{}, messages:{}",
                roomId, name, s, m);
        Map<String, Object> r = new HashMap<>();
        r.put("groupId", roomId);
        r.put("name", name);
        return r;
    }

    /** 이메일/표시이름으로 회원 조회 (없으면 null). */
    NoteMember resolveMember(String key) {
        if (key == null) return null;
        String k = key.trim();
        if (k.isEmpty()) return null;
        // 이메일 → (소문자 이메일) → 로그인 계정 id(이메일일 수 있음) → 표시이름 순
        NoteMember m = noteMemberRepository.findFirstByEmail(k);
        if (m == null) m = noteMemberRepository.findFirstByEmail(k.toLowerCase());
        if (m == null) m = noteMemberRepository.findById(k).orElse(null);
        if (m == null) m = noteMemberRepository.findFirstByName(k);
        return m;
    }

    /**
     * 룸 생성 — 이름 + (선택)비밀번호 + 초기 멤버(이메일/닉네임 목록) 일괄 추가.
     * allowMemberChat/allowMemberFile 은 null 이면 기본값(대화 허용, 파일 차단)을 쓴다.
     */
    @Transactional
    public Map<String, Object> createGroup(String ownerId, String name, String password, List<String> memberKeys,
                                           Boolean allowMemberChat, Boolean allowMemberFile) {
        if (name == null || name.trim().isEmpty()) {
            throw new IllegalArgumentException("룸 이름을 입력하세요.");
        }
        StudyRoom g = new StudyRoom();
        g.setOwnerMemberId(ownerId);
        g.setName(name.trim());
        g.setPassword(password != null && !password.isBlank() ? password.trim() : null);
        g.setAllowMemberChat(allowMemberChat == null || allowMemberChat);
        g.setAllowMemberFile(Boolean.TRUE.equals(allowMemberFile));
        g.setIsDeleted(false);
        g.setInsertDateTime(LocalDateTime.now());
        g.setUpdateDateTime(LocalDateTime.now());
        roomRepository.save(g);

        int added = 0;
        List<String> notFound = new ArrayList<>();
        if (memberKeys != null) {
            for (String key : memberKeys) {
                if (key == null || key.trim().isEmpty()) continue;
                NoteMember member = resolveMember(key);
                if (member == null) {
                    notFound.add(key.trim());
                    continue;
                }
                // 방장은 이미 룸의 주인이라 멤버로 중복 등록하지 않는다.
                if (member.getId().equals(ownerId)) {
                    log.info("[StudyRoomService] 룸 생성 - 방장 본인 멤버 추가는 건너뜀: {}", ownerId);
                    continue;
                }
                StudyRoomMember gm = memberRepository
                        .findByRoomIdAndMemberId(g.getId(), member.getId())
                        .orElseGet(StudyRoomMember::new);
                gm.setRoomId(g.getId());
                gm.setMemberId(member.getId());
                gm.setMemberName(member.getName() != null ? member.getName() : member.getEmail());
                gm.setIsDeleted(false);
                if (gm.getInsertDateTime() == null) gm.setInsertDateTime(LocalDateTime.now());
                gm.setUpdateDateTime(LocalDateTime.now());
                memberRepository.save(gm);
                added++;
            }
        }
        log.info("[StudyRoomService] 룸 생성 - owner: {}, roomId: {}, name: {}, members: {}, notFound: {}",
                ownerId, g.getId(), name, added, notFound.size());
        Map<String, Object> result = toGroupMap(g, added);
        result.put("notFound", notFound);
        return result;
    }

    public List<Map<String, Object>> listGroups(String ownerId) {
        List<StudyRoom> groups = roomRepository.findByOwnerMemberIdAndIsDeletedFalseOrderByIdDesc(ownerId);
        List<Map<String, Object>> list = new ArrayList<>();
        for (StudyRoom g : groups) {
            int count = memberRepository.findByRoomIdAndIsDeletedFalseOrderByIdAsc(g.getId()).size();
            list.add(toGroupMap(g, count));
        }
        return list;
    }

    /** 멤버 권한 옵션 변경 — 방장만. null 인 항목은 기존 값을 유지한다. */
    @Transactional
    public Map<String, Object> updateGroupOptions(String ownerId, Long roomId,
                                                  Boolean allowMemberChat, Boolean allowMemberFile) {
        Optional<StudyRoom> opt = roomRepository.findById(roomId);
        if (opt.isEmpty() || !opt.get().getOwnerMemberId().equals(ownerId)
                || Boolean.TRUE.equals(opt.get().getIsDeleted())) {
            return null; // 룸 없음/권한 없음
        }
        StudyRoom g = opt.get();
        if (allowMemberChat != null) g.setAllowMemberChat(allowMemberChat);
        if (allowMemberFile != null) g.setAllowMemberFile(allowMemberFile);
        g.setUpdateDateTime(LocalDateTime.now());
        roomRepository.save(g);
        log.info("[StudyRoomService] 룸 옵션 변경 - owner: {}, roomId: {}, chat: {}, file: {}",
                ownerId, roomId, g.getAllowMemberChat(), g.getAllowMemberFile());
        int count = memberRepository.findByRoomIdAndIsDeletedFalseOrderByIdAsc(roomId).size();
        return toGroupMap(g, count);
    }

    @Transactional
    public boolean deleteGroup(String ownerId, Long roomId) {
        Optional<StudyRoom> opt = roomRepository.findById(roomId);
        if (opt.isEmpty() || !opt.get().getOwnerMemberId().equals(ownerId)) return false;
        StudyRoom g = opt.get();
        g.setIsDeleted(true);
        g.setDeletedAt(LocalDateTime.now());
        g.setUpdateDateTime(LocalDateTime.now());
        roomRepository.save(g);
        // 멤버도 정리
        for (StudyRoomMember m : memberRepository.findByRoomIdAndIsDeletedFalseOrderByIdAsc(roomId)) {
            m.setIsDeleted(true);
            m.setUpdateDateTime(LocalDateTime.now());
            memberRepository.save(m);
        }
        log.info("[StudyRoomService] 룸 삭제 - owner: {}, roomId: {}", ownerId, roomId);
        return true;
    }

    /** 멤버 추가 (이메일/표시이름으로 회원 해석). 추가된 멤버 맵 반환, 실패 시 null. */
    @Transactional
    public Map<String, Object> addMember(String ownerId, Long roomId, String key) {
        Optional<StudyRoom> opt = roomRepository.findById(roomId);
        if (opt.isEmpty() || !opt.get().getOwnerMemberId().equals(ownerId) || Boolean.TRUE.equals(opt.get().getIsDeleted())) {
            return null; // 룸 없음/권한 없음
        }
        NoteMember member = resolveMember(key);
        if (member == null) return null; // 회원 없음
        // 방장은 이미 룸의 주인 — 멤버로 중복 등록하면 대화/공유 수신자가 꼬인다.
        if (member.getId().equals(ownerId)) {
            throw new IllegalArgumentException("본인은 멤버로 추가할 수 없습니다.");
        }

        Optional<StudyRoomMember> existing = memberRepository.findByRoomIdAndMemberId(roomId, member.getId());
        StudyRoomMember gm = existing.orElseGet(StudyRoomMember::new);
        gm.setRoomId(roomId);
        gm.setMemberId(member.getId());
        gm.setMemberName(member.getName() != null ? member.getName() : member.getEmail());
        gm.setIsDeleted(false);
        if (gm.getInsertDateTime() == null) gm.setInsertDateTime(LocalDateTime.now());
        gm.setUpdateDateTime(LocalDateTime.now());
        memberRepository.save(gm);
        log.info("[StudyRoomService] 멤버 추가 - roomId: {}, memberId: {}", roomId, member.getId());
        return toMemberMap(gm);
    }

    @Transactional
    public boolean removeMember(String ownerId, Long roomId, String memberId) {
        Optional<StudyRoom> opt = roomRepository.findById(roomId);
        if (opt.isEmpty() || !opt.get().getOwnerMemberId().equals(ownerId)) return false;
        Optional<StudyRoomMember> gmOpt = memberRepository.findByRoomIdAndMemberId(roomId, memberId);
        if (gmOpt.isEmpty()) return false;
        StudyRoomMember gm = gmOpt.get();
        gm.setIsDeleted(true);
        gm.setUpdateDateTime(LocalDateTime.now());
        memberRepository.save(gm);
        return true;
    }

    public List<Map<String, Object>> listMembers(String ownerId, Long roomId) {
        Optional<StudyRoom> opt = roomRepository.findById(roomId);
        if (opt.isEmpty() || !opt.get().getOwnerMemberId().equals(ownerId)) return new ArrayList<>();
        List<Map<String, Object>> list = new ArrayList<>();
        for (StudyRoomMember m : memberRepository.findByRoomIdAndIsDeletedFalseOrderByIdAsc(roomId)) {
            list.add(toMemberMap(m));
        }
        return list;
    }

    private Map<String, Object> toGroupMap(StudyRoom g, int memberCount) {
        Map<String, Object> m = new HashMap<>();
        m.put("groupId", g.getId());
        m.put("name", g.getName());
        m.put("memberCount", memberCount);
        boolean hasPassword = g.getPassword() != null && !g.getPassword().isBlank();
        m.put("hasPassword", hasPassword);
        // 소유자 본인 룸 목록(listGroups는 ownerId로 필터)이므로 잠금 해제 비교용 비밀번호를 함께 반환
        m.put("password", hasPassword ? g.getPassword() : null);
        // 멤버 권한 옵션 — 구 데이터(NULL) 방어: 대화는 허용, 파일은 차단이 기본.
        m.put("allowMemberChat", !Boolean.FALSE.equals(g.getAllowMemberChat()));
        m.put("allowMemberFile", Boolean.TRUE.equals(g.getAllowMemberFile()));
        return m;
    }

    private Map<String, Object> toMemberMap(StudyRoomMember gm) {
        Map<String, Object> m = new HashMap<>();
        m.put("memberId", gm.getMemberId());
        m.put("memberName", gm.getMemberName());
        return m;
    }
}

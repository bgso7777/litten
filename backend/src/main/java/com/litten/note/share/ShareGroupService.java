package com.litten.note.share;

import com.litten.Constants;
import com.litten.note.NoteMember;
import com.litten.note.NoteMemberRepository;
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

/** 공유 그룹 CRUD + 멤버 관리. 모두 소유자(로그인 회원) 단위. */
@Slf4j
@Service
@RequiredArgsConstructor
public class ShareGroupService {

    private final ShareGroupRepository groupRepository;
    private final ShareGroupMemberRepository memberRepository;
    private final NoteMemberRepository noteMemberRepository;

    /** 이메일/표시이름으로 회원 조회 (없으면 null). */
    NoteMember resolveMember(String key) {
        if (key == null) return null;
        String k = key.trim();
        if (k.isEmpty()) return null;
        NoteMember m = noteMemberRepository.findFirstByEmail(k);
        if (m == null) m = noteMemberRepository.findFirstByName(k);
        return m;
    }

    /** 그룹 생성 — 이름 + (선택)비밀번호 + 초기 멤버(이메일/닉네임 목록) 일괄 추가. */
    @Transactional
    public Map<String, Object> createGroup(String ownerId, String name, String password, List<String> memberKeys) {
        if (name == null || name.trim().isEmpty()) {
            throw new IllegalArgumentException("그룹 이름을 입력하세요.");
        }
        ShareGroup g = new ShareGroup();
        g.setOwnerMemberId(ownerId);
        g.setName(name.trim());
        g.setPassword(password != null && !password.isBlank() ? password.trim() : null);
        g.setIsDeleted(false);
        g.setInsertDateTime(LocalDateTime.now());
        g.setUpdateDateTime(LocalDateTime.now());
        groupRepository.save(g);

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
                ShareGroupMember gm = memberRepository
                        .findByGroupIdAndMemberId(g.getId(), member.getId())
                        .orElseGet(ShareGroupMember::new);
                gm.setGroupId(g.getId());
                gm.setMemberId(member.getId());
                gm.setMemberName(member.getName() != null ? member.getName() : member.getEmail());
                gm.setIsDeleted(false);
                if (gm.getInsertDateTime() == null) gm.setInsertDateTime(LocalDateTime.now());
                gm.setUpdateDateTime(LocalDateTime.now());
                memberRepository.save(gm);
                added++;
            }
        }
        log.info("[ShareGroupService] 그룹 생성 - owner: {}, groupId: {}, name: {}, members: {}, notFound: {}",
                ownerId, g.getId(), name, added, notFound.size());
        Map<String, Object> result = toGroupMap(g, added);
        result.put("notFound", notFound);
        return result;
    }

    public List<Map<String, Object>> listGroups(String ownerId) {
        List<ShareGroup> groups = groupRepository.findByOwnerMemberIdAndIsDeletedFalseOrderByIdDesc(ownerId);
        List<Map<String, Object>> list = new ArrayList<>();
        for (ShareGroup g : groups) {
            int count = memberRepository.findByGroupIdAndIsDeletedFalseOrderByIdAsc(g.getId()).size();
            list.add(toGroupMap(g, count));
        }
        return list;
    }

    @Transactional
    public boolean deleteGroup(String ownerId, Long groupId) {
        Optional<ShareGroup> opt = groupRepository.findById(groupId);
        if (opt.isEmpty() || !opt.get().getOwnerMemberId().equals(ownerId)) return false;
        ShareGroup g = opt.get();
        g.setIsDeleted(true);
        g.setDeletedAt(LocalDateTime.now());
        g.setUpdateDateTime(LocalDateTime.now());
        groupRepository.save(g);
        // 멤버도 정리
        for (ShareGroupMember m : memberRepository.findByGroupIdAndIsDeletedFalseOrderByIdAsc(groupId)) {
            m.setIsDeleted(true);
            m.setUpdateDateTime(LocalDateTime.now());
            memberRepository.save(m);
        }
        log.info("[ShareGroupService] 그룹 삭제 - owner: {}, groupId: {}", ownerId, groupId);
        return true;
    }

    /** 멤버 추가 (이메일/표시이름으로 회원 해석). 추가된 멤버 맵 반환, 실패 시 null. */
    @Transactional
    public Map<String, Object> addMember(String ownerId, Long groupId, String key) {
        Optional<ShareGroup> opt = groupRepository.findById(groupId);
        if (opt.isEmpty() || !opt.get().getOwnerMemberId().equals(ownerId) || Boolean.TRUE.equals(opt.get().getIsDeleted())) {
            return null; // 그룹 없음/권한 없음
        }
        NoteMember member = resolveMember(key);
        if (member == null) return null; // 회원 없음

        Optional<ShareGroupMember> existing = memberRepository.findByGroupIdAndMemberId(groupId, member.getId());
        ShareGroupMember gm = existing.orElseGet(ShareGroupMember::new);
        gm.setGroupId(groupId);
        gm.setMemberId(member.getId());
        gm.setMemberName(member.getName() != null ? member.getName() : member.getEmail());
        gm.setIsDeleted(false);
        if (gm.getInsertDateTime() == null) gm.setInsertDateTime(LocalDateTime.now());
        gm.setUpdateDateTime(LocalDateTime.now());
        memberRepository.save(gm);
        log.info("[ShareGroupService] 멤버 추가 - groupId: {}, memberId: {}", groupId, member.getId());
        return toMemberMap(gm);
    }

    @Transactional
    public boolean removeMember(String ownerId, Long groupId, String memberId) {
        Optional<ShareGroup> opt = groupRepository.findById(groupId);
        if (opt.isEmpty() || !opt.get().getOwnerMemberId().equals(ownerId)) return false;
        Optional<ShareGroupMember> gmOpt = memberRepository.findByGroupIdAndMemberId(groupId, memberId);
        if (gmOpt.isEmpty()) return false;
        ShareGroupMember gm = gmOpt.get();
        gm.setIsDeleted(true);
        gm.setUpdateDateTime(LocalDateTime.now());
        memberRepository.save(gm);
        return true;
    }

    public List<Map<String, Object>> listMembers(String ownerId, Long groupId) {
        Optional<ShareGroup> opt = groupRepository.findById(groupId);
        if (opt.isEmpty() || !opt.get().getOwnerMemberId().equals(ownerId)) return new ArrayList<>();
        List<Map<String, Object>> list = new ArrayList<>();
        for (ShareGroupMember m : memberRepository.findByGroupIdAndIsDeletedFalseOrderByIdAsc(groupId)) {
            list.add(toMemberMap(m));
        }
        return list;
    }

    private Map<String, Object> toGroupMap(ShareGroup g, int memberCount) {
        Map<String, Object> m = new HashMap<>();
        m.put("groupId", g.getId());
        m.put("name", g.getName());
        m.put("memberCount", memberCount);
        return m;
    }

    private Map<String, Object> toMemberMap(ShareGroupMember gm) {
        Map<String, Object> m = new HashMap<>();
        m.put("memberId", gm.getMemberId());
        m.put("memberName", gm.getMemberName());
        return m;
    }
}

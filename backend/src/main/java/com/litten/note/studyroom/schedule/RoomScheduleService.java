package com.litten.note.studyroom.schedule;

import com.litten.note.NoteMember;
import com.litten.note.NoteMemberRepository;
import com.litten.note.selfroom.SelfStudyRoom;
import com.litten.note.selfroom.SelfStudyRoomRepository;
import com.litten.note.studyroom.StudyRoom;
import com.litten.note.studyroom.StudyRoomMember;
import com.litten.note.studyroom.StudyRoomMemberRepository;
import com.litten.note.studyroom.StudyRoomRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * 셀 일정 서비스. 세 종류의 셀을 모두 지원한다.
 *
 *   group : note_study_room       — 방장/멤버 전원의 캘린더에 표시
 *   self  : note_self_study_room  — 본인만
 *   user  : 1:1 (전용 테이블 없음) — 작성자와 상대 둘 다
 *
 * 권한:
 *   group : 방장은 항상 가능, 멤버는 allowMemberSchedule 이 켜진 셀에서만
 *   self  : 본인만
 *   user  : 양쪽 다 가능(1:1에는 권한 옵션이 없다)
 *   수정/삭제는 어느 종류든 일정을 만든 사람만.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class RoomScheduleService {

    public static final String TARGET_GROUP = "group";
    public static final String TARGET_SELF = "self";
    public static final String TARGET_USER = "user";

    private final RoomScheduleRepository scheduleRepository;
    private final StudyRoomRepository roomRepository;
    private final StudyRoomMemberRepository memberRepository;
    private final SelfStudyRoomRepository selfRoomRepository;
    private final NoteMemberRepository noteMemberRepository;

    /** 셀 일정 생성. 권한/대상이 잘못되면 IllegalArgumentException. */
    @Transactional
    public Map<String, Object> create(String memberId, String targetType, Long roomId,
                                      Long selfRoomId, String peerKey, String title,
                                      LocalDate scheduleDate, LocalDate endDate,
                                      LocalTime startTime, LocalTime endTime, String notes,
                                      String notificationRules, LocalTime notificationStartTime,
                                      LocalTime notificationEndTime, Integer colorIndex) {
        if (title == null || title.trim().isEmpty()) {
            throw new IllegalArgumentException("일정 제목을 입력하세요.");
        }
        if (scheduleDate == null || startTime == null || endTime == null) {
            throw new IllegalArgumentException("일정 날짜와 시간을 입력하세요.");
        }
        String type = (targetType == null || targetType.isBlank()) ? TARGET_GROUP : targetType.trim();

        RoomSchedule s = new RoomSchedule();
        s.setTargetType(type);

        switch (type) {
            case TARGET_GROUP -> {
                if (roomId == null) throw new IllegalArgumentException("셀을 지정해 주세요.");
                StudyRoom room = activeRoom(roomId);
                boolean isOwner = room.getOwnerMemberId().equals(memberId);
                boolean isMember = memberRepository.findByRoomIdAndMemberId(roomId, memberId).isPresent();
                if (!isOwner && !isMember) {
                    throw new IllegalArgumentException("셀 멤버만 일정을 만들 수 있습니다.");
                }
                // 방장이 '멤버 일정 생성'을 허용한 셀에서만 멤버가 만들 수 있다. (기본 차단)
                if (!isOwner && !Boolean.TRUE.equals(room.getAllowMemberSchedule())) {
                    throw new IllegalArgumentException("이 셀은 방장만 일정을 만들 수 있습니다.");
                }
                s.setRoomId(roomId);
            }
            case TARGET_SELF -> {
                if (selfRoomId == null) throw new IllegalArgumentException("셀을 지정해 주세요.");
                SelfStudyRoom self = selfRoomRepository.findById(selfRoomId).orElse(null);
                if (self == null || Boolean.TRUE.equals(self.getIsDeleted())
                        || !memberId.equals(self.getMemberId())) {
                    throw new IllegalArgumentException("셀을 찾을 수 없습니다.");
                }
                s.setSelfRoomId(selfRoomId);
            }
            case TARGET_USER -> {
                NoteMember peer = resolveMember(peerKey);
                if (peer == null) throw new IllegalArgumentException("상대를 찾을 수 없습니다.");
                if (peer.getId().equals(memberId)) {
                    throw new IllegalArgumentException("자기 자신과의 1:1 셀에는 일정을 만들 수 없습니다.");
                }
                s.setPeerMemberId(peer.getId());
            }
            default -> throw new IllegalArgumentException("알 수 없는 셀 종류입니다: " + type);
        }

        s.setCreatorMemberId(memberId);
        s.setCreatorName(displayName(memberId));
        s.setTitle(title.trim());
        s.setScheduleDate(scheduleDate);
        s.setEndDate(endDate);
        s.setStartTime(startTime);
        s.setEndTime(endTime);
        s.setNotes(notes);
        s.setNotificationRules(notificationRules);
        s.setNotificationStartTime(notificationStartTime);
        s.setNotificationEndTime(notificationEndTime);
        s.setColorIndex(colorIndex != null ? colorIndex : 0);
        s.setIsDeleted(false);
        // JPA Auditing 미사용 — 등록/수정 일시를 직접 채운다.
        s.setInsertDateTime(LocalDateTime.now());
        s.setUpdateDateTime(LocalDateTime.now());
        scheduleRepository.save(s);

        log.info("[RoomScheduleService] 셀 일정 생성 - type: {}, creator: {}, scheduleId: {}, title: {}",
                type, memberId, s.getId(), s.getTitle());
        return toPayload(s);
    }

    /** 내가 볼 수 있는 모든 셀 일정 — 그룹/나만의/1:1을 합쳐서 반환. */
    public List<Map<String, Object>> listMine(String memberId) {
        List<Map<String, Object>> list = new ArrayList<>();

        // 1) 그룹 셀 — 내가 방장이거나 멤버인 셀
        Map<Long, StudyRoom> roomById = new HashMap<>();
        for (StudyRoom r : roomRepository.findByOwnerMemberIdAndIsDeletedFalseOrderByIdDesc(memberId)) {
            roomById.put(r.getId(), r);
        }
        for (StudyRoomMember m : memberRepository.findByMemberIdAndIsDeletedFalse(memberId)) {
            if (roomById.containsKey(m.getRoomId())) continue;
            roomRepository.findById(m.getRoomId())
                    .filter(r -> !Boolean.TRUE.equals(r.getIsDeleted()))
                    .ifPresent(r -> roomById.put(r.getId(), r));
        }
        if (!roomById.isEmpty()) {
            for (RoomSchedule s : scheduleRepository
                    .findByTargetTypeAndRoomIdInAndIsDeletedFalse(TARGET_GROUP, new ArrayList<>(roomById.keySet()))) {
                Map<String, Object> p = toPayload(s);
                StudyRoom r = roomById.get(s.getRoomId());
                if (r != null) p.put("roomName", r.getName());
                list.add(p);
            }
        }

        // 2) 나만의 셀
        Map<Long, SelfStudyRoom> selfById = new HashMap<>();
        for (SelfStudyRoom sr : selfRoomRepository.findByMemberIdAndIsDeletedFalseOrderByIdAsc(memberId)) {
            selfById.put(sr.getId(), sr);
        }
        if (!selfById.isEmpty()) {
            for (RoomSchedule s : scheduleRepository
                    .findByTargetTypeAndSelfRoomIdInAndIsDeletedFalse(TARGET_SELF, new ArrayList<>(selfById.keySet()))) {
                Map<String, Object> p = toPayload(s);
                SelfStudyRoom sr = selfById.get(s.getSelfRoomId());
                if (sr != null) p.put("roomName", sr.getName());
                list.add(p);
            }
        }

        // 3) 1:1 셀 — 내가 만든 것 + 상대가 나에게 건 것
        for (RoomSchedule s : scheduleRepository
                .findByTargetTypeAndCreatorMemberIdAndIsDeletedFalse(TARGET_USER, memberId)) {
            Map<String, Object> p = toPayload(s);
            p.put("roomName", displayName(s.getPeerMemberId()));
            list.add(p);
        }
        for (RoomSchedule s : scheduleRepository
                .findByTargetTypeAndPeerMemberIdAndIsDeletedFalse(TARGET_USER, memberId)) {
            Map<String, Object> p = toPayload(s);
            p.put("roomName", s.getCreatorName());
            list.add(p);
        }

        list.sort((a, b) -> {
            String da = String.valueOf(a.get("date")) + a.get("startTime");
            String db = String.valueOf(b.get("date")) + b.get("startTime");
            return da.compareTo(db);
        });
        log.info("[RoomScheduleService] 셀 일정 조회 - member: {}, schedules: {}", memberId, list.size());
        return list;
    }

    /** 일정 수정 — 작성자 본인 또는 (그룹 셀) 방장. 대상 없음/권한 없음이면 null. */
    @Transactional
    public Map<String, Object> update(String memberId, Long scheduleId, String title,
                                      LocalDate scheduleDate, LocalDate endDate,
                                      LocalTime startTime, LocalTime endTime, String notes,
                                      String notificationRules, LocalTime notificationStartTime,
                                      LocalTime notificationEndTime, Integer colorIndex) {
        Optional<RoomSchedule> opt = scheduleRepository.findById(scheduleId);
        if (opt.isEmpty() || Boolean.TRUE.equals(opt.get().getIsDeleted())) return null;
        RoomSchedule s = opt.get();
        if (!canModify(memberId, s)) return null;

        if (title != null && !title.trim().isEmpty()) s.setTitle(title.trim());
        if (scheduleDate != null) s.setScheduleDate(scheduleDate);
        s.setEndDate(endDate);
        if (startTime != null) s.setStartTime(startTime);
        if (endTime != null) s.setEndTime(endTime);
        s.setNotes(notes);
        s.setNotificationRules(notificationRules);
        s.setNotificationStartTime(notificationStartTime);
        s.setNotificationEndTime(notificationEndTime);
        if (colorIndex != null) s.setColorIndex(colorIndex);
        s.setUpdateDateTime(LocalDateTime.now());
        scheduleRepository.save(s);

        log.info("[RoomScheduleService] 셀 일정 수정 - scheduleId: {}, by: {}", scheduleId, memberId);
        return toPayload(s);
    }

    /** 일정 삭제(soft) — 작성자 본인 또는 (그룹 셀) 방장. */
    @Transactional
    public boolean delete(String memberId, Long scheduleId) {
        Optional<RoomSchedule> opt = scheduleRepository.findById(scheduleId);
        if (opt.isEmpty() || Boolean.TRUE.equals(opt.get().getIsDeleted())) return false;
        RoomSchedule s = opt.get();
        if (!canModify(memberId, s)) return false;

        s.setIsDeleted(true);
        s.setDeletedAt(LocalDateTime.now());
        s.setUpdateDateTime(LocalDateTime.now());
        scheduleRepository.save(s);
        log.info("[RoomScheduleService] 셀 일정 삭제 - scheduleId: {}, by: {}", scheduleId, memberId);
        return true;
    }

    /** 수정/삭제는 일정을 만든 사람만 가능하다(방장도 남의 일정은 건드리지 못한다). */
    private boolean canModify(String memberId, RoomSchedule s) {
        if (memberId.equals(s.getCreatorMemberId())) return true;
        log.info("[RoomScheduleService] 셀 일정 변경 권한 없음 - scheduleId: {}, by: {}", s.getId(), memberId);
        return false;
    }

    private StudyRoom activeRoom(Long roomId) {
        StudyRoom room = roomRepository.findById(roomId).orElse(null);
        if (room == null || Boolean.TRUE.equals(room.getIsDeleted())) {
            throw new IllegalArgumentException("셀을 찾을 수 없습니다.");
        }
        return room;
    }

    /** 이메일 → 소문자 이메일 → 회원 ID → 표시이름 순으로 상대를 찾는다.
     *  (StudyRoomService.resolveMember 와 같은 규칙 — 프론트가 넘기는 키 형태가 동일하다.) */
    private NoteMember resolveMember(String key) {
        if (key == null || key.trim().isEmpty()) return null;
        String k = key.trim();
        NoteMember m = noteMemberRepository.findFirstByEmail(k);
        if (m == null) m = noteMemberRepository.findFirstByEmail(k.toLowerCase());
        if (m == null) m = noteMemberRepository.findById(k).orElse(null);
        if (m == null) m = noteMemberRepository.findFirstByName(k);
        return m;
    }

    private String displayName(String memberId) {
        if (memberId == null) return null;
        NoteMember m = noteMemberRepository.findById(memberId).orElse(null);
        if (m == null) return null;
        return m.getName() != null ? m.getName() : m.getEmail();
    }

    /** 프론트가 개인 일정과 같은 모양으로 다룰 수 있도록 평평한 Map 으로 변환. */
    private Map<String, Object> toPayload(RoomSchedule s) {
        Map<String, Object> m = new HashMap<>();
        m.put("scheduleId", s.getId());
        m.put("targetType", s.getTargetType());
        m.put("roomId", s.getRoomId());
        m.put("selfRoomId", s.getSelfRoomId());
        m.put("peerMemberId", s.getPeerMemberId());
        m.put("creatorMemberId", s.getCreatorMemberId());
        m.put("creatorName", s.getCreatorName());
        m.put("title", s.getTitle());
        m.put("date", s.getScheduleDate() != null ? s.getScheduleDate().toString() : null);
        m.put("endDate", s.getEndDate() != null ? s.getEndDate().toString() : null);
        m.put("startTime", s.getStartTime() != null ? s.getStartTime().toString() : null);
        m.put("endTime", s.getEndTime() != null ? s.getEndTime().toString() : null);
        m.put("notes", s.getNotes());
        m.put("colorIndex", s.getColorIndex());
        m.put("notificationRules", s.getNotificationRules());
        m.put("notificationStartTime",
                s.getNotificationStartTime() != null ? s.getNotificationStartTime().toString() : null);
        m.put("notificationEndTime",
                s.getNotificationEndTime() != null ? s.getNotificationEndTime().toString() : null);
        m.put("updatedAt", s.getUpdateDateTime() != null ? s.getUpdateDateTime().toString() : null);
        return m;
    }
}

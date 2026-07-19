package com.litten.note.studyroom.schedule;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface RoomScheduleRepository extends JpaRepository<RoomSchedule, Long> {

    /** 그룹 셀 여러 개의 일정 — 내가 방장이거나 멤버인 셀들. */
    List<RoomSchedule> findByTargetTypeAndRoomIdInAndIsDeletedFalse(String targetType, List<Long> roomIds);

    /** 나만의 셀 일정 — 내 셀프룸들. */
    List<RoomSchedule> findByTargetTypeAndSelfRoomIdInAndIsDeletedFalse(String targetType, List<Long> selfRoomIds);

    /** 1:1 셀 일정 — 내가 만든 것. */
    List<RoomSchedule> findByTargetTypeAndCreatorMemberIdAndIsDeletedFalse(String targetType, String creatorMemberId);

    /** 1:1 셀 일정 — 상대가 나에게 건 것. */
    List<RoomSchedule> findByTargetTypeAndPeerMemberIdAndIsDeletedFalse(String targetType, String peerMemberId);
}

package com.litten.note.studyroom.message;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface RoomMessageRepository extends JpaRepository<RoomMessage, Long> {

    // 내가 보낸 메시지 (최신순)
    List<RoomMessage> findBySenderMemberIdAndIsDeletedFalseOrderByIdDesc(String senderMemberId);

    /** 룸 이름 변경 시 과거 메시지의 group_name 스냅샷 갱신(대화 묶음 유지). */
    @Modifying
    @Query("update RoomMessage m set m.groupName = :name where m.roomId = :roomId")
    int renameGroup(@Param("roomId") Long roomId, @Param("name") String name);

    /** 회원 탈퇴 — 내가 보낸 메시지를 삭제하지 않고 '발신자 탈퇴'로 표시(수신자 화면 보존). */
    @Modifying
    @org.springframework.transaction.annotation.Transactional
    @Query("update RoomMessage m set m.senderWithdrawn = true where m.senderMemberId = :memberId")
    int markSenderWithdrawn(@Param("memberId") String memberId);
}

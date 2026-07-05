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
}

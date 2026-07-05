package com.litten.note.studyroom;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface RoomShareRepository extends JpaRepository<RoomShare, Long> {

    List<RoomShare> findBySenderMemberIdAndIsDeletedFalseOrderByIdDesc(String senderMemberId);

    /** 룸 이름 변경 시 과거 공유의 group_name 스냅샷 갱신(대화 묶음 유지). */
    @Modifying
    @Query("update RoomShare f set f.groupName = :name where f.roomId = :roomId")
    int renameGroup(@Param("roomId") Long roomId, @Param("name") String name);
}

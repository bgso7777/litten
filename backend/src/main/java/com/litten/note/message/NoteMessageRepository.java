package com.litten.note.message;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface NoteMessageRepository extends JpaRepository<NoteMessage, Long> {

    // 내가 보낸 메시지 (최신순)
    List<NoteMessage> findBySenderMemberIdAndIsDeletedFalseOrderByIdDesc(String senderMemberId);

    /** 그룹 이름 변경 시 과거 메시지의 group_name 스냅샷 갱신(대화 묶음 유지). */
    @Modifying
    @Query("update NoteMessage m set m.groupName = :name where m.groupId = :groupId")
    int renameGroup(@Param("groupId") Long groupId, @Param("name") String name);
}

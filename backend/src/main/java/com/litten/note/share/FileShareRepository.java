package com.litten.note.share;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface FileShareRepository extends JpaRepository<FileShare, Long> {

    List<FileShare> findBySenderMemberIdAndIsDeletedFalseOrderByIdDesc(String senderMemberId);

    /** 그룹 이름 변경 시 과거 공유의 group_name 스냅샷 갱신(대화 묶음 유지). */
    @Modifying
    @Query("update FileShare f set f.groupName = :name where f.groupId = :groupId")
    int renameGroup(@Param("groupId") Long groupId, @Param("name") String name);
}

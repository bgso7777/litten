package com.litten.note.selfroom;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface SelfStudyRoomItemRepository extends JpaRepository<SelfStudyRoomItem, Long> {

    List<SelfStudyRoomItem> findByRoomIdAndIsDeletedFalseOrderByIdAsc(Long roomId);
}

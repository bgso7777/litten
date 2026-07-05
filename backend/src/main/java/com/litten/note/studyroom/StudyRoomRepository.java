package com.litten.note.studyroom;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface StudyRoomRepository extends JpaRepository<StudyRoom, Long> {

    List<StudyRoom> findByOwnerMemberIdAndIsDeletedFalseOrderByIdDesc(String ownerMemberId);
}

package com.litten.note.studyroom;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface StudyRoomMemberRepository extends JpaRepository<StudyRoomMember, Long> {

    List<StudyRoomMember> findByRoomIdAndIsDeletedFalseOrderByIdAsc(Long roomId);

    Optional<StudyRoomMember> findByRoomIdAndMemberId(Long roomId, String memberId);
}

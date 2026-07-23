package com.litten.note.aichat;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

public interface AiChatRepository extends JpaRepository<AiChat, Long> {

    List<AiChat> findByMemberIdAndIsDeletedFalseOrderByUpdateDateTimeDesc(String memberId);

    Optional<AiChat> findByMemberIdAndClientId(String memberId, String clientId);

    // 회원 탈퇴 — 회원의 AI 셀 전체 삭제
    @Transactional
    void deleteByMemberId(String memberId);
}

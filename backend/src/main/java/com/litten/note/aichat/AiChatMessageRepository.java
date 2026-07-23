package com.litten.note.aichat;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

public interface AiChatMessageRepository extends JpaRepository<AiChatMessage, Long> {

    /** 방의 전체 메시지(오름차순 = 대화 순서). 화면 표시용. */
    List<AiChatMessage> findByChatIdAndIsDeletedFalseOrderByIdAsc(Long chatId);

    /** 러닝요약에 아직 접히지 않은(= id > summarizedMsgId) 메시지들. AI 전송 윈도우 계산용. */
    List<AiChatMessage> findByChatIdAndIsDeletedFalseAndIdGreaterThanOrderByIdAsc(Long chatId, Long afterId);

    /** 방 삭제 시 메시지 일괄 소프트삭제는 서비스에서 처리. 회원 탈퇴용 물리삭제. */
    @Transactional
    void deleteByChatId(Long chatId);

    @Transactional
    void deleteByMemberId(String memberId);
}

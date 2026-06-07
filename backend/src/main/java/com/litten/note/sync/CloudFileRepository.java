package com.litten.note.sync;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface CloudFileRepository extends JpaRepository<CloudFile, Long> {

    // 전체 조회 (삭제 tombstone 포함) — 초기/전체 동기화. 다른 기기의 삭제를 전파하려면 삭제 항목도 내려줘야 한다.
    List<CloudFile> findByMemberId(String memberId, Pageable pageable);

    // 증분 조회 (삭제 tombstone 포함) — since 이후 서버에서 변경(수정/삭제)된 파일.
    List<CloudFile> findByMemberIdAndUpdateDateTimeAfter(String memberId, LocalDateTime since, Pageable pageable);

    // localId 단건 조회 (삭제 포함) — 업서트/재활성화(수정 우선) 경로에서 사용.
    Optional<CloudFile> findByMemberIdAndLocalId(String memberId, String localId);
}

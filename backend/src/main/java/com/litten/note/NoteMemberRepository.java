package com.litten.note;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface NoteMemberRepository extends JpaRepository<NoteMember,String> {

    NoteMember findByIdAndState(String id, String state);

    NoteMember findByUuidAndState(String uuid, String state);

    NoteMember findByIdAndUuidAndState(String id, String uuid, String state);

    List<NoteMember> findByUuid(String uuid);

    // 소셜 로그인 — 제공자+제공자 고유ID(sub)로 계정 조회
    NoteMember findFirstByProviderAndProviderIdAndState(String provider, String providerId, String state);

    // 사용자 간 공유 — 수신자 조회(이메일/표시이름). 첫 일치 1건.
    NoteMember findFirstByEmail(String email);

    NoteMember findFirstByName(String name);

    @Override
    Page<NoteMember> findAll(Pageable pageable);

    @Override
    void deleteById(String id);

    @Query(nativeQuery=true, value="DELETE FROM note_member WHERE uuid=:uuid")
    void deleteByUuid(@Param("uuid") String uuid);

    @Override
    <S extends NoteMember> S save(S s);

}

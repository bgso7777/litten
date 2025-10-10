package com.litten.note;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface NoteMemberRepository extends JpaRepository<NoteMember,String> {

    NoteMember findByIdAndState(String id, String state);

    NoteMember findByUuidAndState(String uuid, String state);

    NoteMember findByIdAndUuidAndState(String id, String uuid, String state);

    List<NoteMember> findByUuid(String uuid);

    @Override
    Page<NoteMember> findAll(Pageable pageable);

    @Override
    void deleteById(String id);

    @Override
    <S extends NoteMember> S save(S s);

}

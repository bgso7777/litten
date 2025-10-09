package com.litten.note;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface NoteMemberRepository extends JpaRepository<NoteMember,String> {

    NoteMember findByIdAndStateCode(String id, String stateCode);

    @Override
    Page<NoteMember> findAll(Pageable pageable);

    @Override
    void deleteById(String id);

    @Override
    <S extends NoteMember> S save(S s);

}

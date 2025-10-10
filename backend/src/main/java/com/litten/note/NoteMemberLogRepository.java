package com.litten.note;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface NoteMemberLogRepository extends JpaRepository<NoteMemberLog,Integer> {

    NoteMemberLog findByIdAndState(String id, String state);

    NoteMemberLog findByUuidAndState(String uuid, String state);

    NoteMemberLog findByIdAndUuidAndState(String id, String uuid, String state);

    @Override
    Page<NoteMemberLog> findAll(Pageable pageable);

    @Override
    void deleteById(Integer id);

    @Override
    <S extends NoteMemberLog> S save(S entity);
}

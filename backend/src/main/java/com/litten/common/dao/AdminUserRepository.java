package com.litten.common.dao;

import com.litten.common.domain.AdminUser;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AdminUserRepository extends JpaRepository<AdminUser, Long> {
    AdminUser findByLoginId(String loginId);
    AdminUser findByUuid(String uuid);
}
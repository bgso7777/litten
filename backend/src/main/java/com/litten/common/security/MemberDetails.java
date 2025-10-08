package com.litten.common.security;

import lombok.Getter;
import lombok.ToString;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.userdetails.User;

import java.util.Collection;

@ToString
public class MemberDetails extends User {
    @Getter
    private final String realName;

    public MemberDetails(String realName, String username, String password, Collection<? extends GrantedAuthority> authorities) {
        super(username, password, authorities);
        this.realName = realName;
    }
}
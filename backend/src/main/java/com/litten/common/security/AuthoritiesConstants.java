package com.litten.common.security;

import org.springframework.security.core.authority.SimpleGrantedAuthority;

/**
 * Constants for Spring Security authorities.
 */
public final class AuthoritiesConstants {

    public static final String ANONYMOUS                    = "ANONYMOUS";

    public static final String MEMBER_ADMIN_ADMIN           = "MEMBER_ADMIN_ADMIN";
    public static final String MEMBER_ADMIN_MANAGEMENT      = "MEMBER_ADMIN_MANAGEMENT";
    public static final String MEMBER_ADMIN_VIEWER          = "MEMBER_ADMIN_VIEWER";

    public static final String MEMBER_INDIVIDUAL            = "MEMBER_INDIVIDUAL";
    public static final String MEMBER_INDIVIDUAL_MASTER     = "MEMBER_INDIVIDUAL_MASTER";
    public static final String MEMBER_COMPANY               = "MEMBER_COMPANY";
    public static final String MEMBER_COMPANY_MASTER        = "MEMBER_COMPANY_MASTER";

    public static final SimpleGrantedAuthority ROLE_ANONYMOUS                   = new SimpleGrantedAuthority(ANONYMOUS);

    public static final SimpleGrantedAuthority ROLE_MEMBER_ADMIN_ADMIN          = new SimpleGrantedAuthority(MEMBER_ADMIN_ADMIN);
    public static final SimpleGrantedAuthority ROLE_MEMBER_ADMIN_MANAGEMENT     = new SimpleGrantedAuthority(MEMBER_ADMIN_MANAGEMENT);
    public static final SimpleGrantedAuthority ROLE_MEMBER_ADMIN_VIEWER         = new SimpleGrantedAuthority(MEMBER_ADMIN_VIEWER);

    public static final SimpleGrantedAuthority ROLE_MEMBER_INDIVIDUAL           = new SimpleGrantedAuthority(MEMBER_INDIVIDUAL);
    public static final SimpleGrantedAuthority ROLE_MEMBER_INDIVIDUAL_MASTER    = new SimpleGrantedAuthority(MEMBER_INDIVIDUAL_MASTER);
    public static final SimpleGrantedAuthority ROLE_MEMBER_COMPANY              = new SimpleGrantedAuthority(MEMBER_COMPANY);
    public static final SimpleGrantedAuthority ROLE_MEMBER_COMPANY_MASTER       = new SimpleGrantedAuthority(MEMBER_COMPANY_MASTER);

    private AuthoritiesConstants() {
    }
}
package com.litten.common.security;

import com.litten.Constants;
import com.litten.common.dao.AdminUserRepository;
import com.litten.common.dao.MemberRepository;
import com.litten.common.domain.AdminUser;
import com.litten.common.domain.Member;
import com.litten.common.dynamic.BeanUtil;
import lombok.extern.log4j.Log4j2;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

@Log4j2
@Service("userDetailsService")
public class MemberDetailsService implements UserDetailsService {

    public MemberDetailsService() {
    }

    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        log.debug("인증 id - {}", username);
        MemberDetails domainUserDetails = null;
        try {
            if( username.indexOf(Constants.ANONYMOUS_MEMBER_ID_PREFIX)!=-1 ) {
                Member member = new Member();
                member.setId(username.substring(username.indexOf(Constants.ANONYMOUS_MEMBER_ID_PREFIX) + Constants.ANONYMOUS_MEMBER_ID_PREFIX.length()));
                member.setName(username.substring(username.indexOf(Constants.ANONYMOUS_MEMBER_ID_PREFIX)));
                member.setPassword(Constants.ANONYMOUS_CRYPTO_PASSWORD);
                domainUserDetails = createAnonymous(username, member);
            } else if( username.indexOf(Constants.TEMP_ADMIN_MEMBER_ID_PREFIX)!=-1 ) {
                AdminUserRepository adminUserRepository = BeanUtil.getBean2(AdminUserRepository.class);
                String loginId = username.substring(username.indexOf(Constants.TEMP_ADMIN_MEMBER_ID_PREFIX)+Constants.TEMP_ADMIN_MEMBER_ID_PREFIX.length());
                AdminUser adminUser = adminUserRepository.findByLoginId(loginId);
                domainUserDetails = createMemberAdminAdmin(username, adminUser);
            } else {
                MemberRepository memberRepository = BeanUtil.getBean2(MemberRepository.class);
//                List<Member> members = memberRepository.findByMemberIdAndStatusCodeNot(username, Constants.CODE_MEMBER_STATUS_WITHDRAWAL);
                List<Member> members = memberRepository.findByIdAndStatusCodeInAndLevelCode(username, new String[]{Constants.CODE_MEMBER_STATUS_NORMAL}, Constants.CODE_LEVEL_MASTER);
                if ( members==null || members.size()==0 ) {
                    // 앞단에서 미리 id와 pw의 일치 여부를 체크 함.
                    throw new UsernameNotFoundException("User [" + username + "] was not found in the database");
                } else {
                    // 기업
                    if (members != null && members.get(0).getUserType().equals(Constants.CODE_USER_TYPE_COMPANY)) {
                        if (members.get(0).getCompanyMaster() != null && members.get(0).getCompanyMaster().equals(Constants.STRING_TRUE))
                            domainUserDetails = createMemberCompanyMaster(username, members.get(0));
                        else
                            domainUserDetails = createMemberCompany(username, members.get(0));
                    // 개인
                    } else if (members != null && members.get(0).getUserType().equals(Constants.CODE_USER_TYPE_INDIVIDUAL)) {
                        if (members.get(0).getCompanyMaster() != null && members.get(0).getCompanyMaster().equals(Constants.STRING_TRUE))
                            domainUserDetails = createMemberIndividualMaster(username, members.get(0));
                        else
                            domainUserDetails = createMemberIndividual(username, members.get(0));
                    } else {
                    }
                }
            }
        } catch (Exception e) {
            log.error("MemberDetailsService.loadUserByUsername", e);
            throw new UsernameNotFoundException("User [" + username + "] was not found in the database");
        }
        return domainUserDetails;
    }

    private MemberDetails createMemberIndividual(String login, Member member) {
        List<GrantedAuthority> authorities = new ArrayList<GrantedAuthority>() {
            {
                add(AuthoritiesConstants.ROLE_MEMBER_INDIVIDUAL);
            }
        };
        return new MemberDetails(member.getName(), member.getId(), member.getPassword(), authorities);
    }

    private MemberDetails createMemberIndividualMaster(String login, Member member) {
        List<GrantedAuthority> authorities = new ArrayList<GrantedAuthority>() {
            {
                add(AuthoritiesConstants.ROLE_MEMBER_INDIVIDUAL_MASTER);
            }
        };
        return new MemberDetails(member.getName(), member.getId(), member.getPassword(), authorities);
    }

    private MemberDetails createMemberCompany(String login, Member member) {
        List<GrantedAuthority> authorities = new ArrayList<GrantedAuthority>() {
            {
                add(AuthoritiesConstants.ROLE_MEMBER_COMPANY);
            }
        };
        return new MemberDetails(member.getName(), member.getId(), member.getPassword(), authorities);
    }

    private MemberDetails createMemberCompanyMaster(String login, Member member) {
        List<GrantedAuthority> authorities = new ArrayList<GrantedAuthority>() {
            {
                add(AuthoritiesConstants.ROLE_MEMBER_COMPANY_MASTER);
            }
        };
        return new MemberDetails(member.getName(), member.getId(), member.getPassword(), authorities);
    }


    private MemberDetails createAnonymous(String login, Member member) {
        List<GrantedAuthority> authorities = new ArrayList<GrantedAuthority>() {
            {
                add(AuthoritiesConstants.ROLE_ANONYMOUS);
            }
        };
        return new MemberDetails(member.getName(), member.getId(), member.getPassword(), authorities);
    }

    private MemberDetails createMemberAdminAdmin(String login, AdminUser adminUser) {
        List<GrantedAuthority> authorities = new ArrayList<GrantedAuthority>() {
            {
                add(AuthoritiesConstants.ROLE_MEMBER_ADMIN_ADMIN);
            }
        };
        return new MemberDetails(adminUser.getName(), adminUser.getLoginId(), adminUser.getPassword(), authorities);
    }

}
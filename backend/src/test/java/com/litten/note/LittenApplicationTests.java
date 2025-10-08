package com.litten.note;

import com.litten.common.service.MemberService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import lombok.extern.log4j.Log4j2;

@Log4j2
@SpringBootTest
class LittenApplicationTests {

    static {
        System.setProperty("LOG_DIR","./logs");
        System.setProperty("app.home","./");
        System.setProperty("spring.profiles.active","local");
    }

    @Autowired
    MemberService memberService;

    @Test
    void contextLoads() {
        this.testCallConfigManger();
    }

    void testCallConfigManger() {
//        ServiceUtil.deleteCompanyPhoneNumber(0L);
        log.debug("");
    }

}

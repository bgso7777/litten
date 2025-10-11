package com.litten.common.controller;

import com.litten.common.config.Config;
import com.litten.note.NoteMemberService;
import com.litten.common.util.FileUtil;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.litten.Constants;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.ModelAndView;

import jakarta.servlet.http.HttpServletRequest;
import java.util.*;

@Controller
public class ModelAndViewController {

    // 지원 페이지
    @CrossOrigin(origins="*", allowedHeaders="*")
    @GetMapping("/anon/svc/support/sample/html/{value1}")
    @ModelAttribute
    public ModelAndView supportSampleHtml(@PathVariable("value1") String value1) {
        ModelAndView modelAndView = new ModelAndView("support/sample/html/"+value1);
        initCommonModelAndView(modelAndView);
        return modelAndView;
    }

    // 비밀번호 변경 페이지 방문
    /**
     * send change password page
     * @param value1
     * @param value2
     * @return
     */
    @CrossOrigin(origins="*", allowedHeaders="*")
    @RequestMapping("/anon/svc/members/change-password2/{value1}/{value2}")
    public ModelAndView changePasswordStep2( @PathVariable("value1") String value1,
                                             @PathVariable("value2") String value2) {
        NoteMemberService memberService = new NoteMemberService();
        Map<String, Object> result = new HashMap<>();
        try {
            result = memberService.get(value1, value2);
        } catch(Exception e) {
            e.printStackTrace();
            result.put(Constants.TAG_RESULT,Constants.RESULT_FAIL);
        }
        ModelAndView modelAndView = new ModelAndView(Constants.PAGE_CHANGEPASSWORD_STEP2);
        initCommonModelAndView(modelAndView);
        modelAndView.addObject(Constants.TAG_RESULT, result);
        return modelAndView;
    }

    // 비밀번호 변경
    /**
     * change password
     * @param httpServletRequest
     * @return
     */
    @CrossOrigin(origins="*", allowedHeaders="*")
    @RequestMapping(value = "/anon/svc/members/change-password3")
    public ModelAndView changePasswordStep3(HttpServletRequest httpServletRequest) {
        ModelAndView modelAndView = new ModelAndView(Constants.PAGE_CHANGEPASSWORD_STEP3);
        initCommonModelAndView(modelAndView);
        NoteMemberService memberService = new NoteMemberService();
        Map<String, Object> result = new HashMap<>();
        try {
            Enumeration enumeration = httpServletRequest.getParameterNames();
            while (enumeration.hasMoreElements()) {
                String key = (String) enumeration.nextElement();
                result.put(key,httpServletRequest.getParameter(key));
            }
            ObjectMapper mapper = new ObjectMapper();
            JsonNode requestBody = mapper.valueToTree(result);
            result = memberService.put(requestBody);
        } catch(Exception e) {
            e.printStackTrace();
            result.put(Constants.TAG_RESULT,Constants.RESULT_FAIL);
        }
        modelAndView.addObject(Constants.TAG_RESULT, result);
        return modelAndView;
    }

    private ModelAndView initCommonModelAndView(ModelAndView modelAndView){
        modelAndView.addObject(Constants.TAG_PREFIX_PATH,Config.getInstance().getPrefixPath());
        modelAndView.addObject(Constants.TAG_VERSION,Config.getInstance().getVersion());
        return modelAndView;
    }
}
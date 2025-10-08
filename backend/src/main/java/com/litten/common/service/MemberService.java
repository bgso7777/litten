package com.litten.common.service;

import com.litten.common.dynamic.ConstantsDynamic;
import com.litten.common.dynamic.CustomHttpService;
import lombok.extern.log4j.Log4j2;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.Map;

@Log4j2
@Service
public class MemberService extends CustomHttpService {

    @Transactional
    public Map<String, Object> putProcessCustomCRUD(Object requestObject) throws Exception {
        Map<String, Object> result = new HashMap<>();
        result.put(ConstantsDynamic.TAG_RESULT, ConstantsDynamic.RESULT_SUCCESS);

        

        return result;
    }

}

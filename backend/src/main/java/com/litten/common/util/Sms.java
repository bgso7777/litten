package com.litten.common.util;

import com.litten.Constants;
import com.litten.common.config.Config;
import com.mashape.unirest.http.HttpResponse;
import com.mashape.unirest.http.JsonNode;
import com.mashape.unirest.http.Unirest;
import lombok.extern.log4j.Log4j2;
import org.json.simple.JSONObject;

@Log4j2
public class Sms {

    public static int sendRetrieveDnis(String mobile, String dnis, String siteLanCd) {

        int result = Constants.RESULT_SUCCESS;

        JSONObject body = new JSONObject();
        body.put("fkCompany", 0);
        body.put("solutionType", "B11");
        body.put("notiCheckType", "CUSTOMER");
        body.put("msgType", "B1001");
        body.put("templateCode", "aicesvc010");
        body.put("fkCallId", mobile);
        body.put("reserveDt", "00000000000000");
        body.put("idFrom", "15336116");
        body.put("idTo", mobile);
        if( siteLanCd.equals("KR") )
            body.put("body", "[플루닛] 손비서 AI 전용 번호("+dnis+")가 이용약관 제8조에 따라 3개월간 사용 기록이 없어 회수되었습니다.");
        else
            body.put("body", "[Ploonet] The dedicated number("+dnis+") for the Handy Secretary AI Assistant has been retrieved in accordance with the terms and conditions. ");
        body.put("payYn", "N");

        try {
            HttpResponse<JsonNode> response = null;
            response = Unirest.post(Config.getInstance().getMessageUrl())
                    .header("Content-Type", "application/json")
                    .body(body.toJSONString())
                    .asJson();
            if (response.getStatus() == 200) {
                com.mashape.unirest.http.JsonNode jsonNode = response.getBody();
                if (((String) jsonNode.getObject().get(Constants.TAG_RESULT)).equalsIgnoreCase("Y")) {
                    result = Constants.RESULT_SUCCESS;
                } else {
                    result = Constants.RESULT_FAIL;
                }
            } else {
                result = response.getStatus();
            }
        } catch (Exception e) {
            log.error(e);
        }

        return result;
    }

}

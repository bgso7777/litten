package com.litten.common.util;

import com.litten.Constants;
import com.litten.common.config.Config;
import com.mashape.unirest.http.HttpResponse;
import com.mashape.unirest.http.JsonNode;
import com.mashape.unirest.http.Unirest;
import lombok.extern.log4j.Log4j2;
import org.json.simple.JSONObject;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;

@Log4j2
public class TalkAlert {

//    public static int sendRetrieveDnis(String mobile, String dnis, String siteLanCd) {
//
//        int result = Constants.RESULT_SUCCESS;
//
//        JSONObject body = new JSONObject();
//        body.put("fkCompany", 0);
//        body.put("solutionType", "B11");
//        body.put("notiCheckType", "CUSTOMER");
//        body.put("msgType", "B1001");
//        body.put("templateCode", "aicesvc010");
//        body.put("fkCallId", mobile);
//        body.put("reserveDt", "00000000000000");
//        body.put("idFrom", "15336116");
//        body.put("idTo", mobile);
//        if( siteLanCd.equals("KR") )
//            body.put("body", "[플루닛] 손비서 AI 전용 번호("+dnis+")가 이용약관 제8조에 따라 3개월간 사용 기록이 없어 회수되었습니다.");
//        else
//            body.put("body", "[Ploonet] The dedicated number("+dnis+") for the Handy Secretary AI Assistant has been retrieved in accordance with the terms and conditions. ");
//        body.put("payYn", "N");
//
//        try {
//            HttpResponse<JsonNode> response = null;
//            response = Unirest.post(Config.getInstance().getMessageUrl())?
//                    .header("Content-Type", "application/json")
//                    .body(body.toJSONString())
//                    .asJson();
//            if (response.getStatus() == 200) {
//                JsonNode jsonNode = response.getBody();
//                if (((String) jsonNode.getObject().get(Constants.TAG_RESULT)).equalsIgnoreCase("Y")) {
//                    result = Constants.RESULT_SUCCESS;
//                } else {
//                    result = Constants.RESULT_FAIL;
//                }
//            } else {
//                result = response.getStatus();
//            }
//        } catch (Exception e) {
//            log.error(e);
//        }
//
//        return result;
//    }


//    ploonet.msg.api.url=http://10.0.131.55:8282/aice/msggw

    public int sendRetrieveDnis(String mobile, String dnis, String siteLanCd) {

        int result = Constants.RESULT_SUCCESS;

        JSONObject body = new JSONObject();

        body.put("channelType", "voice");
        body.put("msgType", "B1001");;
        body.put("noticeCheckType", "CUSTOMER");
        body.put("actCode", "B1532");
        body.put("templateCode", "aihandy002");

        body.put("svcType", "BULK_PLAN");
        body.put("jobCode", "OBC-"+LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMddHHmmss"))+"-"+dnis);

        body.put("title", "손비서 번호 회수 안내");
        StringBuffer bodyData = new StringBuffer("abcefghijk~z");
//        bodyData.append("[알림] 손비서 AI 비서 번호 회수 안내\r\n\r\n");
//        bodyData.append("안녕하세요. 손비서입니다.\r\n\r\n");
//        bodyData.append("손비서 이용약관 제8조에 따라, 최근 3개월 동안 사용 기록이 없는 전화번호는 자동 회수 대상이 됩니다.\r\n");
//        bodyData.append("이에 따라 고객님께서 보유하셨던 손비서 번호가 회수되었음을 안내드립니다.\r\n\r\n");
//        bodyData.append("• 회수 번호 : "+dnis+"\r\n");
//        bodyData.append("• 회수 일자 : "+LocalDate.now().format(DateTimeFormatter.ofPattern("yyyyMMdd"))+"\r\n\r\n");
//        bodyData.append("번호가 회수됨에 따라 해당 번호로의 손비서 서비스 이용이 불가합니다.\r\n");
//        bodyData.append("계속해서 손비서 서비스를 이용하시려면 [1:1 문의글 남기기]를 통해 말씀해주세요.\r\n\r\n");
//        bodyData.append("궁금한 사항이 있으시면 언제든지 문의해 주세요.\r\n\r\n");
//        bodyData.append("감사합니다.\r\n");
//        bodyData.append("손비서 팀 드림");
        body.put("body", bodyData.toString());

        body.put("fkCompany", 8314);
        body.put("solutionType", "B11");
        body.put("idFrom", "15336116");

        body.put("idsTo", mobile);

        LocalDate reserveDate = LocalDate.now();
        LocalTime reserveTime = LocalTime.of(11,30,0);
        String reserveDt = reserveDate.format(DateTimeFormatter.ofPattern("yyyyMMdd"))+reserveTime.format(DateTimeFormatter.ofPattern("HHmmss"));
        body.put("reserveDt", "00000000000000"); // 00000000000000 즉시

        String bodyString = body.toJSONString();
        String url = Config.getInstance().getMessageKakaoUrl() + "/messages/v1/send/bulk/kakao";
//        try {
//            HttpResponse<JsonNode> response = null;
//            response = Unirest.post(url)
//                    .header("Content-Type", "application/json")
//                    .body(bodyString)
//                    .asJson();
//            if ( response.getStatus()==200 ) {
//                JsonNode jsonNode = response.getBody();
//                if (((String) jsonNode.getObject().get(Constants.TAG_RESULT)).equalsIgnoreCase("Y")) {
//                    result = Constants.RESULT_SUCCESS;
//                } else {
//                    result = Constants.RESULT_FAIL;
//                }
//            } else {
//                result = response.getStatus();
//            }
//        } catch (Exception e) {
//            log.error(e);
//        }
        try {
            HttpResponse<JsonNode> response = null;
            response = Unirest.post(url)
                    .header("Content-Type", "application/json")
                    .body(body)
                    .asJson();
            org.json.JSONObject jsonResponse = response.getBody().getObject();
            if ( response.getStatus()==200 ) {
                result = Constants.RESULT_SUCCESS;
            } else {
                result = Constants.RESULT_FAIL;
            }
//            resultMap.put("status", jsonResponse);
            log.info("AlimTalkSend res: {}", jsonResponse.toString());
        } catch (Exception e) {
            log.error("AlimTalkSend error: {}", e);
//            resultMap.put("status", null);
            result = Constants.RESULT_FAIL;
        }

        return result;
    }

    public Integer alertKakaoBulk(Long fkCompany, String solutionType, String noticeCheckType, String msgType, String actCode, String templateCode, String channelType, String idFrom, String [] idTo, String title, String bodyMsg, String reserveDt, String svcType, String jobCode) throws Exception {

        int result = Constants.RESULT_SUCCESS;
        org.json.JSONObject body = new org.json.JSONObject();

        body.put("fkCompany", fkCompany);
        body.put("solutionType", solutionType);
        body.put("noticeCheckType", noticeCheckType);
        body.put("msgType", msgType);
        body.put("actCode", actCode);
        body.put("templateCode", templateCode);
        body.put("channelType", channelType);
        body.put("reserveDt", reserveDt);
        body.put("idFrom", idFrom);
        body.put("idsTo", idTo);
        body.put("title", title);
        body.put("body", bodyMsg);
        body.put("svcType", svcType);
        body.put("jobCode", jobCode);

        try {
            HttpResponse<JsonNode> response = Unirest.post(Config.getInstance().getMessageKakaoUrl())
                    .header("Content-Type", "application/json")
                    .body(body)
                    .asJson();
            org.json.JSONObject jsonResponse = response.getBody().getObject();
            if ( response.getStatus()==200 ) {
                ;
            } else {
                result = response.getStatus();
            }
        } catch (Exception e) {
            log.error(e);
            result = Constants.RESULT_FAIL;
        }
        return result;
    }
}

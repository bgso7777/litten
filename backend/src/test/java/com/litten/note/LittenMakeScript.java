package com.litten.note;

import com.litten.common.util.Crypto;

public class LittenMakeScript {

    public static void main(String[] argv) {
        createWithdrawMemberScript(argv);
    }

    public static void createWithdrawMemberScript(String[] argv) {
        String memberDeleteIdcUrl = "127.0.0.1:8989/account/member";
//        String[] withdrawMemberIds = {"shcho@saltlux.com","thkim2@saltlux.com","kdh2@saltlux.com","cjpark2@saltlux.com","jaesik.nam2@saltlux.com","hyungjun.lim2@saltlux.com","2203242@saltlux.com","2203212@saltlux.com","ghpark2@saltlux.com","jhbay2@saltlux.com","2210102@saltlux.com","jmlim2@saltlux.com","sunghyun.cho2@saltlux.com","junseop.kim2@saltlux.com","jinwoo.jang2@saltlux.com","hjchoi2@saltlux.com","cho@factory.com","sh@slatlux.com","sh@slatlux.com"};
//        String[] withdrawMemberIds = {"dhlee2@saltlux.com","tony2@saltlux.com","fd_staff_id","jangsr@saltlux.com","mc@ploonet.com","cyber@ploonet.com","seri.jang2@saltlux.com","aro@hyundai.com","tory.factory@ploonet.com","jang@factory.com","landhyun28@saltlux.com","hgfdswq.esdfghjk@ploonet.com","asdf@asdf,com","teverasdvaz.factory@ploonet.com","sr@saltlux.com","seri.jang@saltlux.com","seri.jang@saltlux.com","fd_staff_id","hnlee@saltlux.com","hnlee@jiran.com","hnlee2@saltlux.com","lee@factory.com","hnlee@saltlux.com","hnlee@saltlux.com","hnlee@saltlux.com","hnlee@saltlux.com","hnlee@saltlux.com","fd_staff_id","parkjw@saltlux.com","jiwon.park2@saltlux.com","park@factory.com","landhyun29@saltlux.com","parkjw@saltlux.com"};
//        String[] withdrawMemberIds = {"yms3103@naver.com"};
//        String[] withdrawMemberIds = {"wangi.kim@saltlux.com"};
        String[] withdrawMemberIds = {"qa@mcnulty.com","jooranlee98@gmail.com","goodwert@naver.com","angela_317@naver.com","jinwoo.jang@saltlux.com","sunghyun.cho@saltlux.com","dusdka1292@naver.com","danny8259@gmail.com","daeyoung.lee2@gmail.com","kimda0ljj@gmail.com","forever319@naver.com","melodik@naver.com","han21139@nate.com","bobept@hanmail.net","mch4517@hanmail.net","akdbsrb@naver.com","yu@saltlux.com","knyworld21@naver.com","savi12@naver.com","minhyuk1463@naver.com","sujinhan0422@gmail.com","kdwhoney@gmail.com","sst01_@naver.com","summer_vibeee@naver.com","jiyoon.baek@saltlux.com","jooran.lee@saltlux.com"};
        String authToken = "eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJ0ZW1wLmFkbWluaXN0cmF0b3JAcGxvb25ldC5jb20iLCJhdXRoIjoiTUVNQkVSX0FETUlOX0FETUlOIiwicmVhbF9uYW1lIjoi7Jq07JiB7J6QIiwiaXNNb2JpbGUiOmZhbHNlLCJleHAiOjE3MDkwMzc0MDh9.6dE3GqsaSlmeex5F1fbjS6EEG8huVepKMjI9SETFeaEnVfiTiuR8HZt1DfpQoM-IpR2Gxh9W7CQnTaOLT7I5yA";
        for (String memberId : withdrawMemberIds) {
            StringBuffer requestUrl = new StringBuffer("");
            requestUrl.append("curl -X PUT '" + memberDeleteIdcUrl + "/" +Crypto.encodeBase64(memberId)+ "' ");
            requestUrl.append("-H 'Content-Type: application/json' ");
            requestUrl.append("-H 'auth-token:" + authToken + "' ");
            requestUrl.append("-d '{\"statusCode\":\"A1103\",\"secessionDescription\":\"강제탈퇴\",\"secessionCode\":\"M06A01\",\"isMobile\":false}' ");
            System.out.println(requestUrl);
        }
    }

    public static void createDeleteMemberScript(String[] argv) {
        String memberDeleteIdcUrl = "127.0.0.1:8989/account/member/";
//        String[] deleteMemberIds = {"shimm23@naver.com","yend7777@gmail.com","dark.ahin@gmail.com","peilily@naver.com","lhidns@gmail.com"};
//        String[] deleteMemberIds = {"dd@dfs","eumji.moon@saltlux.com","dark.ahin@gmail.com","test04@gmail.com","shimm23@naver.com"};
//        String[] deleteMemberIds = {"anelitgel12@gmail.com"};
//        String[] deleteMemberIds = {"dark.ahin@gmail.com","biajotti.jh@gmail.com","jarave2000@paldept.com","woowonsoft3@gmail.com","ysyeng719@daum.net","mjsh1123@gmail.com","anelitgel12@gmail.com","apple_2@ploonet.com","woowonsoft4@gmail.com"};
//        String[] deleteMemberIds = {"yspsn719@gmail.com","ysysoo719@gmail.com","ysyeng719@naver.com"};
//        String[] deleteMemberIds = {"mjsh1123@gmail.com","shimm23@naver.com","yend7777@gmail.com","yend9800@gmail.com","biajott@naver.com","steve.choi@saltlux.com","steve.choi"};
//        String[] deleteMemberIds = {"support@ploonet.com","woowonsoft4@gmail.com"};
//        String[] deleteMemberIds = {"opilior@gmail.com","shimm23@naver.com","asdf@af.com","biajotti@naver.com","youmooneumji@gmail.com","alsdyd0906@naver.com","ltha1750@naver.com","teffy770812@gmail.com","lhidnsdev@gmail.com","junwoo@lee@saltlux.com","dmsgusaus2@naver.com","kefib87310@fulwark.com","dmsgusaus2@daum.net","limorbear@gmail.com","anelitgel12@gmail.com","initbyran@naver.com","kmr4766@naver.com","lhidns@gmail.com","wlsgura@hanmail.net","yend9800@gmail.com","moontest05@gmail.com","dmsgusaus33@naver.com","biajotti@naver.com","shimm23@naver.com"};
//        String[] deleteMemberIds = {"sbg7777@gmail.com","test_union_UP_20230803_0001@test.unionapi.com","test_union_UE_20230803_0001@test.unionapi.com","junwoo.lee@saltlux.com","lhidnsdev@gmail.com","ysyoo719@gmail.com","moontest05@gmail.com","shimm23@naver.com","biajotti@naver.com","ameba@naver.com","nigodif281@kkoup.com","kwangho.choi@saltlux.com","anelitgel12@gmail.com","dmsgusaus33@naver.com","landhyun49@saltulx.com","jinny100@empas.com"};
//        String[] deleteMemberIds = {"sh.han@ingpeople.com","james2h@protonmail.com"};
//        String[] deleteMemberIds = {"romey.park@saltlux.com"};
//        String[] deleteMemberIds = {"mooneumji@gmail.com","moontest06@gmail.com","mkbbm77@naver.com"};
//        String[] deleteMemberIds = {"pearty@saltlux.com","danny.kwon2@saltlux.com","eumji.moon2@saltlux.com","pearty.jung2@saltlux.com","afjsifiej@naver.com","jung@factory.com","landhyun27@saltlux.com","myjung@jiran.com","alsdyd0906@naver.com","teest@naver.com","ㅇㄹㅇ","test04@gmail.com","landhyun46@saltlux.com","moontest03@gmail.com","my@saltlux.com","pearty@saltlux.com"};
//        String[] deleteMemberIds = {"apple_1@ploonet.com","apple@ploonet.com","pangsoo@ploonet.com","ploonetsy@ploonet.com","hsygo94@gmail.com","sukyean.hong@saltlux.com","biajotti@naver.com","biajotti.jh@gmail.com","jeounghee.kim@saltlux.com"};
//        String[] deleteMemberIds = {"pearty.jung@saltlux.com","alsdyd0906@naver.com","taehoon.kim@saltlux.com","changseri@naver.com","seri@ploonet.com","dark.ahin@gmail.com","peilily@naver.com"};
//        String[] deleteMemberIds = {"arfat.laks@gmail.com","waykikisoft@gmail.com","yms3103@naver.com","sarja79@naver.com","cocojia7979@gmail.com"};
//        String[] deleteMemberIds = {"factory@ploonet.com","fory.factory@ploonet.com"};
//        String[] deleteMemberIds = {"yend7777@gmail.com","yend9800@gmail.com"};
//        String[] deleteMemberIds = {"taehoon.kim@saltlux.com"};
//        String[] deleteMemberIds = {"marinofficer@naver.com"};
//        String[] deleteMemberIds = {"moon02eumji@gmail.com","moon04eumji@gmail.com",};
//        String[] deleteMemberIds = {"moon08eumji@gmail.com","danny8259@gmail.com","sukyean.hong@saltlux.com","biajotti.jh@gmail.com","dark.ahin@gmail.com","bingjr2023@gamil.com","opilior86@gmail.com","zxcv0888@naver.com","yend7777@gmail.com","lhidns@gmail.com","teffy@nate.com","bgso777@naver.com"};
//        String[] deleteMemberIds = {"lhidns@gmail.com"};
//        String[] deleteMemberIds = {"bgso777@naver.com"};
        String[] deleteMemberIds = {"shcho@saltlux.com","thkim2@saltlux.com","kdh2@saltlux.com","cjpark2@saltlux.com","jaesik.nam2@saltlux.com","hyungjun.lim2@saltlux.com","2203242@saltlux.com","2203212@saltlux.com","ghpark2@saltlux.com","jhbay2@saltlux.com","2210102@saltlux.com","jmlim2@saltlux.com","sunghyun.cho2@saltlux.com","junseop.kim2@saltlux.com","jinwoo.jang2@saltlux.com","hjchoi2@saltlux.com","cho@factory.com","sh@slatlux.com","sh@slatlux.com"};
        String authToken = "eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJ0ZW1wLmFkbWluaXN0cmF0b3JAcGxvb25ldC5jb20iLCJhdXRoIjoiTUVNQkVSX0FETUlOX0FETUlOIiwicmVhbF9uYW1lIjoi7Jq07JiB7J6QIiwiaXNNb2JpbGUiOmZhbHNlLCJleHAiOjE3MDExNzE3MjF9.6TBdtDmwuMMui4nEW0vnj0VKzPfgergMiZ-i_HmcT6T-sMHUZhqLbRx804qpSZQLzxKTI2yMggjb29qZnc5SZw";
        for (String id : deleteMemberIds) {
            StringBuffer requestUrl = new StringBuffer("");
            requestUrl.append("curl -X DELETE '"+memberDeleteIdcUrl+ Crypto.encodeBase64(id)+"' ");
            requestUrl.append("-H 'Content-Type: application/json' ");
            requestUrl.append("-H 'auth-token:"+authToken+"' ");
            System.out.println(requestUrl);
        }
    } //

    public static void createDeleteCompanyScript(String[] argv) {
        String companyDeleteUrl = "127.0.0.1:8989/account/company/";
        String[] deleteMemberIds = {"jwpark@saltlux.com","biajotti@naver.com","shimm23@naver.com","yend7777@gmail.com","test01@gmail.com","test02@gmail.com","biajotti.jh@gmail.com"};
        String authToken = "eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJ0ZW1wLmFkbWluaXN0cmF0b3JAcGxvb25ldC5jb20iLCJhdXRoIjoiTUVNQkVSX0FETUlOX0FETUlOIiwicmVhbF9uYW1lIjoi7Jq07JiB7J6QIiwiZXhwIjoxNjg5MTk0MDM3fQ.nD6EbAQ9jhG9mkwK1xYL6ZKTLnpCSmqp14tCLY26j3wZbPyQ5P4zQfgcO-sDBAKbQ4GFpCjeFGnFbk04SE-_YA";
        for (String id : deleteMemberIds) {
            id = id.replaceAll("[@.-]","_");
            StringBuffer requestUrl = new StringBuffer("");
            requestUrl.append("curl -X DELETE '"+companyDeleteUrl+Crypto.encodeBase64(id)+"' ");
            requestUrl.append("-H 'Content-Type: application/json' ");
            requestUrl.append("-H 'auth-token:"+authToken+"' ");
            System.out.println(requestUrl);
        }
    }
}

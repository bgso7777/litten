package com.litten.common.util;

import com.litten.Constants;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

import java.util.Base64;

public class Crypto {

    /**
     * 원문 패스워드르 암호화하여 tbl_company_staff 테이블의 fd_staff_pw에 저장한다.
     * @param password 원문 패스워드
     * @return {bcrypt}+암호화 패스워드
     */
    public static String getMemberPassword(String password) {
        return "{bcrypt}"+(new BCryptPasswordEncoder()).encode(new String(password));
    }

    /**
     * 원문 패스워드를 암호화하여, 암호화된 패스워드와 비교하여 일치 여부를 판단한다.
     * @param password 원문 패스워드
     * @param encryptPassword 암호화된 패스워드 {bcrypt} 제거된
     * @return
     */
    public static boolean matchesMemberPassword(String password, String encryptPassword) {
        return new BCryptPasswordEncoder().matches(new String(password),new String(encryptPassword));
    }

    public static String encryptServerIp(String serverIp) {
        String encPassword = (new BCryptPasswordEncoder()).encode(new String(serverIp));
        return Base64.getEncoder().encodeToString(encPassword.getBytes());
    }

    public static boolean matchesServerIp(String serverIp, String encryptServerIp) {
        return new BCryptPasswordEncoder().matches(new String(serverIp),new String(Base64.getDecoder().decode(encryptServerIp)));
    }

    /**
     * TODO 암호화 해야 함
     * @param plainText
     * @return
     */
    public static String encodeIdPw(String plainText){
        return new String(Base64.getEncoder().encode(plainText.getBytes()));
    }

    /**
     * TODO 암호화 해야 함
     * @param cryptoText
     * @return
     */
    public static String decodeIdPw(String cryptoText){
        return new String(Base64.getDecoder().decode(cryptoText.getBytes()));
    }

    public static String encodeBase64(String plainText){
        return new String(Base64.getEncoder().encode(plainText.getBytes()));
    }

    public static String decodeBase64(String cryptoText){
        String ret = "";
        try {
            ret = new String(Base64.getDecoder().decode(cryptoText.getBytes()));
        } catch(IllegalArgumentException e) {
            ret = new String(Base64.getUrlDecoder().decode(cryptoText.getBytes()));
        }
        return ret;
    }

    public static String encryptChangePasswordMemberId(String plainMemberId){
        CryptoAes cryptoAes = new CryptoAes(Constants.KEY_OF_CHANGE_PASSWORD_MEMBER_ID);
        return cryptoAes.encrypt(plainMemberId);
    }

    public static String decryptChangePasswordMemberId(String cypherMemberId){
        CryptoAes cryptoAes = new CryptoAes(Constants.KEY_OF_CHANGE_PASSWORD_MEMBER_ID);
        return cryptoAes.decrypt(cypherMemberId);
    }

    public static String encryptChangePasswordDueDate(String plainYyyyMMddHHmmss){
        CryptoAes cryptoAes = new CryptoAes(Constants.KEY_OF_CHANGE_PASSWORD_MEMBER_ID);
        return cryptoAes.encrypt(plainYyyyMMddHHmmss);
    }

    public static String decryptChangePasswordDueDate(String cypherYyyyMMddHHmmss){
        CryptoAes cryptoAes = new CryptoAes(Constants.KEY_OF_CHANGE_PASSWORD_MEMBER_ID);
        return cryptoAes.decrypt(cypherYyyyMMddHHmmss);
    }

    public static void main(String args[]){
        String string = "MjAyMzA4MTYwMQ";
//System.out.println(new String(Base64.getUrlEncoder().encode("유니온api_개인_회원가입테스트_0818".getBytes())));
        try {
            System.out.println(new String(Base64.getDecoder().decode(string.getBytes())));
        } catch(IllegalArgumentException e) {
            System.out.println(new String(Base64.getUrlDecoder().decode(string.getBytes())));
        }


    }
}

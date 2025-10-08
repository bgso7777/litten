package com.litten.common.util;

import java.security.MessageDigest;
import java.security.spec.AlgorithmParameterSpec;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;

public class CryptoAes {

    private Cipher ecipher;
    private Cipher dcipher;

    public CryptoAes(){
        try{
            KeyGenerator kgen = KeyGenerator.getInstance("AES");
            kgen.init(256); // key size
            this.setupCrypto(kgen.generateKey());
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public CryptoAes(String key){
    	SecretKeySpec skey = new SecretKeySpec(getMD5(key), "AES");
        this.setupCrypto(skey);
    }

    private void setupCrypto(SecretKey key){ 
        // Create an 8-byte initialization vector 
        byte[] iv = new byte[] {
            0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09,0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f 
        };
        AlgorithmParameterSpec paramSpec = new IvParameterSpec(iv); 
        try {
            ecipher = Cipher.getInstance("AES/CBC/PKCS5Padding");//"AES/CBC/PKCS5Padding"
            dcipher = Cipher.getInstance("AES/CBC/PKCS5Padding");//"AES/CBC/PKCS5Padding"
            
            // CBC requires an initialization vector 
            ecipher.init(Cipher.ENCRYPT_MODE, key, paramSpec); 
            dcipher.init(Cipher.DECRYPT_MODE, key, paramSpec); 
        } catch (Exception e) {
            e.printStackTrace(); 
        } 
    }

    public String encrypt(String plaintext){
        if(plaintext==null||plaintext.equals(""))
            return "";
        String encryptData = plaintext;
        try {
            byte[] ciphertext = ecipher.doFinal(plaintext.getBytes("UTF-8"));
            return this.byteToHex(ciphertext);
        } catch (Exception e) {
            e.printStackTrace();
        }
        return encryptData;
    }

    public String decrypt(String hexCipherText){
    	if(hexCipherText==null||hexCipherText.equals(""))
    		return "";
    	String plaintext = hexCipherText;
        try {
        	return new String(dcipher.doFinal(this.hexToByte(hexCipherText)), "UTF-8");
        } catch (Exception e){ 
            e.printStackTrace();
        }
        return plaintext;
    }
    
    private static byte[] getMD5(String input){
        try {
            byte[] bytesOfMessage = input.getBytes("UTF-8");
            MessageDigest md = MessageDigest.getInstance("MD5");
            return md.digest(bytesOfMessage);
        } catch (Exception e) {
             return null; 
        }
    }
 
    static final String HEXES = "0123456789ABCDEF"; 
 
    public static String byteToHex( byte [] raw ) { 
        if ( raw == null ) { 
          return null; 
        } 
        final StringBuilder hex = new StringBuilder( 2 * raw.length ); 
        for ( final byte b : raw ) { 
          hex.append(HEXES.charAt((b & 0xF0) >> 4)) 
             .append(HEXES.charAt((b & 0x0F))); 
        } 
        return hex.toString(); 
    } 
 
    public static byte[] hexToByte( String hexString ) {
        int len = hexString.length(); 
        byte[] ba = new byte[len / 2]; 
        for (int i = 0; i < len; i += 2) {  
            try{   
            	ba[i/2] = (byte) ((Character.digit(hexString.charAt(i), 16) << 4) + Character.digit(hexString.charAt(i+1), 16));
            } catch(StringIndexOutOfBoundsException e){
                e.printStackTrace();
            }
        } 
        return ba; 
    }

}
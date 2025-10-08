package com.litten.common.util;

import java.io.BufferedReader;
import java.io.FileNotFoundException;
import java.io.FileReader;

public class FileUtil {

    public static StringBuffer getFileToStringBuffer(String fileName) throws FileNotFoundException {
        StringBuffer sb = new StringBuffer();
        BufferedReader pin = null;
        FileReader fin = null;

        try {
            fin = new FileReader(fileName);
            pin = new BufferedReader(fin);
            String temp = "";
            while ((temp = pin.readLine()) != null)
                sb.append(temp + "\n");
        } catch (FileNotFoundException fe) {
            throw fe;
        } catch (Exception e) {
        } finally {
            try {
                if (pin != null) pin.close();
            } catch (Exception ce) {
            }
            try {
                if (fin != null) fin.close();
            } catch (Exception ce) {
            }
        }
        return sb;
    }
}

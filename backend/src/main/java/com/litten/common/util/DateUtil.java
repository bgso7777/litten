package com.litten.common.util;

import java.text.DateFormat;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.time.LocalDateTime;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeFormatterBuilder;
import java.time.temporal.ChronoField;
import java.util.Calendar;

public class DateUtil {

    private static final DateTimeFormatter DATE_TIME_NANOSECONDS_OFFSET_FORMATTER = new DateTimeFormatterBuilder().parseCaseInsensitive().append(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
                                                                                                                  .appendFraction(ChronoField.NANO_OF_SECOND, 0, 3, true)
                                                                                                                  .appendOffset("+HH:mm", "Z")
                                                                                                                  .toFormatter();

    public static ZonedDateTime getDate(String isoString) {
        ZonedDateTime zdt = ZonedDateTime.parse(isoString, DATE_TIME_NANOSECONDS_OFFSET_FORMATTER);
        return zdt;
    }

    public static String getchangePasswordDueDate(int isecond) {
        Calendar calendar = Calendar.getInstance();
        calendar.add(Calendar.SECOND, isecond);
        SimpleDateFormat simpleDateFormat = new SimpleDateFormat("yyyyMMddHHmmss");
        return simpleDateFormat.format(calendar.getTime());
    }

    public static String getCurrentDate(String datePattern) {
        String ret = null;
        Calendar cal = Calendar.getInstance();
        try {
            SimpleDateFormat simpleDateFormat = new SimpleDateFormat(datePattern);
            ret = simpleDateFormat.format(cal.getTime());
        } catch (Exception e) {
            e.printStackTrace();
        }
        return ret;
    }

    public static LocalDateTime getLocalDateTime(String strDateTime, String strPattern) {
        LocalDateTime localDateTime = null;
        try {
            strDateTime = strDateTime.trim();
            if(!strDateTime.equals(""))
                localDateTime = LocalDateTime.parse(strDateTime, DateTimeFormatter.ofPattern(strPattern));
        } catch (Exception e) {
            e.printStackTrace();
        }
        return localDateTime;
    }

    public static boolean isDateValid(String date, String strPattern) {
        try {
            DateFormat df = new SimpleDateFormat(strPattern);
            df.setLenient(false);
            df.parse(date);
            return true;
        } catch (ParseException e) {
            return false;
        } catch (Exception e) {
            return false;
        }
    }

    public static boolean checkDateFromTo(String from, String to, String strPattern) {
        LocalDateTime fromLocalDateTime = getLocalDateTime(from, strPattern);
        LocalDateTime toLocalDateTime = getLocalDateTime(to, strPattern);
        int result = fromLocalDateTime.compareTo(toLocalDateTime);

        if(result == 0) // 동일
            return true;
        else if (result < 0) // to 이후 날짜
            return true;
        else // to 이전 날자
            return false;
    }

    public static void main(String[] argv) {
//        LocalDateTime loginDate = LocalDateTime.now();
//        ZonedDateTime zdt = loginDate.atZone(ZoneId.of("Asia/Seoul"));
//System.out.println(zdt.toInstant().toEpochMilli());

//System.out.print( getchangePasswordDueDate(60) );

System.out.println( checkDateFromTo("2023-03-28 00:00:00", "2023-03-27 00:00:00", "yyyy-MM-dd HH:mm:ss") );

    }
}

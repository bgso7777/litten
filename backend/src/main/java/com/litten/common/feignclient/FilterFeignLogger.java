package com.litten.common.feignclient;

import feign.Logger;
import lombok.extern.log4j.Log4j2;

@Log4j2
public class FilterFeignLogger extends Logger {
    @Override
    protected void log(String configKey,String format,Object... args) {
        log.info(String.format(methodTag(configKey) + format, args));
    }
}

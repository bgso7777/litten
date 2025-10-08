package com.litten.common.feignclient;

import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@FeignClient(name = "account-config-gw", url = "${server.config-manager-url}", configuration = { ConfFeign.class })
public interface ConfigMangerClient {

    @DeleteMapping(value = "v1/extensions/companies/{companySeq}", consumes = MediaType.APPLICATION_JSON_VALUE, produces = MediaType.APPLICATION_JSON_VALUE)
    Map<String, Object> clearExtensions(@PathVariable Long companySeq);

    @DeleteMapping(value = "dnis/companies/{companySeq}", consumes = MediaType.APPLICATION_JSON_VALUE, produces = MediaType.APPLICATION_JSON_VALUE)
    Map<String, Object> clearPhoneNumber(@PathVariable Long companySeq);

    /*
                String url = Config.getInstance().getConfigManagerUrl();  // http://localhost:8151/aice/configManager
            url = url + "/v1/extensions/companies/" + dnises.get(0).getCompanySeq();

            String url = Config.getInstance().getConfigManagerUrl();  // http://localhost:8151/aice/configManager /delete/{dnis}
            url = url + "/dnis/companies/" + companySequence;
     */
}

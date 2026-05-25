package com.litten.common.config;

import jakarta.annotation.PostConstruct;
import lombok.extern.log4j.Log4j2;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.yaml.snakeyaml.Yaml;

import java.io.File;
import java.nio.file.Files;
import java.util.Map;

/**
 * API 키 관리.
 * application.yml(환경변수) 우선, 값이 없으면 /home/backend/api-key 파일에서 로드.
 *
 * 파일 형식:
 * api:
 *   key:
 *     supadata: sd_xxx
 *     claude: sk-ant-xxx
 *     openai: sk-proj-xxx
 */
@Log4j2
@Component
public class ApiKeyProperties {

    private static final String API_KEY_FILE = "/home/backend/api-key";

    @Value("${supadata.api-key:}")
    private String supadataFromYml;

    @Value("${claude.api.key:}")
    private String claudeFromYml;

    @Value("${openai.api.key:}")
    private String openaiFromYml;

    private String supadataKey;
    private String claudeKey;
    private String openaiKey;

    @PostConstruct
    public void init() {
        supadataKey = supadataFromYml;
        claudeKey   = claudeFromYml;
        openaiKey   = openaiFromYml;

        if (isBlank(supadataKey) || isBlank(claudeKey) || isBlank(openaiKey)) {
            loadFromFile();
        }

        log.info("[ApiKeyProperties] supadata={}, claude={}, openai={}",
                masked(supadataKey), masked(claudeKey), masked(openaiKey));
    }

    private void loadFromFile() {
        File f = new File(API_KEY_FILE);
        if (!f.exists()) {
            log.warn("[ApiKeyProperties] API 키 파일 없음 - path: {}", API_KEY_FILE);
            return;
        }
        try {
            String content = Files.readString(f.toPath());
            Yaml yaml = new Yaml();
            Map<String, Object> root = yaml.load(content);
            Map<String, Object> keys = getNestedMap(root, "api", "key");
            if (keys == null) {
                log.warn("[ApiKeyProperties] api.key 섹션 없음 - path: {}", API_KEY_FILE);
                return;
            }

            if (isBlank(supadataKey)) {
                supadataKey = str(keys.get("supadata"));
                if (!isBlank(supadataKey)) log.info("[ApiKeyProperties] supadata 키 파일 로드 완료");
            }
            if (isBlank(claudeKey)) {
                claudeKey = str(keys.get("claude"));
                if (!isBlank(claudeKey)) log.info("[ApiKeyProperties] claude 키 파일 로드 완료");
            }
            if (isBlank(openaiKey)) {
                openaiKey = str(keys.get("openai"));
                if (!isBlank(openaiKey)) log.info("[ApiKeyProperties] openai 키 파일 로드 완료");
            }
        } catch (Exception e) {
            log.error("[ApiKeyProperties] API 키 파일 읽기 실패 - error: {}", e.getMessage());
        }
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> getNestedMap(Map<String, Object> map, String... keys) {
        Object cur = map;
        for (String key : keys) {
            if (!(cur instanceof Map)) return null;
            cur = ((Map<String, Object>) cur).get(key);
        }
        return (cur instanceof Map) ? (Map<String, Object>) cur : null;
    }

    private String str(Object v) { return v == null ? "" : v.toString().trim(); }
    private boolean isBlank(String v) { return v == null || v.isBlank(); }
    private String masked(String v) {
        if (isBlank(v)) return "(없음)";
        return v.substring(0, Math.min(10, v.length())) + "...";
    }

    public String getSupadataKey() { return supadataKey; }
    public String getClaudeKey()   { return claudeKey; }
    public String getOpenaiKey()   { return openaiKey; }
}

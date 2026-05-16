package com.litten.note.youtube;

import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Log4j2
@Component
@RequiredArgsConstructor
public class YoutubeScheduler {

    private final YoutubeService youtubeService;

    // 5분마다 실행 (앱 시작 후 1분 뒤 첫 실행)
    @Scheduled(initialDelay = 60000, fixedDelay = 300000)
    public void pollYoutubeChannels() {
        log.info("[YoutubeScheduler] 유튜브 채널 폴링 시작");
        try {
            youtubeService.pollAllChannels();
            log.info("[YoutubeScheduler] 유튜브 채널 폴링 완료");
        } catch (Exception e) {
            log.error("[YoutubeScheduler] 폴링 중 오류 발생: {}", e.getMessage(), e);
        }
    }
}

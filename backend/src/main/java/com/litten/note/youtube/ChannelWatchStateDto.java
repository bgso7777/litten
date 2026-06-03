package com.litten.note.youtube;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

/**
 * 채널 확인 상태 동기화 DTO.
 * 프론트 ChannelWatchState.toJson() 과 필드명 일치:
 *   { channelId, lastSeenAt, lastSeenVideoId, updatedAt }
 *
 * 서버 엔티티의 syncedAt ↔ 프론트 updatedAt 으로 매핑한다.
 */
@Getter
@Setter
@NoArgsConstructor
@JsonIgnoreProperties(ignoreUnknown = true)
public class ChannelWatchStateDto {

    private String channelId;
    private LocalDateTime lastSeenAt;
    private String lastSeenVideoId;
    private LocalDateTime updatedAt;   // 엔티티 syncedAt

    public static ChannelWatchStateDto of(ChannelWatchState e) {
        ChannelWatchStateDto dto = new ChannelWatchStateDto();
        dto.channelId       = e.getChannelId();
        dto.lastSeenAt      = e.getLastSeenAt();
        dto.lastSeenVideoId = e.getLastSeenVideoId();
        dto.updatedAt       = e.getSyncedAt();
        return dto;
    }
}

package com.litten.note.youtube;

import java.time.LocalDateTime;

public record YoutubeVideoSummaryDto(
    Long id,
    String channelId,
    String videoId,
    String title,
    LocalDateTime publishedAt,
    String status
) {
    public static YoutubeVideoSummaryDto from(YoutubeVideo v) {
        return new YoutubeVideoSummaryDto(
            v.getId(), v.getChannelId(), v.getVideoId(),
            v.getTitle(), v.getPublishedAt(), v.getStatus()
        );
    }
}

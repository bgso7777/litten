package com.litten.note.youtube;

import com.litten.common.dynamic.BaseEntity;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.*;
import java.io.Serializable;

/**
 * 유튜브 채널 정보 엔티티 (youtube_channel).
 * 채널 자체 정보만 보관. 멤버별 구독 설정은 MemberYoutubeChannel 에서 관리.
 */
@Getter
@Setter
@NoArgsConstructor
@Entity(name = "YoutubeChannel")
@Table(name = "youtube_channel",
    indexes = {
        @Index(name = "idx_youtube_channel_id", columnList = "channel_id")
    }
)
public class YoutubeChannel extends BaseEntity implements Serializable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id", columnDefinition = "BIGINT NOT NULL AUTO_INCREMENT COMMENT 'PK'")
    private Long id;

    @Column(name = "channel_id", nullable = false, unique = true,
            columnDefinition = "VARCHAR(64) NOT NULL COMMENT '유튜브 채널 ID'")
    private String channelId;

    @Column(name = "channel_name", nullable = false,
            columnDefinition = "VARCHAR(256) NOT NULL COMMENT '채널명'")
    private String channelName;

    @Column(name = "channel_thumbnail",
            columnDefinition = "VARCHAR(512) NULL COMMENT '채널 썸네일 URL'")
    private String channelThumbnail;
}

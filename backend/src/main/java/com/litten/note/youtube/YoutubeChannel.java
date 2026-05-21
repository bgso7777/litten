package com.litten.note.youtube;

import com.litten.common.dynamic.BaseEntity;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.*;
import java.io.Serializable;

@Getter
@Setter
@NoArgsConstructor
@Entity(name = "YoutubeChannel")
@Table(name = "youtube_channel", indexes = {
    @Index(name = "idx_youtube_channel_member_active", columnList = "member_id, is_active"),
    @Index(name = "idx_youtube_channel_member_channel", columnList = "member_id, channel_id")
})
public class YoutubeChannel extends BaseEntity implements Serializable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id", columnDefinition = "BIGINT NOT NULL AUTO_INCREMENT COMMENT 'PK'")
    private Long id;

    @Column(name = "member_id", columnDefinition = "VARCHAR(128) NOT NULL COMMENT '회원 ID'")
    private String memberId;

    @Column(name = "channel_id", columnDefinition = "VARCHAR(64) NOT NULL COMMENT '유튜브 채널 ID'")
    private String channelId;

    @Column(name = "channel_name", columnDefinition = "VARCHAR(256) NOT NULL COMMENT '채널명'")
    private String channelName;

    @Column(name = "channel_thumbnail", columnDefinition = "VARCHAR(512) NULL COMMENT '채널 썸네일 URL'")
    private String channelThumbnail;

    @Column(name = "is_active", columnDefinition = "BOOLEAN NOT NULL DEFAULT TRUE COMMENT '구독 활성 여부'")
    private Boolean isActive = true;

    @Column(name = "auto_title", columnDefinition = "BOOLEAN NOT NULL DEFAULT TRUE COMMENT '영상 제목 자동 저장'")
    private Boolean autoTitle = true;

    @Column(name = "auto_memo", columnDefinition = "BOOLEAN NOT NULL DEFAULT FALSE COMMENT '메모 자동 생성'")
    private Boolean autoMemo = false;

    @Column(name = "auto_summary", columnDefinition = "BOOLEAN NOT NULL DEFAULT FALSE COMMENT '요약 자동 생성'")
    private Boolean autoSummary = false;

    @Column(name = "summary_type", columnDefinition = "VARCHAR(32) NULL DEFAULT NULL COMMENT '요약 수준 (ONE_LINE/SHORT/NORMAL/DETAILED/FULL)'")
    private String summaryType;

    @Column(name = "auto_remind", columnDefinition = "BOOLEAN NOT NULL DEFAULT FALSE COMMENT '리마인드 자동 생성'")
    private Boolean autoRemind = false;

    @Column(name = "remind_type", columnDefinition = "VARCHAR(32) NULL DEFAULT NULL COMMENT '리마인드 종류 (ONE/THREE/FIVE/TEN/TWENTY/CUSTOM)'")
    private String remindType;

    @Column(name = "remind_custom_count", columnDefinition = "INT NULL DEFAULT NULL COMMENT '리마인드 CUSTOM 개수'")
    private Integer remindCustomCount;
}

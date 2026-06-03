package com.litten.note.youtube;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * 멤버의 유튜브 채널 구독 정보 응답 DTO.
 * YoutubeChannel(채널 정보) + MemberYoutubeChannel(구독 설정) 조합.
 */
@Getter
@Setter
@NoArgsConstructor
public class YoutubeSubscriptionDto {

    private Long   id;              // MemberYoutubeChannel.id
    private String memberId;
    private String channelId;
    private String channelName;
    private String channelThumbnail;
    private Boolean isActive;

    private Boolean autoTitle;
    private Boolean autoMemo;
    private Boolean autoSummary;
    private String  summaryType;
    private Boolean autoRemind;
    private String  remindType;
    private Integer remindCustomCount;

    public static YoutubeSubscriptionDto of(MemberYoutubeChannel sub) {
        YoutubeChannel ch = sub.getChannel();
        YoutubeSubscriptionDto dto = new YoutubeSubscriptionDto();
        dto.id               = sub.getId();
        dto.memberId         = sub.getMemberId();
        dto.channelId        = sub.getChannelId();
        dto.channelName      = ch != null ? ch.getChannelName()      : null;
        dto.channelThumbnail = ch != null ? ch.getChannelThumbnail() : null;
        dto.isActive         = sub.getIsActive();
        dto.autoTitle        = sub.getAutoTitle();
        dto.autoMemo         = sub.getAutoMemo();
        dto.autoSummary      = sub.getAutoSummary();
        dto.summaryType      = sub.getSummaryType();
        dto.autoRemind       = sub.getAutoRemind();
        dto.remindType       = sub.getRemindType();
        dto.remindCustomCount = sub.getRemindCustomCount();
        return dto;
    }
}

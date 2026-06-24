package com.litten.note.youtube;

import com.fasterxml.jackson.databind.annotation.JsonDeserialize;
import com.fasterxml.jackson.databind.annotation.JsonSerialize;
import com.fasterxml.jackson.datatype.jsr310.deser.LocalDateTimeDeserializer;
import com.fasterxml.jackson.datatype.jsr310.ser.LocalDateTimeSerializer;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

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
    private Boolean autoQuiz;
    private String  quizType;
    private Integer quizCustomCount;

    // 채널 구독(등록)일시 — 전체탭에서 채널을 "등록일 기준"으로 정렬하기 위해 내려준다.
    // (BaseEntity.insertDateTime = @CreatedDate)
    @JsonSerialize(using = LocalDateTimeSerializer.class)
    @JsonDeserialize(using = LocalDateTimeDeserializer.class)
    private LocalDateTime subscribedAt;

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
        dto.autoQuiz       = sub.getAutoQuiz();
        dto.quizType       = sub.getQuizType();
        dto.quizCustomCount = sub.getQuizCustomCount();
        dto.subscribedAt     = sub.getInsertDateTime(); // 등록일시(BaseEntity) → 전체탭 등록일 정렬용
        return dto;
    }
}

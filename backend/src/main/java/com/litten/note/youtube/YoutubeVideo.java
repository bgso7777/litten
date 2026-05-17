package com.litten.note.youtube;

import com.litten.common.dynamic.BaseEntity;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.*;
import java.io.Serializable;
import java.time.LocalDateTime;

@Getter
@Setter
@NoArgsConstructor
@Entity(name = "YoutubeVideo")
@Table(name = "youtube_video", indexes = {
    @Index(name = "idx_youtube_video_channel", columnList = "channel_id")
})
public class YoutubeVideo extends BaseEntity implements Serializable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id", columnDefinition = "BIGINT NOT NULL AUTO_INCREMENT COMMENT 'PK'")
    private Long id;

    @Column(name = "channel_id", columnDefinition = "VARCHAR(64) NOT NULL COMMENT '유튜브 채널 ID'")
    private String channelId;

    @Column(name = "video_id", columnDefinition = "VARCHAR(32) NOT NULL COMMENT '유튜브 영상 ID'", unique = true)
    private String videoId;

    @Column(name = "title", columnDefinition = "VARCHAR(512) NOT NULL COMMENT '영상 제목'")
    private String title;

    @Column(name = "published_at", columnDefinition = "DATETIME NULL COMMENT '영상 게시일시'")
    private LocalDateTime publishedAt;

    @Column(name = "transcript_text", columnDefinition = "LONGTEXT NULL COMMENT '추출된 자막 텍스트'")
    private String transcriptText;

    @Column(name = "summary", columnDefinition = "LONGTEXT NULL COMMENT 'AI 요약 결과'")
    private String summary;

    @Column(name = "status", columnDefinition = "VARCHAR(32) NOT NULL DEFAULT 'pending' COMMENT '처리 상태 (pending/done/no_transcript/error)'")
    private String status = "pending";

    @Column(name = "error_message", columnDefinition = "VARCHAR(1024) NULL COMMENT '오류 메시지'")
    private String errorMessage;

    @Column(name = "processed_at", columnDefinition = "DATETIME NULL COMMENT '처리 완료일시'")
    private LocalDateTime processedAt;
}

package com.litten.note.youtube;

import com.litten.common.dynamic.BaseEntity;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.*;
import java.io.Serializable;
import java.time.LocalDateTime;

/**
 * 채널별 "확인 상태" 엔티티 (note_channel_watch_state).
 *
 * 프론트 ChannelWatchState 모델과 1:1 매핑.
 * 사용자가 마지막으로 확인한 최신 영상 시각을 추적해 "새 영상(new)" 여부를 판단한다.
 *   - 채널 최신 영상 게시일 > last_seen_at → 새 영상 있음
 *
 * 프리미엄(로그인) 동기화 대상. (member_id, channel_id) 단위로 유일.
 * 비로그인은 프론트 로컬(SharedPreferences)에만 저장하고 서버에 올리지 않는다.
 */
@Getter
@Setter
@NoArgsConstructor
@Entity(name = "ChannelWatchState")
@Table(name = "note_channel_watch_state",
    uniqueConstraints = @UniqueConstraint(
        name = "unique_watch_member_channel",
        columnNames = {"member_id", "channel_id"}
    ),
    indexes = {
        @Index(name = "idx_watch_member", columnList = "member_id")
    }
)
public class ChannelWatchState extends BaseEntity implements Serializable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id", columnDefinition = "BIGINT NOT NULL AUTO_INCREMENT COMMENT 'PK'")
    private Long id;

    @Column(name = "member_id", nullable = false,
            columnDefinition = "VARCHAR(128) NOT NULL COMMENT '회원 ID (로그인 사용자)'")
    private String memberId;

    @Column(name = "channel_id", nullable = false,
            columnDefinition = "VARCHAR(64) NOT NULL COMMENT '유튜브 채널 ID'")
    private String channelId;

    @Column(name = "last_seen_at",
            columnDefinition = "TIMESTAMP NULL COMMENT '마지막 확인 시점의 최신 영상 게시일'")
    private LocalDateTime lastSeenAt;

    @Column(name = "last_seen_video_id",
            columnDefinition = "VARCHAR(50) NULL COMMENT '마지막 확인한 최신 영상 videoId (보조 식별)'")
    private String lastSeenVideoId;

    @Column(name = "synced_at", nullable = false,
            columnDefinition = "TIMESTAMP NOT NULL COMMENT '상태 갱신 시각 (동기화 충돌 해결 기준 — 프론트 updatedAt)'")
    private LocalDateTime syncedAt;
}

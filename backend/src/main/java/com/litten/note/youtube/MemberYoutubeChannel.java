package com.litten.note.youtube;

import com.litten.common.dynamic.BaseEntity;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.*;
import java.io.Serializable;

/**
 * 멤버-유튜브채널 구독 관계 엔티티 (note_member_youtube_channel).
 * 멤버별 구독 여부 및 자동화 설정 보관.
 */
@Getter
@Setter
@NoArgsConstructor
@Entity(name = "MemberYoutubeChannel")
@Table(name = "note_member_youtube_channel",
    uniqueConstraints = @UniqueConstraint(
        name = "unique_member_channel",
        columnNames = {"member_id", "channel_id"}
    ),
    indexes = {
        @Index(name = "idx_member_channel_member",  columnList = "member_id, is_active"),
        @Index(name = "idx_member_channel_channel", columnList = "channel_id, is_active")
    }
)
public class MemberYoutubeChannel extends BaseEntity implements Serializable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id", columnDefinition = "BIGINT NOT NULL AUTO_INCREMENT COMMENT 'PK'")
    private Long id;

    @Column(name = "member_id", nullable = false,
            columnDefinition = "VARCHAR(128) NOT NULL COMMENT '회원 ID'")
    private String memberId;

    @Column(name = "channel_id", nullable = false,
            columnDefinition = "VARCHAR(64) NOT NULL COMMENT '유튜브 채널 ID (youtube_channel.channel_id)'")
    private String channelId;

    @Column(name = "is_active", nullable = false,
            columnDefinition = "BOOLEAN NOT NULL DEFAULT TRUE COMMENT '구독 활성 여부'")
    private Boolean isActive = true;

    // ── 자동화 설정 ──────────────────────────────────────────────────────────

    @Column(name = "auto_title", nullable = false,
            columnDefinition = "BOOLEAN NOT NULL DEFAULT TRUE COMMENT '영상 제목 자동 저장'")
    private Boolean autoTitle = true;

    @Column(name = "auto_memo", nullable = false,
            columnDefinition = "BOOLEAN NOT NULL DEFAULT FALSE COMMENT '메모 자동 생성'")
    private Boolean autoMemo = false;

    @Column(name = "auto_summary", nullable = false,
            columnDefinition = "BOOLEAN NOT NULL DEFAULT FALSE COMMENT '요약 자동 생성'")
    private Boolean autoSummary = false;

    @Column(name = "summary_type",
            columnDefinition = "VARCHAR(32) NULL COMMENT '요약 수준 (ONE_LINE/SHORT/NORMAL/DETAILED/FULL)'")
    private String summaryType;

    @Column(name = "auto_remind", nullable = false,
            columnDefinition = "BOOLEAN NOT NULL DEFAULT FALSE COMMENT '리마인드 자동 생성'")
    private Boolean autoRemind = false;

    @Column(name = "remind_type",
            columnDefinition = "VARCHAR(32) NULL COMMENT '리마인드 종류 (ONE/THREE/FIVE/TEN/TWENTY/CUSTOM)'")
    private String remindType;

    @Column(name = "remind_custom_count",
            columnDefinition = "INT NULL COMMENT '리마인드 CUSTOM 개수'")
    private Integer remindCustomCount;

    // ── 채널 정보 (조회 편의용 — 쓰기 제외) ──────────────────────────────────

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "channel_id", referencedColumnName = "channel_id",
                insertable = false, updatable = false)
    private YoutubeChannel channel;
}

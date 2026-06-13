package com.litten.note.youtube;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 레거시 구독 행 등록일시(insert_date_time) 1회 backfill.
 *
 * 배경: 과거에는 JPA Auditing(@EnableJpaAuditing) 미사용 + subscribe()에서 등록일시를
 * 세팅하지 않아 note_member_youtube_channel.insert_date_time 이 NULL 로 남았다.
 * 이 때문에 전체탭 "등록일 기준" 정렬(YoutubeSubscriptionDto.subscribedAt)이 동작하지 못했다.
 *
 * 진짜 등록일시는 복구 불가하므로, 등록 순서(PK id 오름차순)를 보존해 회원별로
 * 1일 간격의 합성 등록일시를 부여한다. (가장 최근 등록 = 현재 시각, 과거로 갈수록 하루씩)
 *
 * NULL 행만 갱신하므로 멱등(idempotent): backfill 이후/신규 구독(now() 세팅)은 영향받지 않는다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class YoutubeRegisteredAtBackfill {

    private final MemberYoutubeChannelRepository repository;

    @EventListener(ApplicationReadyEvent.class)
    @Transactional
    public void backfill() {
        List<MemberYoutubeChannel> nullRows = repository.findByInsertDateTimeIsNull();
        if (nullRows.isEmpty()) {
            log.info("[YoutubeRegisteredAtBackfill] 등록일시 backfill 대상 없음 - 생략");
            return;
        }

        final LocalDateTime now = LocalDateTime.now();
        Map<String, List<MemberYoutubeChannel>> byMember = nullRows.stream()
                .collect(Collectors.groupingBy(MemberYoutubeChannel::getMemberId));

        int updated = 0;
        for (Map.Entry<String, List<MemberYoutubeChannel>> entry : byMember.entrySet()) {
            List<MemberYoutubeChannel> rows = entry.getValue();
            rows.sort(Comparator.comparing(MemberYoutubeChannel::getId)); // 등록 순서(오래된→최신)
            int n = rows.size();
            for (int i = 0; i < n; i++) {
                // i=0(가장 오래된) → now-(n-1)일, 마지막(최신) → now
                rows.get(i).setInsertDateTime(now.minusDays((long) (n - 1 - i)));
                updated++;
            }
        }
        repository.saveAll(nullRows);
        log.info("[YoutubeRegisteredAtBackfill] 등록일시 backfill 완료 - 회원 {}명, 채널 {}건", byMember.size(), updated);
    }
}

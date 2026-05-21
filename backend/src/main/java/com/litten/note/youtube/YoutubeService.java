package com.litten.note.youtube;

import com.litten.note.summary.SummaryRequestVo;
import com.litten.note.summary.SummaryResponseVo;
import com.litten.note.summary.SummaryService;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.stereotype.Service;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.transaction.annotation.Transactional;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.concurrent.TimeUnit;

@Log4j2
@Service
@RequiredArgsConstructor
public class YoutubeService {

    private static final String RSS_BASE_URL = "https://www.youtube.com/feeds/videos.xml?channel_id=";
    private static final int TRANSCRIPT_TIMEOUT_SECONDS = 60;
    private static final int MAX_TRANSCRIPT_CHARS = 8000;

    private final YoutubeChannelRepository channelRepository;
    private final YoutubeVideoRepository videoRepository;
    private final SummaryService summaryService;

    // ── 채널 구독 ──────────────────────────────────────────────────────────────

    @Transactional
    public YoutubeChannel subscribe(String memberId, String channelId, String channelName, String channelThumbnail,
                                    Boolean autoTitle, Boolean autoMemo, Boolean autoSummary, Boolean autoRemind,
                                    String summaryType, String remindType, Integer remindCustomCount) {
        log.debug("[YoutubeService] subscribe 진입 - memberId: {}, channelId: {}", memberId, channelId);

        boolean useSummary = autoSummary != null && autoSummary;
        boolean useRemind  = autoRemind  != null && autoRemind;
        String normalizedSummaryType = useSummary ? (summaryType == null || summaryType.isBlank() ? "NORMAL" : summaryType) : null;
        String normalizedRemindType  = useRemind  ? (remindType  == null || remindType.isBlank()  ? "FIVE"   : remindType)  : null;
        Integer normalizedRemindCount = "CUSTOM".equals(normalizedRemindType) ? remindCustomCount : null;

        if (channelRepository.existsByMemberIdAndChannelId(memberId, channelId)) {
            YoutubeChannel existing = channelRepository.findByMemberIdAndChannelId(memberId, channelId).orElseThrow();
            existing.setIsActive(true);
            existing.setChannelName(channelName);
            existing.setChannelThumbnail(channelThumbnail);
            existing.setAutoTitle(autoTitle != null ? autoTitle : true);
            existing.setAutoMemo(autoMemo != null ? autoMemo : false);
            existing.setAutoSummary(useSummary);
            existing.setAutoRemind(useRemind);
            existing.setSummaryType(normalizedSummaryType);
            existing.setRemindType(normalizedRemindType);
            existing.setRemindCustomCount(normalizedRemindCount);
            log.info("[YoutubeService] 기존 채널 구독 재활성화 - channelId: {}", channelId);
            return channelRepository.save(existing);
        }

        YoutubeChannel channel = new YoutubeChannel();
        channel.setMemberId(memberId);
        channel.setChannelId(channelId);
        channel.setChannelName(channelName);
        channel.setChannelThumbnail(channelThumbnail);
        channel.setIsActive(true);
        channel.setAutoTitle(autoTitle != null ? autoTitle : true);
        channel.setAutoMemo(autoMemo != null ? autoMemo : false);
        channel.setAutoSummary(useSummary);
        channel.setAutoRemind(useRemind);
        channel.setSummaryType(normalizedSummaryType);
        channel.setRemindType(normalizedRemindType);
        channel.setRemindCustomCount(normalizedRemindCount);
        log.info("[YoutubeService] 채널 구독 등록 - memberId: {}, channelId: {}, autoTitle: {}, autoSummary: {} ({}), autoRemind: {} ({}{})",
                memberId, channelId, autoTitle, useSummary, normalizedSummaryType, useRemind, normalizedRemindType,
                normalizedRemindCount != null ? "=" + normalizedRemindCount : "");
        return channelRepository.save(channel);
    }

    @Transactional
    public boolean updateSettings(String memberId, Long channelPk,
                                  Boolean autoTitle, Boolean autoMemo, Boolean autoSummary, Boolean autoRemind,
                                  String summaryType, boolean clearSummaryType,
                                  String remindType, boolean clearRemindType,
                                  Integer remindCustomCount, boolean clearRemindCustomCount) {
        log.debug("[YoutubeService] updateSettings 진입 - memberId: {}, channelPk: {}", memberId, channelPk);
        return channelRepository.findById(channelPk).map(ch -> {
            if (!ch.getMemberId().equals(memberId)) return false;
            if (autoTitle   != null) ch.setAutoTitle(autoTitle);
            if (autoMemo    != null) ch.setAutoMemo(autoMemo);
            if (autoSummary != null) {
                ch.setAutoSummary(autoSummary);
                if (autoSummary) {
                    String t = summaryType != null && !summaryType.isBlank()
                            ? summaryType
                            : (ch.getSummaryType() != null ? ch.getSummaryType() : "NORMAL");
                    ch.setSummaryType(t);
                } else {
                    ch.setSummaryType(null);
                }
            } else if (summaryType != null && !summaryType.isBlank()) {
                ch.setSummaryType(summaryType);
            } else if (clearSummaryType) {
                ch.setSummaryType(null);
            }
            if (autoRemind != null) {
                ch.setAutoRemind(autoRemind);
                if (autoRemind) {
                    String t = remindType != null && !remindType.isBlank()
                            ? remindType
                            : (ch.getRemindType() != null ? ch.getRemindType() : "FIVE");
                    ch.setRemindType(t);
                    if ("CUSTOM".equals(t)) {
                        if (remindCustomCount != null) ch.setRemindCustomCount(remindCustomCount);
                    } else {
                        ch.setRemindCustomCount(null);
                    }
                } else {
                    ch.setRemindType(null);
                    ch.setRemindCustomCount(null);
                }
            } else {
                if (remindType != null && !remindType.isBlank()) {
                    ch.setRemindType(remindType);
                    if (!"CUSTOM".equals(remindType)) ch.setRemindCustomCount(null);
                } else if (clearRemindType) {
                    ch.setRemindType(null);
                    ch.setRemindCustomCount(null);
                }
                if (remindCustomCount != null) {
                    ch.setRemindCustomCount(remindCustomCount);
                } else if (clearRemindCustomCount) {
                    ch.setRemindCustomCount(null);
                }
            }
            channelRepository.save(ch);
            log.info("[YoutubeService] 설정 업데이트 완료 - channelId: {}, summaryType: {}, remindType: {}, remindCustomCount: {}",
                    ch.getChannelId(), ch.getSummaryType(), ch.getRemindType(), ch.getRemindCustomCount());
            return true;
        }).orElse(false);
    }

    @Transactional
    public void unsubscribe(String memberId, Long channelPk) {
        log.debug("[YoutubeService] unsubscribe 진입 - memberId: {}, channelPk: {}", memberId, channelPk);
        channelRepository.findById(channelPk).ifPresent(ch -> {
            if (ch.getMemberId().equals(memberId)) {
                ch.setIsActive(false);
                channelRepository.save(ch);
                log.info("[YoutubeService] 채널 구독 해제 - channelId: {}", ch.getChannelId());
            }
        });
    }

    public List<YoutubeChannel> getSubscribedChannels(String memberId) {
        return channelRepository.findByMemberIdAndIsActiveTrue(memberId);
    }

    // ── 채널 영상 목록 조회 (제목만, 페이징) ───────────────────────────────────

    public Page<YoutubeVideoSummaryDto> getChannelVideoSummaries(String channelId, int page, int size) {
        log.debug("[YoutubeService] getChannelVideoSummaries - channelId: {}, page: {}, size: {}", channelId, page, size);
        PageRequest pageable = PageRequest.of(page, size, Sort.by("publishedAt").descending());
        return videoRepository.findByChannelIdOrderByPublishedAtDesc(channelId, pageable)
                .map(YoutubeVideoSummaryDto::from);
    }

    // ── 영상 상세 조회 (자막/요약 포함) ───────────────────────────────────────

    public Optional<YoutubeVideo> findVideoById(Long id) {
        return videoRepository.findById(id);
    }

    // ── RSS 폴링 — 스케줄러에서 호출 ──────────────────────────────────────────

    private static final int POLL_BATCH_SIZE = 50;

    public void pollAllChannels() {
        log.debug("[YoutubeService] pollAllChannels 진입");
        int pageNum = 0;
        int total = 0;
        Page<YoutubeChannel> page;
        do {
            page = channelRepository.findByIsActiveTrue(PageRequest.of(pageNum++, POLL_BATCH_SIZE));
            log.info("[YoutubeService] 채널 배치 처리 - batch: {}/{}, count: {}",
                    pageNum, page.getTotalPages(), page.getContent().size());
            for (YoutubeChannel channel : page.getContent()) {
                try {
                    pollChannel(channel);
                } catch (Exception e) {
                    log.error("[YoutubeService] 채널 폴링 실패 - channelId: {}, error: {}",
                            channel.getChannelId(), e.getMessage());
                }
            }
            total += page.getContent().size();
        } while (!page.isLast());
        log.info("[YoutubeService] pollAllChannels 완료 - 총 처리 채널 수: {}", total);
    }

    // RSS 파싱과 영상 처리를 동시에 수행 — 영상 목록을 메모리에 모으지 않고
    // entry를 만나는 즉시 processNewVideo()로 넘겨 GC가 빨리 회수하도록 한다.
    private void pollChannel(YoutubeChannel channel) throws Exception {
        String channelId = channel.getChannelId();
        boolean autoSummary = Boolean.TRUE.equals(channel.getAutoSummary());
        String summaryType = channel.getSummaryType();
        log.debug("[YoutubeService] pollChannel 진입 - channelId: {}, summaryType: {}", channelId, summaryType);

        String rssUrl = RSS_BASE_URL + channelId;
        log.debug("[YoutubeService] RSS 피드 요청 - url: {}", rssUrl);

        URL url = new URL(rssUrl);
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        conn.setRequestMethod("GET");
        conn.setConnectTimeout(10000);
        conn.setReadTimeout(15000);
        conn.setRequestProperty("User-Agent", "Mozilla/5.0");

        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
        factory.setNamespaceAware(true);
        DocumentBuilder builder = factory.newDocumentBuilder();
        Document doc;

        try {
            try (InputStream is = conn.getInputStream()) {
                doc = builder.parse(is);
            }
        } finally {
            conn.disconnect();
        }

        NodeList entries = doc.getElementsByTagNameNS("http://www.w3.org/2005/Atom", "entry");
        int total = entries.getLength();
        int processed = 0;
        int skipped = 0;
        log.info("[YoutubeService] RSS 파싱 완료 - channelId: {}, 영상 수: {}", channelId, total);

        for (int i = 0; i < total; i++) {
            Element entry = (Element) entries.item(i);
            String videoId = getTagText(entry, "http://www.youtube.com/xml/schemas/2015", "videoId");
            String title = getTagText(entry, "http://www.w3.org/2005/Atom", "title");
            String published = getTagText(entry, "http://www.w3.org/2005/Atom", "published");

            if (videoId == null || videoId.isBlank()) continue;
            if (videoRepository.existsByVideoId(videoId)) {
                log.debug("[YoutubeService] 이미 처리된 영상 - videoId: {}", videoId);
                skipped++;
                continue;
            }

            log.info("[YoutubeService] 신규 영상 감지 - videoId: {}, title: {}", videoId, title);
            processNewVideo(channelId, videoId, title != null ? title : "",
                    published != null ? published : "", autoSummary, summaryType);
            processed++;
        }

        log.info("[YoutubeService] 채널 처리 종료 - channelId: {}, 총: {}, 신규처리: {}, 스킵: {}",
                channelId, total, processed, skipped);
    }

    private String getTagText(Element parent, String namespace, String tagName) {
        NodeList nodes = parent.getElementsByTagNameNS(namespace, tagName);
        if (nodes.getLength() > 0) {
            return nodes.item(0).getTextContent();
        }
        return null;
    }

    // ── 신규 영상 처리 ─────────────────────────────────────────────────────────
    // self-invocation으로 @Transactional이 무시되므로 트랜잭션을 각 save()에 위임.
    // 외부 호출(Python subprocess, AI API)이 DB 연결을 점유하지 않도록 의도적으로 비트랜잭션.
    public void processNewVideo(String channelId, String videoId, String title, String publishedAtStr, boolean doSummary, String summaryType) {
        log.info("[YoutubeService] processNewVideo 진입 - videoId: {}, title: {}, doSummary: {}, summaryType: {}", videoId, title, doSummary, summaryType);

        YoutubeVideo video = new YoutubeVideo();
        video.setChannelId(channelId);
        video.setVideoId(videoId);
        video.setTitle(title);
        video.setStatus("pending");

        try {
            // ISO 8601 파싱 (e.g. 2024-01-15T12:00:00+00:00)
            if (publishedAtStr != null && !publishedAtStr.isBlank()) {
                String normalized = publishedAtStr.replaceAll("\\+\\d{2}:\\d{2}$", "").replace("Z", "");
                video.setPublishedAt(LocalDateTime.parse(normalized, DateTimeFormatter.ISO_LOCAL_DATE_TIME));
            }
        } catch (Exception e) {
            log.warn("[YoutubeService] publishedAt 파싱 실패 - value: {}", publishedAtStr);
        }

        // Step 1: 영상 레코드 저장 (DB 연결 즉시 반환)
        videoRepository.save(video);

        // Step 2: 자막 추출 (최대 60초, DB 연결 없음).
        // extractTranscript()가 이미 MAX_TRANSCRIPT_CHARS 한도 내로 반환하므로 추가 substring 불필요.
        String transcript = extractTranscript(videoId);
        if (transcript == null || transcript.isBlank()) {
            video.setStatus("no_transcript");
            video.setProcessedAt(LocalDateTime.now());
            videoRepository.save(video);
            log.info("[YoutubeService] 자막 없음 - videoId: {}", videoId);
            return;
        }

        // 자막을 즉시 DB에 저장하고 entity의 transcriptText만 유지 — raw 변수 해제로 임시 String 회수 유도.
        video.setTranscriptText(transcript);
        videoRepository.save(video);

        // Step 3: AI 요약 (외부 API 호출). 요약 호출 중 자막+프롬프트+응답이 잠시 메모리에 공존하므로
        // 호출 후 summary는 즉시 entity에 옮기고 raw 변수는 해제.
        if (doSummary) {
            String summary = summarize(videoId, title, transcript, summaryType);
            video.setSummary(summary);
            summary = null;
        }
        transcript = null;

        // Step 4: 최종 상태 저장
        video.setStatus("done");
        video.setProcessedAt(LocalDateTime.now());
        videoRepository.save(video);
        log.info("[YoutubeService] 처리 완료 - videoId: {}", videoId);
    }

    // ── 자막 추출 (Python subprocess) ─────────────────────────────────────────

    private String extractTranscript(String videoId) {
        log.debug("[YoutubeService] extractTranscript 진입 - videoId: {}", videoId);

        String script =
            "from youtube_transcript_api import YouTubeTranscriptApi; " +
            "api = YouTubeTranscriptApi(); " +
            "t = api.fetch('" + videoId + "', languages=['ko', 'en', 'ja', 'zh-Hans', 'zh-Hant']); " +
            "print(' '.join([s.text for s in t]))";

        Process process = null;
        try {
            ProcessBuilder pb = new ProcessBuilder("python3", "-c", script);
            pb.redirectErrorStream(false);
            process = pb.start();

            // stdout을 MAX_TRANSCRIPT_CHARS까지만 읽고 즉시 subprocess 종료.
            // 자막 전체를 메모리에 모으지 않음 — 1시간 강의도 8000자에서 잘라 종료.
            StringBuilder transcript = new StringBuilder(Math.min(8192, MAX_TRANSCRIPT_CHARS));
            boolean truncated = false;
            try (BufferedReader br = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                char[] buf = new char[4096];
                int read;
                while ((read = br.read(buf)) != -1) {
                    int remaining = MAX_TRANSCRIPT_CHARS - transcript.length();
                    if (remaining <= 0) {
                        truncated = true;
                        break;
                    }
                    transcript.append(buf, 0, Math.min(read, remaining));
                }
            }
            if (truncated) {
                log.info("[YoutubeService] 자막 한도({}자) 도달, subprocess 강제 종료 - videoId: {}",
                        MAX_TRANSCRIPT_CHARS, videoId);
                process.destroyForcibly();
            }

            // stderr는 진단 목적 — 최대 2KB만 읽음.
            StringBuilder stderr = new StringBuilder();
            try (BufferedReader er = new BufferedReader(new InputStreamReader(process.getErrorStream()))) {
                char[] ebuf = new char[1024];
                int read;
                while ((read = er.read(ebuf)) != -1 && stderr.length() < 2048) {
                    stderr.append(ebuf, 0, Math.min(read, 2048 - stderr.length()));
                }
            }

            boolean finished = process.waitFor(TRANSCRIPT_TIMEOUT_SECONDS, TimeUnit.SECONDS);
            if (!finished) {
                process.destroyForcibly();
                log.error("[YoutubeService] 자막 추출 타임아웃 - videoId: {}", videoId);
                return null;
            }

            // truncated 경로에서는 destroyForcibly가 exit code를 비정상으로 만들 수 있으므로
            // 자막이 한 글자 이상 있으면 성공으로 본다.
            int exitCode = process.exitValue();
            if (exitCode != 0 && !truncated) {
                log.warn("[YoutubeService] 자막 추출 실패 - videoId: {}, stderr: {}", videoId, stderr);
                return null;
            }

            String result = transcript.toString().trim();
            log.info("[YoutubeService] 자막 추출 성공 - videoId: {}, 길이: {}, truncated: {}",
                    videoId, result.length(), truncated);
            return result.isEmpty() ? null : result;

        } catch (Exception e) {
            if (process != null && process.isAlive()) process.destroyForcibly();
            log.error("[YoutubeService] 자막 추출 오류 - videoId: {}, error: {}", videoId, e.getMessage());
            return null;
        }
    }

    // ── AI 요약 ────────────────────────────────────────────────────────────────

    // summaryType → SummaryRequestVo.summaryLevel(1~5)
    private static int summaryLevelOf(String summaryType) {
        if (summaryType == null) return 3;
        return switch (summaryType) {
            case "ONE_LINE" -> 1;
            case "SHORT"    -> 2;
            case "NORMAL"   -> 3;
            case "DETAILED" -> 4;
            case "FULL"     -> 5;
            default         -> 3;
        };
    }

    private String summarize(String videoId, String title, String transcript, String summaryType) {
        int level = summaryLevelOf(summaryType);
        log.debug("[YoutubeService] summarize 진입 - videoId: {}, summaryType: {}, level: {}", videoId, summaryType, level);
        try {
            SummaryRequestVo req = new SummaryRequestVo();
            req.setText("유튜브 영상 제목: " + title + "\n\n자막 내용:\n" + transcript);
            req.setTextLanguage("ko");
            req.setSummaryLanguage("ko");
            req.setSummaryLevel(level);
            req.setFileId(videoId);

            SummaryResponseVo res = summaryService.summarize(req);
            if (res.isSuccess()) {
                log.info("[YoutubeService] AI 요약 성공 - videoId: {}", videoId);
                return res.getSummary();
            } else {
                log.warn("[YoutubeService] AI 요약 실패 - videoId: {}, error: {}", videoId, res.getError());
                return null;
            }
        } catch (Exception e) {
            log.error("[YoutubeService] AI 요약 오류 - videoId: {}, error: {}", videoId, e.getMessage());
            return null;
        }
    }

    // ── 채널 검색 (RSS 기반 채널 정보 조회) ───────────────────────────────────

    public Map<String, String> fetchChannelInfo(String channelId) {
        log.debug("[YoutubeService] fetchChannelInfo 진입 - channelId: {}", channelId);
        try {
            String rssUrl = RSS_BASE_URL + channelId;
            URL url = new URL(rssUrl);
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setConnectTimeout(10000);
            conn.setReadTimeout(15000);
            conn.setRequestProperty("User-Agent", "Mozilla/5.0");

            try {
                int status = conn.getResponseCode();
                log.info("[YoutubeService] fetchChannelInfo RSS 응답 코드 - channelId: {}, status: {}", channelId, status);
                if (status != 200) {
                    log.warn("[YoutubeService] fetchChannelInfo RSS 응답 오류 - channelId: {}, status: {}", channelId, status);
                    return null;
                }

                DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
                factory.setNamespaceAware(true);
                DocumentBuilder builder = factory.newDocumentBuilder();
                Document doc;
                try (InputStream is = conn.getInputStream()) {
                    doc = builder.parse(is);
                }

                // 피드 최상위 <title>이 채널명 (entry 내 title과 구별하기 위해 feed 직계 자식 탐색)
                NodeList titleNodes = doc.getElementsByTagNameNS("http://www.w3.org/2005/Atom", "title");
                String channelName = channelId;
                if (titleNodes.getLength() > 0) {
                    channelName = titleNodes.item(0).getTextContent().trim();
                }

                Map<String, String> info = new HashMap<>();
                info.put("channelId", channelId);
                info.put("channelName", channelName);
                info.put("channelThumbnail", "");
                log.info("[YoutubeService] 채널 정보 조회 성공 - channelId: {}, name: {}", channelId, channelName);
                return info;
            } finally {
                conn.disconnect();
            }

        } catch (Exception e) {
            log.error("[YoutubeService] 채널 정보 조회 실패 - channelId: {}, error: {}", channelId, e.getMessage());
            return null;
        }
    }
}

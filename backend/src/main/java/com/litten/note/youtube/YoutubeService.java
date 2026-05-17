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
import java.util.stream.Collectors;

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
                                    Boolean autoTitle, Boolean autoMemo, Boolean autoSummary, Boolean autoRemind) {
        log.debug("[YoutubeService] subscribe 진입 - memberId: {}, channelId: {}", memberId, channelId);

        if (channelRepository.existsByMemberIdAndChannelId(memberId, channelId)) {
            YoutubeChannel existing = channelRepository.findByMemberIdAndChannelId(memberId, channelId).orElseThrow();
            existing.setIsActive(true);
            existing.setChannelName(channelName);
            existing.setChannelThumbnail(channelThumbnail);
            existing.setAutoTitle(autoTitle != null ? autoTitle : true);
            existing.setAutoMemo(autoMemo != null ? autoMemo : false);
            existing.setAutoSummary(autoSummary != null ? autoSummary : false);
            existing.setAutoRemind(autoRemind != null ? autoRemind : false);
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
        channel.setAutoSummary(autoSummary != null ? autoSummary : false);
        channel.setAutoRemind(autoRemind != null ? autoRemind : false);
        log.info("[YoutubeService] 채널 구독 등록 - memberId: {}, channelId: {}, autoTitle: {}, autoSummary: {}", memberId, channelId, autoTitle, autoSummary);
        return channelRepository.save(channel);
    }

    @Transactional
    public boolean updateSettings(String memberId, Long channelPk,
                                  Boolean autoTitle, Boolean autoMemo, Boolean autoSummary, Boolean autoRemind) {
        log.debug("[YoutubeService] updateSettings 진입 - memberId: {}, channelPk: {}", memberId, channelPk);
        return channelRepository.findById(channelPk).map(ch -> {
            if (!ch.getMemberId().equals(memberId)) return false;
            if (autoTitle   != null) ch.setAutoTitle(autoTitle);
            if (autoMemo    != null) ch.setAutoMemo(autoMemo);
            if (autoSummary != null) ch.setAutoSummary(autoSummary);
            if (autoRemind  != null) ch.setAutoRemind(autoRemind);
            channelRepository.save(ch);
            log.info("[YoutubeService] 설정 업데이트 완료 - channelId: {}", ch.getChannelId());
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

    public List<YoutubeVideo> getChannelVideos(String channelId) {
        return videoRepository.findByChannelIdOrderByPublishedAtDesc(channelId);
    }

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

    public void pollAllChannels() {
        log.debug("[YoutubeService] pollAllChannels 진입");
        List<YoutubeChannel> channels = channelRepository.findByIsActiveTrue();
        log.info("[YoutubeService] 구독 채널 수: {}", channels.size());

        // 채널별로 순차 처리 (서버 부하 최소화)
        for (YoutubeChannel channel : channels) {
            try {
                pollChannel(channel);
            } catch (Exception e) {
                log.error("[YoutubeService] 채널 폴링 실패 - channelId: {}, error: {}", channel.getChannelId(), e.getMessage());
            }
        }
    }

    private void pollChannel(YoutubeChannel channel) throws Exception {
        log.debug("[YoutubeService] pollChannel 진입 - channelId: {}", channel.getChannelId());
        List<Map<String, String>> videos = fetchRssFeed(channel.getChannelId());

        for (Map<String, String> video : videos) {
            String videoId = video.get("videoId");
            if (videoRepository.existsByVideoId(videoId)) {
                log.debug("[YoutubeService] 이미 처리된 영상 - videoId: {}", videoId);
                continue;
            }

            log.info("[YoutubeService] 신규 영상 감지 - videoId: {}, title: {}", videoId, video.get("title"));
            processNewVideo(channel.getChannelId(), videoId, video.get("title"), video.get("publishedAt"),
                    Boolean.TRUE.equals(channel.getAutoSummary()));
        }
    }

    // ── RSS 피드 파싱 ──────────────────────────────────────────────────────────

    private List<Map<String, String>> fetchRssFeed(String channelId) throws Exception {
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

        try (InputStream is = conn.getInputStream()) {
            doc = builder.parse(is);
        }

        List<Map<String, String>> result = new ArrayList<>();
        NodeList entries = doc.getElementsByTagNameNS("http://www.w3.org/2005/Atom", "entry");

        for (int i = 0; i < entries.getLength(); i++) {
            Element entry = (Element) entries.item(i);
            String videoId = getTagText(entry, "http://www.youtube.com/xml/schemas/2015", "videoId");
            String title = getTagText(entry, "http://www.w3.org/2005/Atom", "title");
            String published = getTagText(entry, "http://www.w3.org/2005/Atom", "published");

            if (videoId != null && !videoId.isBlank()) {
                Map<String, String> map = new HashMap<>();
                map.put("videoId", videoId);
                map.put("title", title != null ? title : "");
                map.put("publishedAt", published != null ? published : "");
                result.add(map);
            }
        }

        log.info("[YoutubeService] RSS 파싱 완료 - channelId: {}, 영상 수: {}", channelId, result.size());
        return result;
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
    public void processNewVideo(String channelId, String videoId, String title, String publishedAtStr, boolean doSummary) {
        log.info("[YoutubeService] processNewVideo 진입 - videoId: {}, title: {}, doSummary: {}", videoId, title, doSummary);

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

        // Step 2: 자막 추출 (최대 60초, DB 연결 없음)
        String transcript = extractTranscript(videoId);
        if (transcript == null || transcript.isBlank()) {
            video.setStatus("no_transcript");
            video.setProcessedAt(LocalDateTime.now());
            videoRepository.save(video);
            log.info("[YoutubeService] 자막 없음 - videoId: {}", videoId);
            return;
        }

        // 너무 긴 자막은 앞부분만 사용
        if (transcript.length() > MAX_TRANSCRIPT_CHARS) {
            transcript = transcript.substring(0, MAX_TRANSCRIPT_CHARS);
            log.info("[YoutubeService] 자막 잘림 - videoId: {}, 원본길이: {}", videoId, transcript.length());
        }

        video.setTranscriptText(transcript);

        // Step 3: AI 요약 (외부 API 호출, DB 연결 없음)
        if (doSummary) {
            String summary = summarize(videoId, title, transcript);
            video.setSummary(summary);
        }

        // Step 4: 최종 결과 저장 (DB 연결 즉시 반환)
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

        try {
            ProcessBuilder pb = new ProcessBuilder("python3", "-c", script);
            pb.redirectErrorStream(false);

            Process process = pb.start();
            boolean finished = process.waitFor(TRANSCRIPT_TIMEOUT_SECONDS, TimeUnit.SECONDS);

            if (!finished) {
                process.destroyForcibly();
                log.error("[YoutubeService] 자막 추출 타임아웃 - videoId: {}", videoId);
                return null;
            }

            String stdout = new BufferedReader(new InputStreamReader(process.getInputStream()))
                .lines().collect(Collectors.joining("\n")).trim();
            String stderr = new BufferedReader(new InputStreamReader(process.getErrorStream()))
                .lines().collect(Collectors.joining("\n")).trim();

            int exitCode = process.exitValue();
            if (exitCode != 0) {
                log.warn("[YoutubeService] 자막 추출 실패 - videoId: {}, stderr: {}", videoId, stderr);
                return null;
            }

            log.info("[YoutubeService] 자막 추출 성공 - videoId: {}, 길이: {}", videoId, stdout.length());
            return stdout;

        } catch (Exception e) {
            log.error("[YoutubeService] 자막 추출 오류 - videoId: {}, error: {}", videoId, e.getMessage());
            return null;
        }
    }

    // ── AI 요약 ────────────────────────────────────────────────────────────────

    private String summarize(String videoId, String title, String transcript) {
        log.debug("[YoutubeService] summarize 진입 - videoId: {}", videoId);
        try {
            SummaryRequestVo req = new SummaryRequestVo();
            req.setText("유튜브 영상 제목: " + title + "\n\n자막 내용:\n" + transcript);
            req.setTextLanguage("ko");
            req.setSummaryLanguage("ko");
            req.setSummaryLevel(3);
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

        } catch (Exception e) {
            log.error("[YoutubeService] 채널 정보 조회 실패 - channelId: {}, error: {}", channelId, e.getMessage());
            return null;
        }
    }
}

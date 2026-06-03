package com.litten.note.youtube;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.litten.common.config.ApiKeyProperties;
import com.litten.note.summary.SummaryRequestVo;
import com.litten.note.summary.SummaryResponseVo;
import com.litten.note.summary.SummaryService;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.beans.factory.annotation.Value;
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
    private static final String SUPADATA_TRANSCRIPT_URL = "https://api.supadata.ai/v1/youtube/transcript";

    @Value("${youtube.cookies-path:}")
    private String cookiesPath;

    @Value("${youtube.ytdlp-enabled:true}")
    private boolean ytdlpEnabled;

    @Value("${supadata.only:false}")
    private boolean supadataOnly;

    private final ApiKeyProperties apiKeyProperties;
    private final ObjectMapper objectMapper;

    // 1:1 번갈아 호출하기 위한 카운터 (짝수=yt-dlp 먼저, 홀수=Supadata 먼저)
    private final java.util.concurrent.atomic.AtomicInteger transcriptRequestCounter = new java.util.concurrent.atomic.AtomicInteger(0);

    private final YoutubeChannelRepository        channelRepository;
    private final MemberYoutubeChannelRepository  memberChannelRepository;
    private final YoutubeVideoRepository          videoRepository;
    private final SummaryService                  summaryService;

    // ── 채널 구독 ──────────────────────────────────────────────────────────────

    @Transactional
    public MemberYoutubeChannel subscribe(String memberId, String channelId, String channelName, String channelThumbnail,
                                          Boolean autoTitle, Boolean autoMemo, Boolean autoSummary, Boolean autoRemind,
                                          String summaryType, String remindType, Integer remindCustomCount) {
        log.debug("[YoutubeService] subscribe 진입 - memberId: {}, channelId: {}", memberId, channelId);

        boolean useSummary = autoSummary != null && autoSummary;
        boolean useRemind  = autoRemind  != null && autoRemind;
        String normalizedSummaryType  = useSummary ? (summaryType == null || summaryType.isBlank() ? "NORMAL" : summaryType) : null;
        String normalizedRemindType   = useRemind  ? (remindType  == null || remindType.isBlank()  ? "FIVE"   : remindType)  : null;
        Integer normalizedRemindCount = "CUSTOM".equals(normalizedRemindType) ? remindCustomCount : null;

        // 1) youtube_channel 없으면 생성, 있으면 채널 정보 갱신
        YoutubeChannel channel = channelRepository.findByChannelId(channelId).orElseGet(() -> {
            YoutubeChannel c = new YoutubeChannel();
            c.setChannelId(channelId);
            return c;
        });
        channel.setChannelName(channelName);
        channel.setChannelThumbnail(channelThumbnail);
        channelRepository.save(channel);

        // 2) note_member_youtube_channel 생성 또는 갱신
        MemberYoutubeChannel sub = memberChannelRepository
                .findByMemberIdAndChannelId(memberId, channelId)
                .orElseGet(() -> {
                    MemberYoutubeChannel s = new MemberYoutubeChannel();
                    s.setMemberId(memberId);
                    s.setChannelId(channelId);
                    return s;
                });
        sub.setIsActive(true);
        sub.setAutoTitle(autoTitle != null ? autoTitle : true);
        sub.setAutoMemo(autoMemo != null ? autoMemo : false);
        sub.setAutoSummary(useSummary);
        sub.setAutoRemind(useRemind);
        sub.setSummaryType(normalizedSummaryType);
        sub.setRemindType(normalizedRemindType);
        sub.setRemindCustomCount(normalizedRemindCount);

        log.info("[YoutubeService] 채널 구독 등록/갱신 - memberId: {}, channelId: {}, autoSummary: {} ({}), autoRemind: {} ({}{})",
                memberId, channelId, useSummary, normalizedSummaryType, useRemind, normalizedRemindType,
                normalizedRemindCount != null ? "=" + normalizedRemindCount : "");
        return memberChannelRepository.save(sub);
    }

    @Transactional
    public boolean updateSettings(String memberId, Long subscriptionId,
                                  Boolean autoTitle, Boolean autoMemo, Boolean autoSummary, Boolean autoRemind,
                                  String summaryType, boolean clearSummaryType,
                                  String remindType, boolean clearRemindType,
                                  Integer remindCustomCount, boolean clearRemindCustomCount) {
        log.debug("[YoutubeService] updateSettings 진입 - memberId: {}, subscriptionId: {}", memberId, subscriptionId);
        return memberChannelRepository.findById(subscriptionId).map(sub -> {
            if (!sub.getMemberId().equals(memberId)) return false;
            if (autoTitle != null) sub.setAutoTitle(autoTitle);
            if (autoMemo  != null) sub.setAutoMemo(autoMemo);
            if (autoSummary != null) {
                sub.setAutoSummary(autoSummary);
                if (autoSummary) {
                    String t = summaryType != null && !summaryType.isBlank()
                            ? summaryType
                            : (sub.getSummaryType() != null ? sub.getSummaryType() : "NORMAL");
                    sub.setSummaryType(t);
                } else {
                    sub.setSummaryType(null);
                }
            } else if (summaryType != null && !summaryType.isBlank()) {
                sub.setSummaryType(summaryType);
            } else if (clearSummaryType) {
                sub.setSummaryType(null);
            }
            if (autoRemind != null) {
                sub.setAutoRemind(autoRemind);
                if (autoRemind) {
                    String t = remindType != null && !remindType.isBlank()
                            ? remindType
                            : (sub.getRemindType() != null ? sub.getRemindType() : "FIVE");
                    sub.setRemindType(t);
                    if ("CUSTOM".equals(t)) {
                        if (remindCustomCount != null) sub.setRemindCustomCount(remindCustomCount);
                    } else {
                        sub.setRemindCustomCount(null);
                    }
                } else {
                    sub.setRemindType(null);
                    sub.setRemindCustomCount(null);
                }
            } else {
                if (remindType != null && !remindType.isBlank()) {
                    sub.setRemindType(remindType);
                    if (!"CUSTOM".equals(remindType)) sub.setRemindCustomCount(null);
                } else if (clearRemindType) {
                    sub.setRemindType(null);
                    sub.setRemindCustomCount(null);
                }
                if (remindCustomCount != null) {
                    sub.setRemindCustomCount(remindCustomCount);
                } else if (clearRemindCustomCount) {
                    sub.setRemindCustomCount(null);
                }
            }
            memberChannelRepository.save(sub);
            log.info("[YoutubeService] 설정 업데이트 완료 - channelId: {}, summaryType: {}, remindType: {}",
                    sub.getChannelId(), sub.getSummaryType(), sub.getRemindType());
            return true;
        }).orElse(false);
    }

    @Transactional
    public void unsubscribe(String memberId, Long subscriptionId) {
        log.debug("[YoutubeService] unsubscribe 진입 - memberId: {}, subscriptionId: {}", memberId, subscriptionId);
        memberChannelRepository.findById(subscriptionId).ifPresent(sub -> {
            if (sub.getMemberId().equals(memberId)) {
                sub.setIsActive(false);
                memberChannelRepository.save(sub);
                log.info("[YoutubeService] 채널 구독 해제 - channelId: {}", sub.getChannelId());
            }
        });
    }

    public List<YoutubeSubscriptionDto> getSubscribedChannels(String memberId) {
        return memberChannelRepository.findByMemberIdAndIsActiveTrue(memberId)
                .stream()
                .map(YoutubeSubscriptionDto::of)
                .toList();
    }

    // ── 채널 영상 목록 조회 (제목만, 페이징) ───────────────────────────────────

    public Page<YoutubeVideoSummaryDto> getChannelVideoSummaries(String channelId, int page, int size) {
        log.debug("[YoutubeService] getChannelVideoSummaries - channelId: {}, page: {}, size: {}", channelId, page, size);
        PageRequest pageable = PageRequest.of(page, size);
        return videoRepository.findSummariesByChannelId(channelId, pageable);
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
        int total   = 0;
        Page<YoutubeChannel> page;
        do {
            page = channelRepository.findChannelsWithActiveSubscribers(
                    PageRequest.of(pageNum++, POLL_BATCH_SIZE));
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
        log.debug("[YoutubeService] pollChannel 진입 - channelId: {}", channelId);

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

            Optional<YoutubeVideo> existingOpt = videoRepository.findByVideoId(videoId);
            if (existingOpt.isPresent()) {
                YoutubeVideo existing = existingOpt.get();
                if (title != null && !title.isBlank() && !title.equals(existing.getTitle())) {
                    log.info("[YoutubeService] 영상 제목 갱신 - videoId: {}, 이전: {}, 신규: {}", videoId, existing.getTitle(), title);
                    existing.setTitle(title);
                    videoRepository.save(existing);
                } else {
                    log.debug("[YoutubeService] 이미 처리된 영상 - videoId: {}", videoId);
                }
                skipped++;
                continue;
            }

            log.info("[YoutubeService] 신규 영상 감지 - videoId: {}, title: {}", videoId, title);
            processNewVideo(channelId, videoId, title != null ? title : "",
                    published != null ? published : "");
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

    // ── 신규 영상 처리 (제목/메타데이터만 저장 — 자막은 클라이언트에서 수집 후 저장) ───────
    public void processNewVideo(String channelId, String videoId, String title, String publishedAtStr) {
        log.info("[YoutubeService] processNewVideo 진입 - videoId: {}, title: {}", videoId, title);

        YoutubeVideo video = new YoutubeVideo();
        video.setChannelId(channelId);
        video.setVideoId(videoId);
        video.setTitle(title);
        video.setStatus("pending");

        try {
            if (publishedAtStr != null && !publishedAtStr.isBlank()) {
                String normalized = publishedAtStr.replaceAll("\\+\\d{2}:\\d{2}$", "").replace("Z", "");
                video.setPublishedAt(LocalDateTime.parse(normalized, DateTimeFormatter.ISO_LOCAL_DATE_TIME));
            }
        } catch (Exception e) {
            log.warn("[YoutubeService] publishedAt 파싱 실패 - value: {}", publishedAtStr);
        }

        videoRepository.save(video);
        log.info("[YoutubeService] 영상 레코드 저장 완료 (자막은 클라이언트 수집 대기) - videoId: {}", videoId);

        // 자막 추출은 클라이언트(앱)에서 수행 후 saveTranscript() API로 저장
        // extractTranscript() 서버 직접 호출 비활성화 — 클라우드 IP 차단으로 IpBlocked 발생
        /*
        String transcript = extractTranscript(videoId);
        if (transcript == null || transcript.isBlank()) {
            video.setStatus("no_transcript");
            video.setProcessedAt(LocalDateTime.now());
            videoRepository.save(video);
            return;
        }
        video.setTranscriptText(transcript);
        video.setStatus("done");
        video.setProcessedAt(LocalDateTime.now());
        videoRepository.save(video);
        */
    }

    // ── 클라이언트에서 수집한 자막 저장 ─────────────────────────────────────────

    @Transactional
    public boolean saveTranscript(String videoId, String transcript) {
        log.info("[YoutubeService] saveTranscript 진입 - videoId: {}, length: {}", videoId, transcript != null ? transcript.length() : 0);
        return videoRepository.findByVideoId(videoId).map(video -> {
            video.setTranscriptText(transcript);
            video.setStatus("done");
            video.setProcessedAt(LocalDateTime.now());
            videoRepository.save(video);
            log.info("[YoutubeService] 자막 저장 완료 - videoId: {}", videoId);
            return true;
        }).orElseGet(() -> {
            log.warn("[YoutubeService] 자막 저장 실패 - videoId 없음: {}", videoId);
            return false;
        });
    }

    // ── 자막 추출 (Python subprocess) ─────────────────────────────────────────

    private String extractTranscript(String videoId) {
        log.info("[YoutubeService] extractTranscript 진입 - videoId: {}", videoId);

        // v1.x API: YouTubeTranscriptApi(http_client=requests.Session)
        // 쿠키 파일이 있으면 MozillaCookieJar 로 로드해서 Session 에 주입, 없으면 bare Session 그대로 사용.
        String cp = (cookiesPath != null) ? cookiesPath.trim() : "";
        String cookiesBlock = cp.isEmpty() ? "" :
            "_jar=__import__('http.cookiejar',fromlist=['MozillaCookieJar']).MozillaCookieJar(); " +
            "((_jar.load('" + cp + "',ignore_discard=True,ignore_expires=True),_session.__setattr__('cookies',_jar)) if os.path.exists('" + cp + "') else None); ";
        String useCookiesExpr = cp.isEmpty() ? "False" : "os.path.exists('" + cp + "')";
        String script =
            "import sys, os, requests; " +
            "from youtube_transcript_api import YouTubeTranscriptApi; " +
            "print('[DIAG] python=' + sys.version, flush=True); " +
            "print('[DIAG] youtube_transcript_api import OK', flush=True); " +
            "_session=requests.Session(); " +
            cookiesBlock +
            "print('[DIAG] cookies_active=' + str(" + useCookiesExpr + "), flush=True); " +
            "api=YouTubeTranscriptApi(http_client=_session); " +
            "t=api.fetch('" + videoId + "', languages=['ko', 'en', 'ja', 'zh-Hans', 'zh-Hant']); " +
            "lines=[s.text for s in t]; " +
            "print('[DIAG] transcript lines=' + str(len(lines)), flush=True); " +
            "print(' '.join(lines))";

        Process process = null;
        try {
            ProcessBuilder pb = new ProcessBuilder("python3", "-c", script);
            pb.redirectErrorStream(false);
            log.info("[YoutubeService] Python subprocess 시작 - videoId: {}", videoId);
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

            // stderr는 stdout 읽기 완료 후, destroyForcibly() 호출 전에 읽어야 한다.
            // destroyForcibly() 이후에 읽으면 스트림이 닫혀 IOException: Stream closed 발생.
            StringBuilder stderr = new StringBuilder();
            try (BufferedReader er = new BufferedReader(new InputStreamReader(process.getErrorStream()))) {
                char[] ebuf = new char[1024];
                int read;
                while ((read = er.read(ebuf)) != -1 && stderr.length() < 4096) {
                    stderr.append(ebuf, 0, Math.min(read, 4096 - stderr.length()));
                }
            }

            if (truncated) {
                log.info("[YoutubeService] 자막 한도({}자) 도달, subprocess 강제 종료 - videoId: {}",
                        MAX_TRANSCRIPT_CHARS, videoId);
                process.destroyForcibly();
            }

            boolean finished = process.waitFor(TRANSCRIPT_TIMEOUT_SECONDS, TimeUnit.SECONDS);
            if (!finished) {
                process.destroyForcibly();
                log.error("[YoutubeService] 자막 추출 타임아웃({}s) - videoId: {}, stderr: {}",
                        TRANSCRIPT_TIMEOUT_SECONDS, videoId, stderr);
                return null;
            }

            int exitCode = process.exitValue();
            String stdoutPreview = transcript.length() > 0
                    ? transcript.substring(0, Math.min(200, transcript.length()))
                    : "(empty)";
            log.info("[YoutubeService] subprocess 종료 - videoId: {}, exitCode: {}, stdoutLen: {}, stderrLen: {}",
                    videoId, exitCode, transcript.length(), stderr.length());

            // stderr가 있으면 항상 로그 출력 (exitCode 무관)
            if (stderr.length() > 0) {
                log.warn("[YoutubeService] Python stderr - videoId: {}, stderr: {}", videoId, stderr);
            }

            // truncated 경로에서는 destroyForcibly가 exit code를 비정상으로 만들 수 있으므로
            // 자막이 한 글자 이상 있으면 성공으로 본다.
            if (exitCode != 0 && !truncated) {
                log.warn("[YoutubeService] 자막 추출 실패(exitCode={}) - videoId: {}, stdout: {}",
                        exitCode, videoId, stdoutPreview);
                return null;
            }

            String result = transcript.toString().trim();
            log.info("[YoutubeService] 자막 추출 성공 - videoId: {}, 길이: {}, truncated: {}",
                    videoId, result.length(), truncated);
            return result.isEmpty() ? null : result;

        } catch (Exception e) {
            if (process != null && process.isAlive()) process.destroyForcibly();
            log.error("[YoutubeService] 자막 추출 오류 - videoId: {}", videoId, e);
            return null;
        }
    }

    // ── 자막 추출 오케스트레이션 (yt-dlp : Supadata = 1:1 라운드로빈) ─────────────
    // supadataOnly=true 이면 Supadata 전용. 평시엔 번갈아 호출하여 yt-dlp 응답 지연 시 즉시 감지 가능.

    public String extractTranscriptAuto(String videoId) {
        // yt-dlp 비활성화 또는 Supadata 전용 모드
        if (!ytdlpEnabled || supadataOnly) {
            log.info("[YoutubeService] Supadata 전용 모드 (ytdlpEnabled={}, supadataOnly={}) - videoId: {}", ytdlpEnabled, supadataOnly, videoId);
            String result = extractTranscriptViaSupadata(videoId);
            if (result != null && !result.isBlank()) return result;
            if (ytdlpEnabled) {
                log.warn("[YoutubeService] Supadata 실패 → yt-dlp 폴백 - videoId: {}", videoId);
                return extractTranscriptViaYtDlp(videoId);
            }
            return null;
        }

        // 1:1 라운드로빈 (짝수=yt-dlp 먼저, 홀수=Supadata 먼저)
        int count = transcriptRequestCounter.getAndIncrement();
        boolean ytDlpFirst = (count % 2) == 0;
        log.info("[YoutubeService] 자막 추출 라운드로빈 - videoId: {}, count: {}, ytDlpFirst: {}", videoId, count, ytDlpFirst);

        if (ytDlpFirst) {
            String result = extractTranscriptViaYtDlp(videoId);
            if (result != null && !result.isBlank()) return result;
            log.info("[YoutubeService] yt-dlp 실패 → Supadata 폴백 - videoId: {}", videoId);
            return extractTranscriptViaSupadata(videoId);
        } else {
            String result = extractTranscriptViaSupadata(videoId);
            if (result != null && !result.isBlank()) return result;
            log.info("[YoutubeService] Supadata 실패 → yt-dlp 폴백 - videoId: {}", videoId);
            return extractTranscriptViaYtDlp(videoId);
        }
    }

    // ── Supadata API 자막 추출 ────────────────────────────────────────────────

    public String extractTranscriptViaSupadata(String videoId) {
        String supadataApiKey = apiKeyProperties.getSupadataKey();
        if (supadataApiKey == null || supadataApiKey.isBlank()) {
            log.warn("[YoutubeService] Supadata API 키 미설정 - videoId: {}", videoId);
            return null;
        }
        log.info("[YoutubeService] extractTranscriptViaSupadata 진입 - videoId: {}", videoId);
        try {
            String urlStr = SUPADATA_TRANSCRIPT_URL + "?videoId=" + videoId + "&lang=ko&text=true";
            java.net.HttpURLConnection conn = (java.net.HttpURLConnection) new java.net.URL(urlStr).openConnection();
            conn.setRequestMethod("GET");
            conn.setRequestProperty("x-api-key", supadataApiKey);
            conn.setConnectTimeout(15000);
            conn.setReadTimeout(30000);

            int status = conn.getResponseCode();
            log.info("[YoutubeService] Supadata 응답 - videoId: {}, status: {}", videoId, status);

            if (status != 200) {
                log.warn("[YoutubeService] Supadata 실패 - videoId: {}, status: {}", videoId, status);
                return null;
            }
            try (BufferedReader br = new BufferedReader(new InputStreamReader(conn.getInputStream()))) {
                StringBuilder sb = new StringBuilder();
                String line;
                while ((line = br.readLine()) != null) sb.append(line);
                String body = sb.toString();
                // {"content":"자막 텍스트","lang":"ko","availableLangs":["ko"]}
                // ObjectMapper로 파싱 (regex 사용 시 긴 텍스트에서 StackOverflowError 발생)
                try {
                    Map<String, Object> parsed = objectMapper.readValue(body, new TypeReference<Map<String, Object>>() {});
                    Object contentObj = parsed.get("content");
                    if (contentObj != null) {
                        String text = contentObj.toString().trim();
                        text = unescapeUnicode(text);
                        if (!text.isBlank()) {
                            log.info("[YoutubeService] Supadata 자막 성공 - videoId: {}, length: {}", videoId, text.length());
                            return text.length() > MAX_TRANSCRIPT_CHARS ? text.substring(0, MAX_TRANSCRIPT_CHARS) : text;
                        }
                    }
                } catch (Exception parseEx) {
                    log.warn("[YoutubeService] Supadata 응답 JSON 파싱 실패 - videoId: {}, error: {}", videoId, parseEx.getMessage());
                }
                log.warn("[YoutubeService] Supadata 자막 파싱 실패 - videoId: {}, body: {}", videoId, body.substring(0, Math.min(200, body.length())));
                return null;
            }
        } catch (Exception e) {
            log.error("[YoutubeService] Supadata 오류 - videoId: {}, error: {}", videoId, e.getMessage());
            return null;
        }
    }

    // ── yt-dlp 기반 자막 추출 (신규) ─────────────────────────────────────────
    // downsub.com도 내부적으로 yt-dlp 사용. yt-dlp는 PoToken을 자체 처리하여 YouTube 차단 우회.

    public String extractTranscriptViaYtDlp(String videoId) {
        log.info("[YoutubeService] extractTranscriptViaYtDlp 진입 - videoId: {}", videoId);

        String tmpDir = System.getProperty("java.io.tmpdir");
        String prefix = tmpDir + "/ytdlp_" + videoId;
        String videoUrl = "https://www.youtube.com/watch?v=" + videoId;

        List<String> cmd = new ArrayList<>(List.of(
            "yt-dlp",
            "--skip-download",
            "--write-auto-sub",
            "--write-sub",
            "--sub-langs", "ko.*,en.*,ja.*,zh-Hans.*,zh-Hant.*",
            "--sub-format", "json3/vtt/ttml",
            "--no-playlist",
            "--no-warnings",
            "-q",
            "-o", prefix
        ));
        // 쿠키 파일이 있으면 로그인된 사용자처럼 인식 → IP 차단 우회 효과
        if (cookiesPath != null && !cookiesPath.isBlank()) {
            java.io.File cookieFile = new java.io.File(cookiesPath);
            if (cookieFile.exists()) {
                cmd.add("--cookies");
                cmd.add(cookiesPath);
                log.info("[YoutubeService] yt-dlp 쿠키 사용 - path: {}", cookiesPath);
            } else {
                log.warn("[YoutubeService] yt-dlp 쿠키 파일 없음 - path: {}", cookiesPath);
            }
        }
        cmd.add(videoUrl);
        ProcessBuilder pb = new ProcessBuilder(cmd);
        pb.redirectErrorStream(false);

        Process process = null;
        try {
            log.info("[YoutubeService] yt-dlp subprocess 시작 - videoId: {}", videoId);
            process = pb.start();

            // stderr 읽기 (비동기)
            StringBuilder stderr = new StringBuilder();
            final Process fp = process;
            Thread stderrThread = new Thread(() -> {
                try (BufferedReader er = new BufferedReader(new InputStreamReader(fp.getErrorStream()))) {
                    String line;
                    while ((line = er.readLine()) != null && stderr.length() < 2048) {
                        stderr.append(line).append("\n");
                    }
                } catch (Exception ignored) {}
            });
            stderrThread.setDaemon(true);
            stderrThread.start();

            boolean finished = process.waitFor(TRANSCRIPT_TIMEOUT_SECONDS, TimeUnit.SECONDS);
            if (!finished) {
                process.destroyForcibly();
                log.error("[YoutubeService] yt-dlp 타임아웃({}s) - videoId: {}", TRANSCRIPT_TIMEOUT_SECONDS, videoId);
                return null;
            }

            int exitCode = process.exitValue();
            stderrThread.join(2000);
            log.info("[YoutubeService] yt-dlp 종료 - videoId: {}, exitCode: {}, stderr: {}",
                    videoId, exitCode, stderr.length() > 0 ? stderr.substring(0, Math.min(200, stderr.length())) : "(없음)");

            if (exitCode != 0 && stderr.length() > 0) {
                log.warn("[YoutubeService] yt-dlp 오류 - videoId: {}, stderr: {}", videoId, stderr);
            }

            String transcript = readYtDlpSubtitleFile(prefix, videoId);
            if (transcript != null && !transcript.isBlank()) {
                log.info("[YoutubeService] yt-dlp 자막 추출 성공 - videoId: {}, length: {}", videoId, transcript.length());
                return transcript;
            }

            log.warn("[YoutubeService] yt-dlp 자막 파일 없음 - videoId: {}", videoId);
            return null;

        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            if (process != null && process.isAlive()) process.destroyForcibly();
            log.error("[YoutubeService] yt-dlp 인터럽트 - videoId: {}", videoId);
            return null;
        } catch (Exception e) {
            if (process != null && process.isAlive()) process.destroyForcibly();
            log.error("[YoutubeService] yt-dlp 오류 - videoId: {}, error: {}", videoId, e.getMessage());
            return null;
        } finally {
            cleanupYtDlpTempFiles(videoId);
        }
    }

    private String readYtDlpSubtitleFile(String prefix, String videoId) {
        String[] langs = {"ko", "ko-KR", "ko-Latn", "en", "en-US", "ja", "zh-Hans", "zh-Hant"};
        String[] exts  = {"json3", "vtt", "ttml"};
        for (String lang : langs) {
            for (String ext : exts) {
                java.io.File f = new java.io.File(prefix + "." + lang + "." + ext);
                if (!f.exists()) continue;
                try {
                    String content = java.nio.file.Files.readString(f.toPath());
                    String text = "json3".equals(ext) ? parseJson3Subtitle(content) : parseVttSubtitle(content);
                    if (text != null && !text.isBlank()) {
                        log.info("[YoutubeService] 자막 파일 읽기 성공 - lang: {}, ext: {}, length: {}", lang, ext, text.length());
                        return text.length() > MAX_TRANSCRIPT_CHARS ? text.substring(0, MAX_TRANSCRIPT_CHARS) : text;
                    }
                } catch (Exception e) {
                    log.warn("[YoutubeService] 자막 파일 읽기 실패 - lang: {}, ext: {}, error: {}", lang, ext, e.getMessage());
                }
            }
        }
        // 언어 코드 매칭 실패 시 glob 탐색 (json3, vtt 모두)
        java.io.File tmpDirFile = new java.io.File(System.getProperty("java.io.tmpdir"));
        java.io.File[] files = tmpDirFile.listFiles((dir, name) ->
                name.startsWith("ytdlp_" + videoId) && (name.endsWith(".json3") || name.endsWith(".vtt")));
        if (files != null) {
            for (java.io.File f : files) {
                try {
                    String content = java.nio.file.Files.readString(f.toPath());
                    String text = f.getName().endsWith(".json3") ? parseJson3Subtitle(content) : parseVttSubtitle(content);
                    if (text != null && !text.isBlank()) {
                        log.info("[YoutubeService] 자막 파일(fallback) 읽기 성공 - file: {}", f.getName());
                        return text.length() > MAX_TRANSCRIPT_CHARS ? text.substring(0, MAX_TRANSCRIPT_CHARS) : text;
                    }
                } catch (Exception ignored) {}
            }
        }
        return null;
    }

    private String parseVttSubtitle(String vttContent) {
        // VTT: WEBVTT 헤더, 타임스탬프 라인(-->), 텍스트 순서
        StringBuilder sb = new StringBuilder();
        for (String line : vttContent.split("\n")) {
            line = line.trim();
            if (line.isEmpty() || line.startsWith("WEBVTT") || line.contains("-->")
                    || line.startsWith("NOTE") || line.startsWith("STYLE")
                    || line.matches("\\d+") || line.startsWith("align:") || line.startsWith("position:")) {
                continue;
            }
            // HTML 태그 제거 (<c>, <b>, <i>, 타임스탬프 태그 등)
            line = line.replaceAll("<[^>]+>", "").trim();
            if (!line.isEmpty()) {
                sb.append(line).append(" ");
            }
        }
        return sb.toString().trim();
    }

    private String parseJson3Subtitle(String json3Content) {
        // json3: {"events":[{"segs":[{"utf8":"text"}],"tStartMs":0,"dDurationMs":3000},...]}
        StringBuilder sb = new StringBuilder();
        java.util.regex.Matcher m = java.util.regex.Pattern
                .compile("\"utf8\":\\s*\"((?:[^\"\\\\]|\\\\.)*)\"")
                .matcher(json3Content);
        while (m.find() && sb.length() < MAX_TRANSCRIPT_CHARS) {
            String text = m.group(1)
                    .replace("\\n", " ").replace("\\\"", "\"").replace("\\\\", "\\").trim();
            text = unescapeUnicode(text);
            if (!text.isEmpty() && !text.equals("\\n")) {
                sb.append(text).append(" ");
            }
        }
        return sb.toString().trim();
    }

    private String unescapeUnicode(String s) {
        // Unicode escape 변환 (예: > → >)
        java.util.regex.Matcher m = java.util.regex.Pattern
                .compile("\\\\u([0-9a-fA-F]{4})")
                .matcher(s);
        StringBuffer sb = new StringBuffer();
        while (m.find()) {
            char ch = (char) Integer.parseInt(m.group(1), 16);
            // appendReplacement에서 $와 \가 특수문자로 처리되므로 quoteReplacement 사용
            m.appendReplacement(sb, java.util.regex.Matcher.quoteReplacement(String.valueOf(ch)));
        }
        m.appendTail(sb);
        return sb.toString();
    }

    private void cleanupYtDlpTempFiles(String videoId) {
        try {
            java.io.File tmpDirFile = new java.io.File(System.getProperty("java.io.tmpdir"));
            java.io.File[] files = tmpDirFile.listFiles((dir, name) -> name.startsWith("ytdlp_" + videoId));
            if (files != null) {
                for (java.io.File f : files) {
                    f.delete();
                    log.debug("[YoutubeService] 임시파일 삭제 - {}", f.getName());
                }
            }
        } catch (Exception e) {
            log.warn("[YoutubeService] 임시파일 정리 실패 - videoId: {}", videoId);
        }
    }

    // ── no_transcript 재시도 — 스케줄러에서 호출 ─────────────────────────────

    private static final int RETRY_BATCH_SIZE = 20;

    public void retryNoTranscriptVideos() {
        log.info("[YoutubeService] retryNoTranscriptVideos 시작");
        int pageNum = 0;
        int retried = 0;
        int recovered = 0;
        Page<YoutubeVideo> page;
        do {
            page = videoRepository.findByStatus("no_transcript", PageRequest.of(pageNum++, RETRY_BATCH_SIZE));
            log.info("[YoutubeService] no_transcript 배치 - batch: {}/{}, count: {}",
                    pageNum, page.getTotalPages(), page.getContent().size());
            for (YoutubeVideo video : page.getContent()) {
                String transcript = extractTranscript(video.getVideoId());
                retried++;
                if (transcript != null && !transcript.isBlank()) {
                    video.setTranscriptText(transcript);
                    video.setStatus("done");
                    video.setProcessedAt(LocalDateTime.now());
                    videoRepository.save(video);
                    recovered++;
                    log.info("[YoutubeService] no_transcript 복구 성공 - videoId: {}", video.getVideoId());
                } else {
                    log.debug("[YoutubeService] no_transcript 재시도 실패 - videoId: {}", video.getVideoId());
                }
            }
        } while (!page.isLast());
        log.info("[YoutubeService] retryNoTranscriptVideos 완료 - 재시도: {}, 복구: {}", retried, recovered);
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

    public String summarize(String videoId, String title, String transcript, String summaryType) {
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

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../models/youtube_channel.dart';
import '../services/api_service.dart';

// 앱 지원 30개 언어 목록
const _kLanguages = [
  ('ko', '한국어'),
  ('en', 'English'),
  ('zh', '中文'),
  ('ja', '日本語'),
  ('hi', 'हिन्दी'),
  ('es', 'Español'),
  ('fr', 'Français'),
  ('ar', 'العربية'),
  ('bn', 'বাংলা'),
  ('ru', 'Русский'),
  ('pt', 'Português'),
  ('ur', 'اردو'),
  ('id', 'Bahasa Indonesia'),
  ('de', 'Deutsch'),
  ('sw', 'Kiswahili'),
  ('mr', 'मराठी'),
  ('te', 'తెలుగు'),
  ('tr', 'Türkçe'),
  ('ta', 'தமிழ்'),
  ('fa', 'فارسی'),
  ('uk', 'Українська'),
  ('it', 'Italiano'),
  ('tl', 'Filipino'),
  ('pl', 'Polski'),
  ('ps', 'پښتو'),
  ('ms', 'Bahasa Melayu'),
  ('ro', 'Română'),
  ('nl', 'Nederlands'),
  ('ha', 'Hausa'),
  ('th', 'ไทย'),
];

/// YouTube IFrame 임베드 + 요약 버튼을 포함한 영상 플레이어 시트
Future<void> showYoutubeVideoPlayerSheet({
  required BuildContext context,
  required YoutubeVideo video,
  required YoutubeChannel channel,
  required String? token,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => YoutubeVideoPlayerSheet(
      video: video,
      channel: channel,
      token: token,
    ),
  );
}

class YoutubeVideoPlayerSheet extends StatefulWidget {
  final YoutubeVideo video;
  final YoutubeChannel channel;
  final String? token;

  const YoutubeVideoPlayerSheet({
    super.key,
    required this.video,
    required this.channel,
    required this.token,
  });

  @override
  State<YoutubeVideoPlayerSheet> createState() => _YoutubeVideoPlayerSheetState();
}

class _YoutubeVideoPlayerSheetState extends State<YoutubeVideoPlayerSheet> {
  late final WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    // 데스크톱 유튜브 페이지를 그대로 로드 (스크래핑 X).
    // '스크립트 표시(Show transcript)'는 데스크톱 웹에만 있으므로 데스크톱 UA 사용.
    // 사용자가 네이티브 '더보기 → 스크립트 표시'로 자막을 보고 직접 복사한다.
    // iOS: 인라인 재생 허용 (없으면 영상이 자동 전체화면으로 재생됨)
    final params = Platform.isIOS
        ? WebKitWebViewControllerCreationParams(allowsInlineMediaPlayback: true)
        : const PlatformWebViewControllerCreationParams();
    _webViewController = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36')
      ..addJavaScriptChannel('LittenDiag',
          onMessageReceived: (m) => debugPrint('[TranscriptAuto] ${m.message}'))
      ..setNavigationDelegate(NavigationDelegate(
        // 페이지 로드 후 '더보기' 펼치고 '스크립트 표시'를 자동 클릭
        onPageFinished: (_) => _webViewController.runJavaScript(_autoOpenTranscriptScript),
      ))
      ..loadRequest(Uri.parse('https://www.youtube.com/watch?v=${widget.video.videoId}'));
  }

  /// 데스크톱 유튜브 페이지에서 '더보기 → 스크립트 표시'를 자동으로 클릭하는 스크립트.
  /// 콘텐츠가 비동기로 로드되므로 재시도 폴링한다.
  static const String _autoOpenTranscriptScript = r'''
(function(){
  if (window.__littenTranscriptAuto) return;
  window.__littenTranscriptAuto = true;
  var tries = 0;
  var opened = false;
  var re = /스크립트 표시|show transcript/i;
  function forceInline(){
    var vs = document.querySelectorAll('video');
    for (var i=0;i<vs.length;i++){
      try {
        vs[i].setAttribute('playsinline','');
        vs[i].setAttribute('webkit-playsinline','');
        vs[i].playsInline = true;
      } catch(e){}
    }
  }
  // 초기 전체화면 방지: 즉시 + video 생성 즉시(Observer) + 빠른 초기 루프로 playsinline 설정
  forceInline();
  try {
    var mo = new MutationObserver(function(){ forceInline(); });
    mo.observe(document.documentElement, {childList: true, subtree: true});
    setTimeout(function(){ try { mo.disconnect(); } catch(e){} }, 8000);
  } catch(e){}
  var fast = 0;
  (function fastLoop(){ forceInline(); if (++fast < 25) setTimeout(fastLoop, 150); })();
  function diag(m){ try { LittenDiag.postMessage(m); } catch(e){} }
  function visible(el){
    if (!el || !el.offsetParent) return false;
    var r = el.getBoundingClientRect();
    return r.width > 4 && r.height > 4;
  }
  // 1) 설명 '더보기' 펼치기 — 보이는 expander만, 이미 펼쳐졌으면 건드리지 않음(토글 방지)
  function ensureExpanded(){
    var exps = document.querySelectorAll('ytd-text-inline-expander');
    for (var i=0;i<exps.length;i++){
      var exp = exps[i];
      if (!visible(exp)) continue;
      if (exp.hasAttribute('is-expanded')) return true;
      var b = exp.querySelector('#expand, tp-yt-paper-button#expand');
      if (b && visible(b)) { b.click(); diag('expand 클릭(visible)'); return exp.hasAttribute('is-expanded'); }
    }
    return false;
  }
  // 2) '스크립트 표시' 버튼 클릭 — 매칭 후보를 진단 로그로 출력하고 클릭 가능한 버튼만 클릭
  function clickTranscript(){
    var cand = document.querySelectorAll('button, tp-yt-paper-button, ytd-button-renderer, yt-button-shape, a, yt-formatted-string, span');
    var match = 0;
    for (var i=0;i<cand.length;i++){
      var el = cand[i];
      var lbl = (el.getAttribute && el.getAttribute('aria-label')) || '';
      var txt = (el.textContent || '').trim();
      if (!(re.test(lbl) || re.test(txt))) continue;
      match++;
      var clickable = (el.closest && el.closest('button, tp-yt-paper-button, ytd-button-renderer, yt-button-shape, a')) || el;
      var vis = visible(clickable);
      var top = Math.round(clickable.getBoundingClientRect().top);
      diag('cand#'+match+' '+clickable.tagName+' vis='+vis+' top='+top+' txt="'+txt.slice(0,16)+'" lbl="'+lbl.slice(0,16)+'"');
      if (!vis) continue;
      clickable.scrollIntoView({block:'center'});
      var btn = clickable.querySelector('button') || clickable;
      btn.click();
      diag('클릭 실행 → '+clickable.tagName);
      return true;
    }
    if (match === 0) diag('매칭 0');
    return false;
  }
  function step(){
    tries++;
    forceInline();
    if (!opened) {
      var ex = ensureExpanded();
      if (tries % 5 === 1) diag('step '+tries+' expanded='+ex);
      if (clickTranscript()) { opened = true; diag('완료'); }
    }
    if (!opened && tries < 60) setTimeout(step, 600);
    else if (!opened) diag('포기 (tries='+tries+')');
  }
  setTimeout(step, 1500);
})();
''';

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    // 높이 보장을 위해 DraggableScrollableSheet 사용 (05-25 검증된 구조)
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context2, sc) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Stack(
          children: [
            // 유튜브 watch 페이지 전체 (영상 재생 + 더보기 → 스크립트 표시 등 네이티브 UI)
            Positioned.fill(
              child: WebViewWidget(
                controller: _webViewController,
                gestureRecognizers: {
                  Factory<VerticalDragGestureRecognizer>(
                    () => VerticalDragGestureRecognizer(),
                  ),
                },
              ),
            ),
            // 드래그 핸들 (상단)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                alignment: Alignment.topCenter,
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white70,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // 요약하기 버튼 (우하단)
            Positioned(
              bottom: 24,
              right: 16,
              child: FloatingActionButton.extended(
                onPressed: () => _onSummaryTap(context),
                backgroundColor: color,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('요약하기'),
                elevation: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSummaryTap(BuildContext context) async {
    debugPrint('[YoutubeVideoPlayerSheet] _onSummaryTap 진입 - videoId: ${widget.video.videoId}');

    if (widget.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    // 저작권 동의 + 자막 로딩 다이얼로그 — transcript 문자열을 직접 반환
    if (!context.mounted) return;
    final transcript = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CopyrightConsentDialog(
        token: widget.token!,
        videoId: widget.video.videoId,
      ),
    );

    if (transcript == null || transcript.isEmpty || !context.mounted) return;

    // 자막을 요약 다이얼로그에 전달 — 재요청 없이 바로 요약
    await showDialog<void>(
      context: context,
      builder: (ctx) => _YoutubeSummaryDialog(
        token: widget.token!,
        video: widget.video,
        transcript: transcript,
      ),
    );
  }
}

/// YouTube 스타일 더보기/접기 텍스트 위젯
class _ExpandableText extends StatefulWidget {
  final String text;
  const _ExpandableText({required this.text});

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: Text(
            widget.text,
            style: const TextStyle(fontSize: 14, height: 1.65),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
          secondChild: Text(
            widget.text,
            style: const TextStyle(fontSize: 14, height: 1.65),
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Text(
            _expanded ? '접기' : '더보기',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// 저작권 동의 체크박스 + 자막 데이터 로딩 다이얼로그
class _CopyrightConsentDialog extends StatefulWidget {
  final String token;
  final String videoId;

  const _CopyrightConsentDialog({
    required this.token,
    required this.videoId,
  });

  @override
  State<_CopyrightConsentDialog> createState() => _CopyrightConsentDialogState();
}

class _CopyrightConsentDialogState extends State<_CopyrightConsentDialog> {
  bool _agreed = false;
  bool _loading = false;
  String? _errorMessage;
  String? _transcript;

  Future<void> _fetchTranscript() async {
    debugPrint('[_CopyrightConsentDialog] _fetchTranscript 진입 - videoId: ${widget.videoId}');
    setState(() { _loading = true; _errorMessage = null; });
    try {
      final transcript = await ApiService().extractYoutubeTranscriptViaYtDlp(
        token: widget.token,
        videoId: widget.videoId,
      );
      debugPrint('[_CopyrightConsentDialog] 자막 결과 length: ${transcript?.length}');
      if (!mounted) return;
      if (transcript != null && transcript.isNotEmpty) {
        setState(() { _transcript = transcript; _loading = false; });
      } else {
        setState(() {
          _loading = false;
          _errorMessage = '자막을 가져올 수 없습니다. 자막이 없거나 지원하지 않는 영상입니다.';
        });
      }
    } catch (e) {
      debugPrint('[_CopyrightConsentDialog] 자막 오류: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = '자막 가져오기 실패: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    final canConfirm = _agreed && !_loading && _transcript != null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.policy_outlined, color: color, size: 20),
          const SizedBox(width: 8),
          const Text('자막 요약', style: TextStyle(fontSize: 15)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 로딩 / 완료 / 에러 상태
            if (_loading) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: color),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '자막 데이터를 가져오는 중입니다...',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ] else if (_transcript != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: Colors.green.shade700),
                    const SizedBox(width: 6),
                    Text(
                      '자막 ${_transcript!.length}자 로드 완료',
                      style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ] else if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(_errorMessage!,
                    style: const TextStyle(fontSize: 12, color: Colors.red)),
              ),
              const SizedBox(height: 12),
            ] else ...[
              // 초기 상태: 자막 가져오기 안내
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Text(
                  '요약을 시작하려면 먼저 자막을 가져와야 합니다.\n아래 체크박스에 동의하면 자막을 가져옵니다.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 저작권 동의 체크박스
            InkWell(
              onTap: _loading ? null : () async {
                final newValue = !_agreed;
                setState(() => _agreed = newValue);
                if (newValue && _transcript == null && _errorMessage == null) {
                  await _fetchTranscript();
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _agreed,
                    onChanged: _loading ? null : (v) async {
                      setState(() => _agreed = v ?? false);
                      if ((v ?? false) && _transcript == null && _errorMessage == null) {
                        await _fetchTranscript();
                      }
                    },
                    activeColor: color,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text(
                        '저작권 정책을 준수하며 학습 용도로만 자막을 요약합니다.',
                        style: TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 재시도 버튼 (에러 상태)
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _fetchTranscript,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('다시 시도', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: canConfirm
              ? () => Navigator.of(context).pop(_transcript)
              : null,
          child: const Text('요약하기'),
        ),
      ],
    );
  }
}

/// 요약 옵션 설정 + 실행 다이얼로그 (SummaryDialog와 동일한 UI)
class _YoutubeSummaryDialog extends StatefulWidget {
  final String token;
  final YoutubeVideo video;
  final String transcript;

  const _YoutubeSummaryDialog({
    required this.token,
    required this.video,
    required this.transcript,
  });

  @override
  State<_YoutubeSummaryDialog> createState() => _YoutubeSummaryDialogState();
}

class _YoutubeSummaryDialogState extends State<_YoutubeSummaryDialog> {
  String _textLanguage = 'ko';
  String _summaryLanguage = 'ko';
  int _summaryLevel = 3;
  bool _isLoading = false;
  String? _errorMessage;
  String? _summaryResult;

  String _levelDescription() => switch (_summaryLevel) {
    1 => '핵심 주제와 결론만 · 약 10%',
    2 => '주요 기능과 핵심 논의 · 약 25%',
    3 => '실무 흐름과 설계 의도 · 약 40~50%',
    4 => '전체 논의 흐름 대부분 · 약 70%',
    5 => '전체 맥락 최대한 유지 · 약 90%',
    _ => '실무 흐름과 설계 의도 · 약 40~50%',
  };

  Future<void> _onSummarize() async {
    debugPrint('[_YoutubeSummaryDialog] _onSummarize 진입 - videoId: ${widget.video.videoId}');
    setState(() { _isLoading = true; _errorMessage = null; _summaryResult = null; });

    try {
      // 요약 실행 (자막은 이미 동의 단계에서 가져옴)
      final summary = await ApiService().summarizeText(
        text: widget.transcript,
        textLanguage: _textLanguage,
        summaryLanguage: _summaryLanguage,
        summaryLevel: _summaryLevel,
      );

      debugPrint('[_YoutubeSummaryDialog] 요약 완료 - length: ${summary.length}');

      // 자막 저장
      await ApiService().saveYoutubeTranscript(
        token: widget.token,
        videoId: widget.video.videoId,
        transcript: widget.transcript,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _summaryResult = summary;
      });
    } catch (e) {
      debugPrint('[_YoutubeSummaryDialog] 오류: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '요약 실패: $e';
      });
    }
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  );

  Widget _buildDropdown({
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isDense: true,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: _kLanguages
          .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2, style: const TextStyle(fontSize: 13))))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildLevelDropdown() {
    const items = [
      (1, '한줄 요약'),
      (2, '간단 요약'),
      (3, '일반 요약'),
      (4, '상세 요약'),
      (5, '거의 전체'),
    ];
    return DropdownButtonFormField<int>(
      initialValue: _summaryLevel,
      isDense: true,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2, style: const TextStyle(fontSize: 13))))
          .toList(),
      onChanged: (v) => setState(() => _summaryLevel = v!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.auto_awesome, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.video.title,
              style: const TextStyle(fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 요약 결과 표시
              if (_summaryResult != null) ...[
                Container(
                  width: double.maxFinite,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    _summaryResult!,
                    style: const TextStyle(fontSize: 13, height: 1.65),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
              ],

              // 대상 언어
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 80, child: _buildLabel('대상 언어')),
                  Expanded(
                    child: _buildDropdown(
                      value: _textLanguage,
                      onChanged: (v) => setState(() => _textLanguage = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 요약 언어
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 80, child: _buildLabel('요약 언어')),
                  Expanded(
                    child: _buildDropdown(
                      value: _summaryLanguage,
                      onChanged: (v) => setState(() => _summaryLanguage = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 요약 수준
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 80, child: _buildLabel('요약 수준')),
                  Expanded(child: _buildLevelDropdown()),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                width: double.maxFinite,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _levelDescription(),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.5),
                ),
              ),

              // 에러
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.maxFinite,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(_errorMessage!,
                      style: const TextStyle(fontSize: 12, color: Colors.red)),
                ),
              ],

              // 로딩
              if (_isLoading) ...[
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: color),
                      const SizedBox(height: 8),
                      const Text('자막을 가져와 요약 중입니다...',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
        if (_summaryResult == null)
          FilledButton.icon(
            onPressed: _isLoading ? null : _onSummarize,
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('요약하기'),
          ),
      ],
    );
  }
}

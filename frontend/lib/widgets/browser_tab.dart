import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/app_state_provider.dart';
import '../services/bookmark_service.dart';
import '../services/session_service.dart';
import '../widgets/webview/bookmark_widget.dart';
import '../widgets/empty_state.dart';

class BrowserTab extends StatefulWidget {
  const BrowserTab({super.key});

  @override
  State<BrowserTab> createState() => _BrowserTabState();
}

class _BrowserTabState extends State<BrowserTab> {
  WebViewController? _webViewController;
  String _currentUrl = '';
  final TextEditingController _urlController = TextEditingController();
  final BookmarkService _bookmarkService = BookmarkService();
  final SessionService _sessionService = SessionService();
  bool _isCurrentUrlBookmarked = false;
  bool _showBookmarks = false;
  bool _isLoading = false;
  String _pageTitle = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWebView();
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return Container(
          color: Colors.purple.shade50,
          child: Column(
            children: [
              // URL 입력 영역
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  border: Border(
                    bottom: BorderSide(color: Colors.purple.shade200),
                  ),
                ),
                child: Column(
                  children: [
                    // 브라우저 제목
                    Row(
                      children: [
                        Icon(
                          Icons.public,
                          color: Colors.purple.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _pageTitle.isNotEmpty ? _pageTitle : '브라우저',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isLoading)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.purple.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // URL 입력 필드
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _urlController,
                            decoration: InputDecoration(
                              hintText: 'URL 또는 검색어를 입력하세요...',
                              prefixIcon: const Icon(Icons.language),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            onSubmitted: (url) {
                              if (url.isNotEmpty) {
                                _loadUrl(url);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 내비게이션 버튼들
                        Row(
                          children: [
                            IconButton(
                              onPressed: _canGoBack ? _goBack : null,
                              icon: const Icon(Icons.arrow_back),
                              tooltip: '뒤로',
                            ),
                            IconButton(
                              onPressed: _canGoForward ? _goForward : null,
                              icon: const Icon(Icons.arrow_forward),
                              tooltip: '앞으로',
                            ),
                            IconButton(
                              onPressed: _reload,
                              icon: const Icon(Icons.refresh),
                              tooltip: '새로고침',
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        // 즐겨찾기 버튼
                        IconButton(
                          onPressed: _toggleBookmark,
                          icon: Icon(
                            _isCurrentUrlBookmarked ? Icons.bookmark : Icons.bookmark_border,
                            color: _isCurrentUrlBookmarked ? Colors.amber : Colors.grey,
                          ),
                          tooltip: '즐겨찾기',
                        ),
                        IconButton(
                          onPressed: _toggleBookmarksList,
                          icon: Icon(
                            Icons.bookmark,
                            color: _showBookmarks ? Colors.purple.shade700 : Colors.grey,
                          ),
                          tooltip: '즐겨찾기 목록',
                        ),
                        ElevatedButton(
                          onPressed: () {
                            if (_urlController.text.isNotEmpty) {
                              _loadUrl(_urlController.text);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple.shade700,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('이동'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // WebView 영역 또는 즐겨찾기 목록
              Expanded(
                child: _showBookmarks
                    ? BookmarkWidget(
                        onBookmarkTap: _onBookmarkSelected,
                        currentUrl: _currentUrl,
                      )
                    : _webViewController != null
                        ? WebViewWidget(controller: _webViewController!)
                        : FutureBuilder(
                            future: _initializeWebView(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        color: Colors.purple.shade700,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        '구글 홈페이지를 로드하는 중...',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              } else if (_webViewController != null) {
                                return WebViewWidget(controller: _webViewController!);
                              } else {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        size: 48,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        '브라우저를 로드할 수 없습니다.',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ElevatedButton(
                                        onPressed: _initializeWebView,
                                        child: const Text('다시 시도'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _canGoBack = false;
  bool _canGoForward = false;

  // WebView URL 로드 함수
  void _loadUrl(String url) async {
    if (url.isEmpty) return;

    // URL 정규화 - http:// 또는 https://가 없으면 추가
    String finalUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      // 검색어인지 URL인지 판단
      if (url.contains('.') && !url.contains(' ')) {
        finalUrl = 'https://$url';
      } else {
        // 검색어로 처리
        finalUrl = 'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
      }
    }

    try {
      if (_webViewController == null) {
        // WebViewController 초기화
        _webViewController = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0x00000000))
          ..setNavigationDelegate(
            NavigationDelegate(
              onProgress: (int progress) {
                // 로딩 진행률 처리
              },
              onPageStarted: (String url) {
                setState(() {
                  _currentUrl = url;
                  _urlController.text = url;
                  _isLoading = true;
                });
                _updateBookmarkStatus();
              },
              onPageFinished: (String url) async {
                setState(() {
                  _currentUrl = url;
                  _urlController.text = url;
                  _isLoading = false;
                });
                _updateBookmarkStatus();
                _updateNavigationButtons();

                // 페이지 제목 가져오기
                final title = await _getPageTitle();
                if (title != null && title.isNotEmpty) {
                  setState(() {
                    _pageTitle = title;
                  });
                }

                // 세션에 URL 저장
                _sessionService.saveActiveUrl(url);
                // 백그라운드 재생 설정
                _enableBackgroundPlayback();
              },
              onWebResourceError: (WebResourceError error) {
                debugPrint('WebView error: ${error.description}');
                setState(() {
                  _isLoading = false;
                });
              },
            ),
          );
      }

      await _webViewController!.loadRequest(Uri.parse(finalUrl));
      setState(() {
        _currentUrl = finalUrl;
        _urlController.text = finalUrl;
        _isLoading = true;
      });
    } catch (e) {
      debugPrint('[BrowserTab] URL 로드 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 즐겨찾기 상태 업데이트
  Future<void> _updateBookmarkStatus() async {
    final isBookmarked = await _bookmarkService.isBookmarked(_currentUrl);
    setState(() {
      _isCurrentUrlBookmarked = isBookmarked;
    });
  }

  // 내비게이션 버튼 상태 업데이트
  void _updateNavigationButtons() async {
    if (_webViewController != null) {
      final canGoBack = await _webViewController!.canGoBack();
      final canGoForward = await _webViewController!.canGoForward();
      setState(() {
        _canGoBack = canGoBack;
        _canGoForward = canGoForward;
      });
    }
  }

  // 즐겨찾기 토글
  void _toggleBookmark() async {
    if (_currentUrl.isEmpty) return;

    final title = await _getPageTitle() ?? _currentUrl;

    if (_isCurrentUrlBookmarked) {
      await _bookmarkService.removeBookmark(_currentUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('즐겨찾기에서 제거되었습니다.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      await _bookmarkService.addBookmark(_currentUrl, title);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('즐겨찾기에 추가되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
    _updateBookmarkStatus();
  }

  // 즐겨찾기 목록 토글
  void _toggleBookmarksList() {
    setState(() {
      _showBookmarks = !_showBookmarks;
    });
  }

  // 즐겨찾기에서 URL 선택
  void _onBookmarkSelected(String url) {
    _urlController.text = url;
    _loadUrl(url);
    setState(() {
      _showBookmarks = false;
    });
  }

  // 뒤로 가기
  void _goBack() async {
    if (_webViewController != null && _canGoBack) {
      await _webViewController!.goBack();
      _updateNavigationButtons();
    }
  }

  // 앞으로 가기
  void _goForward() async {
    if (_webViewController != null && _canGoForward) {
      await _webViewController!.goForward();
      _updateNavigationButtons();
    }
  }

  // 새로고침
  void _reload() async {
    if (_webViewController != null) {
      await _webViewController!.reload();
    }
  }

  // 웹뷰에서 백그라운드 미디어 재생을 활성화합니다
  Future<void> _enableBackgroundPlayback() async {
    if (_webViewController == null) return;

    try {
      // iOS와 Android에서 백그라운드 대응
      await _webViewController!.runJavaScript('''
        (() => {
          // 비디오 요소들에 백그라운드 재생 속성 추가
          const videos = document.querySelectorAll('video');
          videos.forEach(video => {
            video.setAttribute('playsinline', 'true');
            video.setAttribute('webkit-playsinline', 'true');

            // iOS Safari에서 백그라운드 재생 허용
            if (video.webkitEnterFullscreen) {
              video.addEventListener('webkitbeginfullscreen', () => {
                video.style.position = 'fixed';
                video.style.top = '0';
                video.style.left = '0';
                video.style.width = '100%';
                video.style.height = '100%';
                video.style.zIndex = '9999';
              });
            }
          });

          // 오디오 요소들에 백그라운드 재생 속성 추가
          const audios = document.querySelectorAll('audio');
          audios.forEach(audio => {
            audio.setAttribute('preload', 'metadata');
          });

          // Web Audio API를 통한 백그라운드 재생 지원
          if (typeof AudioContext !== 'undefined' || typeof webkitAudioContext !== 'undefined') {
            const AudioContext = window.AudioContext || window.webkitAudioContext;
            if (AudioContext) {
              const audioContext = new AudioContext();
              // 오디오 컨텍스트 상태 확인 및 재생 유지
              if (audioContext.state === 'suspended') {
                audioContext.resume();
              }
            }
          }

          console.log('백그라운드 재생 설정 완료');
        })()
      ''');

      debugPrint('✅ 웹뷰 백그라운드 재생 설정 완료');
    } catch (e) {
      debugPrint('❌ 웹뷰 백그라운드 재생 설정 에러: $e');
    }
  }

  // WebView 초기화
  Future<void> _initializeWebView() async {
    if (_webViewController == null) {
      // 우선순위: 1) 현재 _currentUrl 2) SessionService 활성 URL 3) 기본 URL
      String urlToLoad;
      if (_currentUrl.isNotEmpty) {
        urlToLoad = _currentUrl;
      } else {
        final activeUrl = _sessionService.getCurrentActiveUrl();
        if (activeUrl != null && activeUrl.isNotEmpty) {
          urlToLoad = activeUrl;
          _currentUrl = activeUrl; // 복원된 URL로 _currentUrl 업데이트
        } else {
          urlToLoad = _sessionService.getDefaultUrl();
        }
      }
      debugPrint('🌐 WebView 초기화: $_currentUrl → $urlToLoad');
      _loadUrl(urlToLoad);
    }
  }

  // 페이지 제목 가져오기
  Future<String?> _getPageTitle() async {
    try {
      if (_webViewController != null) {
        return await _webViewController!.getTitle();
      }
    } catch (e) {
      debugPrint('[BrowserTab] 페이지 제목 가져오기 오류: $e');
    }
    return null;
  }
}